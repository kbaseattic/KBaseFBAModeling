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

my $manpage =
"
NAME
      fba-buildclassifier - build a classifier from a specified training set

DESCRIPTION
      

EXAMPLES
      Build a classifier for a training set
      > fba-buildclassifier 'kb|trainingset.0'

SEE ALSO
      fba-importtrainingset
      fba-loadtrainingset
      fba-classifygenomes

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Training set"];
my $servercommand = "build_classifier";
my $script = "fba-buildclassifier";
my $translation = {
	"Training set" => "trainingset",
	trainingsetws => "trainingset_ws",
	classifier => "classifier",
	outputid => "output_id",
	workspace => "workspace",
};

#Defining usage and options
my $specs = [
	[ 'outputid:s', 'ID for training set in workspace' ],
	[ 'trainingsetws:s', 'Workspace of training set' ],
    [ 'classifier:s', 'Type of classifier' ],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Classifier construction failed!\n";
} else {
	print "Classifier successfully created in workspace:\n";
	printObjectInfo($output);
}
