#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(printJobData auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Model ID","Reactions (; delimiter)"];
my $servercommand = "reaction_sensitivity_analysis";
my $script = "fba-rxn-sensitivity";
my $translation = {
	"Model ID" => "model",
	modelws => "model_ws",
	newuid => "rxnsens_uid",
	type => "type",
	deleterxn => "delete_noncontributing_reactions",
	editmodel => "integrate_deletions_in_model",
};
#Defining usage and options
my $specs = [
    [ 'newuid|u:s', 'ID for reaction sensitivity in workspace' ],
    [ 'modelws|m:s', 'Workspace where model is located' ],
    [ 'type|t:s', 'Type of reaction sensitivity analysis' ],
    [ 'fromfile|f', 'Load model list from file. Input file should have three columns with headers: Model, Workspace, and Abundance.' ],
    [ 'workspace|w=s', 'Workspace to save merged model', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{reactions_to_delete} = [split(/;/,$opt->{"Reactions (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Reactions sensitivity queue failed!\n";
} else {
	print "Reactions sensitivity queue successful:\n";
	printJobData($output);
}
