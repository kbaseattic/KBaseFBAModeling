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
my $primaryArgs = ["Genome IDs (; delimiter)","Genome workspaces (; delimiter)"];
my $servercommand = "compare_genomes";
my $script = "ga-compare-genomes";
my $translation = {};
#Defining usage and options
my $specs = [
    [ 'pretty|p', 'Pretty print output' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{genomes} = [split(/;/,$opt->{"Genome IDs (; delimiter)"})];
$params->{workspaces} = [split(/;/,$opt->{"Genome workspaces (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Genome comparison failed!\n";
} else {
	print join("\t",('Genome', 'Workspace', 'Genome name', 'Taxonomy', 'Features','Core functions','Noncore functions'))."\n";
    for (my $i=0; $i < @{$output->{genome_comparisons}}; $i++) {
    	my $gencmp = $output->{genome_comparisons}->[$i];
    	my $items = [qw(genome workspace genome_name taxonomy features core_functions noncore_functions)];
    	foreach my $item (@{$items}) {
    		if (defined($gencmp->{$item})) {
    			print $gencmp->{$item};
    		}
    		if ($item ne "noncore_functions") {
    			print "\t";
    		}
    	}
    	print "\n";
    }
    print "\n\n";
    my $columns = ['Functional role','Core','Subsystem','Class','Subclass','Number genomes','Fraction genomes'];
    for (my $i=0; $i < @{$output->{genome_comparisons}}; $i++) {
    	push(@{$columns},$output->{genome_comparisons}->[$i]->{workspace}."/".$output->{genome_comparisons}->[$i]->{genome});
    }
    print join("\t",@{$columns})."\n";
    for (my $i=0; $i < @{$output->{function_comparisons}}; $i++) {
    	my $funccomp = $output->{function_comparisons}->[$i];
    	my $items = [qw(role core subsytem primclass subclass number_genomes fraction_genomes)];
    	my $row = [];
    	foreach my $item (@{$items}) {
    		if (defined($funccomp->{$item})) {
    			push(@{$row},$funccomp->{$item});
    		} else {
    			push(@{$row},"");
    		}
    	}
    	for (my $j=0; $j < @{$output->{genome_comparisons}}; $j++) {
    		my $ftrs = "";
    		my $gencmp = $output->{genome_comparisons}->[$j];
    		if (defined($funccomp->{genome_features}->{$gencmp->{workspace}."/".$gencmp->{genome}})) {
    			$ftrs = join(";",@{$funccomp->{genome_features}->{$gencmp->{workspace}."/".$gencmp->{genome}}});
    		}
    		push(@{$row},$ftrs);
    	}
    	print join("\t",@{$row})."\n";
    }
}