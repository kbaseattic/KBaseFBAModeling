########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use fbaModelServicesScriptSupport;

my $name = "runfba";
my $primin = "model_in";
my $primout = "fba_out";
my $defaultURL = "http://bio-data-1.mcs.anl.gov/services/fba";

my $opts = [
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["overwrite|o", "Save FBA solution in existing model",0],
	["save|s:s", "Save FBA solution in a new model",""],
	["media:s","Media formulation to be used for the FBA simulation","Complete"],
	["notes:s","User notes to be affiliated with FBA simulation",undef],
	["objective:s","String describing the objective of the FBA problem",undef],
	["objfraction:s","Fraction of the objective to enforce to ensure",undef],
	["rxnko:s","Comma delimited list of reactions to be knocked out",undef],
	["geneko:s","Comma delimited list of genes to be knocked out",undef],
	["uptakelim:s","List of max uptakes for atoms to be used as constraints",undef],
	["defaultmaxflux:s","Maximum flux to use as default",undef],
	["defaultmaxuptake:s","Maximum uptake flux to use as default",undef],
	["defaultminuptake:s","Minimum uptake flux to use as default",undef],
	["fva","Perform flux variability analysis",undef],
	["simulateko","Simulate single gene knockouts",undef],
	["minimizeflux","Minimize fluxes in output solution",undef],
	["findminmedia","Predict minimal media formulations for the model",undef],
	["allreversible","Make all reactions reversible in FBA simulation",undef],
	["simplethermoconst","Use simple thermodynamic constraints",undef],
	["thermoconst","Use standard thermodynamic constraints",undef],
	["nothermoerror","Do not include uncertainty in thermodynamic constraints",undef],
	["minthermoerror","Minimize uncertainty in thermodynamic constraints",undef],
	["url=s","URL of the kbase webservice to use",$defaultURL]
];

my ($options,$clientObj) = fbaModelServicesScriptSupport::initialize($opts,$name,$primin,$primout);
my $inputArray = fbaModelServicesScriptSupport::readPrimaryInput($options,$opts,$name,$primin,$primout);
my $json = JSON::XS->new;
my $input = $json->decode(join("\n",@{$inputArray}));
my $output = $clientObj->runfba($input,$options,$options->{overwrite},$options->{save});
fbaModelServicesScriptSupport::printPrimaryOutput($options,$output);