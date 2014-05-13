#!/usr/bin/perl -w

use strict;
use Config::Simple;
use Bio::KBase::fbaModelServices::Impl;
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

$Bio::KBase::fbaModelServices::Server::CallContext = {token => $c->param("kbclientconfig.auth")};
my $fba = Bio::KBase::fbaModelServices::Impl->new({"workspace-url" => "http://kbase.us/services/ws"});
$fba->_setContext($Bio::KBase::fbaModelServices::Server::CallContext,{});
my $ws = $fba->_workspaceServices();
my $models = $ws->list_objects({
	workspaces => ["chenry:BiomassAnalysisMMModels"],
});
#for (my $i=0; $i < 1; $i++) {
for (my $i=0; $i < @{$models}; $i++) {
	print $i."\n";
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory.$models->[$i]->[1].".script",[
		"set timelimit 28800",
		"set mip tolerances mipgap 0.02",
		"set mip tolerances integrality 1e-09",
		"set simplex tolerances feasibility 1e-09",
		"set feasopt tolerance 1e-09",
		"set mip display 0",
		"set mip limits treememory 1000",
		"read LPFiles/".$models->[$i]->[1].".lp",
		"mipopt",
		"write LPSolutions/".$models->[$i]->[1].".txt sol"
	]);
}
