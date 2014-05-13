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
my $template = $fba->_get_msobject("ModelTemplate","chenrydemo","FullBiomassTemplate");
$template->calculatePenalties();
my $tbl = Bio::KBase::ObjectAPI::utilities::LOADTABLE($directory."VariableKey.txt",";");
my $lpfile = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."CurrentProblem.lp");
my $column;
my $hash;
for (my $i=0; $i < @{$tbl->{data}}; $i++) {
	$hash->{$tbl->{data}->[$i]->[2]}->{$tbl->{data}->[$i]->[1]} = $tbl->{data}->[$i]->[0];
}
#for (my $i=0; $i < 1; $i++) {
for (my $i=0; $i < @{$models}; $i++) {
	print $i."\n";
	if (!-e $directory.$models->[$i]->[1].".lp") {
		my $model = $fba->_get_msobject("FBAModel","chenry:BiomassAnalysisMMModels",$models->[$i]->[1]);
		my $mdlrxns = $model->modelreactions();
		my $mdlhash;
		for (my $j=0; $j < @{$mdlrxns}; $j++) {
			if ($mdlrxns->[$j]->direction() eq ">" || $mdlrxns->[$j]->direction() eq "=") {
				$mdlhash->{$mdlrxns->[$j]->id()}->{f} = 1;
			}
			if ($mdlrxns->[$j]->direction() eq "<" || $mdlrxns->[$j]->direction() eq "=") {
				$mdlhash->{$mdlrxns->[$j]->id()}->{r} = 1;
			}
		}
		my $tmprxns = $template->templateReactions();
		my $objhash;
		for (my $j=0; $j < @{$tmprxns}; $j++) {
			if (!defined($mdlhash->{$tmprxns->[$j]->reaction()->id()."_".$tmprxns->[$j]->reaction()->compartment()->id()."0"}->{f}) && defined($hash->{$tmprxns->[$j]->reaction()->id()."_".$tmprxns->[$j]->reaction()->compartment()->id()."0"}->{FORWARD_USE})) {
				$objhash->{$hash->{$tmprxns->[$j]->reaction()->id()."_".$tmprxns->[$j]->reaction()->compartment()->id()."0"}->{FORWARD_USE}} = $tmprxns->[$j]->forward_penalty()+$tmprxns->[$j]->base_cost(); 
			}
			if (!defined($mdlhash->{$tmprxns->[$j]->reaction()->id()."_".$tmprxns->[$j]->reaction()->compartment()->id()."0"}->{f}) && defined($hash->{$tmprxns->[$j]->reaction()->id()."_".$tmprxns->[$j]->reaction()->compartment()->id()."0"}->{REVERSE_USE})) {
				$objhash->{$hash->{$tmprxns->[$j]->reaction()->id()."_".$tmprxns->[$j]->reaction()->compartment()->id()."0"}->{REVERSE_USE}} = $tmprxns->[$j]->reverse_penalty()+$tmprxns->[$j]->base_cost(); 
			}
		}
		#Printing new LP
		my $output = [];
		my $inobj = 0;
		for (my $k=0; $k < @{$lpfile}; $k++) {
			push(@{$output},$lpfile->[$k]);
			if ($lpfile->[$k] =~ m/^Minimize/) {
				my $line = " obj: ";
				foreach my $var (keys(%{$objhash})) {
					if (length($line) > 60) {
						push(@{$output},$line);
						$line = "     ";
					}
					if ($line ne " obj: ") {
						$line .= " + ";
					}
					$line .= sprintf("%.4f",abs($objhash->{$var}))." x".$var;
				}
				push(@{$output},$line);
				for (my $j=$k; $j < @{$lpfile}; $j++) {
					if ($lpfile->[$j] =~ m/^Subject\sTo/) {
						$k = $j-1;
					}	
				}
			}
		}
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory.$models->[$i]->[1].".lp",$output);
	}
}
