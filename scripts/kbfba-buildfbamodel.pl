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
my $primaryArgs = ["Genome"];
my $servercommand = "genome_to_fbamodel";
my $script = "kbfba-buildfbamodel";
my $translation = {
	Genome => "genome",
	genomews => "genome_workspace",
	probanno => "probanno",
	probannows => "probanno_workspace",
	model => "model",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite"
};
#Defining usage and options
my $specs = [
    [ 'model|m:s', 'Name to be provided for output model' ],
    [ 'probanno|p:s', 'ID of probabilistic annotation object to use' ],
    [ 'threshold|t:s', 'Minimum probability of annotations to be used'],
    [ 'workspace|w:s', 'Reference default workspace', { "default" => workspace() } ],
    [ 'probannows:s', 'Workspace of probabilistic annotation object' ],
    [ 'genomews:s', 'Workspace where genome object is located' ],
    [ 'overwrite|o', 'Overwrite any existing model with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model generation failed!\n";
} else {
	print "Model successfully generated in workspace:\n";
	printObjectMeta($output);
}