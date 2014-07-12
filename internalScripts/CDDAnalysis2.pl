#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];

#Loading data
my $CDDData = retrieve($directory."CDDData.store");
my $LongCDDs = {};
my $SingleGeneCDDs = {};

my $array;
open(my $fh, "<", $inputdir."GenomeList.txt");
while (my $line = <$fh>) {
	chomp($line);
	push(@{$array},$line);
}
close($fh);
for (my $i=0; $i <  @{$array}; $i++) {
	print "Loading ".$i.":".$array->[$i]."\n";
	my $fh;
	open($fh, "<", $inputdir.$array->[$i]);
	my $line = <$fh>;
	while (my $line = <$fh>) {
		chomp($line);
		my $items = [split(/\t/,$line)];
		my $genefraction = $items->[7]/($items->[1]/3);
		my $cddfraction = $items->[7]/$CDDData->{$items->[2]}->[0];
		if ($genefraction >= 0.9  && $cddfraction >= 0.9) {
			$SingleGeneCDDs->{$items->[2]}->{$items->[0]} = [$items->[12],$genefraction,$cddfraction];
			$CDDData->{$items->[2]}->[3]++;
		}
		if ($genefraction >= 0.9  && ($CDDData->{$items->[2]}->[0]-($items->[1]/3)) >= 50) {
			if ($items->[10] <= 20 || ($CDDData->{$items->[2]}->[0]-$items->[11]) <= 20) {
				$LongCDDs->{$items->[2]}->{$items->[0]} = [$items->[12],$genefraction,$cddfraction];
				$CDDData->{$items->[2]}->[4]++;
			}
		}
	}
	close($fh);
}

print "Printing SingleGeneCDDs!\n";
store $SingleGeneCDDs, $directory."SingleGeneCDDs.store";
print "Printing LongCDDs!\n";
store $LongCDDs, $directory."LongCDDs.store";
print "Printing CDDData!\n";
store $CDDData, $directory."CDDData.store";
print "Done!\n";

1;