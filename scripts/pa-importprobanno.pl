#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Data::Dumper;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );

my $manpage =
"
NAME
      pa-importprobanno -- import a probabilistic annotation object from a three column file

DESCRIPTION
      The following is an example of the data file:

      gene	role	probability
      kb|g.0.peg.1	2-iminoacetate synthase (ThiH) (EC 4.1.99.19)	0.1
      kb|g.0.peg.2	2-iminoacetate synthase (ThiH) (EC 4.1.99.19)	0.3
      kb|g.0.peg.3	2-iminoacetate synthase (ThiH) (EC 4.1.99.19)	0.5

EXAMPLES
      Import probabilistic annotation data for E. coli K12 genome:
      > pa-importprobanno 'kb|g.0' MyProbAnnoFile.txt

SEE ALSO
      pa-calculate
      pa-getprobanno
      pa-annotate

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Genome ID","Probanno filename"];
my $servercommand = "import_phenotypes";
my $script = "fba-importpheno";
my $translation = {
	"Genome ID" => "genome",
	"outputid" => "outputid",
	workspace => "workspace",
	genomews => "genome_ws",
};
#Defining usage and options
my $specs = [
    [ 'outputid:s', 'ID for probabilistic annotation in workspace' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'workspace|w:s', 'Workspace to save probabilistic annotation in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);

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

my $headings = [split(/\s+/,$headingline)];

while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\s+/,$line)]);
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
	printObjectInfo($output);
}
