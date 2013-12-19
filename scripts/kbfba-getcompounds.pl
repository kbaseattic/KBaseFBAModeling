#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );

my $manpage = "
NAME
      kbfba-getcompounds - Get compound information by ID

DESCRIPTION
      This function will get information on one or a list of compounds.
      By default, the list of compounds should be SEED IDs. However,
      KEGG, Name, and other types are accessible by specifying the
      approriate type with --idtype.

      Provided information includes the estimated Gibbs energy of formation,
      charge, formula, and accepted aliases for the compound.

      Use kbfba-getaliassets to get a list of valid ID types.

EXAMPLES
      Get information on 'cpd00001' and pretty-print the results
      > kbfba-getcompounds -p cpd00001

      Get information on compound 'H2O' (same as cpd00001)
      > kbfba-getcompounds -p --idtype name 'H2O'

SEE ALSO
      kbfba-getaliassets

AUTHORS
      Christopher Henry
";


#Defining globals describing behavior
my $primaryArgs = ["Compound IDs (; delimiter)"];
my $servercommand = "get_compounds";
my $script = "kbfba-getcompounds";
my $translation = {
	idtype => "id_type"
};
#Defining usage and options
my $specs = [
    [ 'idtype|i:s', 'Type of ID (default is to search all alias sets)' ],
    [ 'pretty|p', 'Pretty print output' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{compounds} = [split(/;/,$opt->{"Compound IDs (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Compound retreival failed!\n";
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}
