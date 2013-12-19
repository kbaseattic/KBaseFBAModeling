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


my $manpage =
    "
NAME
      kbfba-reactionsensitivity

DESCRIPTION

      Runs a 'reaction sensitivity' analysis, iteratively deleting specified reactions (or reactions in a specified gapfill solution)
      and identifies a) the growth rate upon removing the reaction and b) any reactions in the network that are inactivated when a given
      reaction is removed. There are two different inputs you can provide to this function:

      1: You can provide a list of reactions (optionally with direction specified by + or -. By default both directions are tested)  Reactions
         will be tested in the order in which they appear. To do this use --rxnstotest.

      --rxnstotest '+rxn00001;-rxn00002'

      2: You can specify a Gapfill solution ID (GapfillUUID.solution.# where # is the solution number) and the sensitivity of removing each reaction
         will be tested. Gapfill reactions will be tested in the opposite order in which they were gapfilled unless --rxnprobs is specified.

      --gapfill 'GapfillID'.solution.#

      OTHER OPTIONS OF NOTE:

      --rxnprobs: If a rxnprobs object is specified, gapfill solution reactions will be tested for removal in order from least likelihood to most likelihood.

      --deleterxns: By default the analysis will replace each reaction (necessary or not) before testing the next one in the list.
      By specifying --deleterxns, the sensitivity analysis will NOT replace 'unnecessary' reactions before testing the next reaction. Thus
      other reactions in the model that were previously 'unnecessary' could become necessary and be kept if they appear later in the list.
      
      If --deleterxns is specified you can actually remove the reactions flagged for deletion using kbfba-delete_noncontributing_reactions.

      If both --deleterxns and --gapfill are specified the gapfill reactions will be tested first, followed by the specified reactions.

EXAMPLES

      > kbfba-reactionsensitivity --rxnstotest '+rxn00001;-rxn00002' MyModel
      > kbfba-reactionsensitivity --gapfill 'GapfillID'.solution.0 MyModel

SEE ALSO
      kbfba-gapfill
      kbfba-delete_noncontributing_reactions

AUTHORS
      Christopher Henry
      Matthew Benedict
";


#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace in which to save the RxnSensitivity object (default: current workspace)', { "default" => workspace() } ],
    [ 'rxnsensid|r:s', 'ID for RxnSensitivity object to be outputted' ],
    [ 'modelws:s', 'Workspace in which the input model is found (default: current workspace)', { "default" => workspace() } ],
    [ 'deleterxns', 'Delete nonconributing reactions before testing the next sensitivity of the others in the list' ],
    [ 'rxnstotest:s', 'Reactions to test the sensitivity for, in order to try them (;-delimited). Specify this or a gapfill solution ID. Use + or - to specify a direction, by default both directions are tested.' ],
    [ 'gapfill:s', 'Gapfill solution ID (UUID.solution.#). Specify this or a list of reactions to test.'],
    [ 'rxnprobs:s', 'RxnProbs object. If provided, reaction sensitivity is done with lowest-likelihood reactions first. Only applicable if a gapfill solution is provided.' ],
    [ 'rxnprobsws:s', 'RxnProbs object workspace (default: current workspace)', { "default" => workspace() } ]
    ];

my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);

my $ok = 0;
if ( defined($opt->{rxnstotest}) ) {
    $params->{reactions_to_delete} = [split(/;/,$opt->{"rxnstotest"})];
    $ok = 1;
} 
if ( defined($opt->{gapfill}) ) {
    $params->{gapfill_solution_id} = $opt->{gapfill};
    $ok = 1;
} 
if ( $ok == 0 ) {
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
