########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::FBA - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::FBA;
package Bio::KBase::ObjectAPI::KBaseFBA::FBA;
use Moose;
use ModelSEED::Exceptions;
use Bio::KBase::ObjectAPI::utilities;

use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::FBA';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has jobID => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobid' );
has jobPath => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobpath' );
has jobDirectory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobdirectory' );
has command => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, default => '' );
has mfatoolkitBinary => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmfatoolkitBinary' );
has mfatoolkitDirectory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmfatoolkitDirectory' );
has dataDirectory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddataDirectory' );
has cplexLicense => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcplexLicense' );
has readableObjective => ( is => 'rw', isa => 'Str',printOrder => '30', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreadableObjective' );
has mediaID => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmediaID' );
has knockouts => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildknockouts' );
has promBounds => ( is => 'rw', isa => 'HashRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildpromBounds' );
has additionalCompoundString => ( is => 'rw', isa => 'Str',printOrder => '4', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildadditionalCompoundString' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildjobid {
	my ($self) = @_;
	my $path = $self->jobPath();
	my $fulldir = File::Temp::tempdir(DIR => $path);
	if (!-d $fulldir) {
		File::Path::mkpath ($fulldir);
	}
	my $jobid = substr($fulldir,length($path."/"));
	return $jobid
}

sub _buildjobpath {
	my ($self) = @_;
	my $path = $self->dataDirectory()."fbajobs";
	if (!-d $path) {
		File::Path::mkpath ($path);
	}
	return $path;
}

sub _buildjobdirectory {
	my ($self) = @_;
	return $self->jobPath()."/".$self->jobID();
}

sub _buildmfatoolkitBinary {
	my ($self) = @_;
	my $config = Bio::KBase::ObjectAPI::utilities::config();
	my $bin;
	if (defined($config->MFATK_BIN()) && length($config->MFATK_BIN()) > 0) {
		$bin = $config->MFATK_BIN();
	} else {
		if ($^O =~ m/^MSWin/) {
			$bin = Bio::KBase::ObjectAPI::utilities::MODELSEEDCORE()."/software/mfatoolkit/bin/mfatoolkit";
			$bin .= ".exe";
		} elsif (-e "/bin/mfatoolkit") {
			$bin = "/bin/mfatoolkit";
		} else {
			$bin = `which mfatoolkit 2>/dev/null`;
			chomp $bin;
		}
	}
	if ((! defined $bin) || (!-e $bin)) {
        ModelSEED::Exception::MissingConfig->throw(
            variable => 'MFATK_BIN',
            message => <<ND
This is the path to the mfatoolkit binary. If it is not already
installed, this program can be downloaded from:
https://github.com/modelseed/mfatoolkit
Add the binary directory to your path or use the following command:
ND
        );
	}
	return $bin;
}

sub _buildmfatoolkitDirectory {
	my ($self) = @_;
	my $bin = $self->mfatoolkitBinary();
	if ($bin =~ m/^(.+\/)[^\/]+$/) {
		return $1;
	}
	return "";
}

sub _builddataDirectory {
	my ($self) = @_;
	my $config = ModelSEED::Configuration->new();
	if (defined($config->user_options()->{MFATK_CACHE})) {
		return $config->user_options()->{MFATK_CACHE}."/";
	}
	return Bio::KBase::ObjectAPI::utilities::MODELSEEDCORE()."/data/";
}

sub _buildcplexLicense {
	my ($self) = @_;
	my $config = ModelSEED::Configuration->new();
	if (defined($config->user_options()->{CPLEX_LICENCE})) {
		return $config->user_options()->{CPLEX_LICENCE};
	}
	return "";
}

sub _buildreadableObjective {
	my ($self) = @_;
	my $string = "Max { ";
	if ($self->maximizeObjective() == 0) {
		$string = "Min { ";
	}
	my $terms = $self->fbaObjectiveTerms();
	for (my $i=0; $i < @{$terms}; $i++) {
		my $term = $terms->[$i];
		if ($i > 0) {
			$string .= " + ";
		}
		my $coef = "";
		if ($term->coefficient() != 1) {
			$coef = "(".$term->coefficient().") ";
		}
		$string .= $coef.$term->entity()->id();
	}
	$string .= " }";
	return $string;
}
sub _buildmediaID {
	my ($self) = @_;
	return $self->media()->id();
}
sub _buildknockouts {
	my ($self) = @_;
	my $string = "";
	my $genekos = $self->geneKOs();
	for (my $i=0; $i < @{$genekos}; $i++) {
		if ($i > 0) {
			$string .= ", ";
		}
		$string .= $genekos->[$i]->id();
	}
	my $rxnstr = "";
	my $rxnkos = $self->reactionKOs();
	for (my $i=0; $i < @{$rxnkos}; $i++) {
		if ($i > 0) {
			$rxnstr .= ", ";
		}
		$rxnstr .= $rxnkos->[$i]->id();
	}
	if (length($string) > 0 && length($rxnstr) > 0) {
		return $string.", ".$rxnstr;
	}
	return $string.$rxnstr;
}
sub _buildpromBounds {
	my ($self) = @_;
	my $bounds = {};
	my $final_bounds = {};
	my $clone = $self->cloneObject();
	$clone->parent($self->parent());
	$clone->promModel_uuid("");
	$clone->fva(1);
	my $results = $clone->runFBA();
	my $fluxes = $results->fbaReactionVariables();
	for (my $i=0; $i < @{$fluxes}; $i++) {
		my $flux = $fluxes->[$i];
		$bounds->{$flux->modelreaction()->reaction()->id()}->[0] = $flux->min();
		$bounds->{$flux->modelreaction()->reaction()->id()}->[1] = $flux->max();
	}
	my $mdlrxns = $self->model()->modelreactions();
	my $geneReactions = {};
	foreach my $mdlrxn (@{$mdlrxns}) {
		foreach my $prot (@{$mdlrxn->modelReactionProteins()}) {
			foreach my $subunit (@{$prot->modelReactionProteinSubunits()}) {
				foreach my $feature (@{$subunit->modelReactionProteinSubunitGenes()}) {
					$geneReactions->{$feature->feature()->id()}->{$mdlrxn->reaction()->id()} = 1;
				}
			}				
		} 
	}
	my $promModel = $self->promModel();
	my $genekos = $self->geneKOs();
	foreach my $gene (@{$genekos}) {
		my $tfmap = $promModel->queryObject("transcriptionFactorMaps",{
			transcriptionFactor_uuid => $gene->uuid()
		});
		if (defined($tfmap)) {
			my $targets = $tfmap->transcriptionFactorMapTargets();
			foreach my $target (@{$targets}) {
				my $offProb = $target->tfOffProbability();
				my $onProb = $target->tfOnProbability();
				my $targetRxns = [keys(%{$geneReactions->{$target->target()->id()}})];
				foreach my $rxn (@{$targetRxns}) {
					my $bounds = $bounds->{$rxn};
					$bounds->[0] *= $offProb;
					$bounds->[1] *= $offProb;
					$final_bounds->{$rxn}->[0] = $bounds->[0];
					$final_bounds->{$rxn}->[1] = $bounds->[1];
				}
			}
		}
	}	

	return $final_bounds;
}
sub _buildadditionalCompoundString {
	my ($self) = @_;
	my $output = "";
	my $addCpds = $self->additionalCpds();
	for (my $i=0; $i < @{$addCpds}; $i++) {
		if (length($output) > 0) {
			$output .= ";";
		}
		$output .= $addCpds->[$i]->name();
	}
	return $output;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************

=head3 biochemistry

Definition:
	Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry = biochemistry();
Description:
	Returns biochemistry behind gapfilling object

=cut

sub biochemistry {
	my ($self) = @_;
	$self->model()->biochemistry();	
}

=head3 annotation

Definition:
	Bio::KBase::ObjectAPI::Annotation = annotation();
Description:
	Returns annotation behind gapfilling object

=cut

sub annotation {
	my ($self) = @_;
	$self->model()->annotation();	
}

=head3 mapping

Definition:
	Bio::KBase::ObjectAPI::KBaseOntology::Mapping = mapping();
Description:
	Returns mapping behind gapfilling object

=cut

sub mapping {
	my ($self) = @_;
	$self->model()->mapping();	
}

=head3 runFBA

Definition:
	Bio::KBase::ObjectAPI::FBAResults = Bio::KBase::ObjectAPI::FBAFormulation->runFBA();
Description:
	Runs the FBA study described by the fomulation and returns a typed object with the results

=cut

sub runFBA {
	my ($self) = @_;
	if (!-e $self->jobDirectory()."/runMFAToolkit.sh") {
		$self->createJobDirectory();
	}
	system($self->command());
	my $fbaresults = $self->add("fbaResults",{});
	$fbaresults->loadMFAToolkitResults();
	return $fbaresults;
}

=head3 createJobDirectory

Definition:
	void Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->createJobDirectory();
Description:
	Creates the MFAtoolkit job directory

=cut

sub createJobDirectory {
	my ($self) = @_;
	my $directory = $self->jobDirectory()."/";
	File::Path::mkpath ($directory."reaction");
	File::Path::mkpath ($directory."MFAOutput/RawData/");
	my $translation = {
		drainflux => "DRAIN_FLUX",
		flux => "FLUX",
		biomassflux => "FLUX"
	};
	#Print model to Model.tbl
	my $model = $self->model();
	my $BioCpd = ["abbrev	charge	deltaG	deltaGErr	formula	id	mass	name"];
	my $mdlcpd = $model->modelcompounds();
	my $cpdhash = {};
	for (my $i=0; $i < @{$mdlcpd}; $i++) {
		my $cpd = $mdlcpd->[$i];
		my $index = $cpd->modelcompartment()->compartmentIndex();
		if (!defined($cpdhash->{$cpd->compound()->id()."_".$index})) {
			my $line = "";
			$cpdhash->{$cpd->compound()->id()."_".$index} = 1;
			my $cols = ["abbreviation","defaultCharge","deltaG","deltaGErr","formula","id","mass","name"];
			for (my $j=0; $j < @{$cols}; $j++) {
				my $function = $cols->[$j];
				if ($j > 0) {
					$line .= "\t";
				}
				if (defined($cpd->compound()->$function())) {	
					$line .= $cpd->compound()->$function();
					if ($index > 0 && $function =~ m/(name)|(id)|(abbreviation)/) {
						$line .= "_".$index;
					}
				}
			}
			push(@{$BioCpd},$line);
		}
	}
	my $rxnhash = {};
	my $BioRxn = ["abbrev	deltaG	deltaGErr	equation	id	name	reversibility	status	thermoReversibility"];
	my $mdlData = ["REACTIONS","LOAD;DIRECTIONALITY;COMPARTMENT;ASSOCIATED PEG"];
	my $mdlrxn = $model->modelreactions();
	for (my $i=0; $i < @{$mdlrxn}; $i++) {
		my $rxn = $mdlrxn->[$i];
		my $direction = $rxn->direction();
		my $rxndir = "<=>";
		if ($direction eq ">") {
			$rxndir = "=>";
		} elsif ($direction eq "<") {
			$rxndir = "<=";
		}
		my $id = $rxn->reaction()->id();
		my $name = $rxn->reaction()->name();
		my $index = $rxn->modelcompartment()->compartmentIndex();	
		if ($index != 0) {
			$id .= "_".$index;
			$name .= "_".$index;
		}
		my $line = $id.";".$rxndir.";".$rxn->modelcompartment()->compartment()->id().";".$rxn->gprString();
		$line =~ s/kb\|g\.\d+\.//g;
		$line =~ s/fig\|\d+\.\d+\.//g;
		push(@{$mdlData},$line);
		if (!defined($rxnhash->{$id})) {
			$rxnhash->{$id} = 1;
			my $reactants = "";
			my $products = "";
			my $rgts = $rxn->modelReactionReagents();
			for (my $j=0;$j < @{$rgts}; $j++) {
				my $rgt = $rgts->[$j];
				if ($rgt->coefficient() < 0) {
					my $suffix = "";
					if ($rgt->modelcompound()->modelcompartment()->compartmentIndex() != 0) {
						$suffix .= "_".$rgt->modelcompound()->modelcompartment()->compartmentIndex();
					}
					$suffix .= "[".$rgt->modelcompound()->modelcompartment()->compartment()->id()."]";
					if (length($reactants) > 0) {
						$reactants .= " + ";
					}
					$reactants .= "(".(-1*$rgt->coefficient()).") ".$rgt->modelcompound()->compound()->id().$suffix;
				}
			}
			for (my $j=0;$j < @{$rgts}; $j++) {
				my $rgt = $rgts->[$j];
				if ($rgt->coefficient() > 0) {
					my $suffix = "";
					if ($rgt->modelcompound()->modelcompartment()->compartmentIndex() != 0) {
						$suffix .= "_".$rgt->modelcompound()->modelcompartment()->compartmentIndex();
					}
					$suffix .= "[".$rgt->modelcompound()->modelcompartment()->compartment()->id()."]";
					if (length($products) > 0) {
						$products .= " + ";
					}
					$products .= "(".$rgt->coefficient().") ".$rgt->modelcompound()->compound()->id().$suffix;
				}
			}
			my $equation = $reactants." ".$rxndir." ".$products;
			my $cols = ["abbreviation","deltaG","deltaGErr","equation","id","name","direction","status","direction"];
			my $rxnline = "";
			for (my $j=0; $j < @{$cols}; $j++) {
				my $function = $cols->[$j];
				if ($j > 0) {
					$rxnline .= "\t";
				}
				if ($function eq "direction") {
					$rxnline .= $direction;
				} elsif ($function eq "equation") {
					$rxnline .= $equation;
				} elsif ($function eq "id") {
					$rxnline .= $id;
				} elsif ($function eq "name") {
					$rxnline .= $name;
				} elsif (defined($rxn->reaction()->$function())) {
					$rxnline .= $rxn->reaction()->$function();
				}
			}
			push(@{$BioRxn},$rxnline);
		}
	}
	if (defined($self->parameters()->{"Complete gap filling"}) && $self->parameters()->{"Complete gap filling"} == 1) {
		$mdlcpd = $model->biochemistry()->compounds();
		for (my $i=0; $i < @{$mdlcpd}; $i++) {
			my $cpd = $mdlcpd->[$i];
			if (!defined($cpdhash->{$cpd->id()."_0"})) {
				my $line = "";
				my $cols = ["abbreviation","defaultCharge","deltaG","deltaGErr","formula","id","mass","name"];
				$cpdhash->{$cpd->id()."_0"} = 1;
				for (my $j=0; $j < @{$cols}; $j++) {
					my $function = $cols->[$j];
					if ($j > 0) {
						$line .= "\t";
					}
					if (defined($cpd->$function())) {
						$line .= $cpd->$function();
					}
				}
				push(@{$BioCpd},$line);
			}
		}
		my $mdlrxn = $model->biochemistry()->reactions();
		for (my $i=0; $i < @{$mdlrxn}; $i++) {
			my $rxn = $mdlrxn->[$i];
			if (!defined($rxnhash->{$rxn->id()})) {
				my $line = "";
				$rxnhash->{$rxn->id()} = 1;
				my $reactants = "";
				my $products = "";
				my $rgts = $rxn->reagents();
				for (my $j=0;$j < @{$rgts}; $j++) {
					my $rgt = $rgts->[$j];
					if ($rgt->coefficient() < 0) {
						my $suffix = "[".$rgt->compartment()->id()."]";
						if (length($reactants) > 0) {
							$reactants .= " + ";
						}
						$reactants .= "(".(-1*$rgt->coefficient()).") ".$rgt->compound()->id().$suffix;
					}
				}
				for (my $j=0;$j < @{$rgts}; $j++) {
					my $rgt = $rgts->[$j];
					if ($rgt->coefficient() > 0) {
						my $suffix = "";
						$suffix .= "[".$rgt->compartment()->id()."]";
						if (length($products) > 0) {
							$products .= " + ";
						}
						$products .= "(".$rgt->coefficient().") ".$rgt->compound()->id().$suffix;
					}
				}
				my $direction = $rxn->thermoReversibility();
				if (!defined($direction)) {
					$direction = "=";
				}
				my $rxndir = "<=>";
				if ($direction eq ">") {
					$rxndir = "=>";
				} elsif ($direction eq "<") {
					$rxndir = "<=";
				}
				my $equation = $reactants." ".$rxndir." ".$products;
				my $cols = ["abbreviation","deltaG","deltaGErr","equation","id","name","direction","status","direction"];
				my $rxnline = "";
				for (my $j=0; $j < @{$cols}; $j++) {
					my $function = $cols->[$j];
					if ($j > 0) {
						$rxnline .= "\t";
					}
					if ($function eq "direction") {
						$rxnline .= $direction;
					} elsif ($function eq "equation") {
						$rxnline .= $equation;
					} elsif (defined($rxn->$function())) {
						$rxnline .= $rxn->$function();
					}
				}
				push(@{$BioRxn},$rxnline);
			}
		}
	}
	my $biomasses = $model->biomasses();
	for (my $i=0; $i < @{$biomasses}; $i++) {
		my $bio = $biomasses->[$i];
		push(@{$mdlData},$bio->id().";=>;c;UNIVERSAL");
		my $reactants = "";
		my $products = "";
		my $rgts = $bio->biomasscompounds();
		for (my $j=0;$j < @{$rgts}; $j++) {
			my $rgt = $rgts->[$j];
			if ($rgt->coefficient() < 0) {
				my $suffix = "";
				if ($rgt->modelcompound()->modelcompartment()->compartmentIndex() != 0) {
					$suffix .= "_".$rgt->modelcompound()->modelcompartment()->compartmentIndex();
				}
				$suffix .= "[".$rgt->modelcompound()->modelcompartment()->compartment()->id()."]";
				if (length($reactants) > 0) {
					$reactants .= " + ";
				}
				$reactants .= "(".(-1*$rgt->coefficient()).") ".$rgt->modelcompound()->compound()->id().$suffix;
			}
		}
		for (my $j=0;$j < @{$rgts}; $j++) {
			my $rgt = $rgts->[$j];
			if ($rgt->coefficient() > 0) {
				my $suffix = "";
				if ($rgt->modelcompound()->modelcompartment()->compartmentIndex() != 0) {
					$suffix .= "_".$rgt->modelcompound()->modelcompartment()->compartmentIndex();
				}
				$suffix .= "[".$rgt->modelcompound()->modelcompartment()->compartment()->id()."]";
				if (length($products) > 0) {
					$products .= " + ";
				}
				$products .= "(".$rgt->coefficient().") ".$rgt->modelcompound()->compound()->id().$suffix;
			}
		}
		my $equation = $reactants." => ".$products;
		my $rxnline = $bio->id()."\t0\t0\t".$equation."\t".$bio->id()."\t".$bio->id()."\t>\tOK\t>";
		push(@{$BioRxn},$rxnline);
	}
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."Compounds.tbl",$BioCpd);
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."Reactions.tbl",$BioRxn);
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."Model.tbl",$mdlData);
	#Printing additional input files specified in formulation
	my $inputfileHash = $self->inputfiles();
	foreach my $filename (keys(%{$inputfileHash})) {
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory.$filename,$inputfileHash->{$filename});
	}
	#Setting drain max based on media
	my $primMedia = $self->media();
	if ($primMedia->name() eq "Complete") {
		if ($self->defaultMaxDrainFlux() <= 0) {
			$self->defaultMaxDrainFlux($self->defaultMaxFlux());
		}
	}
	my $addnlCpds = $self->additionalCpds();
	if (@{$addnlCpds} > 0) {
		my $newPrimMedia = $primMedia->cloneObject();
		$newPrimMedia->parent($primMedia->parent());
		$newPrimMedia->name("TempPrimaryMedia");
		$newPrimMedia->id("TempPrimaryMedia");
		my $mediaCpds = $newPrimMedia->mediacompounds();
		for (my $i=0; $i < @{$addnlCpds}; $i++) {
			my $found = 0;
			for (my $j=0; $j < @{$mediaCpds}; $j++) {
				if ($mediaCpds->[$j]->compound_uuid() eq $addnlCpds->[$i]->uuid()) {
					$mediaCpds->[$j]->maxFlux() = 100;
				}
			}
			if ($found == 0) {
				$newPrimMedia->add("mediacompounds",{compound_uuid => $addnlCpds->[$i]->uuid()});
			}
		}
		$primMedia = $newPrimMedia;
	}
	#Selecting the solver based on whether the problem is MILP
	my $solver = "GLPK";
	if ($self->fluxUseVariables() == 1 || $self->drainfluxUseVariables() == 1 || $self->findMinimalMedia()) {
		if (-e $self->cplexLicense()) {
			$solver = "CPLEX";
		} else {
			$solver = "SCIP";
		}
	}
	#Setting gene KO
	my $geneKO = "none";
	for (my $i=0; $i < @{$self->geneKOs()}; $i++) {
		my $gene = $self->geneKOs()->[$i];
		if ($i == 0) {
			$geneKO = $gene->id();	
		} else {
			$geneKO .= ";".$gene->id();
		}
	}
	$geneKO =~ s/kb\|g\.\d+\.//g;
	$geneKO =~ s/fig\|\d+\.\d+\.//g;
	#Setting reaction KO
	my $rxnKO = "none";
	for (my $i=0; $i < @{$self->reactionKOs()}; $i++) {
		my $rxn = $self->reactionKOs()->[$i];
		if ($i == 0) {
			$rxnKO = $rxn->id();	
		} else {
			$rxnKO .= ";".$rxn->id();
		}
	}
	#Setting exchange species
	my $exchange = "Biomass[c]:-10000:0;cpd02701[c]:-10000:0";
	#TODO
	#Setting the objective
	my $objective = "MAX";
	my $metToOpt = "REACTANTS;bio1";
	my $optMetabolite = 1;
	if ($self->fva() == 1 || $self->comboDeletions() > 0) {
		$optMetabolite = 0;
	}
	if ($self->maximizeObjective() == 0) {
		$objective = "MIN";
		$optMetabolite = 0;
	}
	my $objterms = $self->fbaObjectiveTerms();
	for (my $i=0; $i < @{$objterms}; $i++) {
		my $objterm = $objterms->[$i];
		my $objVarName = "";
		my $objVarComp = "none";
		if (lc($objterm->entityType()) eq "compound") {
			my $entity = $model->getObject("modelcompounds",$objterm->entity_uuid());
			if (defined($entity)) {
				$objVarName = $entity->compound()->id();
				$objVarComp = $entity->modelcompartment()->label();
			}
			$optMetabolite = 0;
		} elsif (lc($objterm->entityType()) eq "reaction") {
			my $entity = $model->getObject("modelreactions",$objterm->entity_uuid());
			if (defined($entity)) {
				$objVarName = $entity->reaction()->id();
				$objVarComp = $entity->modelcompartment()->label();
				$metToOpt = "REACTANTS;".$entity->reaction()->id();
			}
		} elsif (lc($objterm->entityType()) eq "biomass") {
			my $entity = $model->getObject("biomasses",$objterm->entity_uuid());
			if (defined($entity)) {
				$objVarName = $entity->id();
				$objVarComp = "none";
				$metToOpt = "REACTANTS;".$entity->id();
			}
		}
		if (length($objVarName) > 0) {
			$objective .= ";".$translation->{$objterm->variableType()}.";".$objVarName.";".$objVarComp.";".$objterm->coefficient();
		}
	}
	if (@{$objterms} > 1) {
		$optMetabolite = 0;	
	}
	#Setting up uptake limits
	my $uptakeLimits = "none";
	foreach my $atom (keys(%{$self->uptakeLimits()})) {
		if ($uptakeLimits eq "none") {
			$uptakeLimits = $atom.":".$self->uptakeLimits()->{$atom};
		} else {
			$uptakeLimits .= ";".$atom.":".$self->uptakeLimits()->{$atom};
		}
	}
	my $comboDeletions = $self->comboDeletions();
	if ($comboDeletions == 0) {
		$comboDeletions = "none";
	}
	#Creating FBA experiment file
	my $fbaExpFile = $self->setupFBAExperiments();
	if ($fbaExpFile ne "none") {
		$optMetabolite = 0;
	}
	#Setting parameters
	my $parameters = {
		"perform MFA" => 1,
		"Default min drain flux" => $self->defaultMinDrainFlux(),
		"Default max drain flux" => $self->defaultMaxDrainFlux(),
		"Max flux" => $self->defaultMaxFlux(),
		"Min flux" => -1*$self->defaultMaxFlux(),
		"user bounds filename" => $primMedia->name(),
		"create file on completion" => "FBAComplete.txt",
		"Reactions to knockout" => $rxnKO,
		"Genes to knockout" => $geneKO,
		"output folder" => $self->jobID()."/",
		"use database fields" => 1,
		"MFASolver" => $solver,
		"exchange species" => $exchange,
		"database spec file" => $directory."StringDBFile.txt",
		"Reactions use variables" => $self->fluxUseVariables(),
		"Force use variables for all reactions" => 1,
		"Add use variables for any drain fluxes" => $self->drainfluxUseVariables(),
		"Decompose reversible reactions" => $self->decomposeReversibleFlux(),
		"Decompose reversible drain fluxes" => $self->decomposeReversibleDrainFlux(),
		"Make all reactions reversible in MFA" => $self->allReversible(),
		"Constrain objective to this fraction of the optimal value" => $self->objectiveConstraintFraction(),
		"objective" => $objective,
		"find tight bounds" => $self->fva(),
		"Combinatorial deletions" => $comboDeletions,
		"flux minimization" => $self->fluxMinimization(), 
		"uptake limits" => $uptakeLimits,
		"optimize metabolite production if objective is zero" => $optMetabolite,
		"metabolites to optimize" => $metToOpt,
		"FBA experiment file" => $fbaExpFile,
		"determine minimal required media" => $self->findMinimalMedia(),
		"Recursive MILP solution limit" => $self->numberOfSolutions(),
		"database root output directory" => $self->jobPath()."/",
		"database root input directory" => $self->jobDirectory()."/",
	};
	if (defined($self->promModel_uuid()) && length($self->promModel_uuid()) > 0) {
		my $softConst = $self->PROMKappa();
		my $bounds = $self->promBounds();
		foreach my $key (keys(%{$bounds})) {
			$softConst .= ";".$key.":".$bounds->{$key}->[0].":".$bounds->{$key}->[1];
		}
		$parameters->{"Soft Constraint"} = $softConst;
	}
	if ($solver eq "SCIP") {
		$parameters->{"use simple variable and constraint names"} = 1;
	}
	if ($^O =~ m/^MSWin/) {
		$parameters->{"scip executable"} = "scip.exe";
		$parameters->{"perl directory"} = "C:/Perl/bin/perl.exe";
		$parameters->{"os"} = "windows";
	} else {
		$parameters->{"scip executable"} = "scip";
		$parameters->{"perl directory"} = "/usr/bin/perl";
		$parameters->{"os"} = "linux";
	}
	#Setting thermodynamic constraints
	if ($self->thermodynamicConstraints() eq "none") {
		$parameters->{"Thermodynamic constraints"} = 0;
	} elsif ($self->thermodynamicConstraints() eq "simple") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"simple thermo constraints"} = 1;
	} elsif ($self->thermodynamicConstraints() eq "error") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"Account for error in delta G"} = 1;
		$parameters->{"minimize deltaG error"} = 0;
	} elsif ($self->thermodynamicConstraints() eq "noerror") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"Account for error in delta G"} = 0;
		$parameters->{"minimize deltaG error"} = 0;
	} elsif ($self->thermodynamicConstraints() eq "minerror") {
		$parameters->{"Thermodynamic constraints"} = 1;
		$parameters->{"Account for error in delta G"} = 1;
		$parameters->{"minimize deltaG error"} = 1;
	}
	#Setting overide parameters
	foreach my $param (keys(%{$self->parameters()})) {
		$parameters->{$param} = $self->parameters()->{$param};
	}
	#Printing parameter file
	my $paramData = [];
	foreach my $param (keys(%{$parameters})) {
		push(@{$paramData},$param."|".$parameters->{$param}."|Specialized parameters");
	}
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."SpecializedParameters.txt",$paramData);
	#Printing specialized bounds
	my $medialist = [$primMedia];
	push(@{$medialist},@{$self->secondaryMedia()});
	my $mediaData = ["ID\tNAMES\tVARIABLES\tTYPES\tMAX\tMIN\tCOMPARTMENTS"];
	my $cpdbnds = $self->fbaCompoundBounds();
	my $rxnbnds = $self->fbaReactionBounds();
	foreach my $media (@{$medialist}) {
		my $userBounds = {};
		my $mediaCpds = $media->mediacompounds();
		for (my $i=0; $i < @{$mediaCpds}; $i++) {
			if (defined($self->parameters()->{"Complete gap filling"}) && $self->parameters()->{"Complete gap filling"} == 1) {
				$userBounds->{$mediaCpds->[$i]->compound()->id()}->{"e"}->{"DRAIN_FLUX"} = {
					max => 10000,
					min => -10000
				};
			} else {
				$userBounds->{$mediaCpds->[$i]->compound()->id()}->{"e"}->{"DRAIN_FLUX"} = {
					max => $mediaCpds->[$i]->maxFlux(),
					min => $mediaCpds->[$i]->minFlux()
				};
			}
		}
		for (my $i=0; $i < @{$cpdbnds}; $i++) {
			if (defined($self->parameters()->{"Complete gap filling"}) && $self->parameters()->{"Complete gap filling"} == 1) {
				$userBounds->{$cpdbnds->[$i]->compound()->id()}->{$cpdbnds->[$i]->modelcompartment()->label()}->{$translation->{$cpdbnds->[$i]->variableType()}} = {
					max => 10000,
					min => -10000
				};
			} else {
				$userBounds->{$cpdbnds->[$i]->compound()->id()}->{$cpdbnds->[$i]->modelcompartment()->label()}->{$translation->{$cpdbnds->[$i]->variableType()}} = {
					max => $cpdbnds->[$i]->upperBound(),
					min => $cpdbnds->[$i]->lowerBound()
				};
			}
		}
		for (my $i=0; $i < @{$rxnbnds}; $i++) {
			if (defined($self->parameters()->{"Complete gap filling"}) && $self->parameters()->{"Complete gap filling"} == 1) {
				$userBounds->{$rxnbnds->[$i]->reaction()->id()}->{$rxnbnds->[$i]->modelcompartment()->label()}->{$translation->{$rxnbnds->[$i]->variableType()}} = {
					max => 10000,
					min => -10000
				};
			} else {
				$userBounds->{$rxnbnds->[$i]->reaction()->id()}->{$rxnbnds->[$i]->modelcompartment()->label()}->{$translation->{$rxnbnds->[$i]->variableType()}} = {
					max => $rxnbnds->[$i]->upperBound(),
					min => $rxnbnds->[$i]->lowerBound()
				};
			}
		}
		my $dataArrays;
		foreach my $var (keys(%{$userBounds})) {
			foreach my $comp (keys(%{$userBounds->{$var}})) {
				foreach my $type (keys(%{$userBounds->{$var}->{$comp}})) {
					push(@{$dataArrays->{var}},$var);
					push(@{$dataArrays->{type}},$type);
					push(@{$dataArrays->{min}},$userBounds->{$var}->{$comp}->{$type}->{min});
					push(@{$dataArrays->{max}},$userBounds->{$var}->{$comp}->{$type}->{max});
					push(@{$dataArrays->{comp}},$comp);
				}
			}
		}
		my $newLine = $media->name()."\t".$media->name()."\t";
		if (defined($dataArrays->{var}) && @{$dataArrays->{var}} > 0) {
			$newLine .= 
				join("|",@{$dataArrays->{var}})."\t".
				join("|",@{$dataArrays->{type}})."\t".
				join("|",@{$dataArrays->{max}})."\t".
				join("|",@{$dataArrays->{min}})."\t".
				join("|",@{$dataArrays->{comp}});
		} else {
			$newLine .= "\t\t\t\t";
		}
		push(@{$mediaData},$newLine);
	}
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."media.tbl",$mediaData);
	#Set StringDBFile.txt
	my $mfatkdir = $self->mfatoolkitDirectory();
	my $dataDir = $self->dataDirectory();
	my $biochemid = $model->biochemistry()->uuid();
    $biochemid =~ s/\//_/g;
	my $stringdb = [
		"Name\tID attribute\tType\tPath\tFilename\tDelimiter\tItem delimiter\tIndexed columns",
		"compound\tid\tSINGLEFILE\t\t".$directory."Compounds.tbl\tTAB\tSC\tid",
		"reaction\tid\tSINGLEFILE\t".$directory."reaction/\t".$directory."Reactions.tbl\tTAB\t|\tid",
		"cue\tNAME\tSINGLEFILE\t\t".$mfatkdir."../etc/MFAToolkit/cueTable.txt\tTAB\t|\tNAME",
		"media\tID\tSINGLEFILE\t".$dataDir."ReactionDB/Media/\t".$directory."media.tbl\tTAB\t|\tID;NAMES"		
	];
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."StringDBFile.txt",$stringdb);
	#Write shell script
	my $exec = [
		$self->mfatoolkitBinary().' resetparameter "MFA input directory" "'.$dataDir.'ReactionDB/" parameterfile "'.$directory.'SpecializedParameters.txt" LoadCentralSystem "'.$directory.'Model.tbl" > "'.$directory.'log.txt"'
	];
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($directory."runMFAToolkit.sh",$exec);
	chmod 0775,$directory."runMFAToolkit.sh";
	$self->command($self->mfatoolkitBinary().' parameterfile "'.$directory.'SpecializedParameters.txt" LoadCentralSystem "'.$directory.'Model.tbl" > "'.$directory.'log.txt"');
}

