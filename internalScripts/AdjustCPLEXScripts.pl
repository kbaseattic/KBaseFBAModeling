#!/usr/bin/perl -w

use strict;
use Config::Simple;
use Bio::KBase::workspaceService::Client;
use Bio::KBase::workspace::Client;
use File::Path;
$|=1;

my $config = $ARGV[0];
my $directory = $ARGV[1];
if (!defined($config)) {
	print STDERR "No config file provided!\n";
	exit(-1);
}
if (!-e $config) {
	print STDERR "Config file ".$config." not found!\n";
	exit(-1);
}

my $c = Config::Simple->new();
$c->read($config);

my $ws = Bio::KBase::workspace::Client->new("http://kbase.us/services/ws");
my $js = Bio::KBase::workspaceService::Client->new("http://kbase.us/services/workspace");
my $models = $ws->list_objects({
	workspaces => ["chenry:BiomassAnalysisMMModels"],
});
#for (my $i=0; $i < 1; $i++) {
for (my $i=1; $i < @{$models}; $i++) {
	open(LPFILE, "< /homes/chenry/lpfiles/LPFiles/".$models->[$i]->[1].".lp"); 
	my $sting;
	{
	    local $/;
	    $sting = <LPFILE>;
		
	}
	close(LPFILE);
	my $input = {
		type => "Optimization",
		jobdata => {
			memlimit => 8000,
			timelimit => 28800,
			lpfile => $sting,
		},
		queuecommand => "Optimization",
		"state" => "queued",
		auth => $c->param("kbclientconfig.auth"),
		wsurl => "http://kbase.us/services/ws"
	};
	$js->queue_job($input);
}