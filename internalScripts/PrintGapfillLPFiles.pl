#!/usr/bin/perl -w

use strict;
use Config::Simple;
use Bio::KBase::fbaModelServices::Impl;
use File::Path;
$|=1;

my $config = $ARGV[0];
my $directory = $ARGV[1];
my $index = $ARGV[2];
my $count = $ARGV[3];
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
for (my $i=0; $i < 1; $i++) {
#for (my $i=0; $i < @{$models}; $i++) {
	if (($i-$index)%$count == 0) {
		print $i."\n";
		my $form = {
				timePerSolution => 600,
				totalTimeLimit => 600,
				formulation => {
					media => "Carbon-D-Glucose",
					mediaws => "KBaseMedia"
				}
		};
		if (!-e $directory.$models->[$i]->[1].".lp") {
			my $model = $fba->_get_msobject("FBAModel","chenry:BiomassAnalysisMMModels",$models->[$i]->[1]);
			my $biocpds = $model->biomasses()->[0]->biomasscompounds();
			for (my $j=0; $j < @{$biocpds}; $j++) {
				if ($biocpds->[$j]->modelcompound()->compound()->id() eq "cpd11715") {
					$model->biomasses()->[0]->remove("biomasscompounds",$biocpds->[$j]);
				} elsif ($biocpds->[$j]->modelcompound()->compound()->id() eq "cpd11746") {
					$model->biomasses()->[0]->remove("biomasscompounds",$biocpds->[$j]);
				} elsif ($biocpds->[$j]->modelcompound()->compound()->id() eq "cpd09680") {
					$model->biomasses()->[0]->remove("biomasscompounds",$biocpds->[$j]);
				}
			}
			$form->{num_solutions} = 1;
			$form = $fba->_setDefaultGapfillFormulation($form);
			my ($gapfill,$fbaobj) = $fba->_buildGapfillObject($form,$model,"gf.0");
		   	$fbaobj->parameters()->{MFASolver} = "CPLEX";
			$fbaobj->parameters()->{nodelete} = 1;
			$fbaobj->parameters()->{"just print LP file"} = 1;
			$fbaobj->parameters()->{"write LP file"} = 1;
			$fbaobj->parameters()->{"write variable key"} = 1;
			$fbaobj->runFBA();
			system("cp ".$fbaobj->jobDirectory()."/CurrentProblem.lp ".$directory.$models->[$i]->[1].".lp");
			system("cp ".$fbaobj->jobDirectory()."/VariableKey.txt ".$directory.$models->[$i]->[1].".key");
			rmtree($fbaobj->jobDirectory());
		}
	}
}