=head3 setupFBAExperiments

Definition:
	string:FBA experiment filename = setupFBAExperiments());
Description:
	Converts phenotype simulation specs into an FBA experiment file for the MFAToolkit

=cut

sub setupFBAExperiments {
	my ($self) = @_;
	my $fbaExpFile = "none";
	my $fbaSims = $self->fbaPhenotypeSimulations();
	if (@{$fbaSims} > 0) {
		$fbaExpFile = "FBAExperiment.txt";
		my $phenoData = ["Label\tKO\tMedia"];
		my $mediaHash = {};
		my $tempMediaIndex = 1;
		for (my $i=0; $i < @{$fbaSims}; $i++) {
			my $phenoko = "none";
			my $addnlCpds = $fbaSims->[$i]->additionalCpd_uuids();
			my $media = $fbaSims->[$i]->media()->name();
			if (@{$addnlCpds} > 0) {
				if (!defined($mediaHash->{$media.":".join("|",sort(@{$addnlCpds}))})) {
					$mediaHash->{$media.":".join("|",sort(@{$addnlCpds}))} = $self->createTemporaryMedia({
						name => "Temp".$tempMediaIndex,
						media => $fbaSims->[$i]->media(),
						additionalCpd => $fbaSims->[$i]->additionalCpds()
					});
					$tempMediaIndex++;
				}
				$media = $mediaHash->{$media.":".join("|",sort(@{$addnlCpds}))}->name();
			} else {
				$mediaHash->{$media} = $fbaSims->[$i]->media();
			}
			for (my $j=0; $j < @{$fbaSims->[$i]->geneKOs()}; $j++) {
				if ($phenoko eq "none" && $fbaSims->[$i]->geneKOs()->[$j]->id() =~ m/(\w+\.\d+)$/) {
					$phenoko = $1;
				} elsif ($fbaSims->[$i]->geneKOs()->[$j]->id() =~ m/(\w+\.\d+)$/) {
					$phenoko .= ";".$1;
				}
			}
			for (my $j=0; $j < @{$fbaSims->[$i]->reactionKOs()}; $j++) {
				if ($phenoko eq "none") {
					$phenoko = $fbaSims->[$i]->reactionKOs()->[$j]->id();
				} else {
					$phenoko .= ";".$fbaSims->[$i]->reactionKOs()->[$j]->id();
				}
			}
			push(@{$phenoData},$fbaSims->[$i]->uuid()."\t".$phenoko."\t".$media);
		}
		#Adding all additional media used as secondary media to FBAFormulation
		my $mediaRef = $self->secondaryMedia();
		foreach my $tempmedia (keys(%{$mediaHash})) {
			if ($tempmedia ne $self->media()->name()) {
				push(@{$self->secondaryMedia_uuids()},$mediaHash->{$tempmedia}->uuid());
				push(@{$mediaRef},$mediaHash->{$tempmedia});
			}
		}
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($self->jobDirectory()."/".$fbaExpFile,$phenoData);
	}
	return $fbaExpFile;
}

