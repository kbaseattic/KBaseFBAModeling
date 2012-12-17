#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client printJobData runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Job ID"];
my $servercommand = "check_job";
my $script = "kbfba-checkjob";
my $translation = {
	"Job ID" => "jobid",
	workspace => "workspace",
	auth => "auth",
};
#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace containing job object', { "default" => workspace() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Job check failed!\n";
} else {
	print "Retrieved job object for checking:\n";
	printJobData($output);
}
