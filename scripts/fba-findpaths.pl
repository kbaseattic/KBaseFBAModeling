#!/usr/bin/env perl
########################################################################
# Authors: Mike Mundy, Matt Benedict, Nick Chia
# Contact email: mundy.michael@mayo.edu
# Development location: Mayo Clinic
########################################################################

use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );

#Defining globals describing behavior
my $primaryArgs = [ "Reaction synonyms ID", "Media ID", "Input Model ID", "Output Model ID" ];
my $servercommand = "find_paths";
my $script = "fba-findpaths";
my $translation = {
	"Reaction synonyms ID" => "reaction_synonyms",
	"Media ID" => "media",
	"Input Model ID" => "input_model",
	"Output Model ID" => "output_model",
	iterations => "iterations",
	workspace => "workspace",
	mediaws   => "media_workspace",
	biochem   => "biochemistry",
	biochemws => "biochemistry_workspace",
	overwrite => "overwrite"
};

#Defining usage and options
my $specs = [
	[ 'iterations|i', 'number of times to run FBA to find paths', { "default" => 1 } ],
	[ 'workspace|w:s', 'ID of workspace containing reaction synonyms and model objects', { "default" => fbaws() } ],
	[ 'mediaws:s', 'ID of workspace containing media object', { "default" => fbaws() } ],
	[ 'biochem|b:s', 'ID of the biochemistry database', { "default" => "default" } ],
	[ 'biochemws:s', 'ID of workspace containing biochemistry database', { "default" => "kbase" } ],
	[ 'overwrite|o', 'Set as 1 to overwrite existing output model object', { "default" => 0 } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);

#Checking output and report results
if (!defined($output)) {
	print "Find paths failed!\n";
} else {
	print "Path model successfully generated in workspace:\n";
	printObjectMeta($output);
}