=head3 createTemporaryMedia

Definition:
	Bio::KBase::ObjectAPI::KBaseBiochem::Media = createTemporaryMedia({
		name => "Temp".$tempMediaIndex,
		media => $fbaSims->[$i]->media(),
		additionalCpd => $fbaSims->[$i]->additionalCpds()
	});
Description:
	Creates a temporary media conditions with the specified base media plus the specified additional compounds

=cut

sub createTemporaryMedia {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["name","media","additionalCpd"],{}, @_);
	my $newMedia = Bio::KBase::ObjectAPI::KBaseBiochem::Media->new({
		isDefined => 1,
		isMinimal => 0,
		id => $args->{name},
		name => $args->{name},
		type => "temporary"
	});
	$newMedia->parent($self->biochemistry());
	my $cpds = $args->{media}->mediacompounds();
	my $cpdHash = {};
	foreach my $cpd (@{$cpds}) {
		$cpdHash->{$cpd->compound_uuid()} = {
			compound_uuid => $cpd->compound_uuid(),
			concentration => $cpd->concentration(),
			maxFlux => $cpd->maxFlux(),
			minFlux => $cpd->minFlux(),
		};
	}
	foreach my $cpd (@{$args->{additionalCpd}}) {
		$cpdHash->{$cpd->uuid()} = {
			compound_uuid => $cpd->uuid(),
			concentration => 0.001,
			maxFlux => 100,
			minFlux => -100,
		};
	}
	foreach my $cpd (keys(%{$cpdHash})) {
		$newMedia->add("mediacompounds",$cpdHash->{$cpd});	
	}
	return $newMedia;
}

