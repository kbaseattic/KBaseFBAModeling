#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode getToken);
#Defining globals describing behavior
my $primaryArgs = ["FBAModel ID","Format (html,sbml,json,cytoseed,readable,excel)"];
my $servercommand = "export_fbamodel";
my $script = "fba-exportfbamodel";
my $translation = {
	"Format (html,sbml,json,cytoseed,readable,excel)" => "format",
	"FBAModel ID" => "model",
	"fba" => "fbas",
	toshock => "toshock",
	workspace => "workspace",
};
#Defining usage and options
my $specs = [
	[ 'toshock', 'Load data to shock and return node IDs' ],
    [ 'workspace|w:s', 'Workspace with model', { "default" => fbaws() } ],
    [ 'fba|f:s@', 'FBA associated with model (; delimiter)', { "default" => []} ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
my $toshock = 0;
if (defined($params->{toshock})) {
	$toshock = $params->{toshock};
}
my $fbas = [];
if (defined($params->{fbas})) {
	foreach my $fba (@{$params->{fbas}}) {
		push(@{$fbas},split(/;/,$fba));
	}
}
if (defined($opt->{fbas})) {
	foreach my $fba (@{$opt->{fbas}}) {
		push(@{$fbas},split(/;/,$fba));
	}
}
$params->{fbas} = $fbas;
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "FBAModel export failed!\n";
} elsif ($toshock == 0 && $params->{format} eq "excel") {
	my $array = [split(/\t/,$output)];
	$output = Bio::KBase::ObjectAPI::utilities::runexecutable("curl -H \"Authorization: OAuth ".getToken()."\" -X GET ".$array->[2]."?download > ".$params->{model}.".xls");
} else {
	print $output."\n";
}