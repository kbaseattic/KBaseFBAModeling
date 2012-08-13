########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use fbaModelServicesScriptSupport;

my $name = "genome_to_fbamodel";
my $primin = "genome_in";
my $primout = "model_out";
my $defaultURL = "http://www.kbase.us/services/fba";

my $opts = [
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["url=s","URL of the kbase webservice to use",$defaultURL]
];

my ($options,$clientObj) = initialize($opts,$name,$primin,$primout);
my $inputArray = readPrimaryInput($options,$opts,$name,$primin,$primout);
my $json = JSON::XS->new;
$input = $json->decode(join("\n",@{$inputArray}));
my $outputdata = $clientObj->genome_to_fbamodel($input);
$json->pretty(1);
my $output = $json->encode($outputdata);
printPrimaryOutput($options,$output);