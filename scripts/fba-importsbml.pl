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
#Defining globals describing behavior
my $primaryArgs = ["Genome ID","SBML file"];
my $servercommand = "import_fbamodel";
my $script = "fba-importsbml";
my $translation = {
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	"SBML file" => "sbml",
	modelid => "model_id"
};

my $manpage = 
"
NAME
      fba-importsbml

DESCRIPTION

      Import an FBA Model from SBML and save the results as a Model object in a workspace.

EXAMPLES
      Import an E coli model with 'biomass equation' atp + h2o --> adp + pi + h:

      fba-importfbamodel 'kb|g.0.genome' 'kb|g.0.modelfile' 'atp + h2o --> adp + pi + h'

SEE ALSO
      fba-importsbml

AUTHORS
      Christopher Henry

";

#Defining usage and options
my $specs = [
    [ 'modelid|m:s', 'ID for imported model in workspace' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
if (!-e $opt->{"SBML file"}) {
	print "Could not find input SBML file!\n";
	exit();
}
open(my $fh, "<", ) || return;
my $string;
while (my $line = <$fh>) {
	$string .= $line;
}
close($fh);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model import failed!\n";
} else {
	print "Model import successful:\n";
	printObjectInfo($output);
}
