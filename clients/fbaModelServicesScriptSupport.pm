use strict;
use warnings;
use JSON::XS;
use Getopt::Long;
use fbaModelServicesClient;
package fbaModelServicesScriptSupport;

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

sub readPrimaryInput {
	my($options,$opts,$name,$primin,$primout) = @_;
	my $in_fh;
	if ($options->{inputfile}) {
	    open($in_fh, "<", $options->{inpputfile}) or die "Cannot open ".$options->{inpputfile}.": $!";
	} else {
	    $in_fh = \*STDIN;
	}
	my @data = <$in_fh>;
	if ($options->{inputfile}) {
		close($in_fh);	
	}
	if (@data == 0 || (@data == 1 && length($data[0]) == 0)) {
		die usage($opts,$name,$primin,$primout);
	} 
	return [@data];
}

sub printPrimaryOutput {
	my($options,$output) = @_;
	my $out_fh;
	if ($options->{outputfile}) {
	    open($out_fh, ">", $options->{outputfile}) or die "Cannot open ".$options->{outputfile}.": $!";
	} else {
	    $out_fh = \*STDOUT;
	}
	print $out_fh $output;
	close($out_fh);
}

sub initialize {
	my($opts,$name,$primin,$primout) = @_;
	my $options = {};
	my $args = getOptionArgs($opts,$options);
	GetOptions(@{$args}) || die usage($opts,$name,$primin,$primout);
	my $fbaModelServicesObj = fbaModelServicesClient->new($options->{url});
	return ($options,$fbaModelServicesObj);
}

1;