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
my $primaryArgs = ["Pangenome ID","Genome one","Genome two"];
my $servercommand = "pangenome_to_proteome_comparison";
my $script = "ga-protcomp-from-pangenome";
my $translation = {
	"Pangenome ID" => "pangenome",
	"Genome one" => "genomeone",
	"Genome two" => "genometwo",
	pangenomews => "pangenome_workspace",
	workspace => "workspace",
	outid => "outputid" 
};
#Defining usage and options
my $specs = [
    [ 'outid=s', 'Workspace with pangenome object' ],
    [ 'pangenomews=s', 'Workspace with pangenome object' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Generation of protein comparison failed!\n";
} else {
	print "Generation of protein comparison successful:\n";
	printObjectInfo($output);
}