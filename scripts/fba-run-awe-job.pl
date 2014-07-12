#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw( get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws printJobData get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Queue command","Input file","Output file"];
my $script = "fba-run-awe-job";
my $translation = {
	overrideauth => "overrideauth"
};
my $specs = [
	[ 'overrideauth|o', 'Use current auth key for job instead of job auth key' ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$opt->{showerror} = 1;
open( my $fh, "<", $opt->{"Input file"});
my $parameters;
{
    local $/;
    my $str = <$fh>;
    $parameters = decode_json $str;
}
close($fh);

#Calling the server
my $output = runFBACommand($parameters,$opt->{"Queue command"},$opt);
#Checking output and report results
if (!defined($output)) {
	die("Job run failed!");
} else {
	print "Successfully ran job:\n";
	$output = $JSON->encode($output);
	open(OUTPUT, "> ".$opt->{"Output file"}) || die "could not open output file!"; 
	print OUTPUT $output; 
	close(OUTPUT);
}
