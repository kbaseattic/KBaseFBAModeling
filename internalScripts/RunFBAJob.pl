#!/usr/bin/perl -w

########################################################################
# This perl script runs the designated queue for model reconstruction
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 10/6/2009
########################################################################
use strict;
use warnings;
use JSON::XS;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
use LWP::Simple;
use Config::Simple;
use File::Path;
use Bio::KBase::fbaModelServices::Impl;

$|=1;
if (!defined($ARGV[0])) {
	exit(0);
}
my $filename = $ARGV[0];
open( my $fh, "<", $filename."jobfile.json");
my $job;
{
    local $/;
    my $str = <$fh>;
    $job = decode_json $str;
}
close($fh);
my $obj;
if ($job->{wsurl} eq "impl") {
	require "Bio/KBase/workspaceService/Impl.pm";
	$obj = Bio::KBase::fbaModelServices::Impl->new({accounttype => $job->{accounttype},workspace => Bio::KBase::workspaceService::Impl->new()});
} else {
    $obj = Bio::KBase::fbaModelServices::Impl->new({accounttype => $job->{accounttype},"workspace-url" => $job->{wsurl}});
}
#Clearing out old files
if (-d "/tmp/fbajobs/") {
	&clearOldDirectoryFiles("/tmp/fbajobs/");
}
if (!defined($job->{localjob})) {
	 $obj->run_job({
	    job => $job->{id},
	    auth => $job->{auth}
	 });	
} else {
	$obj->run_job({
		job => $job,
		auth => $job->{jobdata}->{auth}
	});
}

sub clearOldDirectoryFiles {
	my($directory) = @_;
	my $now = time();       # get current time
	my $age = 60*60*24*3;  # convert 3 days into seconds
	my $files = [];
	opendir(DIR,$directory) || die "Can't open $directory : $!\n";
	push(@{$files},readdir(DIR));
	close(DIR);
	foreach my $file (@{$files}) {	
		my @stat = stat($directory."/".$file);
		if ($stat[9] < ($now - $age)) {
			print "Deleting $file...";
			if ($file =~ m/\/fbajobs\//) {
				rmtree($file);
			}
		}
	}
}

1;
