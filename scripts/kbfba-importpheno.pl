#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Data::Dumper;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );

my $manpage =
"
NAME
      kbfba-importpheno -- import phenotype data to a PhenotypeSet object

DESCRIPTION
      Import phenotype data from a file and create a PhenotypeSet object. The
      first line of the file defines the names of the fields in the file.  The
      required fields are 'media', 'mediaws', and 'growth'.  Optional fields are
      'geneko' and 'addtlCpd'.  The 'media' field is the ID of a Media object.
      The 'mediaws' field is the ID of the workspace with the Media object.  The
      'growth' field is either 0 to indicate no growth or 1 to indicate growth on
      the specified media.  The 'genko' field is a semicolon delimited list of
      the IDs for gene knockouts.  The 'addtlCpd' field is a semicolon delimited
      list of the IDs of compounds added to the media before measuring the
      phenotype.  The fields can be in any order and must be delimited by tabs.

      The following is an example of the data file:

      media	mediaws	growth	geneko
      Carbon-D-Glucose	KBaseMedia	1	fig|83333.1.peg.1
      Carbon-D-Glucose	KBaseMedia	0	fig|83333.1.peg.2
      Carbon-D-Glucose	KbaseMedia	0	fig|83333.1.peg.3

EXAMPLES
      Import phenotype data for E. coli K12 genome:
      > kbfba-importpheno kb|g.0.genome kb|g.0.phenotype.txt

SEE ALSO
      kbfba-simpheno
      kbfba-exportphenosim

AUTHORS
      Christopher Henry
";

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
    [ 'ignoreerrors', 'Ignore errors encountered during import' ],
    [ 'workspace|w:s', 'Workspace to save phenotypes in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
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
	printObjectMeta($output);
}
