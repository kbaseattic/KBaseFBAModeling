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
my $primaryArgs = ["Genomes (workspace/ID;workspace/ID) or Filename"];
my $servercommand = "build_pangenome";
my $script = "ga-build-pangenome";
my $translation = {
	outputid => "output_id",
	workspace => "workspace",
};
#Defining usage and options
my $specs = [
    [ 'outputid|o:s', 'ID for pangenome in workspace' ],
    [ 'fromfile|f', 'Load model list from file. Input file should have two columns with headers: Genome, Workspace.' ],
    [ 'workspace|w=s', 'Workspace to save merged model', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{genomes} = [];
if (defined($opt->{fromfile}) && $opt->{fromfile} == 1) {
	if (!-e $opt->{"Genomes (workspace/ID;workspace/ID) or Filename"}) {
		print "Could not find input model list file!\n";
		exit();
	}
	open(my $fh, "<", $opt->{"Genomes (workspace/ID;workspace/ID) or Filename"}) || return;
	my $headingline = <$fh>;
	chomp($headingline);
	my $headings = [split(/\t/,$headingline)];
	my $headHash = {};
	for (my $i=0; $i < @{$headings}; $i++) {
		$headHash->{$headings->[$i]} = $i;
	}
	while (my $line = <$fh>) {
		chomp($line);
		my $array = [split(/\t/,$line)];
		push(@{$params->{genomes}},$array->[$headHash->{"Genome"}]);
		push(@{$params->{genome_workspaces}},$array->[$headHash->{"Workspace"}]);
	}
	close($fh);
} else {
	my $list = $opt->{"Genomes (workspace/ID;workspace/ID) or Filename"};
	my $array = [split(/;/,$list)];
	for (my $i=0; $i < @{$array}; $i++) {
		my $subarray = [split(/\//,$array->[$i])];
		push(@{$params->{genomes}},$subarray->[1]);
		push(@{$params->{genome_workspaces}},$subarray->[0]);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Pangenome build failed!\n";
} else {
	print "Pangenome build successful:\n";
	printObjectInfo($output);
}
