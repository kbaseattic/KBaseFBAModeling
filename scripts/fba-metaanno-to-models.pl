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
my $primaryArgs = ["Metagenome annotation ID"];
my $servercommand = "metagenome_to_fbamodels";
my $script = "fba-merge-models";
my $translation = {
	"Metagenome annotation ID" => "metaanno_uid",
	maxotumod => "max_otu_models",
	minabundance => "min_abundance",
	minreactions => "min_reactions",
	confthreshold => "confidence_threshold",
	metaannows => "metaanno_ws",
	workspace => "workspace",
};
#Defining usage and options
my $specs = [
    [ 'maxotumod|m:s', 'Maximum number of otu models to build', { "default" => 2 } ],
    [ 'minabundance|a:s', 'Minimum average abundance for compartment', { "default" => 1 } ],
    [ 'minreactions|r:s', 'Minimum reactions for otu model', { "default" => 100 } ],
    [ 'confthreshold|c:s', 'Confidence threshold for use of function', { "default" => 0.00001 } ],
    [ 'metaannows|e:s', 'Metagenome annotation workspace', { "default" => workspace() } ],
    [ 'workspace|w=s', 'Workspace to save merged model', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model generation failed!\n";
} else {
	print "Model generation successful:\n";
	for (my $i=0; $i < @{$output}; $i++) {
		printObjectInfo($output->[$i]);
	}
}