=head3 parsePhenotypeSimulations

Definition:
	void parsePhenotypeSimulations(
		[{}]
	);
Description:
	Parses array of hashes with phenotype specifications

=cut

sub parsePhenotypeSimulations {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["fbaPhenotypeSimulations"],{}, @_);
	my $phenos = $args->{fbaPhenotypeSimulations};
	for (my $i=0; $i < @{$phenos};$i++) {
		my ($addnluuids,$addnlcpds,$genokouuids,$genekos,$reactionkouuids,$reactionkos) = ([],[],[],[],[],[]);
		my $pheno = $phenos->[$i];
		(my $obj,my $type) = $self->interpretReference($pheno->{media},"Media");
		if (defined($pheno->{geneKOs})) {
			foreach my $gene (@{$pheno->{geneKOs}}) {
				(my $obj) = $self->interpretReference($gene,"Feature");
				if (defined($obj)) {
					push(@{$genekos},$obj);
					push(@{$genokouuids},$obj->uuid());
				}
			}
		}
		if (defined($pheno->{reactionKOs})) {
			foreach my $gene (@{$pheno->{reactionKOs}}) {
				(my $obj) = $self->interpretReference($gene,"Reaction");
				if (defined($obj)) {
					push(@{$reactionkos},$obj);
					push(@{$reactionkouuids},$obj->uuid());
				}
			}
		}
		if (defined($pheno->{additionalCpds})) {
			foreach my $gene (@{$pheno->{additionalCpds}}) {
				(my $obj) = $self->interpretReference($gene,"Compound");
				if (defined($obj)) {
					push(@{$addnlcpds},$obj);
					push(@{$addnluuids},$obj->uuid());
				}
			}
		}
		if (defined($obj)) {
			$self->add("fbaPhenotypeSimulations",{
				media => $obj,
				media_uuid => $obj->uuid(),
				label => $i,
				pH => $pheno->{pH},
				temperature => $pheno->{temperature},
				label => $pheno->{label},
				additionalCpd_uuids => $addnluuids,
				additionalCpds => $addnlcpds,
				geneKO_uuids => $genokouuids,
				geneKOs => $genekos,
				reactionKO_uuids => $reactionkouuids,
				reactionKOs => $reactionkos,
				observedGrowthFraction => $pheno->{growth}
			});
		}
	}
}

