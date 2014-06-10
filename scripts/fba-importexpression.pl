#!/usr/bin/env perl
# Author: Shinnosuke Kondo @ Hope College, Holland, MI
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode getToken);
use Bio::KBase::ObjectAPI::utilities qw(LOADTABLE);
use File::Basename;

#Defining globals describing behavior
my $primaryArgs = ["Gene expression flat file"];
my $servercommand = "import_expression";
my $script = "fba-importexpression";
my $translation = {
	workspace => "workspace",
	auth => "auth",
	ignoreerrors => "ignore_errors",
};

my $manpage = 
"
NAME
      fba-importexpression

DESCRIPTION

      The following infomation is not accurate at all.
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
      atp + h2o --> adp + pi + h  >    c0    
      rxn00001  =    c0    kb|g.0.peg.1
      rxn00002  >    c0    
      rxn00003  <    c0    kb|g.0.peg.2 or kb|g.0.peg.3

EXAMPLES
      Import an E coli model with 'biomass equation' atp + h2o --> adp + pi + h:

      fba-importfbamodel 'kb|g.0.genome' 'kb|g.0.modelfile' 'atp + h2o --> adp + pi + h'

SEE ALSO
      fba-loadgenome
      fba-runfba
      fba-buildfbamodel

AUTHORS
      Shinnosuke Kondo

";

#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace to save imported gene expression in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
if (!-e $opt->{"Gene expression flat file"}) {
	print "Could not find input gene expressioni file!\n";
	exit();
}
$params->{"series"} = basename($opt->{"Gene expression flat file"});

my $data = Bio::KBase::ObjectAPI::utilities::LOADTABLE($opt->{"Gene expression flat file"},"\t",0);

for (my $col_i = 0; $col_i < @{$data->{"headings"}}; $col_i++) {
    $params->{"expression_data_sample_series"}->{$data->{"headings"}->[$col_i]} = {};
    my $sample_id = $data->{"headings"}->[$col_i];
    foreach my $row (@{$data->{"data"}}) {
	# Associate gene feature ID with expession value
	$params->{"expression_data_sample_series"}->{$sample_id}->{"sample_id"} = $sample_id;
	#Make sure that it is treated as a number so that Json conversion can work.
	$params->{"expression_data_sample_series"}->{$sample_id}->{"data_expression_levels_for_sample"}->{$row->[0]} = 0+$row->[$col_i+1];
    }
}

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Gene expression import failed!\n";
} else {
	print "Gene expression import successful:\n";
	printObjectInfo($output);
}
