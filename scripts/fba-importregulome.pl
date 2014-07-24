#!/usr/bin/env perl
# Author: Matt DeJongh @ Hope College, Holland, MI
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode getToken);
use Bio::KBase::ObjectAPI::utilities qw(LOADTABLE);
use File::Basename;
use POSIX qw/strftime/;

#Defining globals describing behavior
my $primaryArgs = ["RegPrecise regulome flat file","Genome ID"];
my $servercommand = "import_regulome";
my $script = "fba-importregulome";
my $translation = {
        "Genome ID" => "genome_id",
	workspace => "workspace",
	genomews => "genome_workspace",
	sourceid => "source_id",
	sourcedate => "source_date",
	ignoreerrors => "ignore_errors",
	regulome => "regulome"
};

my $manpage = 
"
NAME
      fba-importregulome

DESCRIPTION

      Import a RegPrecise regulome from a flat file and save the results as a Regulome object in a workspace.
      The flat file should be downloaded from RegPrecise's genome page, using the 'Download' link for 'Regulated Genes'
      in Tab delimited format. See http://regprecise.lbl.gov/RegPrecise/genome.jsp?genome_id=116 for an example.

      The Genome ID will be used to map the locus tags to feature ids.

EXAMPLES

      fba-importregulome rsp.regulons 'kb|g.629'

SEE ALSO
      fba-importexpression

AUTHORS
      Matt DeJongh, Shinnosuke Kondo

";

#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace to save imported regulome in', { "default" => fbaws() } ],    
    [ 'genomews|g:s', 'Workspace with genome' ],
    [ 'sourceid:s', 'ID of the source'],
    [ 'sourcedate|d:s', 'Date of the source', { "default", => strftime("%Y-%m-%d", localtime)}],
    [ 'regulome|r:s', "Name for the imported regulome" ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);

if (!-e $opt->{"RegPrecise regulome flat file"}) {
	print "Could not find RegPrecise input file!\n";
	exit();
}

# load the regulome data
my $data = Bio::KBase::ObjectAPI::utilities::LOADFILE($opt->{"RegPrecise regulome flat file"},"\t",0);
my ($operon, $regulon, $regulons);

foreach my $line (@$data) {
    if ($line =~ /^# TF - (.+)/) {
	
	# starting a new transcription factor, so save any data already accumulated
	if (defined $regulon) {
	    push @$regulons, $regulon;
	    $regulon = {};
	}
	
	my @parsed = split(/\s*:\s*/,$1);
	# now process the new transcription factor
	$regulon->{"transcription_factor"} = { "locus" => $parsed[1], "name" => $parsed[0] };

	if (@parsed > 2) {
	    $regulon->{"sign"} = $parsed[2];
	    my @effectors;	
	    chomp($parsed[3]);
	    my @effectors_info = split(/\s*\|\s*/,$parsed[3]);
	    foreach my $effector_info (@effectors_info) {
		my ($effector_name, $class) = split(/\s*;\s*/, $effector_info);
		push @effectors, {"name" => $effector_name, "class" => $class};
	    }
	    $regulon->{"effectors"} = \@effectors;
	} else {
	    $regulon->{"effectors"} = [];
	    $regulon->{"sign"} = "";
	}
    }
    elsif ($line =~ /^(\w+)\s+(\w+)\s+(\w+)/) {
	push @$operon, { "locus" => $2, "name" => $3 };
    }
    elsif ($line =~/^\s*$/ && scalar @$operon > 0) {
	    push @{$regulon->{"operons"}}, $operon;
	    $operon = [];
    }
}
# Add them at the end.
push @{$regulon->{"operons"}}, $operon;
push @$regulons, $regulon;
$params->{"regulons"} = $regulons;

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Regulome import failed!\n";
} else {
	print "Regulome import successful:\n";
	printObjectInfo($output);
}
