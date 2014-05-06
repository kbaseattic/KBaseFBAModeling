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
my $genomes = $ws->list_objects({
	workspaces => ["pubSEEDGenomes"],
	type => "KBaseGenomes.Genome",#KBaseGenomes.Genome-1.0
});
for (my $i=0; $i < @{$genomes}; $i++) {
	$fba->genome_to_fbamodel({
		genome => $genomes->[$i]->[1],
		workspace => "chenry:BiomassAnalysisMMModels",
    	genome_workspace => "pubSEEDGenomes",
    	model => $genomes->[$i]->[1].".fbamdl",
	});
	my $form = {
			timePerSolution => 10,
			totalTimeLimit => 10,
			formulation => {
				media => "Carbon-D-Glucose",
				mediaws => "KBaseMedia"
			}
	};
	my $model = $fba->_get_msobject("FBAModel","chenry:BiomassAnalysisMMModels",$genomes->[$i]->[1].".fbamdl");
	$form->{num_solutions} = 1;
	$form = $fba->_setDefaultGapfillFormulation($form);
	my ($gapfill,$fbaobj) = $fba->_buildGapfillObject($form,$model,"gf.0");
   	$fbaobj->parameters()->{MFASolver} = "SCIP";
	$fbaobj->parameters()->{nodelete} = 1;
	$fbaobj->runFBA();
	system("cp ".$fbaobj->jobDirectory()."/Problem.lp ".$directory.$genomes->[$i]->[1].".lp");
	rmtree($fbaobj->jobDirectory());
}