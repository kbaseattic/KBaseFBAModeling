#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );

my $manpage =
"
NAME
      fba-adjusttempbiomass -- adjust biomass reaction in a model template

DESCRIPTION
      Adjust biomass reaction in a ModelTemplate object.

      The 'Template ID' positional argument is the ID of a ModelTemplate object.
      The 'Biomass ID' positional argument is the name or UUID of a biomass
      entity in the ModelTemplate object.

      The --workspace optional argument is the ID of the workspace containing
      the ModelTemplate object.

      The --protein, --dna, --rna, --cofactor, --cellwall, and --lipid optional
      arguments specify the fraction of the item in the biomass.  The --energy
      optional argument specifies the number of ATP required for a gram of
      biomass.

      The --name optional argument specifies the name of the biomass reaction.
      The --new optional argument indicates that a new biomass reaction is
      added to the ModelTemplate object.  You must specify all of the optional
      arguments for a new biomass reaction.

      The --delete optional argument indicates that the biomass reaction is
      deleted from the ModelTemplate object.  The --clearbiomasscompounds
      optional argument indicates that all compounds are cleared from the
      biomass reaction.  The --compoundstoremove optional argument specifies a
      semicolon delimited list of compounds to remove from the biomass reaction.

EXAMPLES
      Add a new compound to the biomass:
      > fba-adjusttempbiomass

SEE ALSO
      fba-adjusttempbiocpd
      fba-gettemplate
      fba-importtemplate

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Template ID","Biomass ID"];
my $servercommand = "adjust_template_biomass";
my $script = "fba-adjusttempbiomass";
my $translation = {
	"Template ID" => "templateModel",
	"Biomass ID" => "biomass",
	workspace => "workspace",
	other => "other",
	protein => "protein",
	dna => "dna",
	rna => "rna",
	cofactor => "cofactor",
	energy => "energy",
	cellwall => "cellwall",
	lipid => "lipid",
	name => "name",
	type => "type",
	"new" => "new",
	"delete" => "delete",
	auth => "auth",
	clearbiomasscompounds => "clearBiomassCompounds",
	compoundstoremove => "compoundsToRemove"
};
#Defining usage and options
my $specs = [
    [ 'name=s', 'Name of template biomass reaction' ],
    [ 'protein=s', 'Fraction of protein in  biomass' ],
    [ 'dna=s', 'Fraction of DNA in  biomass' ],
    [ 'rna=s', 'Fraction of RNA in  biomass' ],
    [ 'cofactor=s', 'Fraction of cofactors in  biomass' ],
    [ 'cellwall=s', 'Fraction of cellwall in  biomass' ],
    [ 'lipid=s', 'Fraction of lipid in  biomass' ],
    [ 'energy=s', 'Number of ATP required for a gram of biomass' ],
    [ 'type=s', 'Type of template biomass reaction' ],
    [ 'new', 'Create new biomass reaction' ],
    [ 'delete', 'Delete specified biomass reaction' ],
    [ 'clearbiomasscompounds', 'Clear all biomass compounds' ],
    [ 'compoundstoremove=s', 'Compounds to remove from reaction (; delimited)' ],
    [ 'workspace|w=s', 'Workspace with template model', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
if (defined($opt->{compoundstoremove})) {
	$params->{compoundsToRemove} = [split(/;/,$opt->{compoundstoremove})];
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of template biomass reaction failed!\n";
} else {
	print "Adjustment of template biomass reaction successful\n";
	printObjectInfo($output);
}
