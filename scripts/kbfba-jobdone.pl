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
my $servercommand = "jobs_done";
my $script = "kbfba-jobdone";
my $translation = {
	"Job ID" => "job",
	auth => "auth",
};
#Defining usage and options
my $specs = [];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Job done failed!\n";
} else {
	print "Job done succeeded!\n";
}
