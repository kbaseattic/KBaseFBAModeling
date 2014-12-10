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
my $manpage =
"
NAME
      fba-getreactions - Get reaction information by ID

DESCRIPTION
      This function will get information on one or a list of reactions.
      The list of reactions can be SEED IDs, KEGG, Name, and other alias.
      approriate type with --idtype.

      Provided information includes reversibility, estimated Gibbs energy
      of reaction, equation in ModelSEED and human-readable format, and EC numbers.
EXAMPLES
      Get information on 'rxn00001' and pretty-print the results
      > fba-getreactions -p rxn00001
      
      Get information on reacton 'inorganic diphosphatase' (same reaction as rxn00001)
      > fba-getreactions -p 'inorganic diphosphatase'

SEE ALSO
      fba-getaliassets

AUTHORS
      Christopher Henry
";

my $primaryArgs = ["Reaction IDs (; delimiter)"];
my $servercommand = "get_reactions";
my $script = "fba-getreactions";
my $translation = {
	idtype => "id_type",
	biochem => "biochemistry",
	biochemws => "biochemistry_workspace"
};
#Defining usage and options
my $specs = [
    [ 'idtype|i:s', 'Type of ID' ],
    [ 'pretty|p', 'Pretty print output' ],
    [ 'biochem|b:s', 'ID of the biochemistry database' ],
    [ 'biochemws:s', 'ID of workspace containing biochemistry database' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{reactions} = [split(/;/,$opt->{"Reaction IDs (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Reaction retreival failed!\n";
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}
