#!/usr/bin/env perl
########################################################################
# Authors: Chris Henry, Matthew benedict
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior

my $primaryArgs = ["Model ID" , "PhenotypeSet ID" , "Output model ID"];
my $servercommand = "add_media_transporters";
my $script = "fba-addphenotypetransporters";
my $translation = {
	"Model ID" => "model",
	"PhenotypeSet ID" => "phenotypeSet",
	"Output model ID" => "outmodel",
	phenotypews => "phenotypeSet_workspace",
	modelws   => "model_workspace",
	workspace => "workspace",
	alltransporters => "all_transporters",
	positivetransporters => "positive_transporters"
};
#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace to save the modified model', { "default" => fbaws() } ],
    [ 'modelws:s', 'Workspace in which the original model is found', { "default" => fbaws() } ],
    [ 'phenotypews:s', 'Workspace in which the PhenotypeSet is found', { "default" => fbaws() } ],
    [ 'alltransporters|a', 'Add transporters for ALL media in the phenotype set' ],
    [ 'positivetransporters|p', 'Add transporters ONLY for media in the phenotype set with non-zero growth rates' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
    print "Failed to generate a new model!\n";
} else {
    print "New model successfully added to the workspace!\n";
    printObjectMeta($output);
}

