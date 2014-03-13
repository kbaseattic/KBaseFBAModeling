#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );

#Defining globals describing behavior
my $primaryArgs = ["RxnSensitivity ID"];
my $servercommand = "delete_noncontributing_reactions";
my $script = "fba-delete_noncontributing_reactions";
my $translation = {
    "RxnSensitivity ID" => "rxn_sensitivity",
    "rxnsensws" => "rxn_sensitivity_ws",
    "newmodel" => "new_model_uid",
    "newmodelws" => "workspace"
};

#Defining usage and options
my $specs = [
    [ 'RxnSensitivity ID : ID for RxnSensitivty object in the workspace (run with --deleterxns)' ],
    [ 'rxnsensws|w:s', 'Workspace for RxnSensitivity object', { "default" => fbaws() } ],
    [ 'newmodel:s', 'ID for new model with reactions deleted (default is to save it to the same ID as was originally used to run the RxnSensitivity)' ],
    [ 'newmodelws:s', 'Workspace for new model with reactions deleted', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
    print "Deleting reactions failed!"
} else {
    printObjectInfo($output);
}
