#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];

my $GeneData = {};
my $SingleGeneCDDs = {};
my $LongCDDs = {};
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
$array->[0] = "kb|g.1870";
for (my $i=0; $i < 1000; $i++) {
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

print "Initial load done!\n";

my $counts = [0,0,0,0,0,0,0,0,0,0];
my $gcounts = [0,0,0,0,0,0,0,0,0,0];
my $ccounts = [0,0,0,0,0,0,0,0,0,0];
foreach my $gene (keys(%{$GeneCDDs})) {
	if ($GeneData->{$gene}->[0] != 0) {
		my $sg = $GeneCDDs->{$gene};
		foreach my $cdd (keys(%{$sg})) {
			if ($CDDData->{$cdd}->[0] != 0) {
				my $genefraction = $sg->{$cdd}->[6]/$GeneData->{$gene}->[0];
				my $cddfraction = $sg->{$cdd}->[6]/$CDDData->{$cdd}->[0];
				for (my $i=0; $i <= 9; $i++) {
					if ($genefraction >= (0.1*$i)  && $cddfraction >= (0.1*$i)) {
						$counts->[$i]++;
					}
					if ($genefraction >= (0.1*$i)) {
						$gcounts->[$i]++;
					}
					if ($cddfraction >= (0.1*$i)) {
						$ccounts->[$i]++;
					}
				}
				if ($genefraction >= 0.9  && $cddfraction >= 0.9) {
					$SingleGeneCDDs->{$cdd}->{$gene} = [$sg->{$cdd}->[4],$genefraction,$cddfraction];
					$CDDData->{$cdd}->[3]++;
				}
				if ($cddfraction < 0.9) {
					delete $CDDGenes->{$cdd}->{$gene};
					delete $sg->{$cdd};
				}
				if ($genefraction >= 0.9  && ($CDDData->{$cdd}->[0]-$GeneData->{$gene}->[0]) >= 50) {
					if ($sg->{$cdd}->[2] <= 20 || ($CDDData->{$cdd}->[0]-$sg->{$cdd}->[3]) <= 20) {
						$LongCDDs->{$cdd}->{$gene} = [$sg->{$cdd}->[4],$genefraction,$cddfraction];
						$CDDData->{$cdd}->[4]++;
					}
				}
			} else {
				print "Zero length CDD!\n";
				delete $CDDGenes->{$cdd}->{$gene};
				delete $sg->{$cdd};
			}
		}
	} else {
		print "Zero length gene!\n";
		delete $CDDGenes->{$cdd}->{$gene};
		delete $GeneCDDs->{$gene}->{$cdd};
	}
}

print "Printing results!\n";

for (my $i=0; $i <= 9; $i++) {
	print "Bcount:".$i."\t".$counts->[$i]."\n";
}
for (my $i=0; $i <= 9; $i++) {
	print "Gcount:".$i."\t".$gcounts->[$i]."\n";
}
for (my $i=0; $i <= 9; $i++) {
	print "Ccount:".$i."\t".$ccounts->[$i]."\n";
}
print "Long count:".keys(%{$LongCDDs})."\n";
print "SingleGeneCDD:".keys(%{$SingleGeneCDDs})."\n";

print "Printing SingleGeneCDDs!\n";
store $SingleGeneCDDs, $directory."SingleGeneCDDs.store";
print "Done!\n";
$SingleGeneCDDs = {};
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
print "Printing LongCDDs!\n";
store $LongCDDs, $directory."LongCDDs.store";
print "Done!\n";
$CDDGenes = {};

1;