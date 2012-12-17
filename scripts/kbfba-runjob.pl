#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Job ID"];
my $servercommand = "run_job";
my $script = "kbfba-runjob";
my $translation = {
	"Job ID" => "jobid",
	"index" => "index",
	workspace => "workspace",
	auth => "auth",
};
my $specs = [
	[ 'index|i:i', 'Index of subjob to run', { "default" => 0 } ],
    [ 'workspace|w:s', 'Workspace containing job object', { "default" => workspace() } ]
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
