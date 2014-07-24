#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Pangenome/Proteome comparison"];
my $servercommand = "compare_genomes";
my $script = "ga-compare-genomes";
my $translation = {
	workspace => "workspace",
	outputid => "output_id"
};
#Defining usage and options
my $specs = [
    [ 'outputid|o:s', 'ID for genome comparison in workspace' ],
    [ 'isproteomecomp', 'Input object is a proteome comparison' ],
    [ 'workspace|w=s', 'Workspace to save merged model', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (defined($opt->{isproteomecomp}) && $opt->{isproteomecomp} == 1) {
	$params->{protcomp_id} = $opt->{"Pangenome/Proteome comparison"};
} else {
	$params->{pangenome_id} = $opt->{"Pangenome/Proteome comparison"};
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Genome comparison failed!\n";
} else {
	print "Genome comparison successful:\n";
	printObjectInfo($output);
}