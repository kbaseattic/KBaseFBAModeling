########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::FBAModel - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use YAML::XS;
use XML::LibXML;
use File::Temp;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::FBAModel;
package Bio::KBase::ObjectAPI::KBaseFBA::FBAModel;
use Moose;
use namespace::autoclean;
use Class::Autouse qw(
    Graph::Undirected
);
use Bio::KBase::ObjectAPI::utilities;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::FBAModel';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has features => ( is => 'rw', isa => 'ArrayRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildfeatures' );
has featureHash => ( is => 'rw', isa => 'HashRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildfeatureHash' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildfeatures {
	my ($self) = @_;
	#Retrieving list of genes in model
	my $rxns = $self->modelreactions();
	my $ftrhash = {};
	for (my $i=0; $i < @{$rxns};$i++) {
		my $rxn = $rxns->[$i];
		my $ftrs = $rxn->featureUUIDs();
		foreach my $ftr (@{$ftrs}) {
			$ftrhash->{$ftr} = 1;
		}
	}
	return [keys(%{$ftrhash})];
}

sub _buildfeatureHash {
	my ($self) = @_;
	my $ftrhash = {};
	my $rxns = $self->modelreactions();
	for (my $i=0; $i < @{$rxns};$i++) {
		my $rxn = $rxns->[$i];
		my $ftrs = $rxn->featureUUIDs();
		foreach my $ftr (@{$ftrs}) {
			$ftrhash->{$ftr}->{$rxn->_reference()} = $rxn;
		}
	}
	return $ftrhash;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************

=head3 addMediaReactions

Definition:
    Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->addMediaReactions({
           media => Bio::KBase::ObjectAPI::KBaseBiochem::Media(REQ)
    })

Description:
    Search the model for reactions that contain EXTRACELLULAR versions of each compound in media "media".
    If none is present, it searches the biochemistry and adds the first one that it finds (note - we might
    later want to define some kind of priority system for them)

=cut

sub addMediaReactions {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args( ["media", "biochemistry"], {}, @_);
    my $media = $args->{media};
    my $bio = $args->{biochemistry};

    # Find extracellular compartment's UUID
    my $ex = $bio->queryObject("compartments", { name => "Extracellular"});
    if (!defined($ex)) {
	die "Unable to find extracellular compartment in biochemistry object...";
    }
    my $ex_uuid = $ex->_reference();

    # Generate lists of transporters
    my $model_rxns = $self->modelreactions();
    my $model_transporters = [];
    for (my $i=0; $i<@{$model_rxns}; $i++) {
	# convert ModelReaction TO to Reaction TO (note - should I be using ModelReaction directly? Not sure how to do that at this point)
	my $rxn = $self->getLinkedObject('Biochemistry', 'reactions', $model_rxns->[$i]->reaction_ref());
	if ( $rxn->isTransport() ) {
	    push(@{$model_transporters},$rxn);
	}
    }
    my $bio_rxns = $bio->reactions();
    my $bio_transporters = [];
    for (my $i=0; $i<@{$bio_rxns}; $i++) {
	if ( $bio_rxns->[$i]->isTransport() ) {
	    push(@{$bio_transporters}, $bio_rxns->[$i]);
	}
    }

    # Now we try to see if the extracellular versions of each media compound are present...
    my $media_cpds = $media->mediacompounds();
    for (my $i = 0; $i < @{$media_cpds}; $i++) {
	my $cpd_uuid = $media_cpds->[$i]->compound_ref();
	my $cpd_name = $media_cpds->[$i]->compound()->id();
	# See if the extracellular version of this compound is in any of our reactions. If it is, 
	# we are OK with it. If not we need to get a reaction that has this property out of the biochemistry object
	# and add it to the model
	my $OK = 0;
	for ( my $j=0; $j<@{$model_transporters}; $j++ ) {
	    my $rxn = $model_transporters->[$j];
	    if ( $rxn->hasReagentInCompartment($cpd_uuid, $ex_uuid) ) {
		$OK = 1;
		last;
	    }
	}
	if ( $OK ) {
#	    print STDERR "Compound ${cpd_name} already has transporter in model\n";
	    next;
	}

	for ( my $j=0; $j<@{$bio_transporters}; $j++ ) {
	    my $rxn = $bio_transporters->[$j];
	    if ( $rxn->hasReagentInCompartment($cpd_uuid, $ex_uuid) ) {
		# We just take the first transporter that will transport the compound we want.
		# We could get more sophisticated (e.g. make sure eveyrthing in the extracellular compartment is
		# present in the media).
		$self->addReactionToModel({ reaction => $rxn });
		push(@{$model_transporters}, $rxn);
		my $rxnid = $rxn->id();
		print STDERR "Transport reaction ${rxnid} added for compound ${cpd_name}\n";
		$OK = 1;
		last;
	    }
	}
	if ( ! $OK ) {
	    print STDERR "WARNING: Unable to find transporter for compound ${cpd_name} in the biochemistry object...\n";
	}
    }
}

=head3 addReactionToModel

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::ModelReaction = Bio::KBase::ObjectAPI::KBaseFBA::ModelReaction->addReactionToModel({
		reaction => REQUIRED,
		direction => undef (default value will be pulled from reaction instance),
		protons => undef (default value will be pulled from reaction instance),
		gpr => "UNKNOWN"
	});
Description:
	Converts the input reaction instance into a model reaction and adds the reaction and associated compounds to the model.

=cut

sub addReactionToModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["reaction"],{
		direction => undef,
		protons => undef,
		gpr => undef,
		overrideCompartment => undef
	}, @_);
	my $rxn = $args->{reaction};
	if (!defined($args->{direction})) {
		$args->{direction} = $rxn->direction();	
	}
	my $mdlcmp = $args->{overrideCompartment};
	if (!defined($mdlcmp->{overrideCompartment}) || $rxn->isTransport()) {
		$mdlcmp = $self->addCompartmentToModel({compartment => $rxn->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
	}
	my $mdlrxn = $self->queryObject("modelreactions",{
		reaction_ref => $rxn->_reference(),
		modelcompartment_ref => $mdlcmp->_reference()
	});
	if (!defined($mdlrxn)) {
		$mdlrxn = $self->add("modelreactions",{
			reaction_ref => $rxn->_reference(),
			direction => $args->{direction},
			protons => $rxn->defaultProtons(),
			modelcompartment_ref => $mdlcmp->_reference(),
		});
		my $rgts = $rxn->reagents();
		for (my $i=0; $i < @{$rgts}; $i++) {
			my $rgt = $rgts->[$i];
			my $rgtcmp = $self->addCompartmentToModel({compartment => $rgt->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
			my $coefficient = $rgt->coefficient();
			my $mdlcpd = $self->addCompoundToModel({
				compound => $rgt->compound(),
				modelCompartment => $rgtcmp,
			});
			$mdlrxn->addReagentToReaction({
				coefficient => $coefficient,
				modelcompound_ref => $mdlcpd->_reference()
			});
		}
		$mdlrxn->setGPRFromArray({"gpr" => [[$args->{gpr}]]});
	}
	return $mdlrxn;
}

=head3 addCompartmentToModel

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->addCompartmentToModel({
		Compartment => REQUIRED,
		pH => 7,
		potential => 0,
		compartmentIndex => 0
	});
Description:
	Adds a compartment to the model after checking that the compartment isn't already there

=cut

sub addCompartmentToModel {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["compartment"],{
		pH => 7,
		potential => 0,
		compartmentIndex => 0
	}, @_);
	my $mdlcmp = $self->queryObject("modelcompartments",{compartment_ref => $args->{compartment}->_reference(),compartmentIndex => $args->{compartmentIndex}});
	if (!defined($mdlcmp)) {
		$mdlcmp = $self->add("modelcompartments",{
			id => $args->{compartment}->id().$args->{compartmentIndex},
			compartment_ref => $args->{compartment}->_reference(),
			label => $args->{compartment}->id().$args->{compartmentIndex},
			pH => $args->{pH},
			compartmentIndex => $args->{compartmentIndex},
		});
	}
	return $mdlcmp;
}

=head3 addCompoundToModel

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound = Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound->addCompoundToModel({
		compound => REQUIRED,
		modelCompartment => REQUIRED,
		charge => undef (default values will be pulled from input compound),
		formula => undef (default values will be pulled from input compound)
	});
Description:
	Adds a compound to the model after checking that the compound isn't already there

=cut

sub addCompoundToModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["compound","modelCompartment"],{
		charge => undef,
		formula => undef
	}, @_);
	my $mdlcpd = $self->queryObject("modelcompounds",{compound_ref => $args->{compound}->_reference(),modelcompartment_ref => $args->{modelCompartment}->_reference()});
	if (!defined($mdlcpd)) {
		if (!defined($args->{charge})) {
			$args->{charge} = $args->{compound}->defaultCharge();
		}
		if (!defined($args->{formula})) {
			$args->{formula} = $args->{compound}->formula();
		}
		$mdlcpd = $self->add("modelcompounds",{
			modelcompartment_ref => $args->{modelCompartment}->_reference(),
			compound_ref => $args->{compound}->_reference(),
			charge => $args->{charge},
			formula => $args->{formula},
		});
	}
	return $mdlcpd;
}

=head3 adjustBiomassReaction

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->adjustBiomassReaction({
		biomass => string
		compound => string,
		compartment => string,
		compartmentIndex => integer,
		coefficient => float
	});
Description:
	Modifies the biomass reaction to adjust a compound, add a compound, or remove a compound
	
=cut
sub adjustBiomassReaction {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["compound","coefficient"],{
    	biomass => "bio1",
    	compartment => "c",
    	compartmentIndex => 0
    }, @_);
    my $bio = $self->searchForBiomass($args->{biomass});
    if (!defined($bio)) {
    	Bio::KBase::ObjectAPI::utilities::error("Biomass ".$args->{biomass}." not found!");
    }
    my $mdlcpd = $self->searchForCompound($args->{compound},$args->{compartment},$args->{compartmentIndex});
    if (!defined($mdlcpd)) {
    	Bio::KBase::ObjectAPI::utilities::error("ModelCompound ".$args->{compound}."_".$args->{compartment}.$args->{compartmentIndex}." not found!");
    }
    $bio->adjustBiomassReaction({
    	coefficient => $args->{coefficient},
		modelcompound => $mdlcpd
    });
}

=head3 manualReactionAdjustment

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->manualReactionAdjustment({
		reaction => string,
    	direction => string,
    	compartment => string,
    	compartmentIndex => integer,
    	gpr => [[[]]],
    	removeReaction => 0/1(0),
    	addReaction => 0/1(0)
	});
