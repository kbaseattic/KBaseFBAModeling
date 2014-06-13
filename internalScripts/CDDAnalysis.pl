#!/usr/bin/perl -w

use JSON;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];

my $GeneData = {};
my $SingleGeneCDDs = {};
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
for (my $i=0; $i < @{$array}; $i++) {
	my $fh;
	open($fh, "<", $inputdir.$array->[$i]);
	my $line = <$fh>;
	while (my $line = <$fh>) {
		chomp($line);
		my $items = [split(/\t/,$line)];
		#Setting gene data
		if (!defined($GeneData->{$items->[0]})) {
			$GeneData->{$items->[0]} = [$items->[1],$items->[6],$items->[13]];
		}
		#Setting CDD data
		if (!defined($CDDData->{$items->[2]})) {
			$CDDData->{$items->[2]} = [$items->[11],$items->[8],0,0];
		} elsif ($CDDData->{$items->[2]}->[0] < $items->[11]) {
			$CDDData->{$items->[2]}->[0] = $items->[11]
		}
		$CDDData->{$items->[2]}->[2]++;
		#Setting Gene CDD data
		$CDDGenes->{$items->[2]}->{$items->[0]} = [$items->[3],$items->[4],$items->[10],$items->[11],$items->[12],$items->[5],$items->[7]];
		$GeneCDDs->{$items->[0]}->{$items->[2]} = [$items->[3],$items->[4],$items->[10],$items->[11],$items->[12],$items->[5],$items->[7]];
	}
	close($fh);
}

print "Initial load done!\n";

my $counts = [0,0,0,0,0,0,0,0,0,0];
foreach my $gene (keys(%{$GeneCDDs})) {
	foreach my $cdd (keys(%{$GeneCDDs->{$gene}})) {
		my $genefraction = $GeneCDDs->{$gene}->{$cdd}->[7]/$GeneData->{$items->[0]}->[0];
		my $cddfraction = $GeneCDDs->{$gene}->{$cdd}->[7]/$CDDData->{$items->[2]}->[0];
		for (my $i=0; $i <= 9; $i++) {
			if ($genefraction >= 0.1*$i  && $cddfraction >= 0.1*$i) {
				$counts->[$i]++;
			}
		}
		if ($genefraction >= 0.9  && $cddfraction >= 0.9) {
			$SingleGeneCDDs->{$gene}->{$cdd} = [$items->[12],$genefraction,$cddfraction];
			$CDDData->{$cdd}->[3]++;
		}
	}
}

print "Printing results!\n";

for (my $i=0; $i <= 9; $i++) {
	print "Count:".$i."\t".$counts->[$i]."\n";
}

open($fh, ">", $directory."SingleGeneCDDs.json");
print $fh to_json( $SingleGeneCDDs, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
close($fh);

open($fh, ">", $directory."GeneCDDs.json");
print $fh to_json( $GeneCDDs, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
close($fh);

open($fh, ">", $directory."CDDData.json");
print $fh to_json( $CDDData, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
close($fh);

open($fh, ">", $directory."CDDGenes.json");
print $fh to_json( $CDDGenes, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
close($fh);

open($fh, ">", $directory."GeneData.json");
print $fh to_json( $GeneData, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
close($fh);

1;