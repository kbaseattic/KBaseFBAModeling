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
my $primaryArgs = ["; delimited list of fbas"];
my $servercommand = "compare_fbas";
my $script = "fba-compare_fbas";
my $translation = {
	workspace => "workspace",
	outputid => "output_id"
};
#Defining usage and options
my $specs = [
    [ 'outputid|o:s', 'ID for fba comparison in workspace' ],
    [ 'workspace|w=s', 'Workspace to save fba comparison', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

$params->{fbas} = [split(/;/,$opt->{"; delimited list of fbas"})];
for (my $i=0; $i < @{$params->{fbas}}; $i++) {
	$params->{fbas}->[$i] = [split(/\//,$params->{fbas}->[$i])];
}

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "FBA comparison failed!\n";
} else {
	print "FBA comparison successful:\n";
	printObjectInfo($output);
}