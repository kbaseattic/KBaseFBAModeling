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
my $primaryArgs = ["Media ID","Compound IDs (; delimiter)"];
my $servercommand = "addmedia";
my $script = "kbfba-addmedia";
my $translation = {
	"Media ID" => "media",
	name => "name",
	"Compound IDs (; delimiter)" => "compounds",
	concentrations => "concentrations",
	maxflux => "maxflux",
	minflux => "minflux",
	workspace => "workspace",
	"defined" => "isDefined",
	type => "type",
	minimal => "isMinimal",
	auth => "auth",
	overwrite => "overwrite",
};
my $arrayparams = {
	compounds => ";",
	concentrations => ";",
	maxflux => ";",
	minflux => ";",
};
#Defining usage and options
my $specs = [
    [ 'name:s', 'Media name' ],
    [ 'concentrations=s', 'Compound concentrations (; delimiter)' ],
    [ 'minflux=s', 'Compound minimum fluxes (; delimiter)' ],
    [ 'maxflux=s', 'Compound maximum fluxes (; delimiter)' ],
    [ 'type|t=s', 'Type of media', { "default" => "unspecified" } ],
    [ 'defined|d', 'Media is defined', { "default" => 0 } ],
    [ 'minimal|m', 'Media is minimal', { "default" => 0 } ],
    [ 'workspace|w:s', 'Workspace with model', { "default" => workspace() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (!defined($params->{name})) {
	$params->{name} = $params->{media};
}
$params->{compounds} = [split(/;/,$params->{compounds})];
if (defined($params->{concentrations})) {
	$params->{concentrations} = [split(/;/,$params->{concentrations})];
}
if (defined($params->{minflux})) {
	$params->{minflux} = [split(/;/,$params->{minflux})];
}
if (defined($params->{maxflux})) {
	$params->{maxflux} = [split(/;/,$params->{maxflux})];
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Media creation failed!\n";
} else {
	print "Successfully added media to workspace:\n";
	printObjectMeta($output);
}