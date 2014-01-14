########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::ModelReactionProteinSubunit - This is the moose object corresponding to the ModelReactionProteinSubunit object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-21T02:47:43
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelReactionProteinSubunit;
package Bio::KBase::ObjectAPI::KBaseFBA::ModelReactionProteinSubunit;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelReactionProteinSubunit';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has gprString => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgprString' );
has exchangeGPRString => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildexchangeGPRString' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildgprString {
	my ($self) = @_;
	if (@{$self->modelReactionProteinSubunitGenes()} == 0) {
		#if (length($self->note()) > 0) {
		#	return $self->note();
		#}
		return "Unknown";
	}
	my $gpr = "";
	foreach my $gene (@{$self->modelReactionProteinSubunitGenes()}) {
		if (length($gpr) > 0) {
			$gpr .= " or ";	
		}
		$gpr .= $gene->feature()->id();
	}
	if (@{$self->modelReactionProteinSubunitGenes()} > 1) {
		$gpr = "(".$gpr.")";	
	}
	return $gpr;
}
sub _buildexchangeGPRString {
	my ($self) = @_;
	my $gpr = "";
	if (!defined($self->role_uuid()) || $self->role_uuid() =~ m/^[0\-]+$/) {
		$gpr .= "{";
	} else {
		$gpr .= "{";
	}
	my $features = $self->modelReactionProteinSubunitGenes();
	my $fgpr = "";
	foreach my $feature (@{$features}) {
		if (length($fgpr) > 0) {
			$fgpr .= "/";
		}
		$fgpr .= $feature->feature()->id();
	}
	$gpr .= $fgpr;
	$gpr .= "}";
	return $gpr;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************

__PACKAGE__->meta->make_immutable;
1;
