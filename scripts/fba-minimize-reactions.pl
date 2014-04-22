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
my $servercommand = "queue_job";
my $script = "fba-minimize-reactions";
my $translation = {
	Model => "model",
	workspace => "workspace",
	modelws => "model_workspace",
	outid => "output_id",
	biomass => "biomass",
	timelimit => "timelimit",
	solver => "solver"
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
    [ 'outid|o:s', 'ID for FBA result in workspace' ],
    [ 'modelws:s', 'Workspace with model for analysis' ],
    [ 'biomass|b:s', 'Biomass to optimize' ],
    [ 'objfraction|f:s', 'Fraction objective to constraint' ],
    [ 'timelimit:s', 'Maximum toal time' ],
    [ 'minrxn|x:s@', 'Minimize this list of reactions (; delimiter)'],
    [ 'minrxnfile:s', 'File with reactions to minimize'],
    [ 'rxnsensitivity|y', 'Flag indicates if sensitivity analysis of gapfill solutions should run'],
    [ 'media|m:s', 'Media formulation for FBA (default is complete media)' ],
    [ 'mediaws:s', 'Workspace with media formulation' ],
    [ 'addlcpd|c:s@', 'Additional compounds (; delimiter)' ],
    [ 'numsol:i', 'Number of solutions desired', {"default" => 1} ],
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
    [ 'solver:s', 'Solver to use for gapfilling' ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (!defined($opt->{mediaws}) && defined($opt->{media})) {
	$opt->{mediaws} = $opt->{workspace};
}
if (defined($opt->{minrxn})) {
	foreach my $terms (@{$opt->{minrxn}}) {
		my $array = [split(/;/,$terms)];
		push(@{$params->{reactions}},@{$array});
	}
} elsif (defined($opt->{minrxnfile})) {
	$params->{reactions} = [];
	$params->{reaction_costs} = {};
	open(my $inputfh, "<", $opt->{minrxnfile}) or die "Cannot open input file";
	my $line;
	while (defined($line = <$inputfh>)) {
		chomp($line);
		my $array = [split(/[\t\s]+/,$line)];
		if (defined($array->[0])) {
			push(@{$params->{reactions}},$array->[0]);
		}
		if (defined($array->[1])) {
			$params->{reaction_costs}->{$array->[0]} = $array->[1];
		}         
	}
	close($inputfh);
} else {
	$params->{reactions} = [];
	$params->{all_model_reactions} = 1;
}
$params->{formulation} = {
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
my $output = runFBACommand({method => "minimize_reactions",parameters => $params},$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Reaction minimization queue failed!\n";
} else {
	print "Reaction minimization job queued:\n";
	printJobData($output);
}
