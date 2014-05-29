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
      fba-adjusttempbiocpd -- adjust compound in biomass reaction of a model template

DESCRIPTION
      Adjust a compound in the biomass reaction of a ModelTemplate object.

      The 'Template ID' positional argument is the ID of a ModelTemplate object.
      The 'Biomass ID' positional argument is the name or UUID of a biomass
      entity in the ModelTemplate object.  The 'Compound ID' positional parameter
      is the ID or name of the compound to adjust.  The compound can be specified
      by any of its aliases.

      The --workspace optional argument is the ID of the workspace containing
      the ModelTemplate object.

      The --compartment optional argument specifies the compartment of the
      biomass compound.  Valid values are 'c' for cytosol, 'd' for plastid, 'e'
      for extracelluar, 'g' for golgi, 'h' for chloroplast, 'l' for lysosome, 'm'
      for mitochondria, 'n' for nucleus, 'p' for periplasm, 'r' for endoplasm,
      'v' for vacuole, 'w' for cellwall, and 'x' for peroxisome.  The default
      value is 'c'.

      The --coef optional argument specifies the coefficient of the biomass
      compound as a floating point number.  The default value is 1.0.  The
      --coeftype optional argument specifies the type of the coefficient.  Valid
      values are MOLFRACTION, MASSFRACTION, AT, GC, MULTIPLIER, EXACT, MOLSPLIT,
      and MASSSPLIT.

      The --class optional argument specifies the class of the biomass compound.
      Valid values are dna, rna, lipid, protein, cellwall, and cofactor.

      The --universal optional argument indicates if the biomass compound should
      be marked as universal.

      The --linkcpds optional argument specifies a semicolon delimited list of
      compound IDs that are linked to the compound.

EXAMPLES
      Add a new compound to the biomass:
      > fba-adjusttempbiocpd

SEE ALSO
      fba-adjusttempbiomass
      fba-gettemplate
      fba-importtemplate

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Template ID","Biomass ID","Compound ID"];
my $servercommand = "adjust_template_biomass";
my $script = "fba-adjusttempbiocpd";
my $translation = {
	"Template ID" => "templateModel",
	"Biomass ID" => "biomass",
	workspace => "workspace",
	auth => "auth"
};
#Defining usage and options
my $specs = [
    [ 'compartment|c=s', 'Compartment of template biomass compound', { "default" => "c" } ],
    [ 'coef=s', 'Coefficient of template biomass compound' ],
    [ 'coeftype=s', 'Coefficient type of template biomass compound' ],
    [ 'class=s', 'Class of template biomass compound' ],
    [ 'universal', 'Indicates if template biomass compound should be universal' ],
    [ 'linkcpds=s@', 'Compounds linked to current compound (; delimited)' ],
    [ 'workspace|w=s', 'Workspace with template model', { "default" => fbaws() } ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage);
$params->{compoundsToAdd} = [$opt->{"Compound ID"},$opt->{compartment},$opt->{class},$opt->{universal},$opt->{coeftype},$opt->{coef},[]];
if (defined($opt->{linkcpds})) {
	foreach my $cpd (@{$opt->{linkcpds}}) {
		my $array = [split(/;/,$cpd)];
		push(@{$params->{compoundsToAdd}->[6]},@{$array});
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Adjustment of template biomass failed!\n";
} else {
	print "Adjustment of template biomass successful\n";
	printObjectInfo($output);
}
