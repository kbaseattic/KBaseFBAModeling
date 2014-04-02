#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw( printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["GTF filename"];
my $servercommand = "gtf_to_genome";
my $script = "ga-importgtf";
my $translation = {
	workspace => "workspace",
	contigs => "contigset",
	contigws => "contigset_ws",
	uid => "genome_uid",
	sourceid => "source_id",
	source => "source",
	name => "scientific_name",
	domain => "domain",
	code => "genetic_code",
	taxonomy => "taxonomy",
};

#Defining usage and options
my $specs = [
	[ 'uid|u=s', 'ID of genome to be saved'],
	[ 'contigs|c=s', 'ID of contig set for genome'],
	[ 'contigws=s', 'ID of workspace with contig set for genome', {"default" => fbaws()} ],
	[ 'source|s=s', 'Source of genome', { "default" => "KBase" } ],
	[ 'sourceid|i=s', 'Source ID of genome' ],
	[ 'name|n=s', 'Scientific name of genome', { "default" => "Unknown species" } ],
	[ 'domain|d=s', 'Domain for genome', { "default" => "Bacteria" }],
	[ 'code|o=s', 'Genetic code for genome', { "default" => 11 }],
	[ 'taxonomy|t=s', 'Taxonomy of genome', { "default" => "Bacteria" }],
    [ 'workspace|w=s', 'Workspace to load genome into', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Loading GTF file
if (!-e $opt->{"GTF filename"}) {
	print "Cannot find GTF file!\n";
	die;
}
open( my $fh, "<", $opt->{"GTF filename"});
{
    local $/;
    $params->{gtf_file} = <$fh>;
}
close($fh);
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Genome failed to load to workspace!\n";
} else {
	print "Genome successfully loaded to workspace:\n";
	printObjectInfo($output);
}
