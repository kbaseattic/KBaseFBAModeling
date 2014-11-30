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
my $primaryArgs = ["Model"];
my $servercommand = "queue_gapgen_model";
my $script = "fba-gapgen";
my $translation = {
	Model => "model",
	modelws => "model_workspace",
	modelout => "out_model",
	outputid => "out_model",
	workspace => "workspace",
	intsol => "integrate_solution",
	phenows => "phenotypeSet_workspace",
	phenoid => "phenotypeSet",
	timepersol => "timePerSolution",
	timelimit => "totalTimeLimit",
	solver => "solver",
	notes => "notes"
};
my $ggTranslation = {
	numsol => "num_solutions",
	nomediahyp => "nomediahyp",
	nobiomasshyp => "nobiomasshyp",
	nogprhyp => "nogprhyp",
	nopathwayhyp => "nopathwayhyp",
	refmedia => "refmedia",
	refmediaws => "refmedia_workspace"
};
my $fbaTranslation = {
	media => "media",
	mediaws => "media_workspace",
	objfraction => "objfraction",
	allrev => "allreversible",
	maximize => "maximizeObjective",
	defaultmaxflux => "defaultmaxflux",
	defaultminuptake => "defaultminuptake",
	defaultmaxuptake => "defaultmaxuptake",
	simplethermo => "simplethermoconst",
	thermoconst => "thermoconst",
	nothermoerror => "nothermoerror",
	minthermoerror => "minthermoerror",
	addlcpd => "additionalcpds"
};
#Defining usage and options
my $specs = [
    [ 'modelout|outputid:s', 'ID for output model in workspace' ],
    [ 'intsol', 'Automatically integrate solution', { "default" => 0 } ],
    [ 'timepersol:s', 'Maximum time spent per solution' ],
    [ 'timelimit:s', 'Maximum toal time' ],
    [ 'media|m:s', 'Media formulation for FBA' ],
    [ 'mediaws:s', 'Workspace with media formulation' ],
    [ 'addlcpd|c:s@', 'Additional compounds (; delimiter)' ],
    [ 'refmedia|r:s', 'Media formulation for FBA' ],
    [ 'refmediaws:s', 'Workspace with media formulation' ],
    [ 'numsol:i', 'Number of solutions desired', {"default" => 1} ],
    [ 'nomediahyp', 'Donot search for media hypotheses', {"default" => 0} ],
    [ 'nobiomasshyp', 'Donot search for biomass hypotheses', {"default" => 0} ],
    [ 'nogprhyp', 'Donot search for gpr hypotheses', {"default" => 0} ],
    [ 'nopathwayhyp', 'Donot search for pathway hypotheses', {"default" => 0} ],
    [ 'maximize:s', 'Maximize objective', { "default" => 1 } ],
	[ 'objterms:s@', 'Objective terms (; delimiter)' ],
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
    [ 'solver:s', 'Solver to use for gapgen' ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (!defined($opt->{mediaws}) && defined($opt->{media})) {
	$opt->{mediaws} = $opt->{workspace};
}
if (!defined($opt->{refmediaws}) && defined($opt->{refmedia})) {
	$opt->{refmediaws} = $opt->{workspace};
}
$params->{formulation} = {};
foreach my $key (keys(%{$ggTranslation})) {
	if (defined($opt->{$key})) {
		$params->{formulation}->{$ggTranslation->{$key}} = $opt->{$key};
	}
}
$params->{formulation}->{formulation} = {
	geneko => [],
	rxnko => [],
	bounds => [],
	constraints => [],
	uptakelim => {},
	additionalcpds => [],
	objectiveTerms => []
};
foreach my $key (keys(%{$fbaTranslation})) {
	if (defined($opt->{$key})) {
		$params->{formulation}->{formulation}->{$fbaTranslation->{$key}} = $opt->{$key};
	}
}
if (defined($opt->{objterms})) {
	foreach my $terms (@{$opt->{objterms}}) {
		my $array = [split(/;/,$terms)];
		foreach my $term (@{$array}) {
			my $termArray = [split(/:/,$term)];
			if (defined($termArray->[2])) {
				push(@{$params->{formulation}->{formulation}->{objectiveTerms}},$termArray);
			}
		}
	}
}
if (defined($opt->{geneko})) {
	foreach my $gene (@{$opt->{geneko}}) {
		push(@{$params->{formulation}->{formulation}->{geneko}},split(/;/,$gene));
	}
}
if (defined($opt->{rxnko})) {
	foreach my $rxn (@{$opt->{rxnko}}) {
		push(@{$params->{formulation}->{formulation}->{rxnko}},split(/;/,$rxn));
	}
}
if (defined($opt->{additionalcpds})) {
	foreach my $cpd (@{$opt->{additionalcpds}}) {
		push(@{$params->{formulation}->{formulation}->{additionalcpds}},split(/;/,$cpd));
	}
}
if (defined($opt->{bounds})) {
	foreach my $terms (@{$opt->{bounds}}) {
		my $array = [split(/;/,$terms)];
		foreach my $term (@{$array}) {
			my $termArray = [split(/:/,$term)];
			if (defined($termArray->[3])) {
				push(@{$params->{formulation}->{formulation}->{bounds}},$termArray);
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
		push(@{$params->{formulation}->{formulation}->{constraints}},[$rhs,$sign,$terms,"Constraint ".$count]);
		$count++;
	}
}
if (defined($opt->{uptakelim})) {
	foreach my $uplims (@{$opt->{rxnko}}) {
		my $array = [split(/;/,$uplims)];
		foreach my $uplim (@{$array}) {
			my $pair = [split(/:/,$uplim)];
			if (defined($pair->[1])) {
				$params->{formulation}->{formulation}->{uptakelim}->{$pair->[0]} = $pair->[1];
			}
		}
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Gapgen queue failed!\n";
} else {
	print "Gapgen job queued:\n";
	printJobData($output);
}