Description:
	
		
=cut
sub manualReactionAdjustment {
    my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["reaction"],{
    	direction => undef,
    	compartment => "c",
    	compartmentIndex => 0,
    	gpr => undef,
    	removeReaction => 0,
    	addReaction => 0
    }, @_);

    if ($args->{reaction} =~ m/^(.+)\[([a-z]+)(\d*)]$/) {
    	$args->{reaction} = $1;
    	$args->{compartment} = $2;
    	$args->{compartmentIndex} = $3;
    }
    if (!defined($args->{compartment})) {
    	$args->{compartment} = "c";
    }
    if (!defined($args->{compartmentIndex})) {
    	$args->{compartmentIndex} = 0;
    }
    my $mdlrxn = $self->searchForReaction($args->{reaction},$args->{compartment},$args->{compartmentIndex});
    if (defined($mdlrxn)) {
    	if ($args->{addReaction} == 1) {
    		Bio::KBase::ObjectAPI::utilities::error("Cannot add reaction ".$args->{reaction}."_".$args->{compartment}.$args->{compartmentIndex}.", reaction is already in model!");
    	} elsif ($args->{removeReaction} == 1) {
    		$self->remove("modelreactions",$mdlrxn);
    	} else {
    		if (defined($args->{direction})) {
    			$mdlrxn->direction($args->{direction});
    		}
    		if (defined($args->{gpr})) {
		    $mdlrxn->setGPRFromArray({gpr => $args->{gpr}});
    		}
    	}
    } else {
    	if ($args->{removeReaction} == 1) {
    		Bio::KBase::ObjectAPI::utilities::error("Cannot remove reaction ".$args->{reaction}."_".$args->{compartment}.$args->{compartmentIndex}.", reaction is not in model!");
    	} elsif ($args->{addReaction} == 1) {
    		my $bio = $self->biochemistry();
    		my $rxn = $bio->searchForReaction($args->{reaction});
    		if (!defined($rxn)) {
		    	Bio::KBase::ObjectAPI::utilities::error("Reaction ".$args->{reaction}." not found in biochemistry!");
		    }
			my $cmp = $bio->queryObject("compartments",{id => $args->{compartment}});
		    if (!defined($cmp)) {
		    	Bio::KBase::ObjectAPI::utilities::error("Compartment ".$args->{compartment}." not found in biochemistry!");
		    }
		    my $mdlcmp = $self->queryObject("modelcompartments",{
		    	compartment_ref => $cmp->_reference(),
		    	compartmentIndex => $args->{compartmentIndex}
		    });
		    if (!defined($mdlcmp)) {
		    	$mdlcmp = $self->addCompartmentToModel({
		    		compartment => $cmp,
		    		pH => 7,
		    		potential => 0,
		    		compartmentIndex => $args->{compartmentIndex}
		    	});
		    }
		    my $mdlrxn = $self->addReactionToModel({
		    	reaction => $rxn,
		    	direction => $args->{direction},
				protons => undef,
				overrideCompartment => $mdlcmp
		    });
		    if (defined($args->{gpr})) {
    			$mdlrxn->setGPRFromArray({gpr => $args->{gpr}});
    		}
    	} else {
    		Bio::KBase::ObjectAPI::utilities::error("Cannot alter reaction ".$args->{reaction}."_".$args->{compartment}.$args->{compartmentIndex}.", reaction is not in model!");
    	}
    }
}

=head3 labelBiomassCompounds

Definition:
	void Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->labelBiomassCompounds();
Description:
	Labels all model compounds indicating whether or not they are biomass components

=cut

sub labelBiomassCompounds {
	my $self = shift;
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		$cpd->isBiomassCompound(0);
	}
	for (my $i=0; $i < @{$self->biomasses()}; $i++) {
		my $bio = $self->biomasses()->[$i];
		for (my $j=0; $j < @{$bio->biomasscompounds()}; $j++) {
			my $biocpd = $bio->biomasscompounds()->[$j];
			$biocpd->modelcompound()->isBiomassCompound(1);
		}
	}
}

=head3 printSBML

Definition:
	void Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->printSBML();
Description:
	Prints the model in SBML format

=cut

