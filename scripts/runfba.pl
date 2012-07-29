########################################################################
# runfba.pl - This is a KBase command script automatically built from server specifications
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use lib "/home/chenry/kbase/models_api/clients/";
use fbaModelServicesClient;
use JSON::XS;
use Getopt::Long;

my $opts = [
	["inpputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
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
	["url=s","URL of the kbase webservice to use","http://bio-data-1.mcs.anl.gov/services/fba"]
];

my $options = {};
my $args = getOptionArgs($opts,$options);
GetOptions(@{$args}) || die usage($opts,"runfba","model_in","fba_out");

my $fbaModelServicesObj = fbaModelServicesClient->new($options->{url});

my $in_fh;
if ($options->{inpputfile}) {
    open($in_fh, "<", $options->{inpputfile}) or die "Cannot open ".$options->{inpputfile}.": $!";
} else {
    $in_fh = \*STDIN;
}

my $out_fh;
if ($options->{outputfile}) {
    open($out_fh, ">", $options->{outputfile}) or die "Cannot open ".$options->{outputfile}.": $!";
} else {
    $out_fh = \*STDOUT;
}
my $json = JSON::XS->new;

my $input;
my @input_txt = <$in_fh>;
my $inputstring = join("\n",@input_txt);
if (length($inputstring) == 0) {
	die usage($opts,"runfba","model_in","fba_out");
}
$input = $json->decode($inputstring);

my $output = $fbaModelServicesObj->runfba($input,$options,$options->{overwrite},$options->{save});
print $out_fh $output;
close($out_fh);

sub getOptionArgs {
	my($opts,$optOut) = @_;
	my $args = [$optOut];
	for (my $i=0; $i < @{$opts}; $i++) {
		if (defined($opts->[$i]->[2])) {
			if ($opts->[$i]->[0] =~ m/^(\w+)/) {
				$optOut->{$1} = $opts->[$i]->[2];
			}
		}
		push(@{$args},$opts->[$i]->[0]);
	}
	return $args;
}

sub usage {
	my($opts,$name,$pipein,$pipeout) = @_;
	my $usage = $name;
	if (length($pipein) > 0) {
		$usage .= " [< ".$pipein."]";
	}
	if (length($pipeout) > 0) {
		$usage .= " [> ".$pipeout."]";
	}
	$usage .= "\n";
	my $lines = [];
	for (my $i=0; $i < @{$opts}; $i++) {
		$lines->[$i] = "";
		my $typearray = [split(/:/,$opts->[$i]->[0])];
		my $options = [split(/\|/,$typearray->[0])];
		$lines->[$i] .= "--".$options->[0];
		if (defined($options->[1])) {
			$lines->[$i] .= "(".$options->[1].")";
		}
		$lines->[$i] .= "\t".$opts->[$i]->[1];
	}
	return $usage.join("\n",@{$lines})."\n";
}
