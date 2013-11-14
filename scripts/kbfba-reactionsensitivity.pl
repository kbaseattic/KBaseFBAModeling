#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspaceService::Helpers qw(printJobData auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );

#Defining globals describing behavior
my $primaryArgs = ["Model ID"];
my $servercommand = "reaction_sensitivity_analysis";
my $script = "kbfba-reactionsensitivity";
my $translation = {
        "Model ID" => "model",
	"modelws" => "model_ws",
	"rxnsensid" => "rxnsens_uid",
	"workspace" => "workspace",
	"deleterxns" => "delete_noncontributing_reactions",
	"rxnprobs" => "rxnprobs_id",
	"rxnprobsws" => "rxnprobs_ws"
};
#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace in which to save the RxnSensitivity object (default: current workspace)', { "default" => workspace() } ],
    [ 'rxnsensid|r:s', 'ID for RxnSensitivity object to be outputted' ],
    [ 'modelws:s', 'Workspace in which the input model is found (default: current workspace)', { "default" => workspace() } ],
    [ 'deleterxns', 'Delete nonconributing reactions before testing the next sensitivity of the others in the list' ],
    [ 'rxnstotest:s', 'Reactions to test the sensitivity for, in order to try them (;-delimited). Specify this or a gapfill solution ID' ],
    [ 'gapfill:s', 'Gapfill solution ID (UUID.solution.#). Specify this or a list of reactions to test.'],
    [ 'rxnprobs:s', 'RxnProbs object. If provided, reaction sensitivity is done with lowest-likelihood reactions first. Only applicable if a gapfill solution is provided.' ],
    [ 'rxnprobsws:s', 'RxnProbs object workspace (default: current workspace)', { "default" => workspace() } ]
    ];

my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

if ( defined($opt->{rxnstotest}) ) {
    $params->{reactions_to_delete} = [split(/;/,$opt->{"rxnstotest"})];
} elsif ( defined($opt->{gapfill}) ) {
    $params->{gapfill_solution_id} = $opt->{gapfill};
} else {
    die "Must specify either a list of reactions to delete or a gapfill solution ID\n";
}

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
    print "Reaction sensitivity analysis failed.\n"
} else {
    print "Reaction sensitivity job queued:\n";
    printJobData($output);
}
