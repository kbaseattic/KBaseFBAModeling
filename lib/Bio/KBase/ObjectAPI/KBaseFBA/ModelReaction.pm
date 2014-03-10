########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::ModelReaction - This is the moose object corresponding to the ModelReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelReaction;
package Bio::KBase::ObjectAPI::KBaseFBA::ModelReaction;
use Moose;
use Bio::KBase::ObjectAPI::utilities;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelReaction';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has equation => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequation' );
has code => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcode' );
has definition => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );
has name => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildname' );
has abbreviation => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildabbreviation' );
has modelCompartmentLabel => ( is => 'rw', isa => 'Str',printOrder => '4', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmodelCompartmentLabel' );
has gprString => ( is => 'rw', isa => 'Str',printOrder => '6', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgprString' );
has exchangeGPRString => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildexchangeGPRString' );
has missingStructure => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmissingStructure' );
has biomassTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildbiomassTransporter' );
has isTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisTransporter' );
has translatedDirection  => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildtranslatedDirection' );
has featureIDs  => ( is => 'rw', isa => 'ArrayRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildfeatureIDs' );
has featureUUIDs  => ( is => 'rw', isa => 'ArrayRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildfeatureUUIDs' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildname {
	my ($self) = @_;
	return $self->reaction->name()."_".$self->modelCompartmentLabel();
}
sub _buildabbreviation {
	my ($self) = @_;
	return $self->reaction->abbreviation()."_".$self->modelCompartmentLabel();
}
sub _builddefinition {
	my ($self) = @_;
	my $reactants = "";
	my $products = "";
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->coefficient() < 0) {
			my $coef = -1*$rgt->coefficient();
			if (length($reactants) > 0) {
				$reactants .= " + ";	
			}
			if ($coef ne "1") {
				$reactants .= "(".$coef.")";
			}
			$reactants .= $rgt->modelcompound()->compound()->name()."[".$rgt->modelcompound()->modelCompartmentLabel()."]";
		} else {
			if (length($products) > 0) {
				$products .= " + ";	
			}
			if ($rgt->coefficient() ne "1") {
				$products .= "(".$rgt->coefficient().")";
			}
			$products .= $rgt->modelcompound()->compound()->name()."[".$rgt->modelcompound()->modelCompartmentLabel()."]";
		}
		
	}
	$reactants .= " ".$self->translatedDirection()." ";
	return $reactants.$products;
}
sub _buildequation {
	my ($self) = @_;
	my $reactants = "";
	my $products = "";
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->coefficient() < 0) {
			my $coef = -1*$rgt->coefficient();
			if (length($reactants) > 0) {
				$reactants .= " + ";	
			}
			if ($coef ne "1") {
				$reactants .= "(".$coef.")";
			}
			$reactants .= $rgt->modelcompound()->id();
		} else {
			if (length($products) > 0) {
				$products .= " + ";	
			}
			if ($rgt->coefficient() ne "1") {
				$products .= "(".$rgt->coefficient().")";
			}
			$products .= $rgt->modelcompound()->id();
		}
	}
	$reactants .= " ".$self->translatedDirection()." ";
	return $reactants.$products;
}
sub _buildcode {
	my ($self) = @_;
	my $reactants = {};
	my $products = {};
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		my $id = $rgt->modelcompound()->id();
		if ($id =~ m/(.+)_c\d+$/) {
			$id = $1;
		} elsif ($id =~ m/(.+)_[(a-z)]\d+$/) {
			$id = $1."[".$2."]";
		}
		if ($rgt->coefficient() < 0) {
			my $coef = -1*$rgt->coefficient();
			$reactants->{$id} = $coef;
		} else {
			$products->{$id} = $rgt->coefficient();
		}
	}
	my $code = "";
	my $array = [sort(keys(%{$reactants}))];
	foreach my $id (@{$array}) {
		if (length($code) > 0) {
			$code .= " + ";
		}
		if ($reactants->{$id} != 1) {
			$code .= "(".$reactants->{$id}.") ";
		}
		$code .= $id;
	}
	$code .= " <=> ";
	$array = [sort(keys(%{$products}))];
	foreach my $id (@{$array}) {
		if (length($code) > 0) {
			$code .= " + ";
		}
		if ($products->{$id} != 1) {
			$code .= "(".$products->{$id}.") ";
		}
		$code .= $id;
	}
	return $code;
}
sub _buildmodelCompartmentLabel {
	my ($self) = @_;
	return $self->modelcompartment()->id();
}
sub _buildgprString {
	my ($self) = @_;
	my $gpr = "";
	foreach my $protein (@{$self->modelReactionProteins()}) {
		if (length($gpr) > 0) {
			$gpr .= " or ";	
		}
		$gpr .= $protein->gprString();
	}
	if (@{$self->modelReactionProteins()} > 1) {
		$gpr = "(".$gpr.")";	
	}
	if (length($gpr) == 0) {
		$gpr = "Unknown";
	}
	return $gpr;
}
sub _buildexchangeGPRString {
	my ($self) = @_;
	my $gpr = "MSGPR{";
	foreach my $protein (@{$self->modelReactionProteins()}) {
		if (length($gpr) > 6) {
			$gpr .= "/";	
		}
		$gpr .= $protein->exchangeGPRString();
	}
	$gpr .= "}";
	return $gpr;
}
sub _buildmissingStructure {
	my ($self) = @_;
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if (@{$rgt->modelcompound()->compound()->structures()} == 0) {
			return 1;	
		}
	}
	return 0;
}
sub _buildbiomassTransporter {
	my ($self) = @_;
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->modelcompound()->isBiomassCompound() == 1) {
			for (my $j=$i+1; $j < @{$rgts}; $j++) {
				my $rgtc = $rgts->[$j];
				if ($rgt->modelcompound()->compound_ref() eq $rgtc->modelcompound()->compound_ref()) {
					if ($rgt->modelcompound()->modelcompartment_ref() ne $rgtc->modelcompound()->modelcompartment_ref()) {
						return 1;
					}
				}
			}
		}
	}
	return 0;
}
sub _buildisTransporter {
	my ($self) = @_;
	my $rgts = $self->modelReactionReagents();
	my $initrgt = $rgts->[0];
	for (my $i=1; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->modelcompound()->modelcompartment_ref() ne $initrgt->modelcompound()->modelcompartment_ref()) {
			return 1;	
		}
	}
	return 0;
}

