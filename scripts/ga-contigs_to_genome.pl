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
my $primaryArgs = ["Contigs ID"];
my $servercommand = "_to_genome";
my $script = "ga-contigs_to_genome";
my $translation = {
	"Contigs ID" => "contigid",
	contigws => "contig_workspace",
	genomeid => "genomeid",
};

#Defining usage and options
my $specs = [
    [ 'contigws=s', 'Workspace with contigs', { "default" => workspace() } ],
    [ 'genomeid=s', 'ID of the genome to be created' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing FBA with same name' ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Contig annotation queuing failed!\n";
} else {
	print "Contig annotation queued:\n";
	printJobData($output);
}
