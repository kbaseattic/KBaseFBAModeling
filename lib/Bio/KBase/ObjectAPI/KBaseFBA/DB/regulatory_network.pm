########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::regulatory_network - This is the moose object corresponding to the KBaseFBA.regulatory_network object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::regulatory_network;
use Bio::KBase::ObjectAPI::IndexedObject;
use Bio::KBase::ObjectAPI::KBaseFBA::RegulatoryInteraction;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::IndexedObject';


our $VERSION = 1.0;
# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');


# SUBOBJECTS:
has regulatory_network => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(RegulatoryInteraction)', metaclass => 'Typed', reader => '_regulatory_network', printOrder => '-1');


# LINKS:


# BUILDERS:


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'KBaseFBA.regulatory_network'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'regulatory_network'; }
sub _top { return 1; }

my $attributes = [];

my $attribute_map = {};
sub _attributes {
	 my ($self, $key) = @_;
	 if (defined($key)) {
	 	 my $ind = $attribute_map->{$key};
	 	 if (defined($ind)) {
	 	 	 return $attributes->[$ind];
	 	 } else {
	 	 	 return;
	 	 }
	 } else {
	 	 return $attributes;
	 }
}

my $links = [];

my $link_map = {};
sub _links {
	 my ($self, $key) = @_;
	 if (defined($key)) {
	 	 my $ind = $link_map->{$key};
	 	 if (defined($ind)) {
	 	 	 return $links->[$ind];
	 	 } else {
	 	 	 return;
	 	 }
	 } else {
	 	 return $links;
	 }
}

my $subobjects = [
          {
            'printOrder' => -1,
            'name' => 'regulatory_network',
            'type' => 'child',
            'class' => 'RegulatoryInteraction',
            'module' => 'KBaseFBA'
          }
        ];

my $subobject_map = {regulatory_network => 0};
sub _subobjects {
	 my ($self, $key) = @_;
	 if (defined($key)) {
	 	 my $ind = $subobject_map->{$key};
	 	 if (defined($ind)) {
	 	 	 return $subobjects->[$ind];
	 	 } else {
	 	 	 return;
	 	 }
	 } else {
	 	 return $subobjects;
	 }
}
# SUBOBJECT READERS:
around 'regulatory_network' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('regulatory_network');
};


__PACKAGE__->meta->make_immutable;
1;
