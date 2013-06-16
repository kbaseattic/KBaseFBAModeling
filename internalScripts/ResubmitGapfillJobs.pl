#!/usr/bin/perl -w

use strict;
use warnings;
use JSON::XS;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
use LWP::Simple;
use Config::Simple;
use Bio::KBase::workspaceService::Client;

$|=1;
if (!defined($ARGV[0])) {
	exit(0);
}
my $directory = $ARGV[0];
my $c = Config::Simple->new();
$c->read($directory."/config.ini");
my $url = $c->param("GapFillManager.wsurl");
my $auth = $c->param("GapFillManager.auth");
my $wserv = Bio::KBase::workspaceService::Client->new($url);

open(PID, "> ".$directory."/PID") || die "could not open PID file\n!"; 
print PID "$$\n"; 
close(PID);
while(1) {
	my $jobs = $wserv->get_jobs({
		type => "FBA",
		status => "error",
		auth => $auth
	});
	print @{$jobs}." jobs with errors!\n";
	for (my $i=0; $i < @{$jobs}; $i++) {
		my $job = $jobs->[$i];
		if (defined($job->{jobdata}->{error}) && $job->{jobdata}->{error} =~ m/Gapfilling\scompleted,\sbut\sno\svalid\ssolutions\sfound/) {
			my $newJobData;
			if (!defined($job->{jobdata}->{newgapfilltime})) {
				$newJobData = {newgapfilltime => 14400,error => ""};
			} elsif ($job->{jobdata}->{newgapfilltime} == 14400) {
				$newJobData = {newgapfilltime => 43200,error => ""};
			} elsif ($job->{jobdata}->{newgapfilltime} == 43200) {
				$newJobData = {newgapfilltime => 86400,error => ""};
			}
			if (defined($newJobData)) {
				print "Resubmitting ".$job->{id}." for ".$newJobData->{newgapfilltime}." seconds!\n";
				eval {
					$wserv->set_job_status({
						auth => $auth,
						jobid => $job->{id},
						currentStatus => "error",
						status => "queued",
						jobdata => $newJobData
					});
				};
			} else {
				print $job->{id}." does not solve after 24 hours!\n";
			}
		} else {
			print $job->{id}." not a timeout error!\n";
		}
	}
	sleep(180);
}

1;
