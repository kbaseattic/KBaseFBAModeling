#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Model IDs (; delimiter)","Model workspaces (; delimiter)"];
my $servercommand = "compare_models";
my $script = "fba-compare-mdls";
my $translation = {};
#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{models} = [split(/;/,$opt->{"Model IDs (; delimiter)"})];
$params->{workspaces} = [split(/;/,$opt->{"Model workspaces (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model comparison failed!\n";
} else {
	print join("\t",('Model', 'Workspace', 'Model name', 'Genome', 'Genome name','Gapfilled reactions', 'Core reactions','Noncore reactions'))."\n";
    for (my $i=0; $i < @{$output->{model_comparisons}}; $i++) {
    	my $mdlcmp = $output->{model_comparisons}->[$i];
    	my $items = [qw(model workspace model_name genome genome_name gapfilled_reactions core_reactions noncore_reactions)];
    	foreach my $item (@{$items}) {
    		if (defined($mdlcmp->{$item})) {
    			print $mdlcmp->{$item};
    		}
    		if ($item ne "noncore_reactions") {
    			print "\t";
    		}
    	}
    	print "\n";
    }
    print "\n\n";
    my $columns = ['Reaction','Compartment', 'Equation','Core','Role','Subsystem','Class','Subclass','Number models','Fraction models'];
    for (my $i=0; $i < @{$output->{model_comparisons}}; $i++) {
    	push(@{$columns},$output->{model_comparisons}->[$i]->{workspace}."/".$output->{model_comparisons}->[$i]->{model});
    }
    print join("\t",@{$columns})."\n";
    for (my $i=0; $i < @{$output->{reaction_comparisons}}; $i++) {
    	my $rxncmp = $output->{reaction_comparisons}->[$i];
    	my $items = [qw(reaction compartment equation core role subsytem primclass subclass number_models fraction_models)];
    	my $row = [];
    	foreach my $item (@{$items}) {
    		if (defined($rxncmp->{$item})) {
    			push(@{$row},$rxncmp->{$item});
    		} else {
    			push(@{$row},"");
    		}
    	}
    	for (my $j=0; $j < @{$output->{model_comparisons}}; $j++) {
    		my $ftrs = "";
    		my $mdlcmp = $output->{model_comparisons}->[$j];
    		if (defined($rxncmp->{model_features}->{$mdlcmp->{workspace}."/".$mdlcmp->{model}})) {
    			$ftrs = join(";",@{$rxncmp->{model_features}->{$mdlcmp->{workspace}."/".$mdlcmp->{model}}});
				push(@{$row},$ftrs);
    		}
    	}
    	print join("\t",@{$row})."\n";
    }
}
