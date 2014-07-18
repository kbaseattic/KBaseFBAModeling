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
my $primaryArgs = ["Models (workspace/ID/abundance) or Filename"];
my $servercommand = "models_to_community_model";
my $script = "fba-merge-models";
my $translation = {
	newuid => "model_uid",
	workspace => "workspace",
	name => "name",
};
#Defining usage and options
my $specs = [
    [ 'newuid|u=s', 'ID for merged model in workspace' ],
    [ 'name|n:s', 'Name for merged model' ],
    [ 'fromfile|f', 'Load model list from file. Input file should have three columns with headers: Model, Workspace, and Abundance.' ],
    [ 'workspace|w=s', 'Workspace to save merged model', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{models} = [];
if (defined($opt->{fromfile}) && $opt->{fromfile} == 1) {
	if (!-e $opt->{"Models (workspace/ID/abundance) or Filename"}) {
		print "Could not find input model list file!\n";
		exit();
	}
	open(my $fh, "<", $opt->{"Models (workspace/ID/abundance) or Filename"}) || return;
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
		push(@{$params->{models}},[$array->[$headHash->{"Model"}],$array->[$headHash->{"Workspace"}],$array->[$headHash->{"Abundance"}]]);
	}
	close($fh);
} else {
	my $list = $opt->{"Models (workspace/ID/abundance) or Filename"};
	my $array = [split(/;/,$list)];
	for (my $i=0; $i < @{$array}; $i++) {
		my $subarray = [split(/\//,$array->[$i])];
		push(@{$params->{models}},[$subarray->[1],$subarray->[0],$subarray->[2]]);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Model merge failed!\n";
} else {
	print "Model merge successful:\n";
	printObjectInfo($output);
}
