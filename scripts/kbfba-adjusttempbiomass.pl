#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Template ID","Biomass ID"];
my $servercommand = "adjust_template_biomass";
my $script = "kbfba-adjusttempbiomass";
my $translation = {
	"Template ID" => "templateModel",
	"Biomass ID" => "biomass",
	workspace => "workspace",
	other => "other",
	protein => "protein",
	dna => "dna",
	rna => "rna",
	cofactor => "cofactor",
	energy => "energy",
	cellwall => "cellwall",
	lipid => "lipid",
	name => "name",
	type => "type",
	"new" => "new",
	"delete" => "delete",
	auth => "auth",
	clearBiomassCompounds => "clearBiomassCompounds"
};
#Defining usage and options
my $specs = [
    [ 'name=s', 'Name of template biomass reaction' ],
    [ 'protein=s', 'Fraction of protein in  biomass' ],
    [ 'dna=s', 'Fraction of DNA in  biomass' ],
    [ 'rna=s', 'Fraction of RNA in  biomass' ],
    [ 'cofactor=s', 'Fraction of cofactors in  biomass' ],
    [ 'cellwall=s', 'Fraction of cellwall in  biomass' ],
    [ 'lipid=s', 'Fraction of lipid in  biomass' ],
    [ 'energy=s', 'Number of ATP required for a gram of biomass' ],
    [ 'type=s', 'Type of template biomass reaction' ],
    [ 'new', 'Create new biomass reaction' ],
    [ 'delete', 'Delete specified biomass reaction' ],
    [ 'clearBiomassCompounds', 'Clear all biomass compounds' ],
    [ 'compoundsToRempve=s@', 'Compounds to remove from reaction (; delimited)' ],
    [ 'workspace|w=s', 'Workspace with template model', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{compoundsToRempve})) {
	foreach my $cpd (@{$opt->{compoundsToRempve}}) {
		push(@{$params->{compoundsToRempve}},split(/;/,$cpd));
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of template reaction failed!\n";
} else {
	print "Adjustment of template reaction successful:\n";
}