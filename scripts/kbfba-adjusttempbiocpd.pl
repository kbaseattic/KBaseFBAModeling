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
my $primaryArgs = ["Template ID","Biomass ID","Compound ID"];
my $servercommand = "adjust_template_biomass";
my $script = "kbfba-adjusttempbiocpd";
my $translation = {
	"Template ID" => "templateModel",
	"Biomass ID" => "biomass",
	workspace => "workspace",
	auth => "auth"
};
#Defining usage and options
my $specs = [
    [ 'compartment|c=s', 'Compartment of template biomass compound', { "default" => "c" } ],
    [ 'coef=s', 'Coefficient of template biomass compound' ],
    [ 'coeftype=s', 'Coefficient type of template biomass compound' ],
    [ 'class=s', 'Class of template biomass compound' ],
    [ 'universal', 'Indicates if template biomass compound should be universal' ],
    [ 'linkcpds=s@', 'Compounds linked to current compound (; delimited)' ],
    [ 'workspace|w=s', 'Workspace with template model', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{compoundsToAdd} = [$opt->{"Compound ID"},$opt->{compartment},$opt->{class},$opt->{universal},$opt->{coeftype},$opt->{coef},[]];
if (defined($opt->{linkcpds})) {
	foreach my $cpd (@{$opt->{linkcpds}}) {
		my $array = [split(/:/,$cpd)];
		push(@{$params->{compoundsToAdd}->[6]},$array);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of template biomass failed!\n";
} else {
	print "Adjustment of template biomass successful:\n";
}