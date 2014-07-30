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
my $primaryArgs = ["Pangenome ID"];
my $servercommand = "genome_heatmap_from_pangenome";
my $script = "ga-heatmap-from-pangenome";
my $translation = {
	"Pangenome ID" => "pangenome",
	pangenomews => "pangenome_workspace",
	workspace => "workspace",
};

#Defining usage and options
my $specs = [
    [ 'pangenomews=s', 'Workspace with pangenome object' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Generation of heatmap failed!\n";
} else {
	print "Generation of heatmap successful:\n";
	print "Labels\t".join("\t",@{$output->{labels}})."\n";
	for (my $i=0; $i < @{$output->{labels}}; $i++) {
		print $output->{labels}->[$i]."\t".join("\t",@{$output->{matrix}->[$i]})."\n";
	}
}