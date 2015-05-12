#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta printObjectInfo);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(load_table fbaws printJobData get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Model"];
my $servercommand = "queue_gapfill_model";
my $script = "fba-gapfill";
my $translation = {
	Model => "model",
	modelws => "model_workspace",
	modelout => "out_model",
	outputid => "out_model",
	gapfillid => "gapFill",
	gapfillws => "gapFill_workspace",
	workspace => "workspace",
	intsol => "integrate_solution",
	timepersol => "timePerSolution",
	timelimit => "totalTimeLimit",
	iterativegf => "completeGapfill",
	solver => "solver",
	fastgapfill => "fastgapfill",
	sourcemdl => "source_model",
	sourcemdlws => "source_model_ws",
	alpha => "alpha",
	omega => "omega",
	scalefluxes => "scalefluxes",
	expthreshtype => "expression_threshold_type",
	lowexpthresh => "low_expression_threshold",
	lowexppen => "low_expression_penalty_factor",
	highexpthresh => "high_expression_threshold",
	highexppen => "high_expression_penalty_factor",
	expsample => "expsample",
	expsamplews => "expsamplews",
	rxnsensitivity => "sensitivity_analysis",
	numsol => "num_solutions",
	nomediahyp => "nomediahyp",
	nobiomasshyp => "nobiomasshyp",
	nogprhyp => "nogprhyp",
	nopathwayhyp => "nopathwayhyp",
	allowunbalanced => "allowunbalanced",
	drainpen => "drainpen",
	directionpen => "directionpen",
	nostructpen => "nostructpen",
	unfavorablepen => "unfavorablepen",
	nodeltagpen => "nodeltagpen",
	biomasstranspen => "biomasstranspen",
	singletranspen => "singletranspen",
	transpen=> "transpen",
	probrxn => "probabilisticReactions",
	probanno => "probabilisticAnnotation",
	probannows => "probabilisticAnnotation_workspace",
	notes => "notes",
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
    [ 'modelws=s', 'Workspace of model to gapfill', { "default" => fbaws() }  ],
    [ 'sourcemdl=s', 'Source model to gapfill from' ],
    [ 'sourcemdlws=s', 'Workspace of source model to gapfill from', { "default" => fbaws() }  ],
    [ 'intsol', 'Automatically integrate solution', { "default" => 0 } ],
    [ 'expsample=s', 'Expression sample to fit gapfilling' ],
    [ 'expsamplews=s', 'Workspace with expression sample', { "default" => fbaws() } ],
    [ 'expthreshtype=s', 'Type of thresholding used with expression data' ],
    [ 'lowexpthresh=s', 'Threshold for genes with low expression' ],
    [ 'lowexppen=s', 'Penalty for use of genes with low expression' ],
    [ 'highexpthresh=s', 'Threshold for genes with high expression' ],
    [ 'highexppen=s', 'Penalty for inactive genes with high expression' ],
    [ 'longgapfill', 'Run a longer gapfilling but with a potentially better solution' ],
    [ 'alpha:s', 'Constant denoting fraction of objective to use for activation', { "default" => 0 } ],
    [ 'omega:s', 'Constant denoting fraction of objective to use for max objective', { "default" => 0 } ],
    [ 'scalefluxes', 'Scale fluxes in objective' ],
    [ 'iterativegf|t', 'Gapfill all inactive reactions', { "default" => 0 } ],
    [ 'targrxn|x:s@', 'Gapfill to activate these reactions only (; delimiter)'],
    [ 'rxnsensitivity|y', 'Flag indicates if sensitivity analysis of gapfill solutions should run'],
    [ 'timepersol:s', 'Maximum time spent per solution' ],
    [ 'timelimit:s', 'Maximum toal time' ],
    [ 'media|m:s', 'Media formulation for FBA (default is complete media)' ],
    [ 'mediaws:s', 'Workspace with media formulation' ],
    [ 'addlcpd|c:s@', 'Additional compounds (; delimiter)' ],
    [ 'numsol:i', 'Number of solutions desired', {"default" => 1} ],
    [ 'nomediahyp', 'Donot search for media hypotheses', {"default" => 0} ],
    [ 'nobiomasshyp', 'Donot search for biomass hypotheses', {"default" => 1} ],
    [ 'nogprhyp', 'Donot search for gpr hypotheses', {"default" => 0} ],
    [ 'nopathwayhyp', 'Donot search for pathway hypotheses', {"default" => 0} ],
    [ 'allowunbalanced', 'Allow unbalanced reactions in solutions', {"default" => 0} ],
    [ 'activitybonus:s', 'Bonus for activating reactions'],
    [ 'drainpen:s', 'Penalty for drain reactions', {"default" => 1} ],
   	[ 'directionpen:s', 'Penalty for reactions operating in wrong direction', {"default" => 1} ],
    [ 'nostructpen:s', 'Penalty for reactions with missing structures', {"default" => 1} ],
    [ 'unfavorablepen:s', 'Penalty for unfavorable reactions', {"default" => 1} ],
    [ 'nodeltagpen:s', 'Penalty for reactions with no delta G', {"default" => 1} ],
    [ 'biomasstranspen:s', 'Penalty for biomass transport reactions', {"default" => 1} ],
    [ 'singletranspen:s', 'Penalty for single transport reactions', {"default" => 1} ],
    [ 'transpen:s', 'Penalty for transport reactions', {"default" => 1} ],
	[ 'probrxn=s', 'ID of probabilistic reaction object' ],
	[ 'probanno=s', 'ID of probabilistic annotation object' ],
    [ 'probannows:s', 'Workspace with probabilistic annotation or probabilistic reaction', { "default" => fbaws() } ],
    [ 'blacklist:s@', 'List of blacklisted reactions (; delimiter)' ],
    [ 'guaranteed:s@', 'List of guaranteed reactions (; delimiter)' ],
    [ 'allowedcmp:s@', 'List of allowed compartments (; delimiter)' ],
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
    [ 'objfraction:s', 'Fraction of objective for follow on analysis', { "default" => 0.1 }],
    [ 'notes:s', 'Notes for flux balance analysis' ],
    [ 'solver:s', 'Solver to use for gapfilling' ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (!defined($opt->{mediaws}) && defined($opt->{media})) {
	$opt->{mediaws} = $opt->{workspace};
}
if (defined($opt->{probanno}) && defined($opt->{probrxn})) {
    die "Attempt to pass probanno and probrxns objects in the same call. This is not allowed because probrxn is calcualted from probanno and could cause collisions";
}
if (defined($opt->{targrxn})) {
	foreach my $terms (@{$opt->{targrxn}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{target_reactions}},@{$array});
	}
}
if (-e $params->{expsample}) {
	my $data = load_table($params->{expsample},"\t",0);
	foreach my $row (@{$data->{"data"}}) {
		$params->{exp_raw_data}->{$row->[0]} = $row->[1];
	}
	delete $params->{expsample};
}

$params->{blacklistedrxns} = [];
$params->{gauranteedrxns} = [];
if (defined($opt->{blacklist})) {
	foreach my $terms (@{$opt->{blacklist}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{blacklistedrxns}},@{$array});
	}
}
if (defined($opt->{guaranteed})) {
	foreach my $terms (@{$opt->{guaranteed}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{gauranteedrxns}},@{$array});
	}
}
$params->{formulation} = {
	geneko => [],
	rxnko => [],
	bounds => [],
	constraints => [],
	uptakelim => {},
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
if (defined($opt->{uptakelim})) {
	foreach my $uplims (@{$opt->{uptakelim}}) {
		my $array = [split(/;/,$uplims)];
		foreach my $uplim (@{$array}) {
			my $pair = [split(/:/,$uplim)];
			if (defined($pair->[1])) {
				$params->{formulation}->{uptakelim}->{$pair->[0]} = $pair->[1];
			}
		}
	}
}
$params->{formulation}->{nobiomasshyp} = 1;
#Calling the server
if ($opt->{longgapfill}) {
	my $output = runFBACommand($params,"queue_gapfill_model",$opt);
	if (!defined($output)) {
		print "Gapfilling queue failed!\n";
	} else {
		print "Gapfilling job queued:\n";
		printJobData($output);
	}
} else {
	$params->{fastgapfill} = 1;
	my $output = runFBACommand($params,"gapfill_model",$opt);
	if (!defined($output)) {
		print "Gapfilling failed!\n";
	} else {
		print "Gapfilling successful!\n";
		printObjectInfo($output);
		print "Run fba-getgapfills or fba-integratesolution to print solution!\n";
	}
}
