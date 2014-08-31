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
      fba-classifygenomes -- classify the input set of genomes

DESCRIPTION
      The following is an example of the data file:

      workspace	database	genome
      	seed	83333.1
      	seed	224308.1
      PubSEEDGenomes		83333.1

EXAMPLES
      Classify an input set of genomes:
      > fba-classifygenomes MyClassifier 83333.1 --database seed

SEE ALSO
      fba-buildclassifier
      fba-loadtrainingset
      fba-classifygenomes

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Classifier","Genomes or filename"];
my $servercommand = "classify_genomes";
my $script = "fba-classifygenomes";
my $translation = {
	Classifier => "classifier",
	classifierws => "classifier_ws",
	workspace => "workspace",
	outputid => "output_id",
};
#Defining usage and options
my $specs = [
    [ 'outputid:s', 'ID for training set in workspace' ],
    [ 'classifierws:s', 'Workspace with classifier' ],
    [ 'database:s', 'Database with genomes' ,{ "default" => "workspace" }],
    [ 'workspace|w:s', 'Workspace to save results in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{workspace_training_set} = [];
$params->{external_training_set} = [];
if (-e $opt->{"Genomes or filename"}) {
	open(my $fh, "<", $opt->{"Genomes or filename"}) || return;
	my $headingline = <$fh>;
	chomp($headingline);
	my $headings = [split(/\s+/,$headingline)];
	my $headingindecies = {};
	for (my $i=0; $i < @{$headings}; $i++) {
		$headingindecies->{$headings->[$i]} = $i;
	}
	while (my $line = <$fh>) {
		chomp($line);
		my $array = [split(/\t/,$line)];
		if ((!defined($headingindecies->{workspace}) || length($array->[$headingindecies->{workspace}]) == 0) && defined($headingindecies->{database}) && length($array->[$headingindecies->{database}]) > 0) {
			push(@{$params->{external_training_set}},[$array->[$headingindecies->{database}],$array->[$headingindecies->{genome}]]);
		} elsif ((!defined($headingindecies->{database}) || length($array->[$headingindecies->{database}]) == 0) && defined($headingindecies->{workspace}) && length($array->[$headingindecies->{workspace}]) > 0) {
			push(@{$params->{workspace_training_set}},[$array->[$headingindecies->{workspace}],$array->[$headingindecies->{genome}]]);
		}
	}
	close($fh);
} else {
	my $list = [split(/;/,$opt->{"Genomes or filename"})];
	for (my $i=0; $i < @{$list}; $i++) {
		if ($opt->{database} eq "workspace") {
			my $array = [split(/\//,$list->[$i])];
			push(@{$params->{workspace_training_set}},[$array->[0],$array->[1]]);
		} else {
			push(@{$params->{external_training_set}},[$opt->{database},$list->[$i]]);
		}
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Trainingset import failed!\n";
} else {
	print "Trainingset import successful:\n";
	printObjectInfo($output);
}
