#!/usr/bin/perl

use Storable;

$|=1;
my $directory = $ARGV[0];
my $inputdir = $ARGV[1];
my $CDDData = retrieve($inputdir."CDDData.store");

my $array;
open(my $fh, "<", $inputdir."GenomeList.txt");
while (my $line = <$fh>) {
	chomp($line);
	push(@{$array},$line);
}
close($fh);
open(my $fhhhh, ">", $directory."AllFusions.txt");
my $headings = ["Gene","Current div","Score","Left","Right","Overlap","Filter left","Filter right","Filter overlap","SG left",
				"SG right","SG overlap","FSG left","FSG right","FSG overlap","Left PRK","Right PRK","Overlap PRK","Best left",
				"Best right","FLong overlap","Matches","Length","Function","ID","Left CDD SGF","Right CDD SGF","Left CDD other",
				"Right CDD other","Overlaps"];
print $fhhhh join("\t",@{$headings})."\n";
my $fusedroles;
my $pairedroles;
my $fusedothercdd;
my $fusedsgfcdd;
my $fusedcddoverlap;
my $cddpairs;
for (my $i=0; $i < @{$array}; $i++) {
	#print "Loading ".$i.":".$array->[$i]."\n";
	my $count = 0;
	my $genome = $array->[$i];
	my $candidates;
	my $GeneCDDs = {};
	my $GeneData = {};
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
	foreach my $gene (keys(%{$GeneCDDs})) {
		my $gcdd = $GeneCDDs->{$gene}; 
		if ($GeneData->{$gene}->[0] >= 300) {
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
						}
						last;
					}	
				}
			}
			my $ratio = $currdiv/$GeneData->{$gene}->[0];
			if ($currdiv > 0 && $ratio >= 0.15 && $ratio <= 0.85) {
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
				my $leftcddsgf;
				my $rightcddsgf;
				my $leftcddother;
				my $rightcddother;
				my $overlapnames;
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
									$leftcddsgf->{$CDDData->{$cdd}->[1]} = 1;
								}
								if ($CDDData->{$cdd}->[4] > 1) {
									$fusion_data->{leftfl}++;
								}
							}
							if (!defined($leftcddsgf->{$CDDData->{$cdd}->[1]})) {
								$leftcddother->{$CDDData->{$cdd}->[1]} = 1;
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
									$rightcddsgf->{$CDDData->{$cdd}->[1]} = 1;
									$fusion_data->{rightsgf}++;
								}
								if ($CDDData->{$cdd}->[4] > 1) {
									$fusion_data->{rightfl}++;
								}
							}
							if (!defined($rightcddsgf->{$CDDData->{$cdd}->[1]})) {
								$rightcddother->{$CDDData->{$cdd}->[1]} = 1;
							}
						} else {
							$overlaps->{$cdd} = $gcdd->{$cdd}->[$i];
							$overlapnames->{$CDDData->{$cdd}->[1]} = 1;
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
				if ($highscore >= 15 && $fusion_data->{leftsgf} > 0 && $fusion_data->{rightsgf} > 0 
				&& $fusion_data->{leftbest} >= 0.25 && $fusion_data->{rightbest} >= 0.25) {
					my $function = $GeneData->{$gene}->[1];
					my $array = [split(/\#/,$function)];
					$function = shift(@{$array});
					$function =~ s/\s+$//;
					my $delimiter = "|";
					if ($function =~ /\s*;\s/) {
						$delimiter = ";";
					}
					if ($function =~ /s+\@\s+/) {
						$delimiter = "\@";
					}
					if ($function =~ /s+\/\s+/) {
						$delimiter = "/";
					}
					my $roles = [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
					for (my $i=0; $i < @{$roles}; $i++) {
						$fusedroles->{$roles->[$i]}->{total}++;
						if (@{$roles} == 1) {
							$fusedroles->{$roles->[$i]}->{singlet}++;
						}
						for (my $j=$i+1; $j < @{$roles}; $j++) {
							if ($roles->[$i] < $roles->[$j]) {
								$pairedroles->{$roles->[$i]}->{$roles->[$j]}->{count}++;
								$pairedroles->{$roles->[$i]}->{$roles->[$j]}->{$delimiter}++;
							} else {
								$pairedroles->{$roles->[$j]}->{$roles->[$i]}->{count}++;
								$pairedroles->{$roles->[$j]}->{$roles->[$i]}->{$delimiter}++;
							}
						}
					}
					foreach my $cdd (keys(%{$leftcddsgf})) {
						$fusedsgfcdd->{$cdd}++;
						foreach my $rcdd (keys(%{$rightcddother})) {
							if ($cdd < $rcdd) {
								$cddpairs->{$cdd}->{$rcdd}++;
							} else {
								$cddpairs->{$rcdd}->{$cdd}++;
							}
						}
					}
					foreach my $cdd (keys(%{$rightcddsgf})) {
						$fusedsgfcdd->{$cdd}++;
					}
					foreach my $cdd (keys(%{$leftcddother})) {
						$fusedothercdd->{$cdd}++;
					}
					foreach my $cdd (keys(%{$rightcddother})) {
						$fusedothercdd->{$cdd}++;
					}
					foreach my $cdd (keys(%{$overlapnames})) {
						$fusedcddoverlap->{$cdd}++;
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
						join(";",keys(%{$leftcddsgf})),
						join(";",keys(%{$rightcddsgf})),
						join(";",keys(%{$leftcddother})),
						join(";",keys(%{$rightcddother})),
						join(";",keys(%{$overlapnames})),
					];
					$count++;
				}
			}
		}
	}
	print $genome."\t".$count."\n";
	if ($count > 0) {
		foreach my $gene (keys(%{$candidates})) {
			print $fhhhh $gene."\t".join("\t",@{$candidates->{$gene}})."\n";
		}
	}
}
close($fhhhh);