sub _buildtranslatedDirection {
	my ($self) = @_;
	if ($self->direction() eq "=") {
		return "<=>";	
	} elsif ($self->direction() eq ">") {
		return "=>";
	} elsif ($self->direction() eq "<") {
		return "<=";
	}
	return $self->direction();
}
sub _buildfeatureIDs {
	my ($self) = @_;
	my $featureHash = {};
	foreach my $protein (@{$self->modelReactionProteins()}) {
		foreach my $subunit (@{$protein->modelReactionProteinSubunits()}) {
			foreach my $gene (@{$subunit->features()}) {
				$featureHash->{$gene->id()} = 1;
			}
		}
	}
	return [keys(%{$featureHash})];
}
sub _buildfeatureUUIDs {
	my ($self) = @_;
	my $featureHash = {};
	foreach my $protein (@{$self->modelReactionProteins()}) {
		foreach my $subunit (@{$protein->modelReactionProteinSubunits()}) {
			foreach my $gene (@{$subunit->features()}) {
				$featureHash->{$gene->_reference()} = 1;
			}
		}
	}
	return [keys(%{$featureHash})];
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************

=head3 addReagentToReaction
Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->addReagentToReaction({
		coefficient => REQUIRED,
		modelcompound_uuid => REQUIRED
	});
Description:
	Add a new ModelCompound object to the ModelReaction if the ModelCompound is not already in the reaction

=cut

sub addReagentToReaction {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["coefficient","modelcompound_ref"],{}, @_);
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		if ($rgts->[$i]->modelcompound_ref() eq $args->{modelcompound_ref}) {
			return $rgts->[$i];
		}
	}
	my $mdlrxnrgt = $self->add("modelReactionReagents",{
		coefficient => $args->{coefficient},
		modelcompound_ref => $args->{modelcompound_ref}
	});
	return $mdlrxnrgt;
}

=head3 addModelReactionProtein
Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->addModelReactionProtein({
		proteinDataTree => REQUIRED:{},
		complex_uuid => REQUIRED:ModelSEED::uuid
	});
Description:
	Adds a new protein to the reaction based on the input data tree

=cut

