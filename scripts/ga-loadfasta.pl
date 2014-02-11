#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo printJobData get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Filename"];
my $servercommand = "fasta_to_ContigSet";
my $script = "ga-loadfasta";
my $translation = {
	userid => "uid",
	name => "name",
	sourceid => "sourceid",
	source => "source",
	type => "type"
};

#Defining usage and options
my $specs = [
    [ 'userid|u=s', 'ID for object in workspace' ],
    [ 'transcripts|t', 'FASTA contains trascripts instead of full contigs' ],
    [ 'proteins|p', 'FASTA contains proteins instead of full contigs' ],
    [ 'name|n=s', 'Name for FASTA data' ],
    [ 'sourceid|i=s', 'Source ID of FASTA data' ],
    [ 'source|s=s', 'Source of FASTA data' ],
    [ 'type|y=s', 'Type of sequence data' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{transcripts}) && $opt->{transcripts} == 1) {
	$params->{type} = "Transcripts";
} elsif (defined($opt->{proteins}) && $opt->{proteins} == 1) {
	$servercommand = "fasta_to_ProteinSet";
}
print $servercommand."\n";
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
	print "Loading of FASTA data to workspace failed!\n";
} else {
	print "Data loaded to workspace:\n";
	printObjectInfo($output);
}
