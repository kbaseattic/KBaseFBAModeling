########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use fbaModelServicesScriptSupport;

my $name = "gapgen_fbamodel";
my $primin = "model_in";
my $primout = "model_out";
my $defaultURL = "http://bio-data-1.mcs.anl.gov/services/fba_gapfill";

my $opts = [
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["overwrite|o", "Overwrite existing model with gapfilled model",1],
	["save|s:s", "Save gapfilled model to new model name",""],
	["media:s","Media formulation to be used for the FBA simulation","Complete"],
	["refmedia:s","Reference media formulation in which the objective must be nonzero"],
	["notes:s","User notes to be affiliated with FBA simulation"],
	["nomediahyp","Set this flag to turn off media hypothesis"],
	["nobiomasshyp","Set this flag to turn off biomass hypothesis"],
	["nogprhyp","Set this flag to turn off GPR hypothesis"],
	["nopathwayhyp","Set this flag to turn off pathway hypothesis"],
	["objective:s","String describing the objective of the FBA problem"],
	["objfraction:s","Fraction of the objective to enforce to ensure"],
	["rxnko:s","Comma delimited list of reactions in model to be knocked out"],
	["geneko:s","Comma delimited list of genes in model to be knocked out"],
	["uptakelim:s","List of max uptakes for atoms to be used as constraints"],
	["defaultmaxflux:s","Maximum flux to use as default"],
	["defaultmaxuptake:s","Maximum uptake flux to use as default"],
	["defaultminuptake:s","Minimum uptake flux to use as default"],
	["url=s","URL of the kbase webservice to use",$defaultURL]
];

my ($options,$clientObj) = fbaModelServicesScriptSupport::initialize($opts,$name,$primin,$primout);
my $inputArray = fbaModelServicesScriptSupport::readPrimaryInput($options,$opts,$name,$primin,$primout);
my $json = JSON::XS->new;
my $input = $json->decode(join("\n",@{$inputArray}));
my $outputdata = $clientObj->gapgen_fbamodel($input,$options,$options->{overwrite},$options->{save});
$json->pretty(1);
my $output = $json->encode($outputdata);
fbaModelServicesScriptSupport::printPrimaryOutput($options,$output);