=head3 parseObjectiveTerms

Definition:
	void parseObjectiveTerms(
		[string]
	);
Description:
	Parses array of strings specifying objective into objective term sub objects

=cut

sub parseObjectiveTerms {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["objTerms"],{}, @_);
	my $terms = $args->{objTerms};
	for (my $i=0; $i < @{$terms};$i++) {
		(my $obj,my $type) = $self->interpretReference($terms->[$i]->{id});
		if (defined($obj)) {
			$self->add("fbaObjectiveTerms",{
				coefficient => $terms->[$i]->{coefficient},
				variableType => $terms->[$i]->{variableType},
				entityType => $type,
				entity_uuid => $obj->uuid(),
			});
		}
	}
}

=head3 parseConstraints

Definition:
	void parseConstraints({
		constraints => [string]
	});
Description:
	Parses array of strings specifying special constraints into constraint objects

=cut

sub parseConstraints {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["constraints"],{}, @_);
	my $vartrans = {
		f => "flux",ff => "forflux",rf => "revflux",
		df => "drainflux",fdf => "fordrainflux",rdf => "revdrainflux",
		ffu => "forfluxuse",rfu => "reffluxuse"
	};
	for (my $i=0; $i < @{$args->{constraints}};$i++) {
		my $array = [split(/\+/,$args->{constraints}->[$i]->{terms})];
		my $terms;
		for (my $j=0; $j < @{$array};$j++) {
			if ($array->[$j] =~ /\((\d+\.*\d*)\)(\w+)_([\w\/]+)\[(w+)\]/) {
				my $coef = $1;
				my $vartype = $vartrans->{$2};
				(my $obj,my $type) = $self->interpretReference($3);
				push(@{$terms},{
					entity_uuid => $obj->uuid(),
					entityType => $type,
					variableType => $vartype,
					coefficient => $coef
				});
			}
		}
		$self->add("fbaConstraints",{
			name => $args->{constraints}->[$i]->{name},
			rhs => $args->{constraints}->[$i]->{rhs},
			sign => $args->{constraints}->[$i]->{sign},
			fbaConstraintVariables => $terms
		});
	}
}

