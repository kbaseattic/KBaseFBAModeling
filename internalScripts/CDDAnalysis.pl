#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];
my $max = $ARGV[2];

my $GeneData = {};
my $GeneCDDs = {};
my $CDDData = {};
my $CDDGenes = {};

my $array;
open(my $fh, "<", $inputdir."GenomeList.txt");
while (my $line = <$fh>) {
	chomp($line);
	push(@{$array},$line);
}
close($fh);
my $starttime = time();
$array->[0] = "kb|g.1870";
for (my $i=0; $i < $max; $i++) {
#for (my $i=0; $i < @{$array}; $i++) {
	print "Loading ".$i.":".$array->[$i]."\n";
	my $fh;
	open($fh, "<", $inputdir.$array->[$i]);
	my $line = <$fh>;
	while (my $line = <$fh>) {
		chomp($line);
		my $items = [split(/\t/,$line)];
		#Setting gene data
		if (!defined($GeneData->{$items->[0]})) {
			#Length/Function/ID
			$GeneData->{$items->[0]} = [$items->[1]/3,$items->[6],$items->[13]];
		}
		#Setting CDD data
		if (!defined($CDDData->{$items->[2]})) {
			#CDD stop/CDD name/Gene count/Single gene count
			$CDDData->{$items->[2]} = [$items->[11],$items->[8],0,0,0];
		} elsif ($CDDData->{$items->[2]}->[0] < $items->[11]) {
			$CDDData->{$items->[2]}->[0] = $items->[11]
		}
		$CDDData->{$items->[2]}->[2]++;
		#Setting Gene CDD data
		#Start/Stop/CDDStart/CDDStop/Eval/Ident/AlignLength
		$CDDGenes->{$items->[2]}->{$items->[0]} = [$items->[3],$items->[4],$items->[10],$items->[11],$items->[12],$items->[5],$items->[7]];
		$GeneCDDs->{$items->[0]}->{$items->[2]} = [$items->[3],$items->[4],$items->[10],$items->[11],$items->[12],$items->[5],$items->[7]];
	}
	close($fh);
}
print "Done loading:".(time()-$starttime)."\n";
$starttime = time();

print "Initial load done!\n";

print "Printing CDDData!\n";
store $CDDData, $directory."CDDData.store";
print "Done!\n";
$CDDData = {};
print "Printing GeneData!\n";
store $GeneData, $directory."GeneData.store";
print "Done!\n";
$GeneData = {};
print "Printing GeneCDDs!\n";
store $GeneCDDs, $directory."GeneCDDs.store";
print "Done!\n";
$GeneCDDs = {};
print "Printing CDDGenes!\n";
store $CDDGenes, $directory."CDDGenes.store";
print "Done!\n";
$CDDGenes = {};

print "Done saving:".(time()-$starttime)."\n";

1;