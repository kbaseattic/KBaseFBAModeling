#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Object ID","Format"];
my $servercommand = "export_object";
my $script = "fba-exportobject";
my $translation = {
	"format" => "format",
	"Object ID" => "reference",
};
#Defining usage and options
my $specs = [
    [ 'list|l', 'List formats available for specified object'],
    [ 'workspace|w:s', 'Workspace with FBA', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,undef,"list");
if ($params->{reference} !~ m/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/) {
	if ($params->{reference} !~ m/\//) {
		$params->{reference} = $params->{workspace}."/".$params->{reference};
	}
}
if (defined($opt->{list})) {
	$params->{list} = 1;
	my $output = runFBACommand($params,$servercommand,$opt);
	print "Available formats for object include:\n";
	print $output;
	exit();
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print STDERR "Object export failed!\n";
} else {
	print STDERR "Object export succeeded!\n";
	print $output;
}