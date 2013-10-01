#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(printJobData auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Sequence ID"];
my $servercommand = "ContigSet_to_Genome";
my $script = "ga-seq-to-genome";
my $translation = {
	genomeid => "uid",
	scientificname => "scientific_name",
	domain => "domain",
	code => "genetic_code",
};

#Defining usage and options
my $specs = [
    [ 'genomeid=s', 'ID for created genome in workspace' ],
    [ 'seqws=s', 'Workspace with sequence object' ],
    [ 'transcripts|t', 'Transcript sequence object' ],
    [ 'proteins|p', 'Protein sequence object' ],
    [ 'scientificname|s=s', 'Scientific name of genome' ],
    [ 'domain|d=s', 'Domain of genome' ],
    [ 'code|c=s', 'Genetic code of genome' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{transcripts}) && $opt->{transcripts} == 1) {
	$servercommand = "TranscriptSet_to_Genome";
	$params->{TranscriptSet_uid} = $opt->{"Sequence ID"};
	$params->{TranscriptSet_ws} = $params->{"seqws"};
} elsif (defined($opt->{proteins}) && $opt->{proteins} == 1) {
	$params->{ProteinSet_uid} = $opt->{"Sequence ID"};
	$params->{ProteinSet_ws} = $params->{"seqws"};
	$servercommand = "ProteinSet_to_Genome";
} else {
	$params->{ContigSet_uid} = $opt->{"Sequence ID"};
	$params->{ContigSet_ws} = $params->{"seqws"};
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Generation of genome object failed!\n";
} else {
	print "Generation of genome object successful:\n";
	printObjectMeta($output);
}
