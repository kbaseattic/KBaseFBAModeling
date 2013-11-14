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
my $primaryArgs = ["Genome ID","Model file","Biomass equation"];
my $servercommand = "import_fbamodel";
my $script = "kbfba-importfbamodel";
my $translation = {
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	"Biomass equation" => "biomass",
	modelid => "model",
	workspace => "workspace",
	auth => "auth",
	ignoreerrors => "ignore_errors",
	overwrite => "overwrite"
};
#Defining usage and options
my $specs = [
    [ "Genome_ID : ID for genome in workspace" ],
    [ "Model file: Tab-delimited file with four columns: \'id\', \'direction\' (<,> or =), \'compartment\' (e.g. c0,e0), and \'gpr\' (use \"\" for empty GPR)." ],
    [ "Biomass equation: A string representing the biomass equation (e.g. 'A --> B')"],
    [ 'modelid|m:s', 'ID for imported model in workspace' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'ignoreerrors|i', 'Ignore errors encountered during load' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{reactions} = [];
if (!-e $opt->{"Model file"}) {
	print "Could not find input model file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Model file"}) || return;
$opt->{"Model file"} = "";
my $headingline = <$fh>;
chomp($headingline);
my $headings = [split(/\t/,$headingline)];
my $data = [];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\t/,$line)]);
}
close($fh);
my $headingColums;
for (my $i=0;$i < @{$headings}; $i++) {
	$headingColums->{$headings->[$i]} = $i;
}
my $reqheadings = ["id","direction","compartment","gpr"];
my $error = 0;
foreach my $heading (@{$reqheadings}) {
	if (!defined($headingColums->{$heading})) {
		$error = 1;
		print "Model file missing required column '".$heading."'!\n";
	} 
}
if ($error == 1) {
	exit();
}
foreach my $rxn (@{$data}) {
	if (@{$rxn} >= 4) {
		my $rxnobj = [
			$rxn->[$headingColums->{id}],
			$rxn->[$headingColums->{direction}],
			$rxn->[$headingColums->{compartment}],
			$rxn->[$headingColums->{gpr}],
		];
		push(@{$params->{reactions}},$rxnobj);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model import failed!\n";
} else {
	print "Model import successful:\n";
	printObjectMeta($output);
}
