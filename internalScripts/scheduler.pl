#!/usr/bin/perl -w

########################################################################
# This perl script runs the designated queue for model reconstruction
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 10/6/2009
########################################################################
use strict;
use warnings;
use JSON::XS;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
use LWP::Simple;
use Config::Simple;
use Bio::KBase::AuthToken;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspaceURL);

$|=1;

#Creating the error message printed whenever the user input makes no sense
my $Usage = "Scheduler must be called with the following syntax:\n".
			"scheduler <config file>\n";
#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print $Usage;
	exit(0);
}
my $sched = scheduler->new();
$sched->readconfig($ARGV[0]);
if (!-d $sched->jobdirectory()) {
	mkdir $sched->jobdirectory();
}
if (!-d $sched->jobdirectory()."/jobs/") {
	mkdir $sched->jobdirectory()."/jobs/";
}
if (!-d $sched->jobdirectory()."/errors/") {
	mkdir $sched->jobdirectory()."/errors/";
}
if (!-d $sched->jobdirectory()."/output/") {
	mkdir $sched->jobdirectory()."/output/";
}
if (-e $sched->jobdirectory()."/schedulerPID") {
	unlink($sched->jobdirectory()."/schedulerPID");
}
open(PID, "> ".$sched->jobdirectory()."/../pids/schedulerPID") || die "could not open PID file!"; 
print PID "$$\n"; 
close(PID);
$sched->monitor();

#Declaring scheduler package
package scheduler;

sub new {
	my ($class,$params) = @_;
	my $self = {_directory => $params->{directory}};
    return bless $self;
}

sub directory {
    my ($self) = @_;
	return $self->{_directory};
}

sub client {
    my ($self) = @_;
    if (!defined($self->{_client})) {
    	if ($self->wsurl() eq "impl") {
			require "Bio/KBase/workspaceService/Impl.pm";
			$self->{_client} = Bio::KBase::workspaceService::Impl->new();
		} else {
    		$self->{_client} = Bio::KBase::workspaceService::Client->new($self->wsurl());
		}
    }
	return $self->{_client};
}

sub runexecutable {
	my ($self,$cmd) = @_;
	my $OutputArray;
	push(@{$OutputArray},`$cmd`);
	return $OutputArray;
}

sub runningJobs {
	my ($self,$type) = @_;
	my $runningJobs;
	if ($self->queuetype() eq "sge") {
		my $output = $self->runexecutable("qstat");
		if (defined($output)) {
			foreach my $line (@{$output}) {
				if ($line =~ m/^(\d+)\s/) {
					$runningJobs->{$1} = 1;
				}
			}
		}
	} elsif ($self->queuetype() eq "nohup") {
		my $output = $self->runexecutable("ps -A");
		if (defined($output)) {
			foreach my $line (@{$output}) {
				if ($line =~ m/^\s+(\d+)\s.+\/([^\/]+)/) {
					my $cmd = $2;
					my $pid = $1;
					my $script = $self->script($type);
					if ($cmd =~ m/$script/) {
						print "Match:".$pid."|".$script."\n";
						$runningJobs->{$pid} = 1;
					}
				}
			}
		}
	}
	return $runningJobs;
}

sub monitor {
    my($self) = @_;
    my $continue = 1;
	my $jobHash = $self->jobtypes();
	while ($continue == 1) {
		local $Bio::KBase::workspaceService::Server::CallContext = {};
		foreach my $type (keys(%{$jobHash})) {
			my $count = $jobHash->{$type}->{threads};
			my $jobs;
			eval {
				$jobs = $self->client()->get_jobs({
					status => "running",
					type => $type,
					auth => $self->auth()
				});
			};
			if (defined($jobs)) {
				my $runningCount = @{$jobs};
				#Checking if outstanding queued jobs exist
				my $runningJobs = $self->runningJobs($type);
				for (my $i=0; $i < @{$jobs}; $i++) {
					my $job = $jobs->[$i];
					if (-d $self->jobdirectory()."/jobs/".$job->{id}) {
						if (defined($job->{jobdata}->{qsubid})) {
							my $id = $job->{jobdata}->{qsubid};
							if (!defined($runningJobs->{$id})) {
								my $input = {
									jobid => $job->{id},
									status => "error",
									auth => $self->auth(),
									currentStatus => "running"
								};
								my $filename = $self->jobdirectory()."/errors/".$self->script($type).".e".$id;
								if (-e $filename) {
									my $error = "";
									open (INPUT, "<", $filename);
								    while (my $Line = <INPUT>) {
								        chomp($Line);
								        $Line =~ s/\r//;
										$error .= $Line."\n";
								    }
								    close(INPUT);
									$input->{jobdata}->{error} = $error;
								}
								eval {
									local $Bio::KBase::workspaceService::Server::CallContext = {};
									my $status = $self->client()->set_job_status($input);
								};
								$runningCount--;
							}
						} else {
							my $input = {
								jobid => $job->{id},
								status => "error",
								auth => $self->auth(),
								currentStatus => "running",
								jobdata => {error => "Failed to queue in cluster!"}
							};
							eval {
								local $Bio::KBase::workspaceService::Server::CallContext = {};
								my $status = $self->client()->set_job_status($input);
							};
							$runningCount--;
						}
					} elsif (!-d $self->jobdirectory()."/jobs/".$job->{id}) {
						print $job->{id}." running in another cluster!\n";
						$runningCount--;
					}
				}
				print $runningCount." jobs of type ".$type." now running on this cluster!\n";
				#Queuing new jobs
				my $openSlots = ($count - $runningCount);
				$jobs = [];
				eval {
					$jobs = $self->client()->get_jobs({
						status => "queued",
						type => $type,
						auth => $self->auth()
					});
				};
				print @{$jobs}." jobs of type ".$type." with ".$openSlots." open slots!\n";
				if (defined($jobs) && $openSlots > 0) {
					while ($openSlots > 0 && @{$jobs} > 0) {
						my $job = shift(@{$jobs});
						print "Queuing job:".$job->{id}."\n";
						$self->queueJob($job);
						$openSlots--;
					}
				}
			}
		}
		print "Deleting old files...\n";
		$self->clearAllOldFiles();
		print "Sleeping...\n";
		sleep(60);
	}
}