sub printSBML {
    my $self = shift;
	# convert ids to SIds
    my $idToSId = sub {
        my $id = shift @_;
        my $cpy = $id;
        # SIds must begin with a letter
        $cpy =~ s/^([^a-zA-Z])/A_$1/;
        # SIDs must only contain letters numbers or '_'
        $cpy =~ s/[^a-zA-Z0-9_]/_/g;
        return $cpy;
    };
    #clean names
    my $stringToString = sub {
		my ($name,$value) = @_;
		$value =~ s/[\[\]\(\)\+]//g;
		$value =~ s/[\s:,]/_/g;
		return $name.'="'.XML::LibXML::Document->new('1.0', 'UTF-8')->createTextNode($value)->toString .'"';
    };
	#Printing header to SBML file
	my $ModelName = $idToSId->($self->id());
	my $output;
	push(@{$output},'<?xml version="1.0" encoding="UTF-8"?>');
	push(@{$output},'<sbml xmlns="http://www.sbml.org/sbml/level2" level="2" version="1" xmlns:html="http://www.w3.org/1999/xhtml">');
	my $name = $self->name()." SEED model";
	$name =~ s/[\s\.]/_/g;
	push(@{$output},'<model id="'.$ModelName.'" name="'.$name.'">');

	#Printing the unit data
	push(@{$output},"<listOfUnitDefinitions>");
	push(@{$output},"\t<unitDefinition id=\"mmol_per_gDW_per_hr\">");
	push(@{$output},"\t\t<listOfUnits>");
	push(@{$output},"\t\t\t<unit kind=\"mole\" scale=\"-3\"/>");
	push(@{$output},"\t\t\t<unit kind=\"gram\" exponent=\"-1\"/>");
	push(@{$output},"\t\t\t<unit kind=\"second\" multiplier=\".00027777\" exponent=\"-1\"/>");
	push(@{$output},"\t\t</listOfUnits>");
	push(@{$output},"\t</unitDefinition>");
	push(@{$output},"</listOfUnitDefinitions>");

	#Printing compartments for SBML file
	push(@{$output},'<listOfCompartments>');
	for (my $i=0; $i < @{$self->modelcompartments()}; $i++) {
		my $cmp = $self->modelcompartments()->[$i];
    	push(@{$output},'<compartment '.$stringToString->("id",$cmp->label()).' '.$stringToString->("name",$cmp->label()).' />');
    }
	push(@{$output},'</listOfCompartments>');
	#Printing the list of metabolites involved in the model
	push(@{$output},'<listOfSpecies>');
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		push(@{$output},'<species '.$stringToString->("id",$cpd->id()).' '.$stringToString->("name",$cpd->name()).' '.$stringToString->("compartment",$cpd->modelCompartmentLabel()).' '.$stringToString->("charge",$cpd->charge()).' boundaryCondition="false"/>');
		if ($cpd->compound()->id() eq "cpd11416" || $cpd->compound()->id() eq "cpd15302" || $cpd->compound()->id() eq "cpd08636") {
			push(@{$output},'<species '.$stringToString->("id",$cpd->compound()->id()."_b").' '.$stringToString->("name",$cpd->compound()->name()."_b").' '.$stringToString->("compartment",$cpd->modelCompartmentLabel()).' '.$stringToString->("charge",$cpd->charge()).' boundaryCondition="true"/>');
		}
	}
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		if ($cpd->modelCompartmentLabel() =~ m/^e/) {
			push(@{$output},'<species '.$stringToString->("id",$cpd->compound()->id()."_b").' '.$stringToString->("name",$cpd->compound()->name()."_b").' '.$stringToString->("compartment",$cpd->modelCompartmentLabel()).' '.$stringToString->("charge",$cpd->charge()).' boundaryCondition="true"/>');
		}
	}
	push(@{$output},'</listOfSpecies>');
	push(@{$output},'<listOfReactions>');
	my $mdlrxns = $self->modelreactions();
	for (my $i=0; $i < @{$mdlrxns}; $i++) {
		my $rxn = $mdlrxns->[$i];
		my $reversibility = "true";
		my $lb = -1000;
		if ($rxn->direction() ne "=") {
			$lb = 0;
			$reversibility = "false";
		}
		push(@{$output},'<reaction '.$stringToString->("id",$rxn->id()).' '.$stringToString->("name",$rxn->name()).' '.$stringToString->("reversible",$reversibility).'>');
		push(@{$output},"<notes>");
		my $ec = $rxn->reaction->getAlias("Enzyme Class");
		my $keggID = $rxn->reaction->getAlias("KEGG");
		my $GeneAssociation = $rxn->gprString;
		my $ProteinAssociation = $rxn->gprString;
		push(@{$output},"<html:p>GENE_ASSOCIATION:".$GeneAssociation."</html:p>");
		push(@{$output},"<html:p>PROTEIN_ASSOCIATION:".$ProteinAssociation."</html:p>");
		if (defined($keggID)) {
			push(@{$output},"<html:p>KEGG_RID:".$keggID."</html:p>");
		}
		if (defined($ec)) {
			push(@{$output},"<html:p>PROTEIN_CLASS:".$ec."</html:p>");
		}
		push(@{$output},"</notes>");
		my $firstreact = 1;
		my $firstprod = 1;
		my $prodoutput = [];
		my $rgts = $rxn->modelReactionReagents();
		my $sign = 1;
		if ($rxn->direction() eq "<") {
			$sign = -1;
		}
		for (my $i=0; $i < @{$rgts}; $i++) {
			my $rgt = $rgts->[$i];
			if ($sign*$rgt->coefficient() < 0) {
				if ($firstreact == 1) {
					$firstreact = 0;
					push(@{$output},"<listOfReactants>");
				}
				push(@{$output},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",(-1*$sign*$rgt->coefficient())).'/>');	
			} else {
				if ($firstprod == 1) {
					$firstprod = 0;
					push(@{$prodoutput},"<listOfProducts>");
				}
				push(@{$prodoutput},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",$sign*$rgt->coefficient()).'/>');
			}
		}
		if ($firstreact != 1) {
			push(@{$output},"</listOfReactants>");
		}
		if ($firstprod != 1) {
			push(@{$prodoutput},"</listOfProducts>");
		}
		push(@{$output},@{$prodoutput});
		push(@{$output},"<kineticLaw>");
		push(@{$output},"\t<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
		push(@{$output},"\t\t\t<ci> FLUX_VALUE </ci>");
		push(@{$output},"\t</math>");
		push(@{$output},"\t<listOfParameters>");
		push(@{$output},"\t\t<parameter id=\"LOWER_BOUND\" value=\"".$lb."\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"UPPER_BOUND\" value=\"1000\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"OBJECTIVE_COEFFICIENT\" value=\"0\"/>");
		push(@{$output},"\t\t<parameter id=\"FLUX_VALUE\" value=\"0.0\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t</listOfParameters>");
		push(@{$output},"</kineticLaw>");
		push(@{$output},'</reaction>');
	}
	my $bios = $self->biomasses();
	for (my $i=0; $i < @{$bios}; $i++) {
		my $rxn = $bios->[$i];
		my $obj = 0;
		if ($i==0) {
			$obj = 1;
		}
		my $reversibility = "false";
		push(@{$output},'<reaction '.$stringToString->("id","biomass".$i).' '.$stringToString->("name",$rxn->name()).' '.$stringToString->("reversible",$reversibility).'>');
		push(@{$output},"<notes>");
		push(@{$output},"<html:p>GENE_ASSOCIATION: </html:p>");
		push(@{$output},"<html:p>PROTEIN_ASSOCIATION: </html:p>");
		push(@{$output},"<html:p>SUBSYSTEM: </html:p>");
		push(@{$output},"<html:p>PROTEIN_CLASS: </html:p>");
		push(@{$output},"</notes>");
		my $firstreact = 1;
		my $firstprod = 1;
		my $prodoutput = [];
		my $biocpds = $rxn->biomasscompounds();
		for (my $i=0; $i < @{$biocpds}; $i++) {
			my $rgt = $biocpds->[$i];
			if ($rgt->coefficient() < 0) {
				if ($firstreact == 1) {
					$firstreact = 0;
					push(@{$output},"<listOfReactants>");
				}
				push(@{$output},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",-1*$rgt->coefficient()).'/>');	
			} else {
				if ($firstprod == 1) {
					$firstprod = 0;
					push(@{$prodoutput},"<listOfProducts>");
				}
				push(@{$prodoutput},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",$rgt->coefficient()).'/>');
			}
		}
		if ($firstreact != 1) {
			push(@{$output},"</listOfReactants>");
		}
		if ($firstprod != 1) {
			push(@{$prodoutput},"</listOfProducts>");
		}
		push(@{$output},@{$prodoutput});
		push(@{$output},"<kineticLaw>");
		push(@{$output},"\t<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
		push(@{$output},"\t\t\t<ci> FLUX_VALUE </ci>");
		push(@{$output},"\t</math>");
		push(@{$output},"\t<listOfParameters>");
		push(@{$output},"\t\t<parameter id=\"LOWER_BOUND\" value=\"0.0\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"UPPER_BOUND\" value=\"1000\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"OBJECTIVE_COEFFICIENT\" value=\"".$obj."\"/>");
		push(@{$output},"\t\t<parameter id=\"FLUX_VALUE\" value=\"0.0\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t</listOfParameters>");
		push(@{$output},"</kineticLaw>");
		push(@{$output},'</reaction>');
	}
	my $cpds = $self->modelcompounds();
	for (my $i=0; $i < @{$cpds}; $i++) {
		my $cpd = $cpds->[$i];
		my $lb = -1000;
		my $ub = 1000;
		if ($cpd->modelCompartmentLabel() =~ m/^e/ || $cpd->compound()->id() eq "cpd08636" || $cpd->compound()->id() eq "cpd11416" || $cpd->compound()->id() eq "cpd15302") {
			push(@{$output},'<reaction '.$stringToString->("id",'EX_'.$cpd->id()).' '.$stringToString->("name",'EX_'.$cpd->name()).' reversible="true">');
			push(@{$output},"\t".'<notes>');
			push(@{$output},"\t\t".'<html:p>GENE_ASSOCIATION: </html:p>');
			push(@{$output},"\t\t".'<html:p>PROTEIN_ASSOCIATION: </html:p>');
			push(@{$output},"\t\t".'<html:p>PROTEIN_CLASS: </html:p>');
			push(@{$output},"\t".'</notes>');
			push(@{$output},"\t".'<listOfReactants>');
			push(@{$output},"\t\t".'<speciesReference '.$stringToString->("species",$cpd->id()).' stoichiometry="1.000000"/>');
			push(@{$output},"\t".'</listOfReactants>');
			push(@{$output},"\t".'<listOfProducts>');
			push(@{$output},"\t\t".'<speciesReference '.$stringToString->("species",$cpd->compound()->id()."_b").' stoichiometry="1.000000"/>');
			push(@{$output},"\t".'</listOfProducts>');
			push(@{$output},"\t".'<kineticLaw>');
			push(@{$output},"\t\t".'<math xmlns="http://www.w3.org/1998/Math/MathML">');
			push(@{$output},"\t\t\t\t".'<ci> FLUX_VALUE </ci>');
			push(@{$output},"\t\t".'</math>');
			push(@{$output},"\t\t".'<listOfParameters>');
			push(@{$output},"\t\t\t".'<parameter id="LOWER_BOUND" value="'.$lb.'" units="mmol_per_gDW_per_hr"/>');
			push(@{$output},"\t\t\t".'<parameter id="UPPER_BOUND" value="'.$ub.'" units="mmol_per_gDW_per_hr"/>');
			push(@{$output},"\t\t\t".'<parameter id="OBJECTIVE_COEFFICIENT" value="0"/>');
			push(@{$output},"\t\t\t".'<parameter id="FLUX_VALUE" value="0.000000" units="mmol_per_gDW_per_hr"/>');
			push(@{$output},"\t\t".'</listOfParameters>');
			push(@{$output},"\t".'</kineticLaw>');
			push(@{$output},'</reaction>');
		}	
	}
	#Closing out the file
	push(@{$output},'</listOfReactions>');
	push(@{$output},'</model>');
	push(@{$output},'</sbml>');
	return join("\n",@{$output});
}

=head3 printExchange

Definition:
	string:Exchange format = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->printExchange();
Description:
	Returns a string with the model in Exchange format

=cut

sub printExchange {
    my $self = shift;
	my $output = "Model{";
	$output .= "attributes(id\tname\ttype\tannotation\tmapping\tbiochemistry){\n";
	$output .= $self->id()."\t".$self->name()."\t".$self->type()."\t".$self->genome_ref()."\t".$self->template_ref()."\n";
	$output .= "}\n";
	$output .= "compartments(id\tname\tph\tpotential){\n";
	my $comps = $self->modelcompartments();
	foreach my $comp (@{$comps}) {
		$output .= $comp->id()."\t".$comp->name()."\t".$comp->pH()."\t".$comp->potential()."\n";	
	}
	$output .= "}\n";
	$output .= "compounds(id\tname\tabbrev\tformula\tcharge){\n";
	my $compounds = $self->modelcompounds();
	foreach my $cpd (@{$compounds}) {
		$output .= $cpd->id()."\t".$cpd->name()."\t".$cpd->abbreviation()."\t".$cpd->formula()."\t".$cpd->charge()."\n";
	}
	$output .= "}\n";
	$output .= "reactions(id\tname\tabbrev\tequation\tgpr){\n";
	my $reactions = $self->modelreactions();
	foreach my $rxn (@{$reactions}) {
		$output .= $rxn->id()."\t".$rxn->name()."\t".$rxn->abbreviation()."\t".$rxn->equation()."\t".$rxn->exchangeGPRString()."\n";
	}
	$output .= "}\n";
	$output .= "biomasses(id\tname\tequation){\n";
	my $biomasses = $self->biomasses();
	foreach my $bio (@{$biomasses}) {
		$output .= $bio->id()."\t".$bio->name()."\t".$bio->modelequation()."\n";
	}
	$output .= "}\n";
	$output .= "}\n";
	return $output;
}

=head3 printModelSEED

Definition:
	string:Exchange format = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->printModelSEED();
Description:
	Returns a string with the model in ModelSEED format

=cut

sub printModelSEED {
    my $self = shift;
	my $output = "REACTIONS\n";
	$output .= "LOAD;DIRECTIONALITY;COMPARTMENT;ASSOCIATED PEG;EQUATION;SUBSYSTEM;CONFIDENCE;REFERENCE;NOTES\n";
	my $reactions = $self->modelreactions();
	foreach my $rxn (@{$reactions}) {
		my $dir = $rxn->direction();
		if ($dir eq ">") {
			$dir = "=>";
		} elsif ($dir eq "<") {
			$dir = "<=";
		} elsif ($dir eq "=") {
			$dir = "<=>";
		}
		my $gpr = $rxn->gprString();
		$gpr =~ s/fig\|\d+\.\d+\.//g;
		$output .= $rxn->reaction()->id().";".$dir.";c;".$gpr.";".$rxn->equation().";none;1;none;none\n";
	}
	my $biomasses = $self->biomasses();
	$output .= "NAME\t".$biomasses->[0]->id()."\n";
	$output .= "DATABASE\t".$biomasses->[0]->name()."\n";
	my $equation = $biomasses->[0]->modelequation();
	$equation =~ s/_c0//g;
	$equation =~ s/\+/ + /g;
	$equation =~ s/=>/ => /g;
	$equation =~ s/\)/) /g;
	$output .= "EQUATION\t".$equation."\n";
	return $output;
}

sub htmlComponents {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([],{}, @_);
	my $data = $self->_createReadableData();
	my $output = {
		title => $self->_type()." Viewer",
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
	$output->{tabs}->{main}->{content} .= "</table>\n";
	my $id;
	my $name;
	foreach my $subobject (@{$data->{subobjects}}) {
		if ($subobject->{name} ne "biomasses") {
			if ($subobject->{name} eq "modelcompartments") {
				$id = "tab-2";
				$name = "Compartments";
			} elsif ($subobject->{name} eq "modelcompounds") {
				$id = "tab-3";
				$name = "Compounds";
			} elsif ($subobject->{name} eq "modelreactions") {
				$id = "tab-4";
				$name = "Reactions";
			}
			push(@{$output->{tablist}},$id);
			$output->{tabs}->{$id} = {
                                content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $subobject->{headings}, $subobject->{data}, 'data-table'),
				name => $name
			};
		}
	}
	push(@{$output->{tablist}},("tab-5","tab-6","tab-7"));
	my $headingsOne = ["Biomass","DNA","RNA","Protein","Cellwall","Lipid","Cofactor","Energy"];
	my $headingsTwo = ["Biomass","Model compound","Name","Compartment","Coefficient"];
        my $dataOne = [];
        my $dataTwo = [];
	my $biomasses = $self->biomasses();
	foreach my $bio (@{$biomasses}) {
                push(@$dataOne, [ $bio->id(), $bio->dna(), $bio->rna(), $bio->protein(), $bio->cellwall(), $bio->lipid(), $bio->cofactor(), $bio->energy() ]);
		my $biocpds = $bio->biomasscompounds();
		foreach my $biocpd (@{$biocpds}) {
			if ($biocpd->coefficient() < 0) {
                                push(@$dataTwo, [ $bio->id(), $biocpd->modelcompound()->id(), $biocpd->modelcompound()->name(), $biocpd->modelcompound()->modelcompartment()->id(), $biocpd->coefficient() ]);
			}
		}
		foreach my $biocpd (@{$biocpds}) {
			if ($biocpd->coefficient() >= 0) {
                                push(@$dataTwo, [ $bio->id(), $biocpd->modelcompound()->id(), $biocpd->modelcompound()->name(), $biocpd->modelcompound()->modelcompartment()->id(), $biocpd->coefficient() ]);
			}
		}
	}
	my $tableOne = Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' );
	my $tableTwo = Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsTwo, $dataTwo, 'data-table' );
	$output->{tabs}->{"tab-5"} = {
		content => $tableOne."<br>".$tableTwo,
		name => "Biomass reactions"
	};
	$headingsOne = ["Integrated","Gapfill simulation","Media","Solution","Cost","Gapfilled reaction","Biomass removal","Media supplement"];
        $dataOne = [];
	my $mgfs = $self->gapfillings();
	foreach my $mgf (@{$mgfs}) {
		my $gf = $mgf->gapfill();
		if (defined($gf->gapfillingSolutions()->[0])) {
			my $count = 0;
			foreach my $sol (@{$gf->gapfillingSolutions()}) {
				my $rxns = "";
				my $bios = "";
				my $medias = "";
				foreach my $rxn (@{$sol->gapfillingSolutionReactions()}) {
					if (length($rxns)) {
						$rxns .= "<br>";
					}
					$rxns .= $rxn->reaction()->id().":".$rxn->reaction()->definition();
				}
				foreach my $cpd (@{$sol->mediaSupplements()}) {
					if (length($medias)) {
						$medias .= "<br>";
					}
					$medias .= $cpd->id().":".$cpd->name();
				}
				foreach my $bio (@{$sol->biomassRemovals()}) {
					if (length($bios)) {
						$bios .= "<br>";
					}
					$bios .= $bio->id().":".$bio->name();
				}
				my $integrated = "No";
				if ($sol->integrated() == 1) {
					$integrated	= "Yes";
				}
                                push(@$dataOne, [ $integrated, $gf->id(), $gf->fbaFormulation()->media()->_reference(), $count, $sol->solutionCost(), $rxns, $bios, $medias ]);
				$count++;
			}
		} else {
                    push(@$dataOne, [ "No", $gf->id(), $gf->fbaFormulation()->media()->_reference(), "None", "None", "None", "None", "None" ]);
		}
	}
	$output->{tabs}->{"tab-6"} = {
		content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
		name => "Gapfilling"
	};
	$headingsOne = ["Integrated","Gapgen simulation","Media","Solution","Cost","Removed reaction","Biomass addition","Media removal"];
        $dataOne = [];
	my $mggs = $self->gapgens();
	foreach my $mgg (@{$mggs}) {
		my $gg = $mgg->gapgen();
		if (defined($gg->gapgenSolutions()->[0])) {
			my $count = 0;
			foreach my $sol (@{$gg->gapgenSolutions()}) {
				my $rxns = "";
				my $bios = "";
				my $medias = "";
				foreach my $rxn (@{$sol->gapgenSolutionReactions()}) {
					if (length($rxns)) {
						$rxns .= "<br>";
					}
					$rxns .= $rxn->modelreaction()->id().":".$rxn->reaction()->definition();
				}
				foreach my $cpd (@{$sol->mediaRemovals()}) {
					if (length($medias)) {
						$medias .= "<br>";
					}
					$medias .= $cpd->id().":".$cpd->name();
				}
				foreach my $bio (@{$sol->biomassSupplements()}) {
					if (length($bios)) {
						$bios .= "<br>";
					}
					$bios .= $bio->id().":".$bio->name();
				}
				my $integrated = "No";
				if ($sol->integrated() == 1) {
					$integrated	= "Yes";
				}
                                push(@$dataOne, [ $integrated, $gg->id(), $gg->fbaFormulation()->media()->_reference(), $count, $sol->solutionCost(), $rxns, $bios, $medias ]);
				$count++;
			}
		} else {
                        push(@$dataOne, [ "No", $gg->id(), $gg->fbaFormulation()->media()->_reference(), "None", "None", "None", "None", "None" ]);
		}
	}
	$output->{tabs}->{"tab-7"} = {
		content => Bio::KBase::ObjectAPI::utilities::PRINTHTMLTABLE( $headingsOne, $dataOne, 'data-table' ),
		name => "Gapgen"
	};
	return $output;
}

=head3 export

Definition:
	string = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->export();
Description:
	Exports model data to the specified format.

=cut

sub export {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["format"], {}, @_);
	if (lc($args->{format}) eq "sbml") {
		return $self->printSBML();
	} elsif (lc($args->{format}) eq "exchange") {
		return $self->printExchange();
	} elsif (lc($args->{format}) eq "readable") {
		return $self->toReadableString();
	} elsif (lc($args->{format}) eq "html") {
		return $self->createHTML();
	} elsif (lc($args->{format}) eq "json") {
		return $self->toJSON({pp => 1});
	} elsif (lc($args->{format}) eq "cytoseed") {
		return $self->printCytoSEED();
	} elsif (lc($args->{format}) eq "modelseed") {
		return $self->printModelSEED();
	} elsif (lc($args->{format}) eq "excel") {
		return $self->printExcel();
	}
	Bio::KBase::ObjectAPI::utilities::error("Unrecognized type for export: ".$args->{format});
}

=head3 printExcel

Definition:
	string printExcel();
Description:
	Prints model data in excel

=cut

sub printExcel {
	my ($self) = @_;
	#my ($fh, $filename) = File::Temp::tempfile("xls-XXXXXX");
    #close($fh);
    my $filename = "/Users/chenry/model.xls";
	require "Spreadsheet/WriteExcel.pm";
	my $wkbk = Spreadsheet::WriteExcel->new($filename);
	my $sheet = $wkbk->add_worksheet("Compounds");
	$sheet->write_row(0,0,["ID","Name","Abbreviation","Formula","Charge","DeltaG","Compartment"]);
	my $cpds = $self->modelcompounds();
	for (my $i=0; $i < @{$cpds}; $i++) {
		my $cpd = $cpds->[$i];
		$sheet->write_row($i+1,0,[$cpd->compound()->id(),$cpd->compound()->name(),$cpd->compound()->abbreviation(),$cpd->compound()->formula(),$cpd->compound()->defaultCharge(),$cpd->compound()->deltaG(),$cpd->modelcompartment()->label()]);
	}	
	$sheet = $wkbk->add_worksheet("Reactions");
	$sheet->write_row(0,0,["ID","Name","Equation","Definition","EC","Compartment","DeltaG"]);
	my $rxns = $self->modelreactions();
	for (my $i=0; $i < @{$rxns}; $i++) {
		my $rxn = $rxns->[$i];
		$sheet->write_row($i+1,0,[$rxn->reaction()->id(),$rxn->reaction()->name(),$rxn->reaction()->equation(),$rxn->reaction()->definition(),join("|",@{$rxn->reaction()->getAliases("Enzyme Class")}),$rxn->modelcompartment()->label(),$rxn->reaction()->deltaG()]);
	}
	$sheet = $wkbk->add_worksheet("Genes");
	$sheet->write_row(0,0,["ID","Type","Functions","Contig","Start","Stop","Direction","Reactions"]);
	my $ftrs = $self->annotation()->features();
	my $ftrHash = $self->featureHash();
	for (my $i=0; $i < @{$ftrs}; $i++) {
		my $ftr = $ftrs->[$i];
		my $reactionList = [];
		foreach my $rxnuuid (keys(%{$ftrHash->{$ftr->_reference()}})) {
			push(@{$reactionList},$ftrHash->{$ftr->_reference()}->{$rxnuuid}->id());
		}
		$sheet->write_row($i+1,0,[$ftr->id(),$ftr->type(),$ftr->roleList(),$ftr->contig(),$ftr->start(),$ftr->stop(),$ftr->direction(),join("|",@{$reactionList})]);
	}
	my $output;
	open(my $fh, "<:raw", $filename);
	my $data = <$fh>;
	close($fh);
	return $data;
}

=head3 printCytoSEED

Definition:
	void Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->printCytoSEED();
Description:
	Prints the model in CytoSEED format

=cut

sub printCytoSEED {
	my ($self,$args) = @_;

	sub compound_to_results {
	    my ($compound, $abstract_compounds, $modelid) = @_;
	   	my $abstractCpd;
	    if (defined($compound->abstractCompound_ref) && $compound->abstractCompound_ref =~ m/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/) {
	    	$abstractCpd = $compound->abstractCompound();
	    }
	    $abstract_compounds->{$abstractCpd->id()} = 1 if defined $abstractCpd;
	    my $keggids = $compound->getAliases("KEGG");
	    # make a copy to keep YAML happy
	    my @keggids = $keggids ? @$keggids : ();
	    my $msid = $compound->id();
	    return ($msid, { "ABBREV" => [$compound->abbreviation()],
			     "NAME" => [$compound->name()],
			     "DATABASE" => [$msid],
			     "FORMULA" => [$compound->formula()],
			     "GROUPING" => [], # FIX
			     "KEGGID" => \@keggids },
		    (defined $abstractCpd) ? [ $abstractCpd->id() ] : []);
	}

	sub reaction_to_results {
	    my ($reaction, $modelreaction, $abstract_reactions, $modelid) = @_;
	    my $abstractRxn;
	    if (defined($reaction->abstractReaction_ref) && $reaction->abstractReaction_ref =~ m/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/) {
	    	$abstractRxn = $reaction->abstractReaction();
	    }
	    $abstract_reactions->{$abstractRxn->id()} = 1 if defined $abstractRxn;
	    my $keggids = $reaction->getAliases("KEGG");
	    # make a copy to keep YAML happy
	    my @keggids = $keggids ? @$keggids : ();
	    my $ecs = $reaction->getAliases("Enzyme Class");
	    my $msid = $reaction->id();
	    my (@substrates, @products);
	    foreach my $reagent (@{$reaction->reagents()}) {
		my $compound = $reagent->compound();
		my $coeff = $reagent->coefficient();
		my $compartment = $reagent->compartment;
		my $cmsid = $compound->id();
		$cmsid = $cmsid."[".$compartment->id()."]" if $compartment->id() ne "c";
		if ($coeff < 0) {
		    if ($coeff == -1) {
			push @substrates, $cmsid;
		    }
		    else {
			push @substrates, "(".(abs $coeff).") ".$cmsid;
		    }
		}
		else {
		    if ($coeff == 1) {
			push @products, $cmsid;
		    }
		    else {
			push @products, "(".(abs $coeff).") ".$cmsid;
		    }
		}
	    }
	    my $equation = (join " + ", @substrates)." <=> ".(join " + ",  @products);

	    my $reversibility = $reaction->thermoReversibility();

	    if (! defined $reversibility) {
		print STDERR "No reversibility for $msid\n";
		$reversibility = "=";
	    }

	    $reversibility = "<=>" if $reversibility eq "=";
	    my $rdref = { "DATABASE" => [$msid],
			  "NAME" => [$reaction->name()],
			  "EQUATION" => [$equation],
			  "REVERSIBILITY" => [$reversibility],
			  "ENZYME" => $ecs,
			  "KEGG MAPS" => [], #FIX
			  "KEGGID" => \@keggids };

	    if (defined $modelreaction) {
		my %pegs;
		my %notes;
		foreach my $protein (@{$modelreaction->modelReactionProteins()}) {
		    $notes{$protein->note()} = 1 if defined $protein->note();
		    foreach my $subunit (@{$protein->modelReactionProteinSubunits()}) {
			$notes{$subunit->note()} = 1 if defined $protein->note();
			foreach my $gene (@{$subunit->modelReactionProteinSubunitGenes()}) {
			    my $feature = $gene->feature();
			    $pegs{$feature->id()} = 1 if defined $feature->id();
			}
		    }
		}
		my @pegs = keys %pegs;
		my @notes = keys %notes;
		# $modelid is a global variable
		$rdref->{$modelid} = { "SUBSYSTEM" => [],
				       "ASSOCIATED PEG" => @pegs == 0 ? \@notes : \@pegs, # notes contain GAP FILLING
				       "NOTES" => \@notes };
	    }
	    
	    return ($msid, $rdref, (defined $abstractRxn) ? [ $abstractRxn->id() ] : []);
	}

	my $model = $self;
	my $modelid = $model->id();
	my (%abstract_compounds, %abstract_reactions);
	my $result = {};
	my $bc = $model->biochemistry();
	my $annotation = $model->annotation();
	my $genome = $annotation->genomes()->[0];

	$result->{"model_data"} = {"Genome" => "ID:".$genome->id(), 
				   "Id" => $modelid, 
				   "Name" => $genome->name(), 
				   "Media" => "Complete", # FIX
				   "Source" => $genome->source()};

	my $compounds = $model->modelcompounds();
	my $reactions = $model->modelreactions();

	foreach my $modelcompound (@$compounds) {
	    my $compound = $modelcompound->compound();
	    my ($msid, $cdref, $extra) = compound_to_results($compound, \%abstract_compounds, $modelid);
	    $cdref->{"ABSTRACT COMPOUND"} = $extra;
	    $result->{"compound_details"}->{$msid} = $cdref;
	}

# now the abstract compounds are loaded into the hash
	$result->{"abstract_compound_details"} = {};
	foreach my $abstract_cpd (keys %abstract_compounds) {
	    my $a_cpd = $bc->getObjectByAlias("compounds", $abstract_cpd, "ModelSEED");
	    my ($msid, $cdref) = compound_to_results($a_cpd, \%abstract_compounds, $modelid);
	    $cdref->{"GROUPING"} = []; # FIX
	    $result->{"abstract_compound_details"}->{$msid} = $cdref;
	}

	foreach my $modelreaction (@$reactions) {
	    my $reaction = $modelreaction->reaction();
	    my ($msid, $rdref, $extra) = reaction_to_results($reaction, $modelreaction, \%abstract_reactions, $modelid);
	    $rdref->{"ABSTRACT REACTION"} = $extra;
	    $result->{"reaction_details"}->{$msid} = $rdref;
	}

	$result->{"abstract_reaction_details"} = {};
	foreach my $abstract_rxn (keys %abstract_reactions) {
	    my $a_rxn = $bc->getObjectByAlias("reactions", $abstract_rxn, "ModelSEED");
	    my ($msid, $rdref) = reaction_to_results($a_rxn, undef, \%abstract_reactions, $modelid);
	    $rdref->{"GROUPING"} = []; # FIX
	    $result->{"abstract_reaction_details"}->{$msid} = $rdref;
	}

	my $biomasses = $model->biomasses();
	my $biomass;

	if (@$biomasses == 0) {
	    print STDERR "No biomass\n";
	    $result->{"biomass_reaction_details"} = {};
	}
	else {
	    $biomass = $biomasses->[0];
	    if (@$biomasses != 1) {
		print STDERR "Multiple biomasses, using the first one\n";
	    }

	    my (@substrates, @products);
	    foreach my $bmcpd (@{$biomass->biomasscompounds()}) {
		my $modelcompound = $bmcpd->modelcompound();
		my $coeff = $bmcpd->coefficient();
		my $compound = $modelcompound->compound();
		my $cmsid = $compound->id();
		if ($coeff < 0) {
		    if ($coeff == -1) {
			push @substrates, $cmsid;
		    }
		    else {
			push @substrates, "(".(abs $coeff).") ".$cmsid;
		    }
		}
		else {
		    if ($coeff == 1) {
			push @products, $cmsid;
		    }
		    else {
			push @products, "(".(abs $coeff).") ".$cmsid;
		    }
		}
	    }
	    my $equation = (join " + ", @substrates)." <=> ".(join " + ",  @products);

	    $result->{"biomass_reaction_details"} = { 
		$modelid => {
		    "DATABASE" => [$biomass->id()], 
		    "EQUATION" => [$equation] 
		}
	    };
	}

	my $fba_results = [];
	my $reaction_classifications = {};

	foreach my $fbaFormulation (@{$model->fbaFormulations()}) {
	    if (! defined $fbaFormulation) {
		print STDERR "FBA formulation is not defined\n";
		next;
	    }
	    if ($fbaFormulation->maximizeObjective()) {
		my @fbaFormulationResults = @{$fbaFormulation->fbaResults()};
		if (@fbaFormulationResults != 1) {
		    print STDERR "Expected 1 fbaResult, got: ", scalar @fbaFormulationResults, "\n";
		    next;
		}
		my $fbaResult = $fbaFormulationResults[0];
		my $fba = {};
		my $fluxes = [];
		$fba->{"fluxes"} = $fluxes;
		$fba->{"media"} = $fbaFormulation->media()->name();
		$fba->{"time"} = $fbaFormulation->modDate();
		$fba->{"growth"} = $fbaResult->objectiveValue();
		my @reactionVariables = @{$fbaResult->fbaReactionVariables()};
		next if @reactionVariables == 0; # FBA failed

		if ($fbaFormulation->fva()) {
		    my @classifications;

		    foreach my $rVar (@reactionVariables) {
			my $modelreaction = $rVar->modelreaction();
			my $reaction = $modelreaction->reaction();
			push @classifications, [$reaction->id(), $rVar->{"class"}, $rVar->{"min"}, $rVar->{"max"}, $rVar->{"value"}];
		    }

		    # roundabout way to get biomass result since the biomass reaction variable isn't being saved
		    foreach my $cVar (@{$fbaResult->fbaCompoundVariables()}) {
			my $modelcpd = $cVar->modelcompound();
			my $cpd = $modelcpd->compound();
			next unless $cpd->id() eq 'cpd11416';
			push @classifications, [$biomass->id(), "Positive", -$cVar->{"max"}, -$cVar->{"min"}, -$cVar->{"value"}];
		    }

		    foreach my $rxnInfo (@classifications) {
			my ($rid, $class, $min, $max, $value) = @$rxnInfo;
			my $flux = {};
			$flux->{"reaction"} = $rid;
			$flux->{"flux"} = $value;
			push @$fluxes, $flux;

			my $dir;
			if ($class eq "Positive") {
			    $class = "essential";
			    $dir = "=>";
			}
			elsif ($class eq "Negative") {
			    $class = "essential";
			    $dir = "<=";
			}
			elsif ($class eq "Positive variable") {
			    $class = "active";
			    $dir = "=>";
			}
			elsif ($class eq "Negative variable") {
			    $class = "active";
			    $dir = "<=";
			}
			elsif ($class eq "Variable") {
			    $class = "active";
			    $dir = "<=>";
			}
			elsif ($class eq "Blocked") {
			    $class = "dead";
			    $dir = "NA";
			}
			else {
			    print STDERR "For reaction ", $rid, ", class is ", $class, "\n";
			    $class = "dead";
			    $dir = "NA";
			}
			push @{$reaction_classifications->{$rid}->{"class"}}, $class;
			push @{$reaction_classifications->{$rid}->{"class_directionality"}}, $dir;
			push @{$reaction_classifications->{$rid}->{"max_flux"}}, $max;
			push @{$reaction_classifications->{$rid}->{"min_flux"}}, $min;
			push @{$reaction_classifications->{$rid}->{"media"}}, $fbaFormulation->media()->name();
			push @{$reaction_classifications->{$rid}->{"reaction"}}, $rid;
		    }
		}
		else {
		    push @{$fba_results}, $fba;
		}
	    }    
	}

	$result->{"fba_results"} = { $modelid => $fba_results };
	$result->{"reaction_classifications"}->{$modelid} = [values %$reaction_classifications];

	return YAML::XS::Dump $result;
}

#***********************************************************************************************************
# ANALYSIS FUNCTIONS:
#***********************************************************************************************************

=head3 gapfillModel

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::GapfillingSolution Bio::KBase::ObjectAPI::KBaseFBA::GapfillingSolution->gapfillModel({
		gapfillingFormulation => Bio::KBase::ObjectAPI::KBaseFBA::Gapfilling,
		fbaFormulation => Bio::KBase::ObjectAPI::KBaseFBA::FBA
	});
Description:
	Runs gapfilling on the model and integrates the output gapfilling solution

=cut

sub gapfillModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["gapfillingFormulation"],{
		fbaFormulation => undef,integrateSolution => 1
	}, @_);
	my $solution = $args->{gapfillingFormulation}->runGapFilling({
		model => $self,
		fbaFormulation => $args->{fbaFormulation}
	});
	if (defined($solution)) {
		push(@{$self->fbaFormulation_refs()},$args->{gapfillingFormulation}->fbaFormulation_ref());
		push(@{$self->unintegratedGapfilling_refs()},$args->{gapfillingFormulation}->_reference());
		return $solution;	
	}
	return;
}

