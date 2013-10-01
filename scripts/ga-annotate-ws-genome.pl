#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(printJobData auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID"];
my $servercommand = "annotate_workspace_Genome";
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
    [ 'selectstages|s', 'Run only selected stages of pipeline' ],
    [ 'assignfunctions|a', 'Assign functions to genes' ],
    [ 'callseleno|o', 'Call selenoproteins' ],
    [ 'callpyrrolyso|p', 'Call pyrrolysoproteins' ],
    [ 'callrna|r', 'Call RNAs' ],
    [ 'callcds|c', 'Call CDSs' ],
    [ 'findclosegen|f', 'Find close neighbors' ],
    [ 'workspace|w=s', 'Workspace to save FBA results', { "default" => workspace() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{pipeline_stages} = [];
if (!defined($opt->{selectstages}) || $opt->{selectstages} == 0) {
	$params->{pipeline_stages} = [
		{
			id => "call_selenoproteins",
			enable => 1,
			parameters => {}
		},
		{
			id => "call_pyrrolysoproteins",
			enable => 1,
			parameters => {}
		},
		{
			id => "call_RNAs",
			enable => 1,
			parameters => {}
		},
		{
			id => "call_CDSs",
			enable => 1,
			parameters => {}
		},
		{
			id => "find_close_neighbors",
			enable => 1,
			parameters => {}
		},
		{
			id => "assign_functions_to_CDSs",
			enable => 1,
			parameters => {}
		}
	];
} else {
	if (defined($opt->{callseleno}) && $opt->{callseleno} == 1) {
		push(@{$params->{pipeline_stages}},{
			id => "call_selenoproteins",
			enable => 1,
			parameters => {}
		});
	} elsif (defined($opt->{callpyrrolyso}) && $opt->{callpyrrolyso} == 1) {
		push(@{$params->{pipeline_stages}},{
			id => "call_pyrrolysoproteins",
			enable => 1,
			parameters => {}
		});
	} elsif (defined($opt->{callrna}) && $opt->{callrna} == 1) {
		push(@{$params->{pipeline_stages}},{
			id => "call_RNAs",
			enable => 1,
			parameters => {}
		});
	} elsif (defined($opt->{callcds}) && $opt->{callcds} == 1) {
		push(@{$params->{pipeline_stages}},{
			id => "call_CDSs",
			enable => 1,
			parameters => {}
		});
	} elsif (defined($opt->{findclosegen}) && $opt->{findclosegen} == 1) {
		push(@{$params->{pipeline_stages}},{
			id => "find_close_neighbors",
			enable => 1,
			parameters => {}
		});
	} elsif (defined($opt->{assignfunctions}) && $opt->{assignfunctions} == 1) {
		push(@{$params->{pipeline_stages}},{
			id => "assign_functions_to_CDSs",
			enable => 1,
			parameters => {}
		});
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Genome annotation queuing failed!\n";
} else {
	print "Genome annotation queued:\n";
	printJobData($output);
}
