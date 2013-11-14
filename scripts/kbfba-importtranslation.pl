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
my $primaryArgs = ["Genome ID","Translation file","ID type"];
my $servercommand = "add_feature_translation";
my $script = "kbfba-importtranslation";
my $translation = {
	"ID type" => "id_type",
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite"
};
#Defining usage and options
my $specs = [
    [ 'Genome ID: ID for a genome in the workspace' ],
    [ 'Translation file: Two-column tab-delimited file: alias (1st column) and feature ID (2nd column)'],
    [ 'ID type: Any string (?)'],
    [ "\n" ],
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{translations} = [];
if (!-e $opt->{"Translation file"}) {
	print "Could not find input translation file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Translation file"}) || return;
$opt->{"Translation file"} = "";
my $data = [];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\t/,$line)]);
}
close($fh);
foreach my $trans (@{$data}) {
	if (@{$trans} >= 2) {
		push(@{$params->{translations}},$trans);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Translation import failed!\n";
} else {
	print "Translation import successful:\n";
	printObjectMeta($output);
}