=head3 parseReactionKOList

Definition:
	void parseReactionKOList(
		string => string(none),delimiter => string(|),array => [string]([])
	);
Description:
	Parses a string or array of strings specifying a list of reaction KOs in the form of references

=cut

sub parseReactionKOList {
	my ($self,$args) = @_;
	$args->{data} = "uuid";
	$args->{class} = "Reaction";
	$self->reactionKO_uuids($self->parseReferenceList($args));
}

=head3 parseGeneKOList

Definition:
	void parseGeneKOList(
		string => string(none),delimiter => string(|),array => [string]([])
	);
Description:
	Parses a string or array of strings specifying a list of gene KOs in the form of references

=cut

sub parseGeneKOList {
	my ($self,$args) = @_;
	$args->{data} = "uuid";
	$args->{class} = "Feature";
	$self->geneKO_uuids($self->parseReferenceList($args));
}

=head3 mediaUUIDs

Definition:
	[string] mediaUUIDs();
Description:
	Returns a list of media uuids used by this FBAFormulation
=cut

sub mediaUUIDs {
	my ($self) = @_;
	my $mediauuids = {
		$self->media_uuid() => 1,
	};
	foreach my $media (@{$self->secondaryMedia_uuids()}) {
		$mediauuids->{$media} = 1;
	}
	my $phenotypes = $self->fbaPhenotypeSimulations();
	foreach my $pheno (@{$phenotypes}) {
		$mediauuids->{$pheno->media_uuid()} = 1;
	}
	return [keys(%{$mediauuids})];
}

