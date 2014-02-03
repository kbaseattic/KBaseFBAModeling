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

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
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

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub addRxnToModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["role_features","model"],{}, @_);
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
	if (@{$proteins} == 0 && $self->type() ne "universal" && $self->type() ne "spontaneous") {
		return;
	}
	my $mdlcmp = $mdl->addCompartmentToModel({compartment => $self->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
	my $mdlrxn = $mdl->add("modelreactions",{
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
	if (@{$proteins} > 0) {
		foreach my $protein (@{$proteins}) {
			$mdlrxn->addModelReactionProtein({
				proteinDataTree => $protein,
				complex_ref => $protein->{cpx}->_reference()
			});
		}
	} else {
		$mdlrxn->addModelReactionProtein({
			proteinDataTree => {note => $self->type()},
		});
	}
	return $mdlrxn;
}

__PACKAGE__->meta->make_immutable;
1;