=head3 integrateGapfillSolution

Definition:
	void Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->integrateGapfillSolution({
		solution => Bio::KBase::ObjectAPI::KBaseFBA::Gapfilling*
	});
Description:
	Integrates a gapfilling solution into the model
	
=cut

sub integrateGapfillSolution {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["gapfill"], { solution => undef,rxnProbGpr => undef }, @_);
	Bio::KBase::ObjectAPI::utilities::verbose("Now integrating gapfill solution into model");
	my $gfmeta = $self->getObject("gapfillings",$args->{gapfill});
	if (!defined($gfmeta)) {
		Bio::KBase::ObjectAPI::utilities::error("Gapfill ".$args->{gapfill}." not found!");
	}
	my $gf = $gfmeta->gapfill();
	my $sol;
	if (!defined($args->{solution})) {
		$args->{solution} = $gf->gapfillingSolutions()->[0]->id();
	}
	$sol = $gf->getObject("gapfillingSolutions",$args->{solution});
	if (!defined($sol)) {
		Bio::KBase::ObjectAPI::utilities::error("Solution ".$args->{solution}." not found in gapfill ".$args->{gapfill}."!");
	}
	$gfmeta->integrated(1);
	$gfmeta->integrated_solution($args->{solution});
	my $IntegrationReport = {
		added => [],
		reversed => []
	};
	#Integrating biomass removals into model
	if (defined($sol->biomassRemovals()) && @{$sol->biomassRemovals()} > 0) {
		my $removals = $sol->biomassRemovals();
		foreach my $rem (@{$removals}) {
            my $biomass = $self->biomasses()->[0];
			my $biocpds = $biomass->biomasscompounds();
			foreach my $biocpd (@{$biocpds}) {
				if ($biocpd->modelcompound()->_reference() eq $rem) {
					Bio::KBase::ObjectAPI::utilities::verbose(
						"Removing ".$biocpd->modelcompound()->id()." from model biomass."
					);
					$biomass->remove("biomasscompounds",$biocpd);
					last;
				}
			}
		}
	}	
	#Integrating new reactions into model
	my $rxns = $sol->gapfillingSolutionReactions();
	for (my $i=0; $i < @{$rxns}; $i++) {
		my $rxn = $rxns->[$i];
		my $rxnid = $rxn->reaction()->id();
		my $mdlrxn = $self->queryObject("modelreactions",{reaction_ref => $rxn->reaction_ref()});
		if (defined($mdlrxn) && $rxn->direction() ne $mdlrxn->direction()) {
			Bio::KBase::ObjectAPI::utilities::verbose(
				"Making ".$mdlrxn->id()." reversible."
			);
			push(@{$IntegrationReport->{reversed}},$rxnid);
			$mdlrxn->direction("=");
		} else {
			Bio::KBase::ObjectAPI::utilities::verbose(
				"Adding ".$rxn->reaction()->id()." to model in ".$rxn->direction()." direction."
			);
			push(@{$IntegrationReport->{added}},$rxnid);
			$self->addReactionToModel({
				reaction => $rxn->reaction(),
				direction => $rxn->direction()
			});
			# If RxnProbs object is defined, use it to assign GPRs to the integrated reactions.
			if (defined($args->{rxnProbGpr}) && defined($args->{rxnProbGpr}->{$rxnid})) {
			    $self->manualReactionAdjustment( { reaction => $rxnid,  gpr => $args->{rxnProbGpr}->{$rxnid} } );
			}
		}
	}
	#Checking if gapfilling formulation is in the unintegrated list 
	return $IntegrationReport;
}

