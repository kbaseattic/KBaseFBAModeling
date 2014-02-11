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

my $manpage = "
NAME
      fba-getcompounds - Get compound information by ID

DESCRIPTION
      This function will get information on one or a list of compounds.
      The list of compounds can be SEED IDs, KEGG, Name, and other alias.

      Provided information includes the estimated Gibbs energy of formation,
      charge, formula, and accepted aliases for the compound.

EXAMPLES
      Get information on 'cpd00001' and pretty-print the results
      > fba-getcompounds -p cpd00001

      Get information on compound 'H2O' (same as cpd00001)
      > fba-getcompounds -p 'H2O'

SEE ALSO
      fba-getaliassets

AUTHORS
      Christopher Henry
";


#Defining globals describing behavior
my $primaryArgs = ["Compound IDs (; delimiter)"];
my $servercommand = "get_compounds";
my $script = "fba-getcompounds";
my $translation = {
	idtype => "id_type"
};
#Defining usage and options
my $specs = [
    [ 'pretty|p', 'Pretty print output' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{compounds} = [split(/;/,$opt->{"Compound IDs (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Compound retreival failed!\n";
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}
