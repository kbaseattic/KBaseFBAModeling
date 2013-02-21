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
my $primaryArgs = ["Genome ID","Phenotype filename"];
my $servercommand = "import_phenotypes";
my $script = "kbfba-importpheno";
my $translation = {
	"Genome ID" => "genome",
	"phenoid" => "phenotypeSet",
	workspace => "workspace",
	genomews => "genome_workspace",
	ignoreerrors => "ignore_errors",
	auth => "auth",
	overwrite => "overwrite"
};
#Defining usage and options
my $specs = [
    [ 'phenoid:s', 'ID for phenotype set in workspace' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'ignoreerrors', 'Ignore errors encountered during load' ],
    [ 'workspace|w:s', 'Workspace to save phenotypes in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{phenotypes} = [];
if (!-e $opt->{"Phenotype filename"}) {
	print "Could not find input phenotype file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Phenotype filename"}) || return;
$opt->{"Phenotype filename"} = "";
my $headingline = <$fh>;
my $array = [split("\r",$headingline)];
$headingline = shift(@{$array});
chomp($headingline);
my $data = [];
for (my $i=0;$i < @{$array}; $i++) {
	push(@{$data},[split(/\t/,$array->[$i])]);
}
my $headings = [split(/\t/,$headingline)];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\t/,$line)]);
}
close($fh);
my $headingColums;
for (my $i=0;$i < @{$headings}; $i++) {
	$headingColums->{$headings->[$i]} = $i;
}
foreach my $pheno (@{$data}) {
	if (defined($headingColums->{media}) && defined($headingColums->{mediaws})) {
		my $phenoobj = [
			[],
			$pheno->[$headingColums->{media}],
			$pheno->[$headingColums->{mediaws}],
			[],
			$pheno->[$headingColums->{growth}],
		];
		if (defined($headingColums->{geneko})) {
			if (defined($pheno->[$headingColums->{geneko}])) {
				if ($pheno->[$headingColums->{geneko}] eq "none") {
					$phenoobj->[0] = [];
				} else {
					$phenoobj->[0] = [split(/\;/,$pheno->[$headingColums->{geneko}])];
				}
			}
		}
		if (defined($headingColums->{addtlCpd})) {
			if (!defined($pheno->[$headingColums->{addtlCpd}]) || $pheno->[$headingColums->{addtlCpd}] eq "none") {
				$phenoobj->[3] = [];
			} else {
				$phenoobj->[3] = [split(/\;/,$pheno->[$headingColums->{addtlCpd}])];
			}
		}
		push(@{$params->{phenotypes}},$phenoobj);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Phenotype import failed!\n";
} else {
	print "Phenotype import successful:\n";
	printObjectMeta($output);
}