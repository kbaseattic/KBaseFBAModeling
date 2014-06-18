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
my $primaryArgs = ["Genome ID","Model reactions file","Biomass equation"];
my $servercommand = "import_fbamodel";
my $script = "fba-importfbamodel";
my $translation = {
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	"Biomass equation" => "biomass",
	modelid => "model",
	workspace => "workspace",
	auth => "auth",
	ignoreerrors => "ignore_errors",
};

my $manpage = 
"
NAME
      fba-importfbamodel

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
      atp + h2o --> adp + pi + h  >    c0    
      rxn00001  =    c0    kb|g.0.peg.1
      rxn00002  >    c0    
      rxn00003  <    c0    kb|g.0.peg.2 or kb|g.0.peg.3
      
      If the user decides to specify reactions in equation form instead of just IDs, it is a good
      idea to provide a second file with specifications on all compounds appearing in user-specified
      reactions. If this file is to be provided, indicate the full name of the file using the compoundfile
      command line option (e.g. --compoundfile '/vol/files/mycompounds.txt'. The first line of the compound
      file is required and contains the following four headers 
      (in any order):

      - id : The ID of the compounds as they appear in any user specified reactions, including the biomass reaction.
      - charg: Molecular charge of the compound at cellular conditions
      - formula: Formula of the compound at cellular conditions
      - name: Primary name of the compound
      - aliases: '|' delimited list of aliases for the compound to aid in matching      
      
      The following is an example data file (note: leave an empty space for fields you do not complete).

      id   charge   formula   name	aliases
      h2o	0	H2O	Water	C00001|cpd00001

EXAMPLES
      Import an E coli model with 'biomass equation' atp + h2o --> adp + pi + h:

      fba-importfbamodel 'kb|g.0.genome' 'kb|g.0.modelfile' 'atp + h2o --> adp + pi + h'

SEE ALSO
      fba-loadgenome
      fba-runfba
      fba-buildfbamodel

AUTHORS
      Christopher Henry

";

#Defining usage and options
my $specs = [
    [ 'modelid|m:s', 'ID for imported model in workspace' ],
    [ 'compoundfile:s', 'Name of file with compound data' ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'ignoreerrors|i', 'Ignore errors encountered during load' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
$params->{reactions} = [];
if (!-e $opt->{"Model reactions file"}) {
	print "Could not find input model file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Model reactions file"}) || return;
$opt->{"Model reactions file"} = "";
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
my $reqheadings = ["id","gpr"];
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
	my $rxnobj = [
		$rxn->[$headingColums->{id}],
		"=",
		"c",
		$rxn->[$headingColums->{gpr}],
	];
	if (defined($headingColums->{direction})) {
		$rxnobj->[1] = $rxn->[$headingColums->{direction}];
	}
	if (defined($headingColums->{compartment})) {
		$rxnobj->[2] = $rxn->[$headingColums->{compartment}];
	}
	if (defined($headingColums->{name})) {
		$rxnobj->[4] = $rxn->[$headingColums->{name}];
	}
	if (defined($headingColums->{enzyme})) {
		$rxnobj->[5] = $rxn->[$headingColums->{enzyme}];
	}
	if (defined($headingColums->{pathway})) {
		$rxnobj->[6] = $rxn->[$headingColums->{pathway}];
	}
	if (defined($headingColums->{reference})) {
		$rxnobj->[7] = $rxn->[$headingColums->{reference}];
	}
	if (defined($headingColums->{equation})) {
		$rxnobj->[8] = $rxn->[$headingColums->{equation}];
	}
	print $rxnobj->[0]."\n";
	push(@{$params->{reactions}},$rxnobj);
}
if (defined($opt->{compoundfile})) {
	if (!-e $opt->{compoundfile}) {
		print "Could not find input compound file!\n";
		exit();
	}
	open(my $fhh, "<", $opt->{compoundfile}) || return;
	$headingline = <$fhh>;
	chomp($headingline);
	$headings = [split(/\t/,$headingline)];
	$data = [];
	while (my $line = <$fhh>) {
		chomp($line);
		push(@{$data},[split(/\t/,$line)]);
	}
	close($fhh);
	for (my $i=0;$i < @{$headings}; $i++) {
		$headingColums->{$headings->[$i]} = $i;
	}
	my $reqheadings = ["id","name"];
	my $error = 0;
	foreach my $heading (@{$reqheadings}) {
		if (!defined($headingColums->{$heading})) {
			$error = 1;
			print "Compound file missing required column '".$heading."'!\n";
		} 
	}
	if ($error == 1) {
		exit();
	}
	foreach my $cpd (@{$data}) {
		my $cpdobj = [
			$cpd->[$headingColums->{id}],
			undef,
			undef,
			$cpd->[$headingColums->{name}],
		];
		if (defined($headingColums->{formula})) {
			$cpdobj->[2] = $cpd->[$headingColums->{formula}];
		}
		if (defined($headingColums->{charge})) {
			$cpdobj->[1] = $cpd->[$headingColums->{charge}];
		}
		if (defined($headingColums->{aliases})) {
			$cpdobj->[4] = $cpd->[$headingColums->{aliases}];
		}
		print $cpdobj->[0]."\n";
		push(@{$params->{compounds}},$cpdobj);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model import failed!\n";
} else {
	print "Model import successful:\n";
	printObjectInfo($output);
}
