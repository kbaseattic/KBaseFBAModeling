#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta printObjectInfo);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws printJobData get_fba_client runFBACommand universalFBAScriptCode );
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
	phenows => "phenotypeSet_workspace",
	phenoid => "phenotypeSet",
	timepersol => "timePerSolution",
	timelimit => "totalTimeLimit",
	iterativegf => "completeGapfill",
	solver => "solver",
	fastgapfill => "fastgapfill",
	sourcemdl => "source_model",
	sourcemdlws => "source_model_ws",
	simultaneous => "simultaneous",
	activitybonus => "activation_penalty"
};
my $gfTranslation = {
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
    [ 'longgapfill', 'Run a longer gapfilling but with a potentially better solution' ],
    [ 'simultaneous', 'Simultaneous gapfill all reactions', { "default" => 0 } ],
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

$params->{formulation} = {
	blacklistedrxns => [qw(
rxn12985 rxn00238 rxn07058 rxn05305 rxn00154 rxn09037 rxn10643
rxn11317 rxn05254 rxn05257 rxn05258 rxn05259 rxn05264 rxn05268
rxn05269 rxn05270 rxn05271 rxn05272 rxn05273 rxn05274 rxn05275
rxn05276 rxn05277 rxn05278 rxn05279 rxn05280 rxn05281 rxn05282
rxn05283 rxn05284 rxn05285 rxn05286 rxn05963 rxn05964 rxn05971
rxn05989 rxn05990 rxn06041 rxn06042 rxn06043 rxn06044 rxn06045
rxn06046 rxn06079 rxn06080 rxn06081 rxn06086 rxn06087 rxn06088
rxn06089 rxn06090 rxn06091 rxn06092 rxn06138 rxn06139 rxn06140
rxn06141 rxn06145 rxn06217 rxn06218 rxn06219 rxn06220 rxn06221
rxn06222 rxn06223 rxn06235 rxn06362 rxn06368 rxn06378 rxn06474
rxn06475 rxn06502 rxn06562 rxn06569 rxn06604 rxn06702 rxn06706
rxn06715 rxn06803 rxn06811 rxn06812 rxn06850 rxn06901 rxn06971
rxn06999 rxn07123 rxn07172 rxn07254 rxn07255 rxn07269 rxn07451
rxn09037 rxn10018 rxn10077 rxn10096 rxn10097 rxn10098 rxn10099
rxn10101 rxn10102 rxn10103 rxn10104 rxn10105 rxn10106 rxn10107
rxn10109 rxn10111 rxn10403 rxn10410 rxn10416 rxn11313 rxn11316
rxn11318 rxn11353 rxn05224 rxn05795 rxn05796 rxn05797 rxn05798
rxn05799 rxn05801 rxn05802 rxn05803 rxn05804 rxn05805 rxn05806
rxn05808 rxn05812 rxn05815 rxn05832 rxn05836 rxn05851 rxn05857
rxn05869 rxn05870 rxn05884 rxn05888 rxn05896 rxn05898 rxn05900
rxn05903 rxn05904 rxn05905 rxn05911 rxn05921 rxn05925 rxn05936
rxn05947 rxn05956 rxn05959 rxn05960 rxn05980 rxn05991 rxn05992
rxn05999 rxn06001 rxn06014 rxn06017 rxn06021 rxn06026 rxn06027
rxn06034 rxn06048 rxn06052 rxn06053 rxn06054 rxn06057 rxn06059
rxn06061 rxn06102 rxn06103 rxn06127 rxn06128 rxn06129 rxn06130
rxn06131 rxn06132 rxn06137 rxn06146 rxn06161 rxn06167 rxn06172
rxn06174 rxn06175 rxn06187 rxn06189 rxn06203 rxn06204 rxn06246
rxn06261 rxn06265 rxn06266 rxn06286 rxn06291 rxn06294 rxn06310
rxn06320 rxn06327 rxn06334 rxn06337 rxn06339 rxn06342 rxn06343
rxn06350 rxn06352 rxn06358 rxn06361 rxn06369 rxn06380 rxn06395
rxn06415 rxn06419 rxn06420 rxn06421 rxn06423 rxn06450 rxn06457
rxn06463 rxn06464 rxn06466 rxn06471 rxn06482 rxn06483 rxn06486
rxn06492 rxn06497 rxn06498 rxn06501 rxn06505 rxn06506 rxn06521
rxn06534 rxn06580 rxn06585 rxn06593 rxn06609 rxn06613 rxn06654
rxn06667 rxn06676 rxn06693 rxn06730 rxn06746 rxn06762 rxn06779
rxn06790 rxn06791 rxn06792 rxn06793 rxn06794 rxn06795 rxn06796
rxn06797 rxn06821 rxn06826 rxn06827 rxn06829 rxn06839 rxn06841
rxn06842 rxn06851 rxn06866 rxn06867 rxn06873 rxn06885 rxn06891
rxn06892 rxn06896 rxn06938 rxn06939 rxn06944 rxn06951 rxn06952
rxn06955 rxn06957 rxn06960 rxn06964 rxn06965 rxn07086 rxn07097
rxn07103 rxn07104 rxn07105 rxn07106 rxn07107 rxn07109 rxn07119
rxn07179 rxn07186 rxn07187 rxn07188 rxn07195 rxn07196 rxn07197
rxn07198 rxn07201 rxn07205 rxn07206 rxn07210 rxn07244 rxn07245
rxn07253 rxn07275 rxn07299 rxn07302 rxn07651 rxn07723 rxn07736
rxn07878 rxn11417 rxn11582 rxn11593 rxn11597 rxn11615 rxn11617
rxn11619 rxn11620 rxn11624 rxn11626 rxn11638 rxn11648 rxn11651
rxn11665 rxn11666 rxn11667 rxn11698 rxn11983 rxn11986 rxn11994
rxn12006 rxn12007 rxn12014 rxn12017 rxn12022 rxn12160 rxn12161
rxn01267 )],
	gauranteedrxns => [qw(
rxn1 rxn2 rxn3 rxn4 rxn5 rxn6 rxn7 rxn8
rxn13782 rxn13783 rxn13784 rxn05294 rxn05295 rxn05296 rxn10002
rxn10088 rxn11921 rxn11922 rxn10200 rxn11923 rxn05029 )],
	allowedcmps => ["c","e","p"]
};
foreach my $key (keys(%{$gfTranslation})) {
	if (defined($opt->{$key})) {
		$params->{formulation}->{$gfTranslation->{$key}} = $opt->{$key};
	}
}
if (defined($opt->{blacklist})) {
	foreach my $terms (@{$opt->{blacklist}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{formulation}->{blacklistedrxns}},@{$array});
	}
}
if (defined($opt->{guaranteed})) {
	foreach my $terms (@{$opt->{guaranteed}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{formulation}->{gauranteedrxns}},@{$array});
	}
}
if (defined($opt->{allowedcmp})) {
	foreach my $terms (@{$opt->{allowedcmp}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{formulation}->{allowedcmps}},@{$array});
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