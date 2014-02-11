#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger, Mike Mundy, Matt Benedict
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
use Bio::KBase::CDMI::CDMIClient;

#Defining globals describing behavior
my $primaryArgs = ["Cofactor list filename"];
my $servercommand = "set_cofactors";
my $script = "fba-setcofactors";
my $translation = {
	biochem => "biochemistry",
	biochemws => "biochemistry_workspace",
	reset => "reset",
	auth => "auth",
	overwrite => "overwrite",
};
#Defining usage and options
my $specs = [
	[ 'biochem|b:s', 'ID of biochemistry database', { "default" => "default"} ],
    [ 'biochemws|w:s', 'Workspace where biochemistry database is located', { "default" => fbaws() } ],
    [ 'reset|r', 'Reset (turn off) compounds as universal cofactors', { "default" => 0 } ],
    [ 'overwrite|o', 'Overwrite existing biochemistry database with same name', { "default" => 0 } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
#Make sure cofactor list file exists
if (!-e $opt->{"Cofactor list filename"}) {
	print "Could not find input cofactor list file!\n";
	exit(1);
}
#Read the lines from the cofactor list file into the data array
open(my $fh, "<", $opt->{"Cofactor list filename"}) || return;
my $data = [];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},$line);
}
close($fh);
#Build the array of cofactor compounds from each line in the file
foreach my $line (@{$data}) {
	push(@{$params->{cofactors}},$line);
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Setting cofactors failed!\n";
	exit(1);
} else {
	print "Cofactors successfully set in biochemistry:\n";
	printObjectMeta($output);
}
exit(0);