#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];

#Loading data
my $GeneData = retrieve($inputdir."GeneData.store");;
my $LongCDDs = retrieve($inputdir."LongCDDs.store");
my $SingleGeneCDDs = retrieve($inputdir."GeneCDDs.store");
my $GeneCDDs = retrieve($inputdir."GeneCDDs.store");
my $CDDData = {};
my $CDDGenes = {};
my $targgenes = [];
my $candidates = {};
my $fusions = {};
my $knownfusions = [qw(
kb|g.1870.peg.1148
kb|g.1870.peg.4242
kb|g.1870.peg.726
kb|g.1870.peg.701
kb|g.1870.peg.3942
kb|g.1870.peg.3932
kb|g.1870.peg.3789
kb|g.1870.peg.3115
kb|g.1870.peg.4397
kb|g.1870.peg.4097
kb|g.1870.peg.4334
kb|g.1870.peg.4379
kb|g.1870.peg.4221
kb|g.1870.peg.4304
kb|g.1870.peg.4025
kb|g.1870.peg.4509
kb|g.1870.peg.4137
kb|g.1870.peg.4450
kb|g.1870.peg.4384
kb|g.1870.peg.4056
kb|g.1870.peg.4391
kb|g.1870.peg.180
kb|g.1870.peg.321
kb|g.1870.peg.377
kb|g.1870.peg.231
kb|g.1870.peg.976
kb|g.1870.peg.510
kb|g.1870.peg.648
kb|g.1870.peg.92
kb|g.1870.peg.914
kb|g.1870.peg.267
kb|g.1870.peg.461
kb|g.1870.peg.96
kb|g.1870.peg.291
kb|g.1870.peg.709
kb|g.1870.peg.62
kb|g.1870.peg.309
kb|g.1870.peg.716
kb|g.1870.peg.331
kb|g.1870.peg.47
kb|g.1870.peg.1654
kb|g.1870.peg.1390
kb|g.1870.peg.1584
kb|g.1870.peg.1167
kb|g.1870.peg.1294
kb|g.1870.peg.1767
kb|g.1870.peg.1760
kb|g.1870.peg.1535
kb|g.1870.peg.1799
kb|g.1870.peg.1090
kb|g.1870.peg.1405
kb|g.1870.peg.1842
kb|g.1870.peg.1806
kb|g.1870.peg.1574
kb|g.1870.peg.1677
kb|g.1870.peg.1042
kb|g.1870.peg.1418
kb|g.1870.peg.1432
kb|g.1870.peg.1086
kb|g.1870.peg.1356
kb|g.1870.peg.1065
kb|g.1870.peg.1624
kb|g.1870.peg.1345
kb|g.1870.peg.1140
kb|g.1870.peg.1245
kb|g.1870.peg.1075
kb|g.1870.peg.1951
kb|g.1870.peg.2341
kb|g.1870.peg.2969
kb|g.1870.peg.2793
kb|g.1870.peg.2033
kb|g.1870.peg.2780
kb|g.1870.peg.2296
kb|g.1870.peg.2481
kb|g.1870.peg.2912
kb|g.1870.peg.2769
kb|g.1870.peg.2467
kb|g.1870.peg.2510
kb|g.1870.peg.2312
kb|g.1870.peg.2158
kb|g.1870.peg.2053
kb|g.1870.peg.2696
kb|g.1870.peg.2288
kb|g.1870.peg.2300
kb|g.1870.peg.2065
kb|g.1870.peg.2142
kb|g.1870.peg.2039
kb|g.1870.peg.2786
kb|g.1870.peg.3012
kb|g.1870.peg.3106
kb|g.1870.peg.3580
kb|g.1870.peg.3733
kb|g.1870.peg.3815
kb|g.1870.peg.3895
kb|g.1870.peg.3703
kb|g.1870.peg.3424
kb|g.1870.peg.3988
kb|g.1870.peg.3858
kb|g.1870.peg.3770
kb|g.1870.peg.3716
kb|g.1870.peg.3795
kb|g.1870.peg.3517
kb|g.1870.peg.3814
kb|g.1870.peg.3290
kb|g.1870.peg.3111
kb|g.1870.peg.3310
kb|g.1870.peg.3315
)];
foreach my $gene (@{$knownfusions}) {
	$fusions->{$gene} = 1;
}
foreach my $gene (keys(%{$GeneCDDs})) {
	if ($gene =~ m/g\.1870\./) {
		push(@{$targgenes},$gene);
	}
	my $sg = $GeneCDDs->{$gene}; 
	my $starts = [];
	my $stops = [];
	foreach my $cdd (keys(%{$sg})) {
		push(@{$starts},$sg->{$cdd}->[0]);
		push(@{$stops},$sg->{$cdd}->[1]);
	}
	$starts = [sort(@{$starts})];
	$stops = [sort(@{$stops})];
	my $currdiv = 0;
	my $highscore = 0;
	my $left = 0;
	my $right = 0;
	for (my $i=1; $i <= @{$stops}; $i++) {
		for (my $j=@{$starts}; $j > 0; $j--) {
			if ($starts->[$j-1] < $stops->[$i-1]) {
				if ($j < @{$starts}) {
					my $tright = @{$starts}-$j;
					if ($i*$tright > $highscore) {
						$right = $tright;
						$left = $i;
						$currdiv = $stops->[$i]+1;
						$highscore = $i*$right;
					}
				} else {
					$i = @{$stops};
				}
				last;
			}	
		}
	}
	if ($currdiv > 0) {
		my $leftsg = 0;
		my $rightsg = 0;
		my $overlapsg = 0;
		my $lefts = {};
		foreach my $cdd (keys(%{$sg})) {
			if ($sg->{$cdd}->[1] <= $currdiv) {
				$lefts->{$cdd} = 1;
			}
			if ($sg->{$cdd}->[0] >= $currdiv && defined($SingleGeneCDDs->{$cdd})) {
				$rightsg++;
			} elsif ($sg->{$cdd}->[1] <= $currdiv && defined($SingleGeneCDDs->{$cdd})) {
				$leftsg++;
			} elsif (defined($SingleGeneCDDs->{$cdd})) { 
				$overlapsg++;
			}
		}
		$longgene = 0;
		my $matches = 0;
		foreach my $cdd (keys(%{$sg})) {
			if (defined($SingleGeneCDDs->{$cdd}) && defined($LongCDDs->{$cdd})) {
				$longgene = 1;
			}
			if ($sg->{$cdd}->[0] >= $currdiv && defined($lefts->{$cdd})) {
				$matches++;
			}
		}
		$candidates->{$gene} = [$currdiv,$highscore,$left,$right,(@{$starts}-$left-$right),$leftsg,$rightsg,$overlapsg,$matches,$GeneData->{$gene}->[0],$GeneData->{$gene}->[1],$GeneData->{$gene}->[2],$longgene];
	}
}

