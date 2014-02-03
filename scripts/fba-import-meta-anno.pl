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
my $primaryArgs = ["Annotation filename"];
my $servercommand = "import_metagenome_annotation";
my $script = "fba-import-meta-anno";
my $translation = {
	newuid => "metaanno_uid",
	sourceid => "source_id",
	source => "source",
	workspace => "workspace",
	type => "type",
	conftype => "confidence_type",
	name => "name",
};
#Defining usage and options
my $specs = [
    [ 'newuid|u:s', 'ID for metagenome annotation in workspace' ],
    [ 'name|n:s', 'Name for metagenome annotation' ],
    [ 'sourceid|i:s', 'Source ID for metagenome annotation' ],
    [ 'source|s:s', 'Source for metagenome annotation' ],
    [ 'type|t:s', 'Type of metagenome annotation' ],
    [ 'conftype|c:s', 'Confidence type for hits in metagenome annotation' ],
    [ 'workspace|w:s', 'Workspace to save phenotypes in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{annotations} = [];
if (!-e $opt->{"Annotation filename"}) {
	print "Could not find input annotation file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Annotation filename"}) || return;
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	push(@{$params->{annotations}},[$array->[0],$array->[1],$array->[4],$array->[2],$array->[3]]);
}
close($fh);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Metagenome annotation import failed!\n";
} else {
	print "Metagenome annotation import successful:\n";
	printObjectInfo($output);
}