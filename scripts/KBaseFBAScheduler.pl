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
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Bio::KBase::AuthToken;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode);
use Bio::KBase::fbaModelServices::Impl;
use Bio::KBase::fbaModelServices::Server;

$|=1;

#Creating the error message printed whenever the user input makes no sense
my $Usage = "Scheduler must be called with the following syntax:\n".
			"kbasefbascheduler monitor <process count>\n".
			"kbasefbascheduler runjob <workspace> <id> <auth>\n".
			"kbasefbascheduler addjob <workspace> <id> <auth>\n".
			"kbasefbascheduler killjobs\n";
my $sched = scheduler->new({directory => $Bin});
#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print $Usage;
	exit(0);
}
#Running requested functions
if ($ARGV[0] eq "monitor") {
	$sched->monitor($ARGV[1]);
} elsif ($ARGV[0] eq "runjob") {
	$sched->run($ARGV[1],$ARGV[2],$ARGV[3]);
} elsif ($ARGV[0] eq "addjob") {
	$sched->queueJob($ARGV[1],$ARGV[2],$ARGV[3]);
} elsif ($ARGV[0] eq "killjobs") {
	$sched->haltalljobs();
}
#Declaring scheduler package
package scheduler;

sub new {
	my ($self,$params) = @_;
	my $self = {_directory => $params->{directory},_client => get_ws_client()};
    return bless $self;
}

sub directory {
    my ($self) = @_;
	return $self->{_directory};
}

sub client {
    my ($self) = @_;
	return $self->{_client};
}

sub runexecutable {
	my ($self,$cmd) = @_;
	my $OutputArray;
	push(@{$OutputArray},`$cmd`);
	return $OutputArray;
}

sub runningJobs {
	my ($self) = @_;
	my $output = $self->runexecutable("qstat");
	my $runningJobs;
	if (defined($output)) {
		foreach my $line (@{$output}) {
			if ($line =~ m/^(\d+)\s/) {
				$runningJobs->{$1} = 1;
			}
		}
	}
	return $runningJobs;
}

sub monitor {
    my($self,$count) = @_;
    if (!defined($count)) {
		print STDERR "Syntax for monitor command: kbasefbascheduler monitor <process count>";
		die;
    }
    my $continue = 1;
	while ($continue == 1) {
		my $runningJobs = $self->runningJobs();
		my $runningCount = keys(%{$runningJobs});
		if ($runningCount < $count) {
			my $openSlots = ($count - $runningCount);
			#Checking if outstanding queued jobs exist
			my $jobs = $self->client()->get_jobs({
				status => "queued",
				auth => auth()
			});
			#Queuing jobs
			while ($openSlots > 0 && @{$jobs} > 0) {
				my $job = shift(@{$jobs});
				#if ($self->set_job_status({
				#	jobid => $job->{id},
				#	jobws => $job->{ws},
				#	status => "running",
				#	auth => $job->{auth}
				#}) == 1) {
				print $openSlots.":".$job->{ws}."/".$job->{id}."/".$job->{auth}."\n\n";
				#	$self->queueJob($job->{ws},$job->{id},$job->{auth});
					$openSlots--;
				#}
			}	
		}
		print "Sleeping...\n";
		sleep(30);
	}
}

sub queueJob {
	my ($self,$ws,$id,$auth) = @_;
	my $cmd = "qsub -l fs_scratch=100 -l arch=lx26-amd64 -b yes -e ".$self->directory()."/errors/ -o ".$self->directory()."/output/ ".$self->directory()."/scheduler.sh run ".$ws." ".$id." ".$auth;
	system($cmd);	
}

sub run {
	my($self,$ws,$id,$auth) = @_;
	my $obj = Bio::KBase::fbaModelServices::Impl->new();
	$obj->run_job({
		jobid => $id,
		workspace => $ws,
		"index" => 0,
		auth => $auth
	});
}

sub haltalljobs {
    my($self) = @_; 
	my $output = $self->runexecutable("qstat");
	if (defined($output)) {
		foreach my $line (@{$output}) {
			if ($line =~ m/^(\d+)\s/) {
				system("qdel ".$1);
			}
		}
	}
}

1;
