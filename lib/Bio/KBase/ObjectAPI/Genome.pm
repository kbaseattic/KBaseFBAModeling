########################################################################
# Bio::KBase::ObjectAPI::Genome - This is the moose object corresponding to the Genome object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use Bio::KBase::ObjectAPI::DB::Genome;
package Bio::KBase::ObjectAPI::Genome;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::DB::Genome';
#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************
my $cmpTranslation = {
    extracellular => "e",
    cellwall => "w",
    periplasm => "p",
    cytosol => "c",
    golgi => "g",
    endoplasm => "r",
    lysosome => "l",
    nucleus => "n",
    chloroplast => "h",
    mitochondria => "m",
    peroxisome => "x",
    vacuole => "v",
    plastid => "d",
    unknown => "u",
};

#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 searchForFeature

Definition:
	Bio::KBase::ObjectAPI::Feature = Bio::KBase::ObjectAPI::Genome->searchForFeature(string id);
Description:
	Searches for the input Feature in the annotation

=cut

sub searchForFeature {
    my ($self,$feature) = @_;
	my $obj = $self->queryObject("features",{id => $feature});
	if (!defined($obj)) {
		$obj = $self->queryObject("features",{aliases => $feature});
	}
	return $obj;
}

=head3 export

Definition:
	string = Bio::KBase::ObjectAPI::Genome->export();
Description:
	Exports annotation data to the specified format.

=cut

sub export {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::Util::utilities::args(["format"], {}, @_);
	if (lc($args->{format}) eq "readable") {
		return $self->toReadableString();
	} elsif (lc($args->{format}) eq "html") {
		return $self->createHTML();
	} elsif (lc($args->{format}) eq "json") {
		return $self->toJSON({pp => 1});
	}
	Bio::KBase::ObjectAPI::Util::utilities::error("Unrecognized type for export: ".$args->{format});
}

sub roles {
    my ($self) = @_;
    my $roles = {};
    my $features = $self->features();
    my $rolehash;
    foreach my $feature (@$features) {
		foreach my $role (@{$feature->roles()}) {
			$rolehash->{$role} = 1;
    	}
    }
    return [keys(%{$rolehash})];
}

__PACKAGE__->meta->make_immutable;
1;
