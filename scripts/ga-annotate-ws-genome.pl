#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta printObjectInfo);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws printJobData get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID"];
my $servercommand = "queue_job";
my $script = "ga-annotate-ws-genome";
my $translation = {
	"Genome ID" => "Genome_uid",
	newuserid => "new_uid",
	genomews => "Genome_ws",
};

#Defining usage and options
my $specs = [
    [ 'newuserid=s', 'New user ID for annotated genome' ],
    [ 'genomews=s', 'Workspace with input genome' ],
    [ 'callgenes|c', 'Call genes' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{annotation_parameters}->{annotate_genes} = 1;
$params->{annotation_parameters}->{call_genes} = 0;
if ($opt->{callgenes} && $opt->{callgenes} == 1) {
	$params->{annotation_parameters}->{call_genes} = 1;
}
#Calling the server
my $output = runFBACommand({method => "annotate_workspace_Genome",parameters => $params},$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Genome annotation failed!\n";
} else {
	print "Genome annotation queued:\n";
	printJobData($output);
}
