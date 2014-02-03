#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspace::ScriptHelpers qw( get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = [];
my $servercommand = "get_mapping";
my $script = "kbfba-getmap";
my $translation = {
	"map" => "map",
	mapws => "workspace",
	idtype => "id_type"
};
#Defining usage and options
my $specs = [
    [ 'map|m:s', 'ID of mapping to be printed' ],
    [ 'mapws:s', 'Workspace for mapping' ],
    [ 'pretty|p', 'Pretty print output' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Mapping retreival failed!\n";
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}