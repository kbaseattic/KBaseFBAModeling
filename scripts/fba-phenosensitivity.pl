#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw( get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws printJobData get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Model ID","Phenotype set"];
my $servercommand = "queue_reconciliation_sensitivity_analysis";
my $script = "fba-phenosensitivity";
my $translation = {
	"Model ID" => "model",
	"Phenotype set" => "phenotypeSet",
	modelws => "model_workspace",
	phenows => "phenotypeSet_workspace",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite",
	nosubmit => "donot_submit_job",
};
my $fbaTranslation = {
	objfraction => "objfraction",
	allrev => "allreversible",
	maximize => "maximizeObjective",
	defaultmaxflux => "defaultmaxflux",
	defaultminuptake => "defaultminuptake",
	defaultmaxuptake => "defaultmaxuptake",
	simplethermo => "simplethermoconst",
	thermoconst => "thermoconst",
	nothermoerror => "nothermoerror",
	minthermoerror => "minthermoerror"
};
#Defining usage and options
my $specs = [
    [ 'phenows:s', 'Workspace with phenotype data object' ],
    [ 'modelws:s', 'Workspace with model object' ],
    [ 'maximize:s', 'Maximize objective', { "default" => 1 } ],
	[ 'gapfills:s@', 'List of gapfillings to assess' ],
    [ 'gapgens:s@', 'List of gapgenerations to assess' ],
	[ 'objterms:s@', 'Objective terms' ],
	[ 'geneko:s@', 'List of gene KO (; delimiter)' ],
	[ 'rxnko:s@', 'List of reaction KO (; delimiter)' ],
    [ 'bounds:s@', 'Custom bounds' ],
    [ 'constraints:s@', 'Custom constraints' ],
    [ 'defaultmaxflux:s', 'Default maximum reaction flux' ],
    [ 'defaultminuptake:s', 'Default minimum nutrient uptake' ],
    [ 'defaultmaxuptake:s', 'Default maximum nutrient uptake' ],
    [ 'uptakelim:s@', 'Atom uptake limits' ],
    [ 'simplethermo', 'Use simple thermodynamic constraints' ],
    [ 'thermoconst', 'Use full thermodynamic constraints' ],
    [ 'nothermoerror', 'No uncertainty in thermodynamic constraints' ],
    [ 'minthermoerror', 'Minimize uncertainty in thermodynamic constraints' ],
    [ 'allrev', 'Treat all reactions as reversible', { "default" => 0 } ],
    [ 'objfraction:s', 'Fraction of objective for follow on analysis', { "default" => 0.1 }],
    [ 'notes:s', 'Notes for flux balance analysis' ],
    [ 'nosubmit', 'Do not submit job to cluster', { "default" => 0 } ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => fbaws() } ],
    [ 'overwrite|o', 'Overwrite any existing FBA with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{gapfills})) {
	foreach my $gfs (@{$opt->{gapfills}}) {
		push(@{$params->{gapFills}},split(/;/,$gfs));
	}
}
if (defined($opt->{gapgens})) {
	foreach my $ggs (@{$opt->{gapgens}}) {
		push(@{$params->{gapGens}},split(/;/,$ggs));
	}
}
$params->{formulation} = {
	geneko => [],
	rxnko => [],
	bounds => [],
	constraints => [],
	uptakelim => {},
	additionalcpds => []
};
foreach my $key (keys(%{$fbaTranslation})) {
	if (defined($opt->{$key})) {
		$params->{formulation}->{$fbaTranslation->{$key}} = $opt->{$key};
	}
}
if (defined($opt->{objterms})) {
	foreach my $terms (@{$opt->{objterms}}) {
		my $array = [split(/;/,$terms)];
		foreach my $term (@{$array}) {
			my $termArray = [split(/:/,$term)];
			if (defined($termArray->[2])) {
				push(@{$params->{formulation}->{objectiveTerms}},$termArray);
			}
		}
	}
}
if (defined($opt->{geneko})) {
	foreach my $gene (@{$opt->{geneko}}) {
		push(@{$params->{formulation}->{geneko}},split(/;/,$gene));
	}
}
if (defined($opt->{rxnko})) {
	foreach my $rxn (@{$opt->{rxnko}}) {
		push(@{$params->{formulation}->{rxnko}},split(/;/,$rxn));
	}
}
if (defined($opt->{bounds})) {
	foreach my $terms (@{$opt->{bounds}}) {
		my $array = [split(/;/,$terms)];
		foreach my $term (@{$array}) {
			my $termArray = [split(/:/,$term)];
			if (defined($termArray->[3])) {
				push(@{$params->{formulation}->{bounds}},$termArray);
			}
		}
	}
}
if (defined($opt->{constraints})) {
	my $count = 0;
	foreach my $constraint (@{$opt->{constraints}}) {
		my $array = [split(/;/,$constraint)];
		my $rhs = shift(@{$array});
		my $sign = shift(@{$array});
		my $terms = [];
		foreach my $term (@{$array}) {
			my $termArray = [split(/:/,$term)];
			if (defined($termArray->[2])) {
				push(@{$terms},$termArray)
			}
		}
		push(@{$params->{formulation}->{constraints}},[$rhs,$sign,$terms,"Constraint ".$count]);
		$count++;
	}
}
if (defined($opt->{uptakelim})) {
	foreach my $uplims (@{$opt->{rxnko}}) {
		my $array = [split(/;/,$uplims)];
		foreach my $uplim (@{$array}) {
			my $pair = [split(/:/,$uplim)];
			if (defined($pair->[1])) {
				$params->{formulation}->{uptakelim}->{$pair->[0]} = $pair->[1];
			}
		}
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Phenotype sensitivity analysis failed!\n";
} else {
	print "Phenotype sensitivity analysis successful:\n";
	printJobData($output);
}
