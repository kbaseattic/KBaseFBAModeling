#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger, Mike Mundy, Matt Benedict
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
use Bio::KBase::CDMI::CDMIClient;

#Defining globals describing behavior
my $primaryArgs = ["Genome ID", "Reaction prob filename"];
my $servercommand = "genome_to_probfbamodel";
my $script = "fba-buildprobfbamodel";
my $translation = {
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	model => "model",
	outputid => "model",
	workspace => "workspace",
	defaultprob => "default_prob",
	rxnprobs => "reaction_probs",
};
#Defining usage and options
my $specs = [
    [ 'model|outputid|m:s', 'ID of the output model' ],
    [ 'workspace|w:s', 'Workspace where output model object is stored', { "default" => fbaws() } ],
    [ 'genomews:s', 'Workspace where genome object is located' ],
    [ 'defaultprob|d:f', 'Default probability for reactions not associated with a complex', { "default" => 0.0 } ],
    [ 'overwrite|o', 'Overwrite any existing model with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Make sure reaction probability file exists
if (!-e $opt->{"Reaction prob filename"}) {
	print "Could not find input reaction probability file!\n";
	exit(1);
}
#Read the lines from the reaction probability file into the data array
open(my $fh, "<", $opt->{"Reaction prob filename"}) || return;
#$opt->{"Reaction prob filename"} = "";
my $headingline = <$fh>;
chomp($headingline);
my $headings = [split(/\t/,$headingline)];
my $data = [];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\t/,$line)]);
}
close($fh);
my $headingColumns;
for (my $i=0;$i < @{$headings}; $i++) {
	$headingColumns->{$headings->[$i]} = $i;
}
#Build the array of reaction probabilities from each line in the file
foreach my $line (@{$data}) {
	if (defined($line->[$headingColumns->{reaction}]) && defined($line->[$headingColumns->{probability}])) {
		my $gene_list = "";
		if (defined($line->[$headingColumns->{genes}])) {
			$gene_list = $line->[$headingColumns->{genes}];
		}
		my $rxnprob = [
			$line->[$headingColumns->{reaction}],
			$line->[$headingColumns->{probability}],
			$gene_list
		];		
		push(@{$params->{reaction_probs}},$rxnprob);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model generation failed!\n";
} else {
	print "Model successfully generated in workspace:\n";
	printObjectMeta($output);
}