=head3 gapgenModel

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::GapgenerationSolution = Bio::KBase::ObjectAPI::KBaseFBA::GapgenerationSolution->gapgenModel({
		gapgenFormulation => Bio::KBase::ObjectAPI::KBaseFBA::Gapgeneration,
		fbaFormulation => Bio::KBase::ObjectAPI::KBaseFBA::FBA
	});
Description:
	Runs gapgeneration on the model and integrates the output gapgeneration solution

=cut

sub gapgenModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["gapgenFormulation"], { fbaFormulation => undef,integrateSolution => 1 }, @_);
	my $solution = $args->{gapgenFormulation}->runGapGeneration({
		model => $self,
		fbaFormulation => $args->{fbaFormulation}
	});
	if (defined($solution)) {
		push(@{$self->fbaFormulation_refs()},$args->{gapgenFormulation}->fbaFormulation_ref());
		push(@{$self->gapgenFormulation_refs()},$args->{gapgenFormulation}->_reference());
		return $solution;	
	}
	return;
}

=head3 integrateGapgenSolution

Definition:
	void Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->integrateGapgenSolution({
		solution => Bio::KBase::ObjectAPI::KBaseFBA::Gapgeneration*
	});
Description:
	Integrates a gapgen solution into the model
	
=cut

sub integrateGapgenSolution {
	my $self = shift;
    my $args = Bio::KBase::ObjectAPI::utilities::args(["gapgen"], { solution => undef }, @_);
	Bio::KBase::ObjectAPI::utilities::verbose("Now integrating gapgen solution into model");
	my $ggmeta = $self->getObject("gapgens",$args->{gapgen});
	if (!defined($ggmeta)) {
		Bio::KBase::ObjectAPI::utilities::error("Gapgen ".$args->{gapgen}." not found!");
	}
	my $gg = $ggmeta->gapgen();
	my $sol;
	if (!defined($args->{solution})) {
		$args->{solution} = $gg->gapgenSolutions()->[0]->id();
	}
	$sol = $gg->getObject("gapgenSolutions",$args->{solution});
	if (!defined($sol)) {
		Bio::KBase::ObjectAPI::utilities::error("Solution ".$args->{solution}." not found in gapgen ".$args->{gapgen}."!");
	}
	$ggmeta->integrated(1);
	$ggmeta->integrated_solution($args->{solution});
	my $solrxns = $sol->gapgenSolutionReactions();
	for (my $m=0; $m < @{$solrxns}; $m++) {
		my $rxn = $solrxns->[$m];
        my $direction = $rxn->direction;
		if ($direction eq $rxn->modelreaction()->direction()) {
			Bio::KBase::ObjectAPI::utilities::verbose("Reaction ".$rxn->modelreaction()->id()." removed.");
			$self->remove("modelreactions",$rxn->modelreaction());
		} elsif ($direction eq ">") {
			Bio::KBase::ObjectAPI::utilities::verbose("Reaction ".$rxn->modelreaction()->id()." switched to <.");
			$rxn->modelreaction()->direction("<");
		} elsif ($direction eq "<") {
			Bio::KBase::ObjectAPI::utilities::verbose("Reaction ".$rxn->modelreaction()->id()." switched to >.");
			$rxn->modelreaction()->direction(">");
		}
	}
}

