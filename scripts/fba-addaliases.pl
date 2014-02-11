#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw( fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID","Filename","ID type"];
my $servercommand = "add_feature_translation";
my $script = "fba-addaliases";
my $translation = {
	"Genome ID" => "genome",
	"ID type" => "id_type",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite",
};
#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Reference default workspace', { "default" => fbaws() } ],
    [ 'overwrite|o', 'Overwrite any existing model with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{translations} = [];
open(my $fh, "<", $opt->{Filename}) || return;
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	if (defined($array->[1])) {
		push(@{$params->{translations}},$array);
	}
}
close($fh);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Alias addition failed!\n";
} else {
	print "Additional aliases successfully integrated:\n";
	printObjectInfo($output);
}