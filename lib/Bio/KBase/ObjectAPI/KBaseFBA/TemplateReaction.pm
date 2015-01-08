########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::TemplateReaction - This is the moose object corresponding to the TemplateReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2013-04-26T05:53:23
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction;
package Bio::KBase::ObjectAPI::KBaseFBA::TemplateReaction;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction';
use Bio::KBase::ObjectAPI::utilities;
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has complexIDs => ( is => 'rw', isa => 'ArrayRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcomplexIDs' );
has isBiomassTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisBiomassTransporter' );
has inSubsystem => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildinSubsystem' );
has reactionID => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionID' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildreactionID {
	my ($self) = @_;
	return $self->reaction()->id()."_".$self->compartment()->id();
}

sub _buildcomplexIDs {
	my ($self) = @_;
	my $output = [];
	my $cpxs = $self->complexs();
	for (my $i=0; $i <@{$cpxs}; $i++) {
		my $cpx = $cpxs->[$i];
		push(@{$output},$cpx->id());
	}
	return $output;
}
sub _buildisBiomassTransporter {
	my ($self) = @_;
	my $rxn = $self->reaction();
	my $rgts = $rxn->reagents();
	my $rgthash;
	my $transported;
	for (my $i=0; $i < @{$rgts}; $i++) {
		if (defined($rgthash->{$rgts->[$i]->compound()->id()}) && $rgthash->{$rgts->[$i]->compound()->id()} ne $rgts->[$i]->compartment()->id()) {
			if ($rgts->[$i]->compartment()->id() eq "e") {
				$transported->{$rgts->[$i]->compound()->id()} = $rgthash->{$rgts->[$i]->compound()->id()};
			} else {
				$transported->{$rgts->[$i]->compound()->id()} = $rgts->[$i]->compartment()->id();
			}
		}
		$rgthash->{$rgts->[$i]->compound()->id()} = $rgts->[$i]->compartment()->id();
	}
	my $biomasshash = $self->parent()->biomassHash();
	foreach my $trans (keys(%{$transported})) {
		if (defined($biomasshash->{$trans."_".$transported->{$trans}})) {
			return 1;
		}
	}
}
sub _buildinSubsystem {
	my ($self) = @_;
	my $complexes = $self->complexs();
	foreach my $complex (@{$complexes}) {
		my $cpxroles = $complex->complexroles();
		foreach my $cpxrole (@{$cpxroles}) {
			my $role = $cpxrole->role();
			my $rolesshash = $role->parent()->roleSubsystemHash();
			if (defined($rolesshash->{$role->id()})) {
				return 1;
			}
		}
	}
	return 0;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub compute_penalties {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([],{
		no_KEGG_penalty => 1,
		no_KEGG_map_penalty => 1,
		functional_role_penalty => 2,
		subsystem_penalty => 1,
		transporter_penalty => 1,
		unknown_structure_penalty => 1,
		biomass_transporter_penalty => 1,
		single_compound_transporter_penalty => 1,
		direction_penalty => 1,
		unbalanced_penalty => 10,
		no_delta_G_penalty => 1
	}, @_);
	my $thermopenalty = 0; 
	my $coefficient = 1;
	if (!defined($self->reaction()->getAlias("KEGG"))) {
		$coefficient += $args->{no_KEGG_penalty};
		$coefficient += $args->{no_KEGG_map_penalty};
	} elsif (!defined(Bio::KBase::ObjectAPI::utilities::KEGGMapHash()->{$self->reaction()->id()})) {
		$coefficient += $args->{no_KEGG_map_penalty};
	}
	if (!defined($self->reaction()->deltaG()) || $self->reaction()->deltaG() == 10000000) {
		$coefficient += $args->{no_delta_G_penalty};
		$thermopenalty += 1.5;
	} else {
		$thermopenalty += $self->reaction()->deltaG()/10;
	}
	if (@{$self->complexs()} == 0) {
		$coefficient += $args->{functional_role_penalty};
		$coefficient += $args->{subsystem_penalty};
	} elsif ($self->inSubsystem() == 1) {
		$coefficient += $args->{subsystem_penalty};
	}
	if ($self->reaction()->isTransport()) {
		$coefficient += $args->{transporter_penalty};
		if (@{$self->reaction()->reagents()} <= 2) {
			$coefficient += $args->{single_compound_transporter_penalty};
		}
		if ($self->isBiomassTransporter() == 1) {
			$coefficient += $args->{biomass_transporter_penalty};
		}
	}
	if ($self->reaction()->unknownStructure()) {
		$coefficient += $args->{unknown_structure_penalty};
	}
	if ($self->reaction()->status() =~ m/[CM]I/) {
		$coefficient += $args->{unbalanced_penalty};
	}
	if ($self->reaction()->thermoReversibility() eq ">") {
		$self->forward_penalty(0);
		$self->reverse_penalty($args->{direction_penalty}+$thermopenalty);	
	} elsif ($self->reaction()->thermoReversibility() eq "<") {
		$self->reverse_penalty(0);
		$self->forward_penalty($args->{direction_penalty}+$thermopenalty);
	} else {
		$self->forward_penalty(0);
		$self->reverse_penalty(0);
	}
	$self->base_cost($coefficient);
}

sub addRxnToModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["role_features","model"],{
		fulldb => 0
	}, @_);
	my $mdl = $args->{model};
	#Gathering roles from annotation
	my $roleFeatures = $args->{role_features};
	my $cpxs = $self->complexs();
	my $proteins = [];
	for (my $i=0; $i < @{$cpxs}; $i++) {
		my $cpx = $cpxs->[$i];
		my $complexroles = $cpx->complexroles();
		my $present = 0;
		my $subunits;
		for (my $j=0; $j < @{$complexroles}; $j++) {
			my $cpxrole = $complexroles->[$j];
			if (defined($roleFeatures->{$cpxrole->role()->id()})) {
				foreach my $compartment (keys(%{$roleFeatures->{$cpxrole->role()->id()}})) {
					if ($compartment eq "u" || $compartment eq $self->compartment()->id()) {
						if ($cpxrole->triggering() == 1) {
							$present = 1;	
						}
					}
					$subunits->{$cpxrole->role()->name()}->{triggering} = $cpxrole->triggering();
					$subunits->{$cpxrole->role()->name()}->{optionalRole} = $cpxrole->optionalRole();
					if (!defined($roleFeatures->{$cpxrole->role()->id()}->{$compartment}->[0])) {
						$subunits->{$cpxrole->role()->name()}->{note} = "Role-based-annotation";
					} else {
						foreach my $feature (@{$roleFeatures->{$cpxrole->role()->id()}->{$compartment}}) {
							$subunits->{$cpxrole->role()->name()}->{genes}->{$feature->_reference()} = $feature;	
						}
					}
				}
			}
		}
		if ($present == 1) {
			for (my $j=0; $j < @{$complexroles}; $j++) {
				my $cpxrole = $complexroles->[$j];
				if ($cpxrole->optionalRole() == 0 && !defined($subunits->{$cpxrole->role()->name()})) {
					$subunits->{$cpxrole->role()->name()}->{triggering} = $cpxrole->triggering();
					$subunits->{$cpxrole->role()->name()}->{optionalRole} = $cpxrole->optionalRole();
					$subunits->{$cpxrole->role()->name()}->{note} = "Complex-based-gapfilling";
				}
			}
			push(@{$proteins},{subunits => $subunits,cpx => $cpx});
		}
	}
	#Adding reaction
	if (@{$proteins} == 0 && $self->type() ne "universal" && $self->type() ne "spontaneous" && $args->{fulldb} == 0) {
		return;
	}

    my $mdlcmp = $mdl->addCompartmentToModel({compartment => $self->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
    my $mdlrxn = $mdl->getObject("modelreactions", $self->reaction()->id()."_".$mdlcmp->id());
    if(!$mdlrxn){
	$mdlrxn = $mdl->add("modelreactions",{
		id => $self->reaction()->id()."_".$mdlcmp->id(),
		probability => 0,
		reaction_ref => $self->reaction_ref(),
		direction => $self->direction(),
		protons => $self->reaction()->defaultProtons(),
		modelcompartment_ref => $mdlcmp->_reference(),
		modelReactionReagents => [],
		modelReactionProteins => []
	});
	my $rgts = $self->reaction->reagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		my $rgtcmp = $mdl->addCompartmentToModel({compartment => $rgt->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
		my $coefficient = $rgt->coefficient();
		my $mdlcpd = $mdl->addCompoundToModel({
			compound => $rgt->compound(),
			modelCompartment => $rgtcmp,
		});
		$mdlrxn->addReagentToReaction({
			coefficient => $coefficient,
			modelcompound_ref => $mdlcpd->_reference()
		});
	}
    }
    if (@{$proteins} > 0 && scalar(@{$mdlrxn->modelReactionProteins()})==0) {
	foreach my $protein (@{$proteins}) {
	    $mdlrxn->addModelReactionProtein({
		proteinDataTree => $protein,
		complex_ref => $protein->{cpx}->_reference()
					     });
	}
    } elsif (scalar(@{$mdlrxn->modelReactionProteins()})==0) {
	$mdlrxn->addModelReactionProtein({
	    proteinDataTree => {note => $self->type()},
					 });
    }

    return $mdlrxn;
}



__PACKAGE__->meta->make_immutable;
1;
