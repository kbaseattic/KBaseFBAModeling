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
      fba-translatefbamodel - Translate model to new genome using protein comparison

DESCRIPTION
      

EXAMPLES
      

SEE ALSO
      

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Protein comparison","Model"];
my $servercommand = "translate_fbamodel";
my $script = "fba-translatefbamodel";
my $translation = {
	"Protein comparison" => "protcomp",
	protcompws => "protcomp_workspace",
	Model => "model",
	modelws => "model_workspace",
	modelout => "output_id",
	outputid => "output_id",
	workspace => "workspace"
};
#Defining usage and options
my $specs = [
    [ 'modelout|outputid|m=s', 'Name to be provided for output model' ],
    [ 'removenogenerxn', 'Remove any reactions in original model with no genes' ],
    [ 'protcompws=s', 'Workspace where protein comparison is located', { "default" => fbaws() } ],
    [ 'modelws=s', 'Workspace where model is located', { "default" => fbaws() } ],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
if (defined($opt->{removenogenerxn})) {
	$params->{keep_nogene_rxn} = 0;
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model generation failed!\n";
} else {
	print "Model successfully generated in workspace:\n";
	printObjectInfo($output);
}
