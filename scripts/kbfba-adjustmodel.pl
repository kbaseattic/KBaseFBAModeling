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
my $primaryArgs = ["Model ID","Reaction ID"];
my $servercommand = "adjust_model_reaction";
my $script = "kbfba-adjustmodel";
my $translation = {
	"Model ID" => "model",
	workspace => "workspace",
	"Reaction ID" => "reaction",
	direction => "direction",
	compartment => "compartment",
	compindex => "compartmentIndex",
	gpr => "gpr",
	removerxn => "removeReaction",
	addrxn => "addReaction",
	auth => "auth",
	overwrite => "overwrite",
	outputid => "outputid"
};
#Defining usage and options
my $specs = [
    [ 'direction|d:s', 'Directionality for reaction', { "default" => "bio1" }  ],
    [ 'compartment|c:s', 'Compartment for reaction', { "default" => "c" } ],
    [ 'compindex|i:s', 'Index of compartment for reaction', { "default" => 0 } ],
    [ 'gpr|g:s', 'GPR for reaction'],
    [ 'removerxn|r', 'Remove reaction', { "default" => 0 } ],
    [ 'addrxn|a', 'Add reaction', { "default" => 0 } ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing FBA with same name' ],
    [ 'outputid|u:s', 'Output ID for adjusted reaction (by default, creates a new version of the same model)']
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of model failed!\n";
} else {
	print "Adjustment of model successful:\n";
	printObjectMeta($output);
}
