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
#Defining globals describing behavior
my $primaryArgs = ["Compound filename"];
my $servercommand = "add_biochemistry_compounds";
my $script = "fba-add-bio-compounds";
my $translation = {
	bio => "biochemistry",
	biows => "biochemistry_ws",
	outputid => "output_id",
	workspace => "workspace"
};

#Defining usage and options
my $specs = [
    [ 'bio=s', 'Reactions file is in SBML format' ],
    [ 'biows=s', 'Workspace with selected biochemistry', { "default" => fbaws() } ],
    [ 'outputid=s', 'ID of output biochemistry' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

open(my $fh, "<", $opt->{"Compound filename"}) || return;
my $headingline = <$fh>;
my $headings = [split(/\t/,$headingline)];
my $headingColums;
for (my $i=0;$i < @{$headings}; $i++) {
	$headingColums->{$headings->[$i]} = $i;
}
$params->{compounds} = [];
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	my $cpdobj = [
		undef,
		$array->[$headingColums->{name}],
		undef,
		undef,
		undef,
		undef,
		undef,
		undef,
		undef
	];
	if (defined($headingColums->{abbreviation})) {
		$cpdobj->[0] = $array->[$headingColums->{abbreviation}];
	}
	if (defined($headingColums->{aliases})) {
		$cpdobj->[2] = [split(/\|/,$array->[$headingColums->{aliases}])];
	}
	if (defined($headingColums->{formula})) {
		$cpdobj->[3] = $array->[$headingColums->{formula}];
	}
	if (defined($headingColums->{charge})) {
		$cpdobj->[4] = $array->[$headingColums->{charge}];
	}
	if (defined($headingColums->{isCofactor})) {
		$cpdobj->[5] = $array->[$headingColums->{isCofactor}];
	}
	if (defined($headingColums->{structureString})) {
		$cpdobj->[6] = $array->[$headingColums->{structureString}];
	}
	if (defined($headingColums->{structureType})) {
		$cpdobj->[7] = $array->[$headingColums->{structureType}];
	}
	if (defined($headingColums->{id})) {
		$cpdobj->[8] = $array->[$headingColums->{id}];
	}
	push(@{$params->{compounds}},$cpdobj);
}    	
close($fh);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Compound addition failed!\n";
} else {
	print "Compound addition successful!\n";
	printObjectInfo($output);
}
