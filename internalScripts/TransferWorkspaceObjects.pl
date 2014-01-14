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
(my $numprocs,my $index) = split(/:/,$multiprocess);
my $objectlist = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/ObjectList.txt");
my $currentproc = -1;
for (my $i=0; $i < @{$objectlist}; $i++) {
	my $array = [split(/\t/,$objectlist->[$i])];
	if (!defined($targettype) || $array->[0] eq $targettype) {
		$currentproc++;
		if ($currentproc >= $numprocs) {
			$currentproc = 0;
		}
		if ($currentproc == $index) {
			my $OutputArray;
			my $command = "perl TransferWorkspaceObject.pl ../../KBaseDeploy/kb-workspaceroot.ini \"".$objectlist->[$i]."\" 2> /dev/null";
			push(@{$OutputArray},`$command`);
			my $found = 0;
			for (my $i=0; $i < @{$OutputArray}; $i++) {
				if ($OutputArray->[$i] =~ m/^Success/) {
					print $OutputArray->[$i];
					$found = 1;
				} elsif ($OutputArray->[$i] =~ m/^Failed/) {
					print $OutputArray->[$i];
					$found = 1;
				}
			}
			if ($found == 0) {
				print "Failed:".$objectlist->[$i]."\n";
			}
		}
	}
}

1;
