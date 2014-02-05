#!/usr/bin/perl -w

########################################################################
# This perl script runs the designated queue for model reconstruction
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 10/6/2009
########################################################################
use strict;
use JSON::XS;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
use LWP::Simple;
use Config::Simple;
use File::Path;
use Bio::KBase::fbaModelServices::Impl;

$|=1;
my $config = $ARGV[0];
my $jobid = $ARGV[1];
my $c = Config::Simple->new();
$c->read($config);
open(PID, "> ".$c->param("scheduler.jobdirectory").$ARGV[1]."/pid") || die "could not open PID file!"; 
print PID "$$\n"; 
close(PID);
my $filename = $c->param("scheduler.jobdirectory").$ARGV[1]."/jobfile.json";
if (!-e $filename) {
	die "Cannot open ".$filename;
}
open( my $fh, "<", $filename);
my $job;
{
    local $/;
    my $str = <$fh>;
    $job = decode_json $str;
}
close($fh);
$Bio::KBase::fbaModelServices::Server::CallContext = {token => $job->{auth}};
$ENV{KB_DEPLOYMENT_CONFIG} = $config;
my $obj = Bio::KBase::fbaModelServices::Impl->new({
	accounttype => $job->{accounttype},
	fbajobcache => $c->param("scheduler.jobdirectory").$ARGV[1]
});
$obj->run_job({
	job => $job->{id},
});
if (-d $c->param("fbaModelServices.fbajobdir")) {
	&clearOldDirectoryFiles($c->param("fbaModelServices.fbajobdir"));
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
			if ($file =~ m/\/fbajobs\/.+/) {
				rmtree($file);
			}
		}
	}
}

1;
