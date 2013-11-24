#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID","Model file","Biomass equation"];
my $servercommand = "import_fbamodel";
my $script = "kbfba-importfbamodel";
my $translation = {
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	"Biomass equation" => "biomass",
	modelid => "model",
	workspace => "workspace",
	auth => "auth",
	ignoreerrors => "ignore_errors",
	overwrite => "overwrite"
};

my $manpage = 
"
NAME
      kbfba-importfbamodel

DESCRIPTION

      Import an FBA Model from text and save the results as a Model object in a workspace.
      The text file describes the reactions and gene-protein-reaction relationships (GPR)
      in the model. Each row (except the header row) in the data file contains data for one
      reaction.

      The first line of the model file is required and contains the following four headers 
      (in any order):

      - id : The ID of the reaction in the model. It must match with one of the IDs or aliases
             existing in the ModelSEED
      - direction: > for forward, < for backward or = for reversible. Direction is relative to
             the direction stored in the ModleSEED
      - compartment: Compartment in which the reaction is found (e.g. c0 for 0'th cytosol)
      - gpr: Gene-protein-reaction relationship in Boolean form.
             The gene IDs in the GPR must match the IDs in the genome object.
      
      The biomass equation should be written as an equation with compound IDs recognizable by 
      the modelSEED, for example:
      
      'atp + h2o --> adp + pi + h'

      The following is an example data file (note 0 leave an empty space for gpr even if your reaction
      does not have one). Note that some old versions of this tool will only work if you use 'or' or 'and', not
      'OR' or 'AND', in the Boolean rules.

      id   direction   compartment   gpr
      rxn00001  =    c0    kb|g.0.peg.1
      rxn00002  >    c0    
      rxn00003  <    c0    kb|g.0.peg.2 or kb|g.0.peg.3

EXAMPLES
      Import an E coli model with 'biomass equation' atp + h2o --> adp + pi + h:

      kbfba-importfbamodel 'kb|g.0.genome' 'kb|g.0.modelfile' 'atp + h2o --> adp + pi + h'

SEE ALSO
      kbfba-loadgenome
      kbfba-runfba
      kbfba-buildfbamodel

AUTHORS
      Christopher Henry

";

#Defining usage and options
my $specs = [
    [ 'modelid|m:s', 'ID for imported model in workspace' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'ignoreerrors|i', 'Ignore errors encountered during load' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
$params->{reactions} = [];
if (!-e $opt->{"Model file"}) {
	print "Could not find input model file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Model file"}) || return;
$opt->{"Model file"} = "";
my $headingline = <$fh>;
chomp($headingline);
my $headings = [split(/\t/,$headingline)];
my $data = [];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\t/,$line)]);
}
close($fh);
my $headingColums;
for (my $i=0;$i < @{$headings}; $i++) {
	$headingColums->{$headings->[$i]} = $i;
}
my $reqheadings = ["id","direction","compartment","gpr"];
my $error = 0;
foreach my $heading (@{$reqheadings}) {
	if (!defined($headingColums->{$heading})) {
		$error = 1;
		print "Model file missing required column '".$heading."'!\n";
	} 
}
if ($error == 1) {
	exit();
}
foreach my $rxn (@{$data}) {
	if (@{$rxn} >= 4) {
		my $rxnobj = [
			$rxn->[$headingColums->{id}],
			$rxn->[$headingColums->{direction}],
			$rxn->[$headingColums->{compartment}],
			$rxn->[$headingColums->{gpr}],
		];
		push(@{$params->{reactions}},$rxnobj);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model import failed!\n";
} else {
	print "Model import successful:\n";
	printObjectMeta($output);
}
