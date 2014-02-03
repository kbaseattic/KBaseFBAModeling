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
my $primaryArgs = ["FBA IDs (; delimiter)","FBA workspaces (; delimiter)"];
my $servercommand = "get_fbas";
my $script = "kbfba-getfbas";
my $translation = {
	idtype => "id_type"
};
#Defining usage and options
my $specs = [
    [ 'idtype|i:s', 'Type of ID' ],
    [ 'pretty|p', 'Pretty print output' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{fbas} = [split(/;/,$opt->{"FBA IDs (; delimiter)"})];
$params->{workspaces} = [split(/;/,$opt->{"FBA workspaces (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "FBA retreival failed!\n";
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}