#!/usr/bin/perl -w

use strict;
use Bio::KBase::fbaModelServices::Impl;
use Bio::KBase::workspace::ScriptHelpers qw(workspaceURL get_ws_client workspace parseObjectMeta parseWorkspaceMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(getToken fbaws get_fba_client runFBACommand universalFBAScriptCode );

$|=1;

$Bio::KBase::fbaModelServices::Server::CallContext = {token => getToken()};
my $fba = Bio::KBase::fbaModelServices::Impl->new({"workspace-url" => workspaceURL()});
$fba->_setContext($Bio::KBase::fbaModelServices::Server::CallContext,{});

my $ws = $fba->_workspaceServices();
my $genomes = $ws->list_objects({
	workspaces => ["HL_PNNLGeneCallsAndAnnotation"],
	type => "KBaseGenomes.Genome"
});

for (my $i=0; $i < @{$genomes}; $i++) {
	my $genome = $fba->_get_msobject("Genome","HL_PNNLGeneCallsAndAnnotation",$genomes->[$i]->[1]);
	$genome->integrate_contigs({contigobj => $genome->contigset(),update_features => 1});
	$fba->_save_msobject($genome,"Genome","HL_PNNLGeneCallsAndAnnotation",$genomes->[$i]->[1]);
}