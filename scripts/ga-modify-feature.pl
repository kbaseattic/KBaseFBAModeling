#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );

my $manpage =
"
NAME
      ga-modify-feature - modify feature in genome

DESCRIPTION
      

EXAMPLES
      
SEE ALSO
      

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Genome","Gene ID"];
my $servercommand = "modify_features";
my $script = "ga-modify-feature";
my $translation = {
	Genome => "genome",
	genomews => "genome_workspace",
	outputid => "output_id",
	workspace => "workspace",
};
#Defining usage and options
my $specs = [
    [ 'genomews=s', 'Workspace where genome is located' ],
    [ 'outputid=s', 'ID to which genome should be saved'],
    [ 'function=s', 'Function of the gene'],
    [ 'type=s', 'Type of the gene'],
    [ 'proteinseq=s', 'Type of the gene'],
    [ 'dnaseq=s', 'Type of the gene'],
    [ 'locations=s', 'List of locations for gene on contigs (contig/start/stop/direction)'],
    [ 'aliases=s', 'List of aliases for gene (; delimited)'],
    [ 'publications=s', 'List of publications for gene (; delimited)'],
    [ 'annotations=s', 'List of notes for gene (; delimited)'],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{features} = [[
	$opt->{"Gene ID"},
	undef,
	undef,
	undef,
	undef,
	undef,
	undef,
	undef,
	undef
]];
if (defined($opt->{function})) {
	$params->{features}->[0]->[1] = $opt->{function};
}
if (defined($opt->{type})) {
	$params->{features}->[0]->[2] = $opt->{type};
}
if (defined($opt->{proteinseq})) {
	$params->{features}->[0]->[6] = $opt->{proteinseq};
}
if (defined($opt->{dnaseq})) {
	$params->{features}->[0]->[7] = $opt->{dnaseq};
}
if (defined($opt->{locations})) {
	my $array = [split(/;/,$opt->{locations})];
	for (my $i=0; $i < @{$array}; $i++) {
		my $subarray = [split(/\//,$array->[$i])];
		push(@{$params->{features}->[0]->[8]},[$subarray->[0],$subarray->[1],$subarray->[3],$subarray->[2]]);
	}
}
if (defined($opt->{aliases})) {
	$params->{features}->[0]->[3] = [split(/;/,$opt->{aliases})];
}
if (defined($opt->{function})) {
	$params->{features}->[0]->[4] = [split(/;/,$opt->{publications})];
}
if (defined($opt->{function})) {
	$params->{features}->[0]->[5] = [split(/;/,$opt->{annotations})];
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Gene addition failed!\n";
} else {
	print "Gene successfully added:\n";
	printObjectInfo($output);
}
