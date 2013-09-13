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
my $primaryArgs = ["Filename"];
my $servercommand = "fasta_to_sequences";
my $script = "ga-fasta_to_sequences";
my $translation = {
	contigid => "contigid",
	source => "source",
	workspace => "workspace",
	code => "genetic_code",
	domain => "domain",
	auth => "auth",
	name => "scientific_name"
};
#Defining usage and options
my $specs = [
    [ 'sequenceid:s', 'ID for contigs in workspace' ],
    [ 'name:s', 'Name of sequence dataset', { "default" => "unknown sample" } ],
    [ 'source:s', 'Source of contig data', { "default" => "unknown" } ],
    [ 'type-s', 'type of sequence data'],
    [ 'workspace|w:s', 'Workspace to save phenotypes in', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{fasta} = "";
if (!-e $opt->{"Filename"}) {
	print "Could not find input fasta file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Filename"}) || return;
while (my $line = <$fh>) {
	$params->{fasta} .= $line;
}
close($fh);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Fasta load failed!\n";
} else {
	print "Fasta load successful:\n";
	printObjectMeta($output);
}