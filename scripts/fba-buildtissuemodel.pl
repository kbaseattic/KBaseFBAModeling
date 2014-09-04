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
      fba-buildtissuemodel - Build a tissue model from a full model

DESCRIPTION

	  fba-buildtissuemodel <Full model> <Transcriptome sample>   

      Description of positional arguments:

      Full model: Full model to trim to tissue model
      Transcriptome sample: Transcriptome data sample 

EXAMPLES
      Build tissue model from full genome model and transcriptome data
      > fba-buildfbamodel 'kb|g.0' --model 'kb|g.0.model'

SEE ALSO
      fba-loadgenome
      fba-runfba
      fba-gapfill
      fba-adjusttemprxn

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Full model","Transcriptome sample"];
my $servercommand = "build_tissue_model";
my $script = "fba-buildtissuemodel";
my $translation = {
	"Transcriptome sample" => "expsample",
	"Full model" => "model",
	modelws => "model_ws",
	media => "media",
	mediaws => "media_ws",	
	transcriptws => "expsample_ws",
	outputid => "output_id",
	solver => "solver",
	workspace => "workspace",
	activation => "activation_penalty"
};
		
#Defining usage and options
my $specs = [
    [ 'outputid=s', 'Name to be provided for output model' ],
    [ 'media=s', 'Media for tissue model analysis' ],
    [ 'mediaws=s', 'Workspace with media for analysis' ],
    [ 'modelws=s', 'Workspace where full model is located' ],
    [ 'transcriptws=s', 'Workspace with transcript data' ],
    [ 'activation=s', 'Coefficient for activating expressed reactions'],
    [ 'solver=s', 'Linear optimization solver to use' ],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Tissue model generation failed!\n";
} else {
	print "Tissue model successfully generated in workspace:\n";
	printObjectInfo($output);
}
