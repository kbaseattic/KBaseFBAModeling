#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Model ID","Reaction IDs (;-separated)"];
my $servercommand = "adjust_model_reaction";
my $script = "kbfba-adjustmodel";
my $translation = {
	"Model ID" => "model",
	workspace => "workspace",
	direction => "direction",
	compartment => "compartment",
	compindex => "compartmentIndex",
	gpr => "gpr",
	removerxn => "removeReaction",
	addrxn => "addReaction",
	auth => "auth",
	overwrite => "overwrite",
	outputid => "outputid"
};
#Defining usage and options
my $specs = [
    [ 'direction|d:s', 'Directionality for reaction (;-separated if multiple)', { "default" => "bio1" }  ],
    [ 'compartment|c:s', 'Compartment for reaction (;-separated if multiple)', { "default" => "c" } ],
    [ 'compindex|i:s', 'Index of compartment for reaction (;-separated if multiple)', { "default" => 0 } ],
    [ 'gpr|g:s', 'GPR for reaction (;-separated if multiple)'],
    [ 'removerxn|r', 'Remove reaction(s)', { "default" => 0 } ],
    [ 'addrxn|a', 'Add reaction(s)', { "default" => 0 } ],
    [ 'workspace|w:s', 'Workspace to save FBA results', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing FBA with same name' ],
    [ 'outputid|u:s', 'Output ID for adjusted reaction (by default, creates a new version of the same model)']
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

# Parse semicolon-delimited arguments (lists) into array refs
my $reactions = [split(/;/,$opt->{"Reaction IDs (;-separated)"})];
$params->{reaction} = $reactions;

if ( defined($params->{gpr}) ) {  
    my $gprs = [split(/;/,$params->{gpr}) ];
    $params->{gpr} = $gprs;
}
if ( defined($params->{direction}) ) {
    my $directions = [split(/;/,$params->{direction}) ];
    $params->{direction} = $directions; 
}
if ( defined($params->{compartment}) ) {
    my $compartments = [split(/;/,$params->{compartment}) ];
    $params->{compartment} = $compartments;
}
if ( defined($params->{compartmentIndex}) ) {
    my $compartmentIndexes = [split(/;/, $params->{compartmentIndex})];
    $params->{compartmentIndex} = $compartmentIndexes;
}

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);

#Checking output and report results
if (!defined($output)) {
	print "Adjustment of model failed!\n";
} else {
	print "Adjustment of model successful:\n";
	printObjectMeta($output);
}
