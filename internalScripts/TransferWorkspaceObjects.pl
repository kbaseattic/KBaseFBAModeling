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
my $successobj = [];
my $failobj = [];
my $errors = [];
my $currentproc = -1;
my $object;
my $error;
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
			for (my $j=0; $j < @{$OutputArray}; $j++) {
				if ($OutputArray->[$j] =~ m/^Success:(.+)/) {
					$object = $1;
					push(@{$successobj},$object);
					$found = 1;
				} elsif ($OutputArray->[$j] =~ m/^Failed:(.+)/) {
					$object = $1;
					push(@{$failobj},$object);
					$found = 1;
				} elsif ($OutputArray->[$j] =~ m/^ERROR_MESSAGE(.+)/) {
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
					push(@{$errors},$object);
					push(@{$errors},$error);
				}
			}
			if ($found == 0) {
				print "Failed:".$objectlist->[$i]."\n";
			}
		}
	}
}
Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."/".$targettype."-".$index."-success.txt",$successobj);
Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."/".$targettype."-".$index."-fail.txt",$failobj);
Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."/".$targettype."-".$index."-errors.txt",$errors);

1;
