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
my $primaryArgs = ["Object type","Object ID"];
my $servercommand = "export_object";
my $script = "kbfba-exportobject";
my $translation = {
	"format" => "format",
	"Object ID" => "reference",
	"Object type" => "type"
};
#Defining usage and options
my $specs = [
    [ 'format|f:s', 'Format for export (html,json,readable)', { "default" => "html" } ],
    [ 'workspace|w:s', 'Workspace with FBA', { "default" => workspace() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if ($params->{reference} !~ m/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/) {
	if ($params->{reference} !~ m/\//) {
		$params->{reference} = $params->{workspace}."/".$params->{reference};
	}
}

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Object export failed!\n";
} else {
	print $output;
}