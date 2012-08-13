########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use fbaModelServicesScriptSupport;

my $name = "gapfill_fbamodel";
my $primin = "model_in";
my $primout = "model_out";
my $defaultURL = "http://www.kbase.us/services/fba";

my $opts = [
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["overwrite|o", "Overwrite existing model with gapfilled model",1],
	["save|s:s", "Save gapfilled model to new model name",""],
	["media:s","Media formulation to be used for the FBA simulation","Complete"],
	["notes:s","User notes to be affiliated with FBA simulation"],
	["objective:s","String describing the objective of the FBA problem"],
	["nomediahyp","Set this flag to turn off media hypothesis"],
	["nobiomasshyp","Set this flag to turn off biomass hypothesis"],
	["nogprhyp","Set this flag to turn off GPR hypothesis"],
	["nopathwayhyp","Set this flag to turn off pathway hypothesis"],
	["allowunbalanced","Allow any unbalanced reactions to be used in gapfilling"],
	["activitybonus:s","Add terms to objective favoring activation of inactive reactions"],
	["drainpen:s","Penalty for gapfilling drain fluxes"],
	["directionpen:s","Penalty for making irreversible reactions reverisble"],
	["nostructpen:s","Penalty for reactions involving a substrate with unknown structure"],
	["unfavorablepen:s","Penalty for thermodynamically unfavorable reactions"],
	["nodeltagpen:s","Penalty for reactions with unknown free energy change"],
	["biomasstranspen:s","Penalty for transporters involving biomass compounds"],
	["singletranspen:s","Penalty for transporters with only one reactant and product"],
	["transpen:s","Penalty for gapfilling transport reactions"],
	["blacklistedrxns:s","'|' delimited list of reactions not allowed to be gapfilled"],
	["gauranteedrxns:s","'|' delimited list of reactions always allowed to be gapfilled"],
	["allowedcmps:s","'|' delimited list of compartments allowed in gapfilled reactions"],
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
my $outputdata = $clientObj->gapfill_fbamodel($input,$options,$options->{overwrite},$options->{save});
$json->pretty(1);
my $output = $json->encode($outputdata);
fbaModelServicesScriptSupport::printPrimaryOutput($options,$output);