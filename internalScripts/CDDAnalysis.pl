#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];
my $CDDData = {};

my $array;
open(my $fh, "<", $inputdir."GenomeList.txt");
while (my $line = <$fh>) {
	chomp($line);
	push(@{$array},$line);
}
close($fh);
for (my $i=0; $i < @{$array}; $i++) {
	print "Loading ".$i.":".$array->[$i]."\n";
	my $fh;
	open($fh, "<", $inputdir.$array->[$i]);
	my $line = <$fh>;
	while (my $line = <$fh>) {
		chomp($line);
		my $items = [split(/\t/,$line)];
		#Setting CDD data
		if (!defined($CDDData->{$items->[2]})) {
			#CDD stop/CDD name/Gene count/Single gene count
			$CDDData->{$items->[2]} = [$items->[11],$items->[8],0,0,0];
		} elsif ($CDDData->{$items->[2]}->[0] < $items->[11]) {
			$CDDData->{$items->[2]}->[0] = $items->[11]
		}
		$CDDData->{$items->[2]}->[2]++;
	}
	close($fh);
}
print "Printing CDDData!\n";
store $CDDData, $directory."CDDData.store";
print "Done!\n";

1;