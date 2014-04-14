#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw( get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws printJobData get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Job ID"];
my $servercommand = "run_job";
my $script = "fba-runjob";
my $translation = {
	"Job ID" => "job",
	auth => "auth",
	usecpx => "usecpx",
	overrideauth => "overrideauth"
};
my $specs = [
	[ 'usecpx|u', 'Run with alternative solver' ],
	[ 'overrideauth|o', 'Use current auth key for job instead of job auth key' ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Job run failed!\n";
} else {
	print "Successfully ran job:\n";
	printJobData($output);
}
