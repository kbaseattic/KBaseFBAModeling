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
use Bio::KBase::workspaceService::Client;

$|=1;
my $config = $ARGV[0];
my $jobid = $ARGV[1];
my $c = Config::Simple->new();
$c->read($config);
open(PID, "> ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/pid") || die "could not open PID file!"; 
print PID "$$\n"; 
close(PID);
my $filename = $c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/jobfile.json";
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
open(LPFILE, "> ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/prob.lp"); 
print LPFILE $job->{jobdata}->{lpfile}; 
close(LPFILE);
open(SCRIPT, "> ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/script"); 
print SCRIPT "set timelimit ".$job->{jobdata}->{timelimit}."\n".
	"set mip tolerances mipgap 0.02\n".
	"set mip tolerances integrality 1e-09\n".
	"set simplex tolerances feasibility 1e-09\n".
	"set feasopt tolerance 1e-09\n".
	"set mip display 0\n".
	"set mip limits treememory ".$job->{jobdata}->{memlimit}."\n".
	"read ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/prob.lp\n".
	"mipopt\n".
	"write ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/solution sol\n".
	"quit\n";
close(SCRIPT);

system("cd ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1].";/vol/model-prod/Software/cplex/cplex/bin/x86-64_sles10_4.1/cplex < ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/script");

open(SOLUTION, "< ".$c->param("scheduler.jobdirectory")."jobs/".$ARGV[1]."/solution"); 
{
    local $/;
    my $str = <$fh>;
    $job->{jobdata}->{solution} = $str;
}
close(SOLUTION);
my $ws = Bio::KBase::workspaceService::Client->new("http://kbase.us/services/workspace");
$ws->set_job_status({
	jobid => $job->{id},
	status => "done",
	auth => $job->{auth},
	currentStatus => "running",
	jobdata => {solution => $job->{jobdata}->{solution}}
});

1;