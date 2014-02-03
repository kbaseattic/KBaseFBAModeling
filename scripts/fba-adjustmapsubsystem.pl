#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Map ID","Subsystem ID"];
my $servercommand = "adjust_mapping_subsystem";
my $script = "fba-adjustmapsubsystem";
my $translation = {
	"Map ID" => "map",
	"Subsystem ID" => "subsystem",
	workspace => "workspace",
	name => "name",
	type => "type",
	class => "class",
	subclass => "subclass",
	"new" => "new",
	"delete" => "delete",
	auth => "auth"
};
#Defining usage and options
my $specs = [
    [ 'name=s', 'Name of subsystem' ],
    [ 'type=s', 'Type of subsystem' ],
    [ 'class=s', 'Class of subsystem' ],
    [ 'subclass=s', 'Subclass of subsystem' ],
    [ 'new', 'Create new subsystem' ],
    [ 'delete', 'Delete specified subsystem' ],
    [ 'rolestoadd=s@', 'Roles to add to subsystem (; delimited)' ],
    [ 'rolestoremove=s@', 'Roles to remove from subsystem (; delimited)' ],
    [ 'workspace|w=s', 'Workspace with mapping to be adjusted', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{rolestoadd})) {
	foreach my $role (@{$opt->{rolestoadd}}) {
		push(@{$params->{rolesToAdd}},split(/;/,$role));
	}
}
if (defined($opt->{rolestoremove})) {
	foreach my $role (@{$opt->{rolestoremove}}) {
		push(@{$params->{rolesToRemove}},split(/;/,$role));
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of map subsystem failed!\n";
} else {
	print "Adjustment of map subsystem successful:\n";
	printObjectInfo($output);
}