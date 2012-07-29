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
	["inputfile|i:s", "Filename that input should be read from instead of STDIN",undef],
	["outputfile|f:s", "Filename that output should be printed to instead of STDOUT",undef],
	["overwrite|o", "Overwrite existing model with gapfilled model",1],
	["save|s:s", "Save gapfilled model to new model name",""],
	["media:s","Media formulation to be used for the FBA simulation","Complete"],
	["notes:s","User notes to be affiliated with FBA simulation"],
	["objective:s","String describing the objective of the FBA problem"],
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
	["url=s","URL of the kbase webservice to use","http://bio-data-1.mcs.anl.gov/services/fba_gapfill"]
];

my $options = {};
my $args = getOptionArgs($opts,$options);
GetOptions(@{$args}) || die usage($opts,"gapfill_fbamodel","model_in","model_out");

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
	die usage($opts,"gapfill_fbamodel","model_in","model_out");
}
$input = $json->decode($inputstring);
my $output = $fbaModelServicesObj->gapfill_fbamodel($input,$options,$options->{overwrite},$options->{save});
$json->pretty(1);
print $out_fh $json->encode($output);
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
