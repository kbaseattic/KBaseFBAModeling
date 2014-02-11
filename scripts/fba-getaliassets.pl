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
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $manpage =
"
NAME
      fba-getaliassets - Retrives a list of aliases for the specified object type (reaction or compound)

DESCRIPTION
      The function returns a list of all possible aliases loaded for compounds or reactions
      in the KBase biochemistry database.

EXAMPLES
      Get alias sets for compounds:
      > fba-getaliassets --compound
      
      Get alias sets for reactions:
      > fba-getaliassets --reaction

AUTHORS
      Christopher Henry
";

my $primaryArgs = [];
my $servercommand = "get_aliassets";
my $script = "fba-getaliassets";
my $translation = {
	biochemistry => "biochemistry"
};
#Defining usage and options
my $specs = [
    [ 'compound|c', 'Print sets for compounds' ],
    [ 'reaction|r', 'Print sets for reactions' ],
    [ 'biochemistry|b=s', 'Biochemistry with aliassets' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{object_type} = "compound";
if (defined($opt->{reaction}) && $opt->{reaction} == 1) {
	$params->{object_type} = "reaction";
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Aliasset printing failed!\n";
} else {
	print "Alias sets:\n".join("\n",@{$output})."\n";
}
