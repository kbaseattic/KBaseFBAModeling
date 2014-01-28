#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(get_fba_client runFBACommand universalFBAScriptCode );

my $manpage =
"
NAME
      fba-buildfbamodel - Build a draft FBA model from an annotated genome

DESCRIPTION
      This function builds a draft metabolic model from an annotated genome.
      To do this, it calls the ModelSEED library. To define reaction-role linkages
      it uses either the entire biochemistry in the KBase or (optionally) a template 
      biochemistry defining the functions that are likely to be present in the group 
      of organisms to which the genome belongs (e.g. bacteria and archaea can be given 
      their own templates according to metabolic functions only found in one or the other).

      Note that the model produced by this fucntion most likely will not grow and you 
      will need to run Gapfill on it to perform simulations. See kbfba-gapfill for details.

      Description of positional arguments:

      Genome: A Genome object in a workspace

EXAMPLES
      Build a draft model for E. coli, save results to 'kb|g.0.model'
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
my $primaryArgs = ["Genome"];
my $servercommand = "genome_to_fbamodel";
my $script = "fba-buildfbamodel";
my $translation = {
	Genome => "genome",
	genomews => "genome_workspace",
	templateid => "templatemodel",
	templatews => "templatemodel_workspace",
	model => "model",
	core => "coremodel",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite"
};
#Defining usage and options
my $specs = [
    [ 'model|m=s', 'Name to be provided for output model' ],
    [ 'genomews=s', 'Workspace where genome is located' ],
    [ 'templateid=s', 'ID of template model to use' ],
    [ 'templatews=s', 'Workspace with template model' ],
    [ 'core', 'Build core model'],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing model with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model generation failed!\n";
} else {
	print "Model successfully generated in workspace:\n";
	printObjectInfo($output);
}
