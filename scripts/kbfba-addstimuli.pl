#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::fbaModelServices::Helpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Name"];
my $servercommand = "add_stimuli";
my $script = "kbfba-addstimuli";
my $translation = {
	id => "stimuliid",
	Name => "name",
	abbreviation => "abbreviation",
	description => "description",
	biochem => "biochemid",
	workspace => "workspace",
	biochemws => "biochem_workspace",
	auth => "auth",
};
#Defining usage and options
my $specs = [
    [ 'abbreviation|a=s', 'Abbreviated name of stimuli'],
    [ 'description|d=s', 'Description of stimuli'],
    [ 'compounds|c=s', 'List of compounds (; delimited) triggering stimuli'],
    [ 'id=s', 'ID to save the stimuli under' ],
    [ 'biochem|b=s', 'ID of biochemistry to add the stimuli to' ],
    [ 'biochemws=s', 'Workspace of biochemistry to add the stimuli to' ],
    [ 'workspace|w=s', 'Workspace with model', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{type} = "environmental";
if (defined($opt->{compounds})) {
	$params->{compounds} = [split(/;/,$opt->{compounds})];
	if (@{$params->{compounds}} > 0) {
		$params->{type} = "chemical"; 
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Stimuli creation failed!\n";
} else {
	print "Successfully added stimuli to database:\n";
	printObjectMeta($output);
}