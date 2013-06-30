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
my $primaryArgs = ["Map ID","Role ID"];
my $servercommand = "adjust_mapping_role";
my $script = "kbfba-adjustmaprole";
my $translation = {
	"Map ID" => "map",
	"Role ID" => "role",
	workspace => "workspace",
	feature => "feature",
	name => "name",
	"new" => "new",
	"delete" => "delete",
	auth => "auth"
};
#Defining usage and options
my $specs = [
    [ 'name=s', 'Name of role' ],
    [ 'feature=s', 'Example feature for role' ],
    [ 'new', 'Create new role' ],
    [ 'delete', 'Delete specified role' ],
    [ 'aliasesToAdd=s@', 'Aliases to add to role (; delimited)' ],
    [ 'aliasesToRemove=s@', 'Aliases to remove from role (; delimited)' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{aliasesToAdd})) {
	foreach my $alias (@{$opt->{aliasesToAdd}}) {
		push(@{$params->{aliasesToAdd}},split(/;/,$alias));
	}
}
if (defined($opt->{aliasesToRemove})) {
	foreach my $alias (@{$opt->{aliasesToRemove}}) {
		push(@{$params->{aliasesToRemove}},split(/;/,$alias));
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of map role failed!\n";
} else {
	print "Adjustment of map role successful:\n";
}