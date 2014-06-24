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
my $primaryArgs = ["Model"];
my $servercommand = "generate_model_stats";
my $script = "fba-modelstats";
my $translation = {
	Model => "model",
	modelws => "model_workspace",
};

#Defining usage and options
my $specs = [
    [ 'modelws:s', 'Workspace with PromConstraint', { "default" => fbaws() } ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model stat compute failed!\n";
} else {
	print "Overall model stats:\n";
	my $rows = [qw(
		id
		scientific_name
		dna_size
		num_contigs
		genome_ref
		domain
		taxonomy
		source
		gc_content
		total_reactions
		total_genes
		total_compounds
		extracellular_compounds
		intracellular_compounds
		transport_reactions
		subsystem_reactions
		subsystem_genes
		spontaneous_reactions
		reactions_with_genes
		gapfilled_reactions
 		model_genes
		minimal_essential_genes
		complete_essential_genes
		minimal_essential_reactions
		complete_essential_reactions
		minimal_blocked_reactions
		complete_blocked_reactions
		minimal_variable_reactions
		complete_variable_reactions
		growth_complete_media
		growth_minimal_media
	)];	
	foreach my $row (@{$rows}) {
		print $row."\t".$output->{$row}."\n";
	}
	print "\nSubsystems stats:\n";
	my $newrows = [qw(
		name
		class
		subclass
		genes
		reactions
		model_genes
		minimal_essential_genes
		complete_essential_genes
		minimal_essential_reactions
		complete_essential_reactions
		minimal_blocked_reactions
		complete_blocked_reactions
		minimal_variable_reactions
		complete_variable_reactions
	)];
	print join("\t",@{$newrows})."\n";
	foreach my $ss (@{$output->{subsystems}}) {
		foreach my $row (@{$newrows}) {
			if (defined($ss->{$row})) {
				print $ss->{$row}."\t";
			} else {
				print "\t";
			}
		}
		print "\n";
	}
}