sub printExchangeFormat {
	my ($self) = @_;
    my $textArray = [
    	"Attributes {",
    	"\tname:".$self->name(),
    	"\tdefaultNameSapce:".$self->defaultNameSpace(),
    	"}",
    	"Biomasses (biomassReaction	compound	coefficient	compartment) {"
	];
	my $bios = $self->biomasses();
	for (my $i=0; $i < @{$bios}; $i++) {
		my $biocpds = $bios->[$i]->biomasscompounds();
		for (my $j=0; $j < @{$biocpds}; $j++) {
			my $items = ["biomass".$i];
			$items->[1] = "Compound/".$self->defaultNameSpace()."/".$biocpds->[$j]->modelcompound()->compound()->id();
			$items->[2] = $biocpds->[$j]->coefficient();
			$items->[3] = $biocpds->[$j]->modelcompound()->compartmentLabel();
			push(@{$textArray},"\t".join("\t",@{$items}));
		}
	}
	push(@{$textArray},("}","Reactions (reaction	direction	compartment	gpr) {"));
    my $reactions = $self->modelreactions();
	my $rows;
	foreach my $reaction (@$reactions) {
        my $rxn_id = $reaction->reaction()->id;
        my $dir    = $reaction->direction;
        my $cmp_id = $reaction->modelcompartment->label;
        my $gpr    = $self->_make_GPR_string($reaction);
        push(@$rows, [$rxn_id, $dir, $cmp_id, $gpr]);
    }
   	push(@{$textArray},"}");
    return join("\n",@{$textArray});
}

=head3 buildGraph

Definition:
	Graph = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->buildGraph();
Description:
	This command builds a graph object from the model

=cut

sub buildGraph {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([], {reactions => 0}, @_);
	my $graph = Graph::Undirected->new;
	if ($args->{reactions} == 0) {
		my $cpds = $self->modelcompounds();
		for (my $i=0;$i < @{$cpds}; $i++) {
			my $v = $cpds->[$i]->id();
			$graph->add_vertex($v);
		}
	}
	my $rxns = $self->modelreactions();
	my $rxnStartHash;
        my $removerxns = { "rxn05296_c0"=>1, "rxn05294_c0"=>1, "rxn05295_c0"=>1 }; # Protein, DNA, RNA synthesis should be removed
	
	for (my $i=0; $i < @{$rxns}; $i++) {
		next if (exists $removerxns->{$rxns->[$i]->id()});
		if ($args->{reactions} == 1) {
#		    print STDERR "Adding vertex for ", $rxns->[$i]->id(), "\n";
		    $graph->add_vertex($rxns->[$i]->id());
		}
		my $rgts = $rxns->[$i]->modelReactionReagents();
		for (my $j=0; $j < @{$rgts}; $j++) {
			my $rgt = $rgts->[$j];
			if (!$rgt->isCofactor() && $rgt->coefficient() < 0 && $rxns->[$i]->direction() ne "<") {
				if ($args->{reactions} == 1) {
#				    print STDERR "\tAdding ", $rgt->modelcompound()->id(), " as a start cpd\n";
				    $rxnStartHash->{$rgt->modelcompound()->id()}->{$rxns->[$i]->id()} = 1;
				} else {
					for (my $k=0; $k < @{$rgts}; $k++) {
						my $prod = $rgts->[$k];
						if (!$prod->isCofactor() && $prod->coefficient() > 0) {
							$graph->add_edge($rgt->modelcompound()->id(),$prod->modelcompound()->id());
						}
					}
				}
			} elsif (!$rgt->isCofactor() && $rgt->coefficient() > 0 && $rxns->[$i]->direction() ne ">") {
				if ($args->{reactions} == 1) {
#				    print STDERR "\tAdding ", $rgt->modelcompound()->id(), " as a start cpd\n";
				    $rxnStartHash->{$rgt->modelcompound()->id()}->{$rxns->[$i]->id()} = 1;
				} else {
					for (my $k=0; $k < @{$rgts}; $k++) {
						my $prod = $rgts->[$k];
						if (!$prod->isCofactor() && $prod->coefficient() < 0) {
							$graph->add_edge($rgt->modelcompound()->id(),$prod->modelcompound()->id());
						}
					}
				}
			}
		}
	}
	if ($args->{reactions} == 1) {
		for (my $i=0; $i < @{$rxns}; $i++) {
		    next if (exists $removerxns->{$rxns->[$i]->id()});
			my $rgts = $rxns->[$i]->modelReactionReagents();
			for (my $j=0; $j < @{$rgts}; $j++) {
				my $rgt = $rgts->[$j];
				if (!$rgt->isCofactor() && $rgt->coefficient() > 0 && $rxns->[$i]->direction() ne "<") {
					foreach my $rxnid (keys(%{$rxnStartHash->{$rgt->modelcompound()->id()}})) {
					    next if $rxns->[$i]->id() eq $rxnid;
#					    print STDERR "Adding an edge for ", $rxns->[$i]->id(), " and ", $rxnid, " based on ", $rgt->modelcompound()->id(), "\n";
					    $graph->add_edge($rxns->[$i]->id(),$rxnid);
					}
				} elsif (!$rgt->isCofactor() && $rgt->coefficient() < 0 && $rxns->[$i]->direction() ne ">") {
					foreach my $rxnid (keys(%{$rxnStartHash->{$rgt->modelcompound()->id()}})) {
					    next if $rxns->[$i]->id() eq $rxnid;
#					    print STDERR "Adding an edge for ", $rxns->[$i]->id(), " and ", $rxnid, " based on ", $rgt->modelcompound()->id(), "\n";
					    $graph->add_edge($rxns->[$i]->id(),$rxnid);
					}
				}
			}
		}
	}
	return $graph;
}

