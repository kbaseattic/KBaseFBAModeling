#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];
my $genome = $ARGV[2];

my $CDDData = retrieve($inputdir."CDDData.store");
open(my $fh, ">", $directory."CDD-Data.txt");
print $fh "ID\tLength\tName\tGenes\tSinglegenes\tLonggenes\n";
foreach my $cdd (keys(%{$CDDData})) {
	print $fh $cdd."\t".join("\t",@{$CDDData->{$cdd}})."\n";
}
close ($fh);
my $GeneCDDs = {};
my $GeneData = {};

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

open(my $fhh, "<", $inputdir.$genome);
my $line = <$fhh>;
while ($line = <$fhh>) {
	chomp($line);
	my $items = [split(/\t/,$line)];
	my $genefraction = $items->[7]/($items->[1]/3);
	my $cddfraction = $items->[7]/$CDDData->{$items->[2]}->[0];
	#Setting Gene CDD data
	#Start:0/Stop:1/CDDStart:2/CDDStop:3/Eval:4/Ident:5/AlignLength:6/Gene fraction:7/CDD fraction:8
	push(@{$GeneCDDs->{$items->[0]}->{$items->[2]}},[$items->[3],$items->[4],$items->[10],$items->[11],$items->[12],$items->[5],$items->[7],$genefraction,$cddfraction]);
	#Setting gene data
	if (!defined($GeneData->{$items->[0]})) {
		#Length/Function/ID
		$GeneData->{$items->[0]} = [$items->[1]/3,$items->[6],$items->[13]];
	}
}
close($fhh);
open(my $fhhh, ">", $directory.$genome."-CDDs.txt");
open(my $fus, ">", $directory.$genome."-FusCDDs.txt");
open(my $nfus, ">", $directory.$genome."-NFusCDDs.txt");
foreach my $gene (keys(%{$GeneCDDs})) {
	my $gcdd = $GeneCDDs->{$gene}; 
	my $usstarts = [];
	my $usstops = [];
	foreach my $cdd (keys(%{$gcdd})) {
		for (my $i=0; $i < @{$gcdd->{$cdd}}; $i++) {
			push(@{$usstarts},$gcdd->{$cdd}->[$i]->[0]+0);
			push(@{$usstops},$gcdd->{$cdd}->[$i]->[1]+0);
		}
	}
	my $starts = [sort { $a <=> $b } @{$usstarts}];
	my $stops = [sort { $a <=> $b } @{$usstops}];
	my $currdiv = 0;
	my $highscore = 0;
	my $left = 0;
	my $right = 0;
	for (my $i=1; $i <= @{$stops}; $i++) {
		for (my $j=@{$starts}; $j > 0; $j--) {
			if ($starts->[$j-1] < $stops->[$i-1]) {
				if ($j < @{$starts}) {
					my $tright = @{$starts}-$j;
					my $temp = $stops->[$i-1]+1;
					my $rtemp = ($GeneData->{$gene}->[0]-$temp);
					if ($temp > 90 && $rtemp > 90 && $i*$tright > $highscore) {
						$right = $tright;
						$left = $i;
						$currdiv = $temp;
						$highscore = $i*$right;
					}
				}# else {
					#$i = @{$stops};
				#}
				last;
			}	
		}
	}
	if ($currdiv > 0) {
		my $fusion_data = {
			leftf => 0,
			rightf => 0,
			left => 0,
			right => 0,
			leftsg => 0,
			leftsgf => 0,
			rightsg => 0,
			rightsgf => 0,
			overlap => 0,
			overlapf => 0,
			overlapsgf => 0,
			overlapprk => 0,
			overlapfl => 0,
			leftprk => 0,
			leftbest => 0,
			rightprk => 0,
			rightbest => 0,
			matches => 0
		};
		my $lefts;
		my $rights;
		my $overlaps;
		foreach my $cdd (keys(%{$gcdd})) {
			for (my $i=0; $i < @{$gcdd->{$cdd}}; $i++) {
				if ($gcdd->{$cdd}->[$i]->[1] <= $currdiv) {
					$lefts->{$cdd} = $gcdd->{$cdd}->[$i];
					my $coverage = $gcdd->{$cdd}->[$i]->[6]/$currdiv;
					if ($coverage > $fusion_data->{leftbest}) {
						$fusion_data->{leftbest} = $coverage;
					}
					$fusion_data->{left}++;
					if ($CDDData->{$cdd}->[3] > 5) {
						$fusion_data->{leftsg}++;
					}
					if ($CDDData->{$cdd}->[1] =~ m/^PRK/) {
						$fusion_data->{leftprk}++;
					}
					if ($gcdd->{$cdd}->[$i]->[8] >= 0.9) {
						$fusion_data->{leftf}++;
						if ($CDDData->{$cdd}->[3] > 5) {
							$fusion_data->{leftsgf}++;
						}
						if ($CDDData->{$cdd}->[4] > 1) {
							$fusion_data->{leftfl}++;
						}
					}
				} elsif ($gcdd->{$cdd}->[$i]->[0] >= $currdiv) {
					$rights->{$cdd} = $gcdd->{$cdd}->[$i];
					my $coverage = $gcdd->{$cdd}->[$i]->[6]/($GeneData->{$gene}->[0]-$currdiv);
					if ($coverage > $fusion_data->{rightbest}) {
						$fusion_data->{rightbest} = $coverage;
					}
					$fusion_data->{right}++;
					if ($CDDData->{$cdd}->[3] > 5) {
						$fusion_data->{rightsg}++;
					}
					if ($CDDData->{$cdd}->[1] =~ m/^PRK/) {
						$fusion_data->{rightprk}++;
					}
					if ($gcdd->{$cdd}->[$i]->[8] >= 0.9) {
						$fusion_data->{rightf}++;
						if ($CDDData->{$cdd}->[3] > 5) {
							$fusion_data->{rightsgf}++;
						}
						if ($CDDData->{$cdd}->[4] > 1) {
							$fusion_data->{rightfl}++;
						}
					}
				} else {
					$overlaps->{$cdd} = $gcdd->{$cdd}->[$i];
					$fusion_data->{overlap}++;
					if ($CDDData->{$cdd}->[3] > 5) {
						$fusion_data->{overlapsg}++;
					}
					if ($CDDData->{$cdd}->[1] =~ m/^PRK/) {
						$fusion_data->{overlapprk}++;
					}
					if ($gcdd->{$cdd}->[$i]->[8] >= 0.9) {
						$fusion_data->{overlapf}++;
						if ($CDDData->{$cdd}->[3] > 5) {
							$fusion_data->{overlapsgf}++;
						}
						if ($CDDData->{$cdd}->[4] > 1) {
							$fusion_data->{overlapfl}++;
						}
					}
				}
			}
		}
		foreach my $cdd (keys(%{$lefts})) {
			if (defined($rights->{$cdd})) {
				$fusion_data->{matches}++;
			}
		}
		$candidates->{$gene} = [
			$currdiv,
			$highscore,
			$fusion_data->{left},
			$fusion_data->{right},
			$fusion_data->{overlap},
			$fusion_data->{leftf},
			$fusion_data->{rightf},
			$fusion_data->{overlapf},
			$fusion_data->{leftsg},
			$fusion_data->{rightsg},
			$fusion_data->{overlapsg},
			$fusion_data->{leftsgf},
			$fusion_data->{rightsgf},
			$fusion_data->{overlapsgf},
			$fusion_data->{leftprk},
			$fusion_data->{rightprk},
			$fusion_data->{overlapprk},
			$fusion_data->{leftbest},
			$fusion_data->{rightbest},
			$fusion_data->{overlapfl},
			$fusion_data->{matches},
			$GeneData->{$gene}->[0],
			$GeneData->{$gene}->[1],
			$GeneData->{$gene}->[2],
		];
		my $labels;
		my $array;
		for (my $i=0; $i < $GeneData->{$gene}->[0]; $i++) {
			my $count = 0;
			$labels->[$count] = $gene;
			if ($i == $currdiv) {
				$array->[$count] .= "_";
			} else {
				$array->[$count] .= "X";
			}
			my $leftkeys = [keys(%{$lefts})];
			my $rightkeys = [keys(%{$rights})];
			my $max = @{$leftkeys};
			if ($max < @{$rightkeys}) {
				$max = @{$rightkeys};
			}
			for (my $j=0; $j < $max; $j++) {
				$count++;
				$labels->[$count] = "";
				if (defined($leftkeys->[$j])) {
					$labels->[$count] .= $CDDData->{$leftkeys->[$j]}->[1].";";
				}
				if (defined($rightkeys->[$j])) {
					$labels->[$count] .= $CDDData->{$rightkeys->[$j]}->[1].";";
				}
				if (defined($leftkeys->[$j]) && $i > $lefts->{$leftkeys->[$j]}->[0] && $i < $lefts->{$leftkeys->[$j]}->[1]) {
					$array->[$count] .= "L";
				} elsif (defined($rightkeys->[$j]) && $i > $rights->{$rightkeys->[$j]}->[0] && $i < $rights->{$rightkeys->[$j]}->[1]) {
					$array->[$count] .= "R";
				} else {
					$array->[$count] .= " ";
				} 
			}
			foreach my $cdd (keys(%{$overlaps})) {
				$count++;
				$labels->[$count] = $CDDData->{$cdd}->[1];
				if ($i > $overlaps->{$cdd}->[0] && $i < $overlaps->{$cdd}->[1]) {
					$array->[$count] .= "O";
				} else {
					$array->[$count] .= " ";
				}
			}
		}
		if (defined($fusions->{$gene})) {
			for (my $i=0; $i < @{$array}; $i++) {
				print $fus $array->[$i]."\t".$labels->[$i]."\n";
			}
			print $fus "\n";
		} else {
			for (my $i=0; $i < @{$array}; $i++) {
				print $nfus $array->[$i]."\t".$labels->[$i]."\n";
			}
			print $nfus "\n";
		}
		for (my $i=0; $i < @{$array}; $i++) {
			print $fhhh $array->[$i]."\t".$labels->[$i]."\n";
		}
		print $fhhh "\n";
	}
}
close($fhhh);
close($fus);
close($nfus);

open(my $fhhhh, ">", $directory.$genome."-fusions.txt");
my $headings = ["Gene","Current div","Score","Left","Right","Overlap","Filter left","Filter right","Filter overlap","SG left","SG right","SG overlap","FSG left","FSG right","FSG overlap","Left PRK","Right PRK","Overlap PRK","Best left","Best right","FLong overlap","Matches","Length","Function","ID"];
print $fhhhh join("\t",@{$headings})."\n";
foreach my $gene (keys(%{$candidates})) {
	print $fhhhh $gene."\t".join("\t",@{$candidates->{$gene}})."\n";
}
close($fhhhh);

1;