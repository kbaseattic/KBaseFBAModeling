#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspace::ScriptHelpers qw( get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Template ID","Template workspace"];
my $servercommand = "get_template_model";
my $script = "fba-gettemplate";
my $translation = {
	"Template ID" => "templateModel",
	"Template workspace" => "workspace",
};
#Defining usage and options
my $specs = [
    [ 'pretty|p', 'Pretty print output' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Template retreival failed!\n";
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}