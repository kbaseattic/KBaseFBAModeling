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
my $primaryArgs = ["Genome file | Genome ID"];
my $script = "kbfba-loadgenome";
my $translation = {
	"Genome file | Genome ID" => "genome",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite",
};
#Defining usage and options
my $specs = [
	[ 'fromfile|f', 'Load genome object from file', {"default" => 0} ],
    [ 'workspace|w:s', 'Workspace to load genome into', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite existing genome with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output;
if ($opt->{fromfile} == 1) {
	if (!-e $params->{genome}) {
		print "Cannot find genome object file!\n";
		die;
	}
	open( my $fh, "<", $params->{genome});
	delete $params->{genome};
	{
	    local $/;
	    my $str = <$fh>;
	    $params->{genomeobj} = decode_json $str;
	}
	$output = runFBACommand($params,"genome_object_to_workspace",$opt);
} else {
	$output = runFBACommand($params,"genome_to_workspace",$opt);
}
#Checking output and report results
if (!defined($output)) {
	print "Genome failed to load to workspace!\n";
} else {
	print "Genome successfully loaded to workspace:\n";
	printObjectMeta($output);
}