sub addModelReactionProtein {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["proteinDataTree"], {complex_ref => ""}, @_);
	my $prots = $self->modelReactionProteins();
	for (my $i=0; $i < @{$prots}; $i++) {
		if ($prots->[$i]->complex_ref() eq $args->{complex_ref}) {
			return $prots->[$i];
		}
	}
	my $protdata = {complex_ref => $args->{complex_ref},modelReactionProteinSubunits => []};
	if (defined($args->{proteinDataTree}->{note})) {
		$protdata->{note} = $args->{proteinDataTree}->{note};
	}
	if (defined($args->{proteinDataTree}->{subunits})) {
		foreach my $subunit (keys(%{$args->{proteinDataTree}->{subunits}})) {
			my $data = {
				triggering => $args->{proteinDataTree}->{subunits}->{$subunit}->{triggering},
				optionalSubunit => $args->{proteinDataTree}->{subunits}->{$subunit}->{optionalRole},
				role => $subunit,
				feature_refs => [],
				note => ""
			};
			if (defined($args->{proteinDataTree}->{subunits}->{$subunit}->{note})) {
				$data->{note} = $args->{proteinDataTree}->{subunits}->{$subunit}->{note};
			}
			if (defined($args->{proteinDataTree}->{subunits}->{$subunit}->{genes})) {
				foreach my $gene (keys(%{$args->{proteinDataTree}->{subunits}->{$subunit}->{genes}})) {
					push(@{$data->{feature_refs}},$gene);
				}
			}
			push(@{$protdata->{modelReactionProteinSubunits}},$data);
		}
	}
	return $self->add("modelReactionProteins",$protdata);
}

=head3 setGPRFromArray
Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->setGPRFromArray({
		gpr => []
	});
Description:
	Sets the GPR of the reaction from three nested arrays

=cut

sub setGPRFromArray {
	my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["gpr"],{}, @_);
	$self->modelReactionProteins([]);
	foreach my $prot (@{$self->modelReactionProteins()}) {
		$self->remove("modelReactionProteins",$prot);
	}
	for (my $i=0; $i < @{$args->{gpr}}; $i++) {
    	if (defined($args->{gpr}->[$i]) && ref($args->{gpr}->[$i]) eq "ARRAY") {
	    	my $prot = $self->add("modelReactionProteins",{
	    		complex_ref => "",
	    		note => "Manually specified GPR"
	    	});
	    	for (my $j=0; $j < @{$args->{gpr}->[$i]}; $j++) {
	    		if (defined($args->{gpr}->[$i]->[$j]) && ref($args->{gpr}->[$i]->[$j]) eq "ARRAY") {
		    		for (my $k=0; $k < @{$args->{gpr}->[$i]->[$j]}; $k++) {
		    			if (defined($args->{gpr}->[$i]->[$j]->[$k])) {
						    my $featureId = $args->{gpr}->[$i]->[$j]->[$k];
						    my $ftrObj = $self->genome()->getObject("features",$featureId);
						    if (!defined($ftrObj)) {
								$prot->note($featureId);
						    }
						    else {
								my $subunit = $prot->add("modelReactionProteinSubunits",{
								    role => "",
								    triggering => 0,
								    optionalSubunit => 0,
								    note => "Manually specified GPR",
								    feature_refs => [$ftrObj->_reference()]
							    });
			    			}
			    		}
		    		}
	    		}
	    	}
    	}
    }
}

