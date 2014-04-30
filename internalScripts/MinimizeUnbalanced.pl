#!/usr/bin/perl -w

use strict;
use Config::Simple;
use Bio::KBase::fbaModelServices::Impl;
$|=1;

my $config = $ARGV[0];
my $object = $ARGV[1];
my $filename = $ARGV[2];

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

my $bio = $fba->_get_msobject("Biochemistry","kbase","default");
my $reactions = $bio->reactions();

my $list;
my $model = $fba->_get_msobject("FBAModel","chenrydemo","kb|g.3051.fbamdl");
foreach my $rxn (@{$reactions}) {
	my $mdlrxn = $model->searchForReaction($rxn->id(),"c",0);
	if (!defined($mdlrxn) && $rxn->id() =~ m/rxn\d+/) {
		print "Adding:".$rxn->id()."\n";
		$model->addReactionToModel({
			reaction => $rxn,
			direction => "=",
		});
		push(@{$list},$rxn->id()."_c0");
	}
}

$fba->minimize_reactions({
	model => "fbamdl.biomass",
	workspace => "chenrydemo",
	model_workspace => "chenrydemo",
	formulation => {
		media => "Carbon-D-Glucose",
		media_workspace => "KBaseMedia"
	},
	reactions => $list,
	all_model_reactions => 0,
	reaction_costs => {},
	output_id => "UnbalancedRxnMinimization",
	solver => "cplex"
});