sub mark_cofactors {
    my $mrxns = shift @_;
	#Set cofactor.
    # list of cofactors that don't always come in pairs; some of these have biosynthetic pathways
    # and should NOT be marked as a cofactor in the very last reaction(s) that synthesize
    # them, so each one can have a list of special case reactions
    my $list = [
#	["cpd00002" => {"rxn00062" => 1,"rxn05145" => 1,"rxn10042" => 1,"rxn00062" => 1,"rxn00097" => 1, "rxn00065" => 1}], # ATP
#	["cpd00008" => {"rxn10042" => 1,"rxn00062" => 1,"rxn00097" => 1, "rxn10052" => 1, "rxn00095" => 1}], # ADP
	["cpd00001" => {"rxn00008" => 1,"rxn00066" => 1, "rxn05319" => 1}], # H2O
	["cpd00009" => {"rxn00001" => 1,"rxn05145" => 1, "rxn00001" => 1, "rxn05312" => 1}], # Pi
	["cpd00010" => {"rxn00100" => 1}], #CoA
	["cpd00011" => {"rxn10114" => 1,"rxn00102" => 1, "rxn00114" => 1, "rxn05467" => 1, "rxn05064" => 1, "rxn00002" => 1}], # CO2
	["cpd00012" => {"rxn00001" => 1,"rxn00104"=>1}], # PPi
	["cpd00421" => {"rxn00104" => 1}], # PPPi
	["cpd00013" => {"rxn05466" => 1, "rxn00114" => 1, "rxn05064" => 1, "rxn00002" => 1}], # NH3
#	["cpd00015" => {"rxn00122" => 1}], # FAD
	["cpd00067" => {}], # H+
	["cpd00099" => {"rxn10473" => 1}], # Cl-
	["cpd00007" => {"rxn00006" => 1, "rxn05468" => 1}], #O2
	["cpd00056" => {"rxn00438" => 1, "rxn00439" => 1, "rxn00440" => 1}], # TPP
	["cpd00449" => {}], # dihydrolipoamide
	["cpd11493" => {"rxn06022" =>1, "rxn06023" => 1}], # ACP
	["cpd00213" => {}], # lipoamide NEED SYNTHETIC STEP
	["cpd00103" => {"rxn00770" => 1, "rxn00789" => 1}], # PRPP 
	["cpd00052" => {"rxn00409" => 1, "rxn00410" => 1, "rxn00407" => 1}], # CTP 
	["cpd00046" => {"rxn00363" => 1, "rxn00364" => 1, "rxn00365" => 1, "rxn00368" => 1, "rxn00369" => 1, "rxn00707" => 1, "rxn01128" => 1, "rxn01510" => 1, "rxn01515" => 1, "rxn01705" => 1, "rxn01706" => 1}], # CMP 
	["cpd00475" => {"rxn00778" => 1}], # ribose 1-phosphate
	["cpd00509" => {"rxn01986" => 1}], # deoxy-ribose 1-phosphate 
	["cpd00014" => {"rxn00119" => 1, "rxn00712" => 1, "rxn06075" => 1, "rxn00117" => 1, "rxn00368" => 1}], # UDP 
	];

    # prioritized list, e.g., ATP/ADP come before Pyruvate/PEP
    my $pairlist = [
        ["cpd00002","cpd00008"],
	["cpd00015","cpd00982"],
        ["cpd00097","cpd00986"],
        ["cpd00109","cpd00110"],
        ["cpd11620","cpd11621"],
        ["cpd00228","cpd00823"],
        ["cpd11665","cpd11669"],
        ["cpd00733","cpd00734"],
        ["cpd11807","cpd11808"],
        ["cpd00364","cpd00415"],
        ["cpd12505","cpd12576"],
        ["cpd12669","cpd12694"],
        ["cpd00003","cpd00004"],
        ["cpd00005","cpd00006"],
        ["cpd00002","cpd00018"],
        ["cpd00008","cpd00018"],
        ["cpd00052","cpd00096"],
        ["cpd00052","cpd00046"],
        ["cpd00046","cpd00096"],
        ["cpd00062","cpd00091"],
        ["cpd00062","cpd00014"],
        ["cpd00014","cpd00091"],
        ["cpd00038","cpd00126"],
        ["cpd00038","cpd00031"],
        ["cpd00126","cpd00031"],
        ["cpd00357","cpd00793"],
        ["cpd00061","cpd00020"],
		["cpd15561","cpd15560"],
		["cpd15499","cpd15500"],
		["cpd11420","cpd11421"],
		["cpd00024","cpd00023"],
		["cpd00023","cpd00053"],
		["cpd00007","cpd00025"],
		["cpd15560","cpd15561"],
		["cpd15499","cpd15500"],
		["cpd15352","cpd15353"],
    ]; 

    foreach my $mrxn (@{$mrxns}) {
		my $rxn = $mrxn->reaction();
		my $rgts = $rxn->reagents();
		my $num_rgts = scalar @{$rgts};
		# first we will mark any compound that is a known cofactor,
		# unless this is a special case reaction
		foreach my $cofactorInfo (@$list) {
			my $cpdId = $cofactorInfo->[0];
			my $specialRxns = $cofactorInfo->[1];
			foreach my $rgt (@$rgts) {
			my $markIt = 0;
			if ($rgt->compound()->id() eq $cpdId) {
				#print STDERR "Found match on $cpdId for ", $rxn->id(), ", checking ", keys %$specialRxns, "\n";
				$markIt = 1 unless exists $specialRxns->{$rxn->id()};
				#print STDERR "markIt is $markIt\n";
			}
			if ($markIt) {
				$rgt->isCofactor(1);
				$num_rgts--;
			}
			}
		}

		# now we loop through the cofactor pairs and look for cofactors
		# on opposite sides of the equation
		foreach my $pair (@{$pairlist}) {
			# quit if we only have three compounds left
			# otherwise we may be left with no non-cofactors or just one
			last if $num_rgts <= 3;
			foreach my $rgt (@{$rgts}) {
				if ($rgt->compound()->id() eq $pair->[0]) {
					foreach my $rgtTwo (@{$rgts}) {
						if ($rgtTwo->compound()->id() eq $pair->[1]) {
							if ($rgt->coefficient()*$rgtTwo->coefficient() < 0) {
									$rgt->isCofactor(1);
									$rgtTwo->isCofactor(1);
									$num_rgts -= 2;
							}
						}
					}
				}
			}
		}
    }
}

=head3 computeNetworkDistances

Definition:
	Table = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->computeNetworkDistances();
Description:
	This command computes distances between all metabolites, reactions, and functional roles

=cut

sub computeNetworkDistances {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([], { reactions => 0, roles => 0, genes => 0 }, @_);
	my $input = {};
	my $tbl = {headings => ["Compounds"],data => []};
	$tbl->{detail} = [] if $args->{detail};
	if ($args->{genes} == 1 || $args->{roles} == 1 || $args->{reactions} == 1) {
		$input->{reactions} = 1;
		$tbl = {headings => ["Reactions"],data => []};
		if ($args->{roles} == 1) {
			$tbl = {headings => ["Roles"],data => []};
		}
		elsif ($args->{genes} == 1) {
			$tbl = {headings => ["Genes"],data => []};
		}
	}

    mark_cofactors($self->modelreactions());

# cofactor set.
	print STDERR "Building graph!\n";
	my $graph = $self->buildGraph($input);
	print STDERR "Computing distances!\n";
	my $apsp = $graph->all_pairs_shortest_paths();
	print STDERR "Shortest paths computed!\n";
	if ($args->{genes} == 1 || $args->{roles} == 1 || $args->{reactions} == 1) {
		my ($roleHash,%rxn2roles);
		my ($geneHash,%rxn2genes);
		my $rxns = $self->modelreactions();
		$tbl->{headings}->[0] = "Reactions";
		if ($args->{roles} == 1) {
			$tbl->{headings}->[0] = "Roles";
			for (my $i=0; $i < @{$rxns}; $i++) {
			    my $modelrxn = $rxns->[$i];
			    my @roles;
			    foreach my $protein (@{$modelrxn->modelReactionProteins()}) {
				foreach my $subunit (@{$protein->modelReactionProteinSubunits()}) {
				    push @roles, $subunit->role();
				}
			    }
			    $rxn2roles{$rxns->[$i]->id()} = \@roles;
			    for (my $j=0;$j < @roles; $j++) {
				$roleHash->{$roles[$j]->name()} = 1;
			    }
			}
			my $count = 0;
			foreach my $role (sort(keys(%{$roleHash}))) {
				$roleHash->{$role} = $count;
				$count++;				
			}
		}
		if ($args->{genes} == 1) {
			$tbl->{headings}->[0] = "Genes";
			for (my $i=0; $i < @{$rxns}; $i++) {
			    my $modelrxn = $rxns->[$i];
			    my %genes;
			    my $isUniversal = 0;
			    foreach my $protein (@{$modelrxn->modelReactionProteins()}) {
				if ((@{$protein->modelReactionProteinSubunits()} == 0) and (length($protein->note()) > 0)) {
				    $isUniversal = 1; # May need to check what is in note.
				}
				else {
				    foreach my $subunit (@{$protein->modelReactionProteinSubunits()}) {
					foreach my $subunitGene (@{$subunit->modelReactionProteinSubunitGenes()}) {
					    # push id rather than object itself because there is no object for unknown genes					   
					    $genes{$subunitGene->feature()->id()} = 1;
					}				    				    
				    }
				}
			    }		
			    # Calculate distance for Unknown gene, too.
			    if (keys %genes == 0 and !$isUniversal) {
				$genes{"Unknown:". $rxns->[$i]->id()} = 1;
			    }
			    my @genes = keys %genes;
			    $rxn2genes{$rxns->[$i]->id()} = \@genes;
			    for (my $j=0;$j < @genes; $j++) {
				$geneHash->{$genes[$j]} = 1;

			    }
			}
			my $count = 0;
			foreach my $role (sort(keys(%{$roleHash}))) {
				$roleHash->{$role} = $count;
				$count++;
			}
			foreach my $gene (sort(keys(%{$geneHash}))) {
				$geneHash->{$gene} = $count;
				$count++;
			}

		}

		for (my $i=0; $i < @{$rxns}; $i++) {
			if ($args->{reactions} == 1) {
				$tbl->{headings}->[$i+1] = $rxns->[$i]->id();
				$tbl->{data}->[$i]->[0] = $rxns->[$i]->id();
			} else {
				my $count = 0;
				foreach my $role (sort(keys(%{$roleHash}))) {
					$tbl->{headings}->[$count+1] = $role;
					$tbl->{data}->[$count]->[0] = $role;
					$count++;
				}
				foreach my $gene (sort(keys(%{$geneHash}))) {
					$tbl->{headings}->[$count+1] = $gene;
					$tbl->{data}->[$count]->[0] = $gene;
					$count++;
				}

			}
			for (my $j=0;$j < @{$rxns}; $j++) {
				if ($args->{reactions} == 1) {
				    if ($i == $j) {
						$tbl->{data}->[$i]->[$j+1] = 0;
				    } 
					else {
						my ($mindist, $vertices) = &shortest_path($rxns->[$i]->id(),  $rxns->[$j]->id(), $apsp);
						$tbl->{data}->[$i]->[$j+1] = $mindist;
						if ($args->{detail}) {
							$tbl->{data}->[$i]->[$j+1] .= "; @$vertices" if @$vertices > 0;
						}
				    }
				} elsif ($args->{roles} == 1) {
				        my @roles1 = @{$rxn2roles{$rxns->[$i]->id()}};
					for (my $k=0;$k < @roles1; $k++) {
						my $indexOne = $roleHash->{$roles1[$k]->name()};

						my @roles2 = @{$rxn2roles{$rxns->[$j]->id()}};
						for (my $m=0;$m < @roles2; $m++) {
							my $indexTwo = $roleHash->{$roles2[$m]->name()}+1;
							if (defined($tbl->{data}->[$indexOne]->[$indexTwo])) {
							    if ($apsp->path_length($rxns->[$i]->id(), $rxns->[$j]->id()) < $tbl->{data}->[$indexOne]->[$indexTwo]) {
								$tbl->{data}->[$indexOne]->[$indexTwo] = $apsp->path_length($rxns->[$i]->id(), $rxns->[$j]->id());
								if ($args->{detail}) {
								    my @vs = $apsp->path_vertices($rxns->[$i]->id(), $rxns->[$j]->id()); 
								    $tbl->{data}->[$indexOne]->[$indexTwo] .= "; @vs" if @vs > 0;
								}
							    }
							} else {
							    $tbl->{data}->[$indexOne]->[$indexTwo] = $apsp->path_length($rxns->[$i]->id(), $rxns->[$j]->id());
							    if ($args->{detail}) {
								my @vs = $apsp->path_vertices($rxns->[$i]->id(), $rxns->[$j]->id()); 
								$tbl->{data}->[$indexOne]->[$indexTwo] .= "; @vs" if @vs > 0;
							    }
							}
						}
					}
				}
				elsif ($args->{genes} == 1) {
				    my @genes1 = @{$rxn2genes{$rxns->[$i]->id()}};
					for (my $k=0;$k < @genes1; $k++) {
						my $indexOne = $geneHash->{$genes1[$k]};
						my @genes2 = @{$rxn2genes{$rxns->[$j]->id()}};
						for (my $m=0;$m < @genes2; $m++) {
							my $indexTwo = $geneHash->{$genes2[$m]}+1;
							if (defined($tbl->{data}->[$indexOne]->[$indexTwo])) {
							    my ($prev, undef) = split ";", $tbl->{data}->[$indexOne]->[$indexTwo];
							    my ($path_length, $vertices) = &shortest_path($rxns->[$i]->id(), $rxns->[$j]->id(), $apsp);
							    if (defined $path_length && ($path_length < $prev)) {
								$tbl->{data}->[$indexOne]->[$indexTwo] = $path_length;
								if ($args->{detail}) {
								    $tbl->{data}->[$indexOne]->[$indexTwo] .= "; @$vertices" if @$vertices > 0;
								}
							    }
							} else {
							    my ($path_length, $vertices) = &shortest_path($rxns->[$i]->id(), $rxns->[$j]->id(), $apsp);
							    $tbl->{data}->[$indexOne]->[$indexTwo] = $path_length;
							    if ($args->{detail}) {
								$tbl->{data}->[$indexOne]->[$indexTwo] .= "; @$vertices" if @$vertices > 0;
							    }
							}
						}
					}
				}
			}
		}
		for (my $i=0; $i < @{$tbl->{data}}; $i++) {
		    for (my $j=0; $j < @{$tbl->{data}->[$i]}; $j++) {
			if (!defined($tbl->{data}->[$i]->[$j])) {
			    $tbl->{data}->[$i]->[$j] = -1;
			}
		    }
		}
	} else {
		my $cpds = $self->modelcompounds();
		$tbl->{headings}->[0] = "Cpd";
		for (my $i=0;$i < @{$cpds}; $i++) {
			$tbl->{headings}->[$i+1] = $cpds->[$i]->id();
			$tbl->{data}->[$i]->[0] = $cpds->[$i]->id();
			for (my $j=0;$j < @{$cpds}; $j++) {
				if ($i == $j) {
					$tbl->{data}->[$i]->[$j+1] = 0;
				} else {
					$tbl->{data}->[$i]->[$j+1] =  $apsp->path_length($cpds->[$i]->id(), $cpds->[$j]->id());
					if ($args->{detail}) {
					    my @vs = $apsp->path_vertices($cpds->[$i]->id(), $cpds->[$j]->id()); 
					    $tbl->{data}->[$i]->[$j+1] .= "; @vs" if @vs > 0;
					}
					if (!defined($tbl->{data}->[$i]->[$j+1])) {
						$tbl->{data}->[$i]->[$j+1] = -1;
					}
				}
			}
		}
	}
	return $tbl;
}

