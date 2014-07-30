#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(parse_input_table get_workspace_object fbaws get_fba_client runFBACommand universalFBAScriptCode );

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
my $primaryArgs = ["Genome","Feature ID or Filename"];
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
	[ 'list|l', 'List features available for deletion' ],
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
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage,undef,["list"]);
if (defined($opt->{list})) {
	my $ws = fbaws();
	if (defined($opt->{genomews})) {
		$ws = $opt->{genomews};
	}
	(my $data,my $prov) = get_workspace_object($ws."/".$ARGV[0]);
	print "Listing genes available for modification:\n";
	for (my $i=0; $i < @{$data->{features}}; $i++) {
		print $data->{features}->[$i]->{id}."\t".$data->{features}->[$i]->{function}."\n";
	}
	exit;
}
if (-e $opt->{"Feature ID or Filename"}) {
	$params->{features} = parse_input_table($opt->{"Feature ID or Filename"},[
		["id",1,undef,undef],
		["function",0,undef,undef],
		["type",0,undef,undef],
		["aliases",0,undef,";"],
		["publications",0,undef,";"],
		["annotations",0,undef,";"],
		["proteinseq",0,undef,undef],
		["dnaseq",0,undef,undef],
		["locations",0,undef,undef]
	]);
	for (my $j=0; $j < @{$params->{features}}; $j++) {
		if (defined($params->{features}->[$j]->[8])) {
			my $array = [split(/;/,$params->{features}->[$j]->[8])];
			for (my $i=0; $i < @{$array}; $i++) {
				my $subarray = [split(/\//,$array->[$i])];
				push(@{$params->{features}->[$j]->[8]},[$subarray->[0],$subarray->[1],$subarray->[3],$subarray->[2]]);
			}
		}
	}
} else {
	$params->{features} = [[
		$opt->{"Feature ID or Filename"},
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
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Feature modification failed!\n";
} else {
	print "Feature successfully modified:\n";
	printObjectInfo($output);
}