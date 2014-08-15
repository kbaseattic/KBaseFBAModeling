#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Metaprofile ID"];
my $servercommand = "import_metagenome_annotation";
my $script = "fba-metaprofile-to-metaanno";
my $translation = {
	newuid => "metaanno_uid",
	outputid => "metaanno_uid",
	"Metaprofile ID" => "metaprofile_id",
	metaprofilews => "metaprofile_ws",
	sourceid => "source_id",
	source => "source",
	workspace => "workspace",
	type => "type",
	conftype => "confidence_type",
	name => "name",
};
#Defining usage and options
my $specs = [
    [ 'newuid|outputid|u:s', 'ID for metagenome annotation in workspace' ],
    [ 'metaprofilews|m:s', 'Workspace with metagenome profile' ],
    [ 'name|n:s', 'Name for metagenome annotation' ],
    [ 'sourceid|i:s', 'Source ID for metagenome annotation' ],
    [ 'source|s:s', 'Source for metagenome annotation' ],
    [ 'type|t:s', 'Type of metagenome annotation' ],
    [ 'conftype|c:s', 'Confidence type for hits in metagenome annotation' ],
    [ 'workspace|w:s', 'Workspace to save phenotypes in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Metagenome annotation import failed!\n";
} else {
	print "Metagenome annotation import successful:\n";
	printObjectInfo($output);
}