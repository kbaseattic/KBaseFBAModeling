#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo printJobData get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID"];
my $servercommand = "domains_to_workspace";
my $script = "ga-get_genome_cdd";
my $translation = {
	outputid => "output_id",
	"Genome ID" => "genome",
	workspace => "workspace"
};

#Defining usage and options
my $specs = [
    [ 'outputid=s', 'ID for created domain object in workspace' ],
    [ 'workspace|w=s', 'Workspace to save CDD object to', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Generation of domain object failed!\n";
} else {
	print "Generation of domain object successful:\n";
	printObjectInfo($output);
}