open($fh, "> ".$directory."AllFusions.txt");
open($fhh, "> ".$directory."FilteredFusions.txt"); 
print $fh "Gene\tDivide\tScore\tLeft\tRight\tOverlap\tLeft SG\tRight SG\tOverlap SG\tMatches\tLength\tFunction\tSEED\tLongCDD\n";
print $fhh "Gene\tDivide\tScore\tLeft\tRight\tOverlap\tLeft SG\tRight SG\tOverlap SG\tMatches\tLength\tFunction\tSEED\tLongCDD\n";
foreach my $gene (keys(%{$candidates})) {
	my $g = $candidates->{$gene};
	print $fh $gene."\t".$g->[0]."\t".$g->[1]."\t".$g->[2]."\t".$g->[3]."\t".$g->[4]."\t".$g->[5]."\t".$g->[6]."\t".$g->[7]."\t".$g->[8]."\t".$g->[9]."\t".$g->[10]."\t".$g->[11]."\t".$g->[12]."\n";
	if ($g->[5] > 0 && $g->[6] > 0) {
		print $fhh $gene."\t".$g->[0]."\t".$g->[1]."\t".$g->[2]."\t".$g->[3]."\t".$g->[4]."\t".$g->[5]."\t".$g->[6]."\t".$g->[7]."\t".$g->[8]."\t".$g->[9]."\t".$g->[10]."\t".$g->[11]."\t".$g->[12]."\n";
	}
}
close($fh);
close($fhh);

open($fh, "> ".$directory."EcoliFusions.txt");
print $fh "Gene\tDivide\tScore\tLeft\tRight\tOverlap\tLeft SG\tRight SG\tOverlap SG\tMatches\tLength\tFunction\tSEED\tLongCDD\tFusion\n";
foreach my $gene (@{$targgenes}) {
	my $g = $candidates->{$gene};
	if (defined($fusions->{$gene})){
		print $fh $gene."\t".$g->[0]."\t".$g->[1]."\t".$g->[2]."\t".$g->[3]."\t".$g->[4]."\t".$g->[5]."\t".$g->[6]."\t".$g->[7]."\t".$g->[8]."\t".$g->[9]."\t".$g->[10]."\t".$g->[11]."\t".$g->[12]."\t1\n";
	} else {
		print $fh $gene."\t".$g->[0]."\t".$g->[1]."\t".$g->[2]."\t".$g->[3]."\t".$g->[4]."\t".$g->[5]."\t".$g->[6]."\t".$g->[7]."\t".$g->[8]."\t".$g->[9]."\t".$g->[10]."\t".$g->[11]."\t".$g->[12]."\t0\n";
	}
}
close($fh);

1;