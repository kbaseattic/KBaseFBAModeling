########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use fbaModelServicesScriptSupport;

my $name = "simphenotypes";
my $primin = "model_in";
my $primout = "phenoptypes_out";
my $defaultURL = "http://www.kbase.us/services/fba";

my $opts = [
	["phenotypes|p=s", "Filename with phenotype table",undef],
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["media:s","Media formulation to be used for the FBA simulation","Complete"],
	["notes:s","User notes to be affiliated with FBA simulation",undef],
	["objective:s","String describing the objective of the FBA problem",undef],
	["rxnko:s","Comma delimited list of reactions to be knocked out",undef],
	["geneko:s","Comma delimited list of genes to be knocked out",undef],
	["uptakelim:s","List of max uptakes for atoms to be used as constraints",undef],
	["defaultmaxflux:s","Maximum flux to use as default",undef],
	["defaultmaxuptake:s","Maximum uptake flux to use as default",undef],
	["defaultminuptake:s","Minimum uptake flux to use as default",undef],
	["url=s","URL of the kbase webservice to use",$defaultURL]
];

my ($options,$clientObj) = initialize($opts,$name,$primin,$primout);
my $inputArray = readPrimaryInput($options,$opts,$name,$primin,$primout);
if (!-e $options->{phenotypes}) {
	die usage($opts,$name,$primin,$primout);
}
my $phenoData = loadtable($options->{phenotypes},"\\t");
$options->{fbaPhenotypeSimulations} = [];
my $columns = {label => -1,geneKOs => -1,reactionKOs => -1,media => -1,additionalCpds => -1,temperature => -1,pH => -1,growth => -1};
for (my $i=0; $i < @{$phenoData->{headings}}; $i++) {
	$columns->{$phenoData->{headings}->[$i]} = $i;
}
for (my $i=0; $i < @{$phenoData->{data}}; $i++) {
	my $row = $phenoData->{data}->[$i];
	my $newpheno = {label => $i,media => $row->[$columns->{media}]};
	if ($columns->{geneKOs} != -1 && $row->[$columns->{geneKOs}] ne "none") {
		$newpheno->{geneKOs} = [split(/,/,$row->[$columns->{geneKOs}])];
	}
	if ($columns->{reactionKOs} != -1 && $row->[$columns->{reactionKOs}] ne "none") {
		$newpheno->{reactionKOs} = [split(/,/,$row->[$columns->{reactionKOs}])];
	}
	if ($columns->{additionalCpds} != -1 && $row->[$columns->{additionalCpds}] ne "none") {
		$newpheno->{additionalCpds} = [split(/,/,$row->[$columns->{additionalCpds}])];
	}
	if ($columns->{pH} != -1) {
		$newpheno->{pH} = $row->[$columns->{pH}];
	}
	if ($columns->{temperature} != -1) {
		$newpheno->{temperature} = $row->[$columns->{temperature}];
	}
	if ($columns->{growth} != -1) {
		$newpheno->{growth} = $row->[$columns->{growth}];
	}
	push(@{$options->{fbaPhenotypeSimulations}},$newpheno);
}
my $json = JSON::XS->new;
$input = $json->decode(join("\n",@{$inputArray}));
my $output = $clientObj->runfba($input,$options,$options->{overwrite},$options->{save});
my $newColumnStart = @{$phenoData->{headings}};
$phenoData->{headings}->[$newColumnStart] = "Simulated growth fraction";
$phenoData->{headings}->[$newColumnStart+1] = "Simulated growth";
$phenoData->{headings}->[$newColumnStart+2] = "Class";
my $phenosimhash = {};
for (my $i=0; $i < @{$output->{fbaPhenotypeSimultations}}; $i++) {
	$phenosimhash->{$output->{fbaPhenotypeSimultations}->[$i]->{uuid}} = $output->{fbaPhenotypeSimultations}->[$i];
}
my $phenoresults = $output->{FBAResults}->[0]->{fbaPhenotypeSimultationResults};
for (my $i=0; $i < @{$phenoresults}; $i++) {
	if (defined($phenosimhash->{$phenoresults->[$i]->{fbaPhenotypeSimulation_uuid}})) {
		my $label = $phenosimhash->{$phenoresults->[$i]->{fbaPhenotypeSimulation_uuid}}->{label};
		$phenoData->{data}->[$label]->[$newColumnStart] = $phenoresults->[$i]->{simulatedGrowthFraction};
    	$phenoData->{data}->[$label]->[$newColumnStart+1] = $phenoresults->[$i]->{simulatedGrowth};
    	$phenoData->{data}->[$label]->[$newColumnStart+2] = $phenoresults->[$i]->{class};
	}
}
my $output = tableToText($phenoData);
printPrimaryOutput($options,$output);