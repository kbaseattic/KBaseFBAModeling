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
my $primaryArgs = ["Model ID"];
my $servercommand = "integrate_reconciliation_solutions";
my $script = "kbfba-integratesolution";
my $translation = {
	"Model ID" => "model",
	modelws => "model_workspace",
	outmodel => "out_model",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite",
	rxnprobs => "rxnprobs",
	rxnprobws =>  "rxnprobs_workspace"

};
#Defining usage and options
my $specs = [
    [ 'gapfillsols|f:s@', 'IDs of gapfilling solutions to integrate (; delimiter)' ],
    [ 'gapgensols|g:s@', 'IDs of gapgen solutions to integrate (; delimiter)'],
    [ 'outmodel|i:s', 'ID to save new model as'],
    [ 'workspace|w:s', 'Reference default workspace', { "default" => workspace() } ],
    [ 'modelws:s', 'Workspace for input FBA model' ],
    [ 'overwrite|o', 'Overwrite any existing model with same name' ],
    [ 'rxnprobs|r:s', 'ID for a rxnprobs object to use to assign GPRs to gapfilled reactions' ],
    [ 'rxnprobsws|x:s', 'Workspace for rxnprobs object', { "default" => workspace() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{gapfillSolutions} = [];
$params->{gapgenSolutions} = [];
if (defined($opt->{gapfillsols})) {
	foreach my $solutions (@{$opt->{gapfillsols}}) {
		push(@{$params->{gapfillSolutions}},split(/;/,$solutions));
	}
}
if (defined($opt->{gapgensols})) {
	foreach my $solutions (@{$opt->{gapgensols}}) {
		push(@{$params->{gapgenSolutions}},split(/;/,$solutions));
	}
}
#Calling the server
print $params;
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Solution integration failed!\n";
} else {
	print "Solutions successfully integrated:\n";
	printObjectMeta($output);
}
