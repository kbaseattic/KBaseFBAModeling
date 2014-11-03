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
my $primaryArgs = ["Model","Constraints filename"];
my $servercommand = "quantitative_optimization";
my $script = "fba-quantopt";
my $translation = {
	Model => "model",
	modelws => "model_workspace",
	outputid => "outputid",
	workspace => "workspace",
	solver => "solver",
	biomass => "biomass",
	intsol => "integrate_solution",
	numsol => "num_solutions",
	timepersol => "timePerSolution",
	timelimit => "totalTimeLimit",
	maxboundmult => "MaxBoundMult",
	minfluxcoef => "MinFluxCoef",
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
	addlcpd => "additionalcpds",
	promconstraint => "promconstraint",
	promconstraintws => "promconstraint_workspace",
	efluxsm => "eflux_sample",
	efluxsr => "eflux_series",
	efluxws => "eflux_workspace",
	tintlesample => "tintle_sample",
	tintlews => "tintle_workspace",
	tintlew => "tintle_w",
	tintlek => "tintle_kappa",
	modelws => "model_workspace",
	regulome => "regulome",
	regulomews => "regulome_workspace"
};
#Defining usage and options
my $specs = [
    [ 'outputid:s', 'ID for output model object' ],
    [ 'intsol', 'Integrate solution immediately' ],
    [ 'media|m:s', 'Media formulation for QuantOpt' ],
    [ 'mediaws:s', 'Workspace with media formulation' ],
    [ 'maxboundmult:s', 'Multiplier on max bounds from FVA' ],
    [ 'minfluxcoef:s', 'Coefficient on minimal flux portion of objective function' ],
    [ 'timepersol:s', 'Maximum time spent per solution' ],
    [ 'timelimit:s', 'Maximum toal time' ],
    [ 'numsol:i', 'Number of solutions desired', {"default" => 1} ],
    [ 'media|m:s', 'Media formulation for QuantOpt' ],
    [ 'modelws:s', 'Workspace with model' ],
    [ 'addlcpd|c:s@', 'Additional compounds (; delimiter)' ],
    [ 'maximize:s', 'Maximize objective', { "default" => 1 } ],
    [ 'biomass|b:s', 'Target biomass (bio1 is default)' ],
    [ 'objterms:s@', 'Objective terms' ],
    [ 'geneko:s@', 'List of gene KO (; delimiter)' ],
    [ 'rxnko:s@', 'List of reaction KO (; delimiter)' ],
    [ 'bounds:s@', 'Custom bounds' ],
    [ 'constraints:s@', 'Custom constraints' ],
    [ 'solver:s', 'Solver to use for QuantOpt' ],
    [ 'workspace|w:s', 'Workspace to save modified model in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (!defined($opt->{mediaws}) && defined($opt->{media})) {
	$opt->{mediaws} = $opt->{workspace};
}
if (!-e $opt->{"Constraints filename"}) {
	print "Input constrains file not found!\n";
	exit();
}
$params->{constraints} = parse_input_table($opt->{"Constraints filename"},[
	["variable",1,undef,undef],
	["type",1,undef,undef],
	["min",1,undef,undef],
	["max",1,undef,undef],
]);
$params->{formulation} = {
	geneko => [],
	rxnko => [],
	bounds => [],
	constraints => [],
	additionalcpds => [],
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
if (defined($opt->{additionalcpds})) {
	foreach my $cpd (@{$opt->{additionalcpds}}) {
		push(@{$params->{formulation}->{additionalcpds}},split(/;/,$cpd));
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
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Flux balance analysis failed!\n";
} else {
	print "Flux balance analysis successful:\n";
	printObjectInfo($output);
}