sub shortest_path {
	my ($rxn1, $rxn2, $apsp) = @_;
	# check two possibilities and choose the shortest one
	my $a =  $apsp->path_length($rxn1, $rxn2);
	my @vs = $apsp->path_vertices($rxn1, $rxn2);
	my $b =  $apsp->path_length($rxn2, $rxn1);
	if (defined $a && defined $b && $b < $a)  {
		$a = $b;
		@vs = $apsp->path_vertices($rxn2, $rxn1);
	}
	
	return ($a, \@vs);

}

=head3 searchForCompound

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound->searchForCompound(string:id);
Description:
	Search for compound in model
	
=cut

sub searchForCompound {
    my $self = shift;
    my $id = shift;
    my $compartment = shift;
    my $index = shift;
    if ($id =~ m/^(.+)\[([a-z]+)(\d*)]$/) {
    	$id = $1;
    	$compartment = $2;
    	$index = $3;
    }
    if (!defined($compartment)) {
    	$compartment = "c";
    }
    if (!defined($index)) {
    	$index = 0;
    }
    my $cpd = $self->biochemistry()->searchForCompound($id);
    if (!defined($cpd)) {
    	return undef;
    }
    my $mdlcmp = $self->queryObject("modelcompartments",{label => $compartment.$index});
    if (!defined($mdlcmp)) {
    	return undef;
    }
    return $self->queryObject("modelcompounds",{
    	modelcompartment_ref => $mdlcmp->_reference(),
    	compound_ref => $cpd->_reference()
    });
}

=head3 searchForBiomass

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::Biomass Bio::KBase::ObjectAPI::KBaseFBA::Biomass->searchForBiomass(string:id);
Description:
	Search for biomass in model
	
=cut

sub searchForBiomass {
    my $self = shift;
    my $id = shift;
    my $obj = $self->queryObject("biomasses",{id => $id});
    if (!defined($obj)) {
    	$obj = $self->queryObject("biomasses",{name => $id});
    }
    return $obj;
}

=head3 searchForReaction

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::Biomass Bio::KBase::ObjectAPI::KBaseFBA::Biomass->searchForReaction(string:id);
Description:
	Search for reaction in model
	
=cut

sub searchForReaction {
    my $self = shift;
    my $id = shift;
    my $compartment = shift;
    my $index = shift;
    if ($id =~ m/^(.+)\[([a-z]+)(\d*)]$/) {
    	$id = $1;
    	$compartment = $2;
    	$index = $3;
    }
    if (!defined($compartment)) {
    	$compartment = "c";
    }
    if (!defined($index)) {
    	$index = 0;
    }
    my $reaction = $self->biochemistry()->searchForReaction($id);
    if (!defined($reaction)) {
    	return undef;
    }
    my $mdlcmp = $self->queryObject("modelcompartments",{label => $compartment.$index});
    if (!defined($mdlcmp)) {
    	return undef;
    }
    return $self->queryObject("modelreactions",{
    	modelcompartment_ref => $mdlcmp->_reference(),
    	reaction_ref => $reaction->_reference()
    });
}


=head3 addPhenotypeTransporters

Definition:
    $self->addPhenotypeTransporters({
    	phenotypeset => Bio::KBase::ObjectAPI::PhenotypeSet,
    	positiveonly => 0/1
    });
Description:
    Add transporters for all media in a PhenotypeSet to the input model.
    Note - this must be called BEFORE _buildFBAObject.

=cut

sub addPhenotypeTransporters {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["phenotypes"], {positiveonly => 0}, @_);
	my $phenotypes = $args->{phenotypes}->phenotypes();
	my $mediahash;
	for (my $i=0; $i < @{$phenotypes}; $i++) {
		my $phenotype = $phenotypes->[$i];
		my $media = $phenotype->media();
		if ($phenotype->normalizedGrowth() > 0 || $args->{positiveonly} == 0) {
			$mediahash->{$media->_reference()} = $media;
		} 
	}
	my $cpdhash;
	foreach my $ref (keys(%{$mediahash})) {
		my $cpds = $mediahash->{$ref}->mediacompounds();
		foreach my $cpd (@{$cpds}) {
			$cpdhash->{$cpd->id()} = $cpd;
		}
	}
	my $NeedTrans = [];
	my $mdlcpds = $self->modelcompounds();
	foreach my $cpd (@{$mdlcpds}) {
		if (defined($cpdhash->{$cpd->compound()->id()}) && $cpd->modelcompartment()->label() =~ m/^e/) {
			delete $cpdhash->{$cpd->compound()->id()};
		}
	}
	my $bio = $self->template()->biochemistry();
	my $rxns = $bio->reactions();
	my $transhash = {};
	foreach my $cpd (keys(%{$cpdhash})) {
		foreach my $rxn (@{$rxns}) {
			my $rgts = $rxn->reagents();
			my $extcoef;
			my $cytcoef;
			my $othercomps = 0;
			foreach my $rgt (@{$rgts}) {
				if ($rgt->compartment()->id() !~ m/[ce]/) {
					$othercomps = 1;
					last;
				}
				if ($rgt->compound()->id() eq $cpd && $rgt->compartment()->id() eq "e") {
					$extcoef = $rgt->coefficient();
				} elsif ($rgt->compound()->id() eq $cpd && $rgt->compartment()->id() eq "c") {
					$cytcoef = $rgt->coefficient();
				}
			}	
			if ($othercomps == 0 && defined($extcoef) && defined($cytcoef) && ($cytcoef*$extcoef) < 0) {
				$transhash->{$rxn->id()} = $rxn;
				last;
			}	
		}
	}
	foreach my $rxn (keys(%{$transhash})) {
		$self->addReactionToModel({
			direction => "=",
			reaction => $transhash->{$rxn}
		});
	}
}

sub __upgrade__ {
	my ($class,$version) = @_;
	if ($version eq "1") {
		return sub {
			my ($hash) = @_;
			if (defined($hash->{fbaFormulations})) {
				delete($hash->{fbaFormulations});
			}
			if (defined($hash->{gapfillingFormulations})) {
				delete($hash->{gapfillingFormulations});
			}
			if (defined($hash->{gapgenFormulations})) {
				delete($hash->{gapgenFormulations});
			}
			$hash->{__VERSION__} = 2;
			if (defined($hash->{parent}) && ref($hash->{parent}) eq "ModelSEED::Store") {#TODO KBaseStore
				my $parent = $hash->{parent};
				delete($hash->{parent});
				if (defined $hash->{uuid}) {
				    $parent->save_data("model/".$hash->{uuid},$hash,{schema_update => 1});
				} else {
				    my $auth = $parent->auth;
				    $parent->save_data("model/".$auth->username."/".$hash->{id},$hash,{schema_update => 1});
				}
				    $hash->{parent} = $parent;
			}
			return $hash;
		};
	} 
}

__PACKAGE__->meta->make_immutable;
1;