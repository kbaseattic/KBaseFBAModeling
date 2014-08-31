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
      fba-importtrainingset -- import training set

DESCRIPTION
      The following is an example of the data file:

      workspace	database	genome	class
      	seed	83333.1	Gram negative
      	seed	224308.1	Gram positive
      PubSEEDGenomes		83333.1	Gram negative

EXAMPLES
      Import trainingset data:
      > fba-importtrainingset trainingset.txt

SEE ALSO
      fba-buildclassifier
      fba-loadtrainingset
      fba-runclassifier

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Trainingset filename"];
my $servercommand = "import_trainingset";
my $script = "fba-importtrainingset";
my $translation = {
	description => "description",
	attributes => "attribute_type",
	workspace => "workspace",
	preload => "preload_attributes",
	outputid => "output_id",
};
#Defining usage and options
my $specs = [
    [ 'outputid:s', 'ID for training set in workspace' ],
    [ 'description:s', 'Description for training set' ],
    [ 'attributes:s', 'Type of attribute' ],
    [ 'preload', 'Preload training set' ],
    [ 'workspace|w:s', 'Workspace to save training set in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{workspace_training_set} = [];
$params->{external_training_set} = [];
if (!-e $opt->{"Trainingset filename"}) {
	print "Could not find input training set file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Trainingset filename"}) || return;
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
		push(@{$params->{external_training_set}},[$array->[$headingindecies->{database}],$array->[$headingindecies->{genome}],$array->[$headingindecies->{class}]]);
	} elsif ((!defined($headingindecies->{database}) || length($array->[$headingindecies->{database}]) == 0) && defined($headingindecies->{workspace}) && length($array->[$headingindecies->{workspace}]) > 0) {
		push(@{$params->{workspace_training_set}},[$array->[$headingindecies->{workspace}],$array->[$headingindecies->{genome}],$array->[$headingindecies->{class}]]);
	}
}
close($fh);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Trainingset import failed!\n";
} else {
	print "Trainingset import successful:\n";
	printObjectInfo($output);
}
