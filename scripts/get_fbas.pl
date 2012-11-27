########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use fbaModelServicesScriptSupport;

my $name = "get_fbas";
my $primin = "fbas_in";
my $primout = "fbas_out";
my $defaultURL = "http://bio-data-1.mcs.anl.gov/services/fba";

my $opts = [
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["url=s","URL of the kbase webservice to use",$defaultURL]
];

my ($options,$clientObj) = fbaModelServicesScriptSupport::initialize($opts,$name,$primin,$primout);
my $inputArray = fbaModelServicesScriptSupport::readPrimaryInput($options,$opts,$name,$primin,$primout);
my $json = JSON::XS->new;
my $input = $json->decode(join("\n",@{$inputArray}));
my $outputdata = $clientObj->get_fbas($input);
$json->pretty(1);
my $output = $json->encode($outputdata);
fbaModelServicesScriptSupport::printPrimaryOutput($options,$output);