=head3 export

Definition:
	string = Bio::KBase::ObjectAPI::KBaseFBA::FBA->export({
		format => readable/html/json
	});
Description:
	Exports media data to the specified format.

=cut

sub export {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["format"], {}, @_);
	if (lc($args->{format}) eq "readable") {
		return $self->toReadableString();
	} elsif (lc($args->{format}) eq "html") {
		return $self->createHTML();
	} elsif (lc($args->{format}) eq "json") {
		return $self->toJSON({pp => 1});
	}
	Bio::KBase::ObjectAPI::utilities::error("Unrecognized type for export: ".$args->{format});
}

=head3 htmlComponents

Definition:
	string = Bio::KBase::ObjectAPI::KBaseFBA::FBA->htmlComponents();
Description:
	Generates html view of FBA result

=cut

sub htmlComponents {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([],{}, @_);
	my $data = $self->_createReadableData();
	my $output = {
		title => "FBA Viewer",
		tablist => [],
		tabs => {
			main => {
				content => "",
				name => "Overview"
			}
		}
	};
	$output->{tabs}->{main}->{content} .= "<table>\n";
	for (my $i=0; $i < @{$data->{attributes}->{headings}}; $i++) {
		$output->{tabs}->{main}->{content} .= "<tr><th>".$data->{attributes}->{headings}->[$i]."</th><td style='font-size:16px;border: 1px solid black;'>".$data->{attributes}->{data}->[0]->[$i]."</td></tr>\n";
	}
	if (defined($self->fbaResults()->[0])) {
		$output->{tabs}->{main}->{content} .= "<tr><th>Objective value</th><td style='font-size:16px;border: 1px solid black;'>".$self->fbaResults()->[0]->objectiveValue()."</td></tr>\n";
	}
	$output->{tabs}->{main}->{content} .= "</table>\n";
	my $index = 2;
	my $tab = "tab-".$index;
	my $headingsOne = ["Media compound","Compound name","Concentration","Min uptake","Max uptake"];
        my $dataOne = [];
	if (@{$self->media()->mediacompounds()} > 0) {
		$index++;
		foreach my $medcpd (@{$self->media()->mediacompounds()}) {
                        push(@$dataOne, [
				$medcpd->compound()->id(),
				$medcpd->compound()->name(),
				$medcpd->concentration(),
				$medcpd->minFlux(),
				$medcpd->maxFlux()
                        ]);
		}
		$output->{tabs}->{$tab} = {
                        content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
			name => "Media"
		};
		push(@{$output->{tablist}},$tab);
	}
	if (@{$self->fbaReactionBounds()} > 0 || @{$self->fbaCompoundBounds()} > 0) {
		$tab = "tab-".$index;
		$index++;
		$headingsOne = ["Variable ID","Definition","Type","Upper bound","Lower bound"];
                $dataOne = [];
		foreach my $bound (@{$self->fbaCompoundBounds()}) {
                        push(@$dataOne, [
                                $bound->modelCompound()->id(),
                                $bound->modelCompound()->name(),
                                $bound->variableType(),
                                $bound->upperBound(),
                                $bound->lowerBound()
                        ]);
		}
		foreach my $bound (@{$self->fbaReactionBounds()}) {
                        push(@$dataOne, [
				$bound->modelReaction()->id(),
				$bound->modelReaction()->definition(),
				$bound->variableType(),
				$bound->upperBound(),
				$bound->lowerBound()
                        ]);
		}
		$output->{tabs}->{$tab} = {
                        content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
			name => "Bounds"
		};
		push(@{$output->{tablist}},$tab);
	}
	if (@{$self->fbaConstraints()} > 0) {
		$tab = "tab-".$index;
		$index++;
		$headingsOne = ["Name","Constraint"];
                $dataOne = [];
		foreach my $const (@{$self->fbaConstraints()}) {
                        push(@$dataOne, [ $const->name(), $const->readableString() ]);
		}
		$output->{tabs}->{$tab} = {
                        content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
			name => "Constraints"
		};
		push(@{$output->{tablist}},$tab);
	}
	#Retrieving result
	if (defined($self->fbaResults()->[0])) {
		my $result = $self->fbaResults()->[0];
		$tab = "tab-".$index;
		$index++;
		$headingsOne = ["Reaction ID","Definition","Variable","Value","Lower bound","Upper bound","Min","Max","Class"];
                $dataOne = [];
		foreach my $rxnflux (@{$result->fbaReactionVariables()}) {
                        push(@$dataOne, [
				$rxnflux->modelreaction()->id(),
				$rxnflux->modelreaction()->definition(),
				$rxnflux->variableType(),
				$rxnflux->value(),
				$rxnflux->lowerBound(),
				$rxnflux->upperBound(),
				$rxnflux->min(),
				$rxnflux->max(),
				$rxnflux->class()
                        ]);
		}
		foreach my $rxnflux (@{$result->fbaBiomassVariables()}) {
                        push(@$dataOne, [
				$rxnflux->biomass()->id(),
				$rxnflux->biomass()->definition(),
				$rxnflux->variableType(),
				$rxnflux->value(),
				$rxnflux->lowerBound(),
				$rxnflux->upperBound(),
				$rxnflux->min(),
				$rxnflux->max(),
				$rxnflux->class()
                        ]);
		}
		$output->{tabs}->{$tab} = {
                        content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
			name => "Reaction fluxes"
		};
		push(@{$output->{tablist}},$tab);
		$tab = "tab-".$index;
		$index++;
		$headingsOne = ["Compound ID","Name","Variable","Value","Lower bound","Upper bound","Min","Max","Class"];
                $dataOne = [];
		foreach my $cpdflux (@{$result->fbaCompoundVariables()}) {
                        push(@$dataOne, [
				$cpdflux->modelcompound()->id(),
				$cpdflux->modelcompound()->name(),
				$cpdflux->variableType(),
				$cpdflux->value(),
				$cpdflux->lowerBound(),
				$cpdflux->upperBound(),
				$cpdflux->min(),
				$cpdflux->max(),
				$cpdflux->class()
                        ]);
		}
		$output->{tabs}->{$tab} = {
                        content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
			name => "Compound fluxes"
		};
		push(@{$output->{tablist}},$tab);
		if (@{$result->fbaPhenotypeSimultationResults()} > 0) {
			$tab = "tab-".$index;
			$index++;
			$headingsOne = ["Label","Media","Addtl cpd","Gene KO","Observed growth","Simulated growth","Class"];
                        $dataOne = [];
			foreach my $pheno (@{$result->fbaPhenotypeSimultationResults()}) {
				my $phenospec = $pheno->fbaPhenotypeSimulation();
				my $genes = "";
				my $addcpd = "";
				for (my $i=0; $i < @{$phenospec->geneKOs()}; $i++) {
					if (length($genes) > 0) {
						$genes .= ";";
					}
					$genes .= $phenospec->geneKOs()->[$i]->id();
				}
				for (my $i=0; $i < @{$phenospec->additionalCpds()}; $i++) {
					if (length($addcpd) > 0) {
						$addcpd .= ";";
					}
					$addcpd .= $phenospec->additionalCpds()->[$i]->name();
				}
                                push(@$dataOne, [
					$phenospec->label(),
					$phenospec->media()->id(),
					$addcpd,
					$genes,
					$phenospec->observedGrowthFraction(),
					$pheno->simulatedGrowth()." (".$pheno->simulatedGrowthFraction().")",
					$pheno->class()
                                ]);
			}
			$output->{tabs}->{$tab} = {
                                content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
				name => "Phenotype results"
			};
			push(@{$output->{tablist}},$tab);
		}
		if (@{$result->fbaPromResults()} > 0) {
			$tab = "tab-".$index;
			$index++;
			$headingsOne = ["Objective fraction","Alpha","Beta"];
                        $dataOne = [];
			foreach my $promres (@{$result->fbaPromResults()}) {
            	push(@{$dataOne},[
            		$promres->objectFraction(),
            		$promres->alpha(),
            		$promres->beta()
            	]);    
			}
			$output->{tabs}->{$tab} = {
                                content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
				name => "PROM results"
			};
			push(@{$output->{tablist}},$tab);
		}
		if (@{$result->fbaDeletionResults()} > 0) {
			$tab = "tab-".$index;
			$index++;
			$headingsOne = ["Gene KOs","Growth fraction"];
                        $dataOne = [];
			foreach my $delres (@{$result->fbaDeletionResults()}) {
				my $genes = "";
				for (my $i=0; $i < @{$delres->genekos()}; $i++) {
					if (length($genes) > 0) {
						$genes .= ";";
					}
					$genes .= $delres->genekos()->[$i]->id();
				}
                                push(@$dataOne, [
					$genes,
					$delres->growthFraction()
                                ]);
			}
			$output->{tabs}->{$tab} = {
                                content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
				name => "Deletion results"
			};
			push(@{$output->{tablist}},$tab);
		}
		if (@{$result->minimalMediaResults()} > 0) {
			$tab = "tab-".$index;
			$index++;
			$headingsOne = ["Media index","Essential nutrient","Compound ID","Name"];
                        $dataOne = [];
			my $mediaIndex = 0;
			foreach my $minmed (@{$result->minimalMediaResults()}) {
				foreach my $minmedcpd (@{$minmed->essentialNutrients()}) {
                                        push(@$dataOne, [
						$mediaIndex,
						"Yes",
						$minmedcpd->id(),
						$minmedcpd->name()
                                        ]);
				}
				foreach my $minmedcpd (@{$minmed->optionalNutrients()}) {
                                        push(@$dataOne, [
						$mediaIndex,
						"No",
						$minmedcpd->id(),
						$minmedcpd->name()
                                        ]);
				}
				$mediaIndex++;
			}
			$output->{tabs}->{$tab} = {
                                content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
				name => "Minimal media"
			};
			push(@{$output->{tablist}},$tab);
		}
		if (@{$result->fbaMetaboliteProductionResults()} > 0) {
			$tab = "tab-".$index;
			$index++;
			$headingsOne = ["Compound ID","Name","Maximum production"];
                        $dataOne = [];
			foreach my $metprod (@{$result->fbaMetaboliteProductionResults()}) {
                                push(@$dataOne, [
					$metprod->modelCompound()->id(),
					$metprod->modelCompound()->name(),
					$metprod->maximumProduction()
                                ]);
			}
			$output->{tabs}->{$tab} = {
                                content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
				name => "Compound production"
			};
			push(@{$output->{tablist}},$tab);
		}
	}
	return $output;
}

__PACKAGE__->meta->make_immutable;
1;
