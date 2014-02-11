#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID","Probanno filename"];
my $servercommand = "import_probanno";
my $script = "fba-importprobanno";
my $translation = {
	"Genome ID" => "genome",
	"probannoid" => "probanno",
	workspace => "workspace",
	genomews => "genome_workspace",
	annotationprobs => "annotationProbabilities",
	ignoreerrors => "ignore_errors",
	auth => "auth",
	overwrite => "overwrite"
};
#Defining usage and options
my $specs = [
    [ 'probannoid:s', 'ID for phenotype set in workspace' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'ignoreerrors|i', 'Ignore errors encountered during load' ],
    [ 'workspace|w:s', 'Workspace to save phenotypes in', { "default" => fbaws() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{phenotypes} = [];
if (!-e $opt->{"Probanno filename"}) {
	print "Could not find input probabilistic annotation file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Probanno filename"}) || return;
$opt->{"Probanno filename"} = "";
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
foreach my $anno (@{$data}) {
	if (defined($headingColums->{feature}) && defined($headingColums->{function}) && defined($headingColums->{probability})) {
		my $annoobj = [
			$anno->[$headingColums->{feature}],
			$anno->[$headingColums->{function}],
			$anno->[$headingColums->{probability}]
		];
		push(@{$params->{annotationProbabilities}},$annoobj);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Probanno import failed!\n";
} else {
	print "Probanno import successful:\n";
	printObjectInfo($output);
}