open($fh, ">", $directory."FusedRoles.txt");
print $fh "Role\tTotal\tSinglet\n";
foreach my $cdd (keys(%{$fusedroles})) {
	print $fh $cdd."\t".$fusedroles->{$cdd}->{total}."\t".$fusedroles->{$cdd}->{singlet}."\n";
}
close($fh);

open($fh, ">", $directory."PairedRoles.txt");
print $fh "Role 1\tRole 2\tCount\tDelimiters\n";
foreach my $cdd (keys(%{$pairedroles})) {
	foreach my $newcdd (keys(%{$pairedroles->{$cdd}})) {
		print $fh $cdd."\t".$newcdd."\t".$pairedroles->{$cdd}->{$newcdd}->{count};
		foreach my $delim (keys(%{$pairedroles->{$cdd}->{$newcdd}})) {
			if ($delim ne "count") {
				print $fh "\t".$delim."_".$pairedroles->{$cdd}->{$newcdd}->{$delim};
			}
		}
		print $fh "\n";
	}
}
close($fh);

open($fh, ">", $directory."FusedSGFCDDs.txt");
print $fh "Single gene filtered CDD\tCount\n";
foreach my $cdd (keys(%{$fusedsgfcdd})) {
	print $fh $cdd."\t".$fusedsgfcdd->{$cdd}."\n";
}
close($fh);

open($fh, ">", $directory."FusedOtherCDDs.txt");
print $fh "Other CDD\tCount\n";
foreach my $cdd (keys(%{$fusedothercdd})) {
	print $fh $cdd."\t".$fusedothercdd->{$cdd}."\n";
}
close($fh);

open($fh, ">", $directory."FusedOverlaps.txt");
print $fh "Overlapping CDD\tCount\n";
foreach my $cdd (keys(%{$fusedcddoverlap})) {
	print $fh $cdd."\t".$fusedcddoverlap->{$cdd}."\n";
}
close($fh);

open($fh, ">", $directory."CDDPairs.txt");
print $fh "CDD1\tCDD2\tCount\n";
foreach my $cdd (keys(%{$cddpairs})) {
	foreach my $newcdd (keys(%{$cddpairs->{$cdd}})) {
		print $fh $cdd."\t".$newcdd."\t".$cddpairs->{$cdd}->{$newcdd}."\n";
	}
}
close($fh);

1;