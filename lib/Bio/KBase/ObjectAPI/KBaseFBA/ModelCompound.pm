########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound - This is the moose object corresponding to the ModelCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelCompound;
package Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelCompound';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has name => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildname' );
has abbreviation => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildabbreviation' );
has id => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildid' );
has modelCompartmentLabel => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmodelCompartmentLabel' );
has isBiomassCompound  => ( is => 'rw', isa => 'Bool',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisBiomassCompound' );
has mapped_uuid  => ( is => 'rw', isa => 'ModelSEED::uuid',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmapped_uuid' );
has formula  => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildformula' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildid {
	my ($self) = @_;
	return $self->compound()->id()."_".$self->modelCompartmentLabel();
}
sub _buildname {
	my ($self) = @_;
	return $self->compound()->name()."_".$self->modelCompartmentLabel();
}
sub _buildabbreviation {
	my ($self) = @_;
	return $self->compound()->abbreviation()."_".$self->modelCompartmentLabel();
}
sub _buildmodelCompartmentLabel {
	my ($self) = @_;
	return $self->modelcompartment()->id();
}
sub _buildisBiomassCompound {
	my ($self) = @_;
	$self->parent()->labelBiomassCompounds();
	return $self->isBiomassCompound();
}
sub _buildmapped_uuid {
	my ($self) = @_;
	return "00000000-0000-0000-0000-000000000000";
}
sub _buildformula {
	my ($self) = @_;
	return $self->compound()->formula();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
