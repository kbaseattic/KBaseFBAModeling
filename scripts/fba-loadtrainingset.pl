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
      fba-loadtrainingset - prepopulate a training set with attributes

DESCRIPTION
      

EXAMPLES
      Prepopulate a single training set
      > fba-loadtrainingset 'kb|trainingset.0'

SEE ALSO
      fba-buildclassifier
      fba-loadtrainingset
      fba-runclassifier

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Training set"];
my $servercommand = "preload_trainingset";
my $script = "fba-loadtrainingset";
my $translation = {
	"Training set" => "trainingset",
	trainingsetws => "trainingset_ws",
	attribute => "attribute_type",
	outputid => "output_id",
	workspace => "workspace",
};

#Defining usage and options
my $specs = [
	[ 'outputid:s', 'ID for training set in workspace' ],
    [ 'attribute:s', 'Type of attribute' ],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Trainingset load failed!\n";
} else {
	print "Trainingset successfully loaded in workspace:\n";
	printObjectInfo($output);
}