sub printJobFile {
	my ($self,$job) = @_;
	$job->{wsurl} = $self->wsurl();
	my $JSON = JSON::XS->new();
    my $data = $JSON->encode($job);
	my $directory = $self->jobdirectory()."/jobs/".$job->{id}."/";
	if (!-d $directory) {
		mkdir $directory;
	}
	if (-e $directory."jobfile.json") {
		unlink $directory."jobfile.json";
	}
	if (-e $directory."pid") {
		unlink $directory."pid";
	}
	open(my $fh, ">", $directory."jobfile.json") || return;
	print $fh $data;
	close($fh);
	return $directory;
}

sub queueJob {
	my ($self,$job) = @_;
	$job->{accounttype} = $self->accounttype();
	my $jobdir = $self->printJobFile($job);
	my $pid;
	my $executable = $self->jobtypes()->{$job->{type}}->{executable}." ".$ARGV[0]." ".$job->{id};
	if ($self->queuetype() eq "sge") {
		my $cmd = "qsub -l arch=lx26-amd64 -b yes -e ".$self->jobdirectory()."/errors/ -o ".$self->jobdirectory()."/output/ ".$executable;	
		my $execOut = $self->runexecutable($cmd);
		foreach my $line (@{$execOut}) {
			if ($line =~ m/Your\sjob\s(\d+)\s/) {
				$pid = ($1+1-1);
				last;
			}
		}
	} elsif ($self->queuetype() eq "nohup") {
		my $cmd = "nohup ".$executable." > ".$jobdir."stdout.log 2> ".$jobdir."stderr.log &";
	  	system($cmd);
	  	open( my $fh, "<", $jobdir."pid");
		$pid = <$fh>;
		close($fh);
	}
	eval {
		local $Bio::KBase::workspaceService::Server::CallContext = {};
		my $status = $self->client()->set_job_status({
			jobid => $job->{id},
			status => "running",
			auth => $self->auth(),
			jobdata => {
				schedulerstatus => $self->jobtypes()->{$job->{type}}->{status},
				qsubid => $pid
			}
		});
	};
}

sub haltalljobs {
    my($self) = @_;
	my $jobHash = $self->jobtypes();
	foreach my $type (keys(%{$jobHash})) {
		my $runningJobs = $self->runningJobs($type);
		foreach my $key (keys(%{$runningJobs})) {
			if ($self->queuetype() eq "sge") {
				system("qdel ".$key);
			} elsif ($self->queuetype() eq "nohup") {
				system("kill -9 ".$key);
			}		
		}
	}
}

sub readconfig {
    my($self,$file) = @_; 
	my $c = Config::Simple->new();
	$c->read($file);
	$self->{_jobdirectory} = $c->param("scheduler.jobdirectory");
	$self->{_wsurl} = $c->param("scheduler.wsurl");
	$self->{_auth} = $c->param("scheduler.auth");
	$self->{_queuetype} = $c->param("scheduler.queuetype");
	$self->{_accounttype} = $c->param("scheduler.accounttype");
	my $types = [split(/;/,$c->param("scheduler.jobtype"))];
	my $executables = [split(/;/,$c->param("scheduler.executable"))];
	my $statuses = [split(/;/,$c->param("scheduler.jobstatus"))];
	my $threads = [split(/;/,$c->param("scheduler.threads"))];
	for (my $i=0; $i < @{$types}; $i++) {
		$self->{_jobtypes}->{$types->[$i]} = {
			type => $types->[$i],
			executable => $executables->[$i],
			status => $statuses->[$i],
			threads => $threads->[$i]
		};
	}
}

sub wsurl {
	 my($self) = @_;
	 return $self->{_wsurl};
}

sub queuetype {
	 my($self) = @_;
	 return $self->{_queuetype};
}

sub jobdirectory {
	 my($self) = @_;
	 return $self->{_jobdirectory};
}

sub jobtypes {
	my($self) = @_;
	return $self->{_jobtypes};
}

sub script {
	my($self,$type) = @_;
	if ($self->jobtypes()->{$type}->{executable} =~ m/([^\/]+)$/) {
		return $1;
	}
	return "";
}

sub auth {
	 my($self) = @_;
	 return $self->{_auth};
}

sub accounttype {
	my($self) = @_;
	return $self->{_accounttype};
}

sub clearOldDirectoryFiles {
	my($self,$directory) = @_;
	my $now = time();       # get current time
	my $age = 60*60*24*3;  # convert 3 days into seconds
	my $files = [];
	opendir(DIR,$directory) || die "Can't open $directory : $!\n";
	push(@{$files},readdir(DIR));
	close(DIR);
	foreach my $file (@{$files}) {	
		my @stat = stat($directory."/".$file);
		if ($stat[9] < ($now - $age)) {
			unlink($directory."/".$file);
		}
	}
}

sub clearAllOldFiles {
	my($self) = @_;
	my $directories = [qw(errors output jobs)];
	for (my $i=0; $i < @{$directories}; $i++) {
		$self->clearOldDirectoryFiles($sched->jobdirectory()."/".$directories->[$i]."/");
	}
}

1;