sub ImportExternalEquation {
	my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["equation","compounds"],{}, @_);
	$args->{equation} =~ s/\s+\<*[-=]+\>\s+/ = /g;
	$args->{equation} =~ s/\s\<[-=]+\s/ = /g;
    $args->{equation} =~ s/\s+\+\s+/ + /g;
	my $array = [split(/\s=\s/,$args->{equation})];
	if (@{$array} == 1) {
		Bio::KBase::ObjectAPI::utilities::error("No equal sign in ".$args->{equation}."!");
	} elsif (@{$array} > 2) {
		Bio::KBase::ObjectAPI::utilities::error("Too many equal signs in ".$args->{equation}."!");
	}
	my $bio = $self->parent()->template()->biochemistry();
    my $rxncpds = $self->modelReactionReagents();
    for (my $i=0; $i < @{$rxncpds}; $i++){
    	$self->remove("modelReactionReagents",$rxncpds->[$i])
    }
    $self->modelReactionReagents([]);
    for (my $i=0; $i < @{$array}; $i++) {
    	my $compounds = [split(/\s\+\s/,$array->[$i])];
    	foreach my $cpd (@{$compounds}) {
    		my $coef = 1;
    		my $compartment = "c";
    		my $index = 0;
    		if ($cpd =~ m/^\((\d+\.*\d*)\)\s+(.+)/) {
    			$coef = $1;
    			$cpd = $2;
    		}
    		if ($cpd =~ m/^(.+)\[([a-z]\d*)\]$/) {
    			$cpd = $1;
    			$compartment = $2;	
    		}
    		if ($compartment =~ m/([a-z])(\d+)/) {
    			$index = $2;
    			$compartment = $1;	
    		}
    		if ($i == 0) {
    			$coef = -1*$coef;
    		}
    		my $cmp = $bio->searchForCompartment($compartment);
    		if (!defined($cmp)) {
    			Bio::KBase::ObjectAPI::utilities::error("Unrecognized compartment in equation:".$cmp."!");
    		}
    		my $mdlcmp = $self->parent()->getObject("modelcompartments",$compartment.$index);
    		if (!defined($mdlcmp)) {
    			$mdlcmp = $self->parent()->add("modelcompartments",{
    				id => $compartment.$index,
					compartment_ref => $cmp->_reference(),
					compartmentIndex => $index,
					label => $compartment.$index,
					pH => 7,
					potential => 0,
    			});
    		}
    		my $cpdobj = $bio->searchForCompound($cpd);
    		if (!defined($cpdobj) && defined($args->{compounds}->{$cpd})) {
    			$cpdobj = $bio->searchForCompound($args->{compounds}->{$cpd}->[3]);
    			if (!defined($cpdobj)) {
    				foreach my $alias (@{$args->{compounds}->{$cpd}->[4]}) {
    					$cpdobj = $bio->searchForCompound($alias);
    					if (defined($cpdobj)) {
    						last;
    					}
    				}
    			}
    		}
    		my $mdlcpd;
    		if (defined($cpdobj)) {
    			$mdlcpd = $self->parent()->searchForCompound($cpdobj->id()."_".$compartment.$index);
    			if (!defined($mdlcpd)) {
    				$mdlcpd = $self->parent()->add("modelcompounds",{
    					id => $cpdobj->id()."_".$compartment.$index,
						compound_ref => $cpdobj->_reference(),
						name => $cpdobj->name()."_".$compartment.$index,
						charge => $cpdobj->defaultCharge(),
						formula => $cpdobj->formula(),
						modelcompartment_ref => "~/modelcompartments/id/".$mdlcmp->id()
    				});
    			}
    		} else {
    			$mdlcpd = $self->parent()->searchForCompound($cpd."_".$compartment.$index);
    			if (!defined($mdlcpd)) {
    				if (!defined($args->{compounds}->{$cpd})) {
    					Bio::KBase::ObjectAPI::utilities::error("Ill defined compound:".$cpd."!");
    				}
    				$mdlcpd = $self->parent()->add("modelcompounds",{
    					id => $cpd."_".$compartment.$index,
						compound_ref => $bio->_reference()."/compounds/id/cpd00000",
						name => $args->{compounds}->{$cpd}->[3]."_".$compartment.$index,
						charge => $args->{compounds}->{$cpd}->[1],
						formula => $args->{compounds}->{$cpd}->[2],
						modelcompartment_ref => "~/modelcompartments/id/".$mdlcmp->id()
    				});
    			}
    		}
    		$self->add("modelReactionReagents",{
    			modelcompound_ref => "~/modelcompounds/id/".$mdlcpd->id(),
				coefficient => $coef
    		});
    	}
    }
    my $rxnobj = $bio->queryObject("reactions",{code => $self->code()});
    if (defined($rxnobj)) {
    	$self->reaction_ref($bio->_reference()."/reactions/id/".$rxnobj->id());
    } else {
    	$self->reaction_ref($bio->_reference()."/reactions/id/rxn00000");
    }
}

sub loadGPRFromString {
	my $self = shift;
	my $gprstring = shift;
	my $geneAliases = $self->parent()->genome()->geneAliasHash();
	my $gpr = Bio::KBase::ObjectAPI::utilities::translateGPRHash(Bio::KBase::ObjectAPI::utilities::parseGPR($gprstring));
	my $missingGenes;
	for (my $m=0; $m < @{$gpr}; $m++) {
		my $protObj = $self->add("modelReactionProteins",{
			complex_ref => "",
			note => "Imported GPR",
			modelReactionProteinSubunits => []
		});		
		for (my $j=0; $j < @{$gpr->[$m]}; $j++) {
			my $subObj = $protObj->add("modelReactionProteinSubunits",{
				role => "",
				triggering => 0,
				optionalSubunit => 0,
				note => "Imported GPR",
				feature_refs => []
			});		
			for (my $k=0; $k < @{$gpr->[$m]->[$j]}; $k++) {
				my $ftrID = $gpr->[$m]->[$j]->[$k];
				if (!defined($geneAliases->{$ftrID})) {
					$missingGenes->{$ftrID} = 1;
				} else {
					$subObj->addLinkArrayItem("features",$geneAliases->{$ftrID});
				}
			}
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
