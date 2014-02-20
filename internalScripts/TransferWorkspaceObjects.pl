#!/usr/bin/perl -w

use strict;
use Bio::KBase::ObjectAPI::KBaseStore;
$|=1;

my $directory = $ARGV[0];
my $multiprocess = $ARGV[1];
if (!defined($multiprocess)) {
	$multiprocess = "1:0";
}
my $targettype = $ARGV[2];
my $runtype = $ARGV[3];
my $objectlist;
my $successobj = [];
(my $numprocs,my $index) = split(/:/,$multiprocess);
if (defined($runtype) && $runtype eq "rr") {
	$objectlist = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/".$targettype."-".$index."-fail.txt");
	$successobj = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/".$targettype."-".$index."-success.txt");
} else {
	$objectlist = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/ObjectList.txt");
}

my $wslist = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/WorkspaceList.txt");
my $wshash = {};
for (my $i=0; $i < @{$wslist}; $i++) {
	my $array = [split(/\t/,$wslist->[$i])];
	$wshash->{$array->[0]} = $array->[1];
}
my $failobj = [];
my $errors = [];
my $currentproc = -1;
my $object;
my $error;
open ( my $fh, ">", $directory."/".$targettype."-".$index."-new_errors.txt");
print @{$objectlist}." objects to print!\n";
for (my $i=0; $i < @{$objectlist}; $i++) {
	my $array = [split(/\t/,$objectlist->[$i])];
	if (!defined($targettype) || $array->[0] eq $targettype) {
	if ($wshash->{$array->[1]} ne "seaver" ) {
		$currentproc++;
		if ($currentproc >= $numprocs) {
			$currentproc = 0;
		}
		if ($currentproc == $index) {
			my $OutputArray;
			$array->[3] = $wshash->{$array->[1]};
			my $command = "perl TransferWorkspaceObject.pl ../../KBaseDeploy/kb-workspaceroot.ini \"".join("\t",@{$array})."\" ".$directory."/GenomeAnno.txt 2> ".$directory."/".$targettype."-".$index."-temperror.txt";
			push(@{$OutputArray},`$command`);
			my $found = 0;
			for (my $j=0; $j < @{$OutputArray}; $j++) {
				if ($OutputArray->[$j] =~ m/^Success:(.+)/) {
					$object = $1;
					print "Success:".$i."\t".$array->[0]."\t".$array->[1]."\t".$array->[2]."\t".$array->[3]."\n";
					push(@{$successobj},$objectlist->[$i]);
					$found = 1;
				} elsif ($OutputArray->[$j] =~ m/^Failed:(.+)/) {
					$object = $1;
					print "Fail:".$i."\t".$array->[0]."\t".$array->[1]."\t".$array->[2]."\t".$array->[3]."\n";
					push(@{$failobj},$objectlist->[$i]);
					$found = 1;
				} elsif ($OutputArray->[$j] =~ m/^ERROR_MESSAGE(.+)/) {
					print "Fail:".$i."\t".$array->[0]."\t".$array->[1]."\t".$array->[2]."\t".$array->[3]."\n";
					$found = 1;
					push(@{$failobj},$objectlist->[$i]);
					$error = $1."\n";
					my $continue = 1;
					while ($continue == 1) {
						if (defined($OutputArray->[$j]) && $OutputArray->[$j] =~ m/(.+)END_ERROR_MESSAGE/) {
							$error .= $1;
							$continue = 0;
						} elsif (defined($OutputArray->[$j])) {
							$error .= $OutputArray->[$j]."\n";
						} elsif ($j >= @{$OutputArray}) {
							$continue = 0;
						}
						$j++;
					}
					print $fh $error."\n\n";
					push(@{$errors},$objectlist->[$i]);
					push(@{$errors},$error);
				}
			}
			if ($found == 0) {
				my $errordata = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/".$targettype."-".$index."-temperror.txt");
				print "Fail:".$i."\t".$array->[0]."\t".$array->[1]."\t".$array->[2]."\t".$array->[3]."\n";
				push(@{$errors},"TRANSFERFAIL:".$objectlist->[$i]);
				push(@{$errors},@{$errordata});
				push(@{$failobj},$objectlist->[$i]);
			}
		}
	}
	}
}
close($fh);
Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."/".$targettype."-".$index."-success.txt",$successobj);
Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."/".$targettype."-".$index."-fail.txt",$failobj);
Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."/".$targettype."-".$index."-errors.txt",$errors);

1;
