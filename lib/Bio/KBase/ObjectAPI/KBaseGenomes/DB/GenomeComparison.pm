########################################################################
# Bio::KBase::ObjectAPI::KBaseGenomes::DB::GenomeComparison - This is the moose object corresponding to the KBaseGenomes.GenomeComparison object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseGenomes::DB::GenomeComparison;
use Bio::KBase::ObjectAPI::IndexedObject;
use Bio::KBase::ObjectAPI::KBaseGenomes::GenomeCompareFunction;
use Bio::KBase::ObjectAPI::KBaseGenomes::GenomeCompareFamily;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::IndexedObject';


our $VERSION = 1.0;
# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has core_functions => (is => 'rw', isa => 'Int', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has genomes => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has core_families => (is => 'rw', isa => 'Int', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has pangenome_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has protcomp_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has functions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(GenomeCompareFunction)', metaclass => 'Typed', reader => '_functions', printOrder => '-1');
has families => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(GenomeCompareFamily)', metaclass => 'Typed', reader => '_families', printOrder => '-1');


# LINKS:
has pangenome => (is => 'rw', type => 'link(,,pangenome_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_pangenome', clearer => 'clear_pangenome', isa => 'Ref', weak_ref => 1);
has protcomp => (is => 'rw', type => 'link(,,protcomp_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_protcomp', clearer => 'clear_protcomp', isa => 'Ref', weak_ref => 1);


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->uuid(); }
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_pangenome {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->pangenome_ref());
}
sub _build_protcomp {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->protcomp_ref());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'KBaseGenomes.GenomeComparison'; }
sub _module { return 'KBaseGenomes'; }
sub _class { return 'GenomeComparison'; }
sub _top { return 1; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'core_functions',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'genomes',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'name',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'core_families',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'pangenome_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'id',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'protcomp_ref',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {core_functions => 0, genomes => 1, name => 2, core_families => 3, pangenome_ref => 4, id => 5, protcomp_ref => 6};
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

my $links = [
          {
            'parent' => undef,
            'name' => 'pangenome',
            'attribute' => 'pangenome_ref',
            'clearer' => 'clear_pangenome',
            'class' => undef,
            'method' => undef,
            'module' => undef,
            'field' => undef
          },
          {
            'parent' => undef,
            'name' => 'protcomp',
            'attribute' => 'protcomp_ref',
            'clearer' => 'clear_protcomp',
            'class' => undef,
            'method' => undef,
            'module' => undef,
            'field' => undef
          }
        ];

my $link_map = {pangenome => 0, protcomp => 1};
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
            'name' => 'functions',
            'type' => 'child',
            'class' => 'GenomeCompareFunction',
            'module' => 'KBaseGenomes'
          },
          {
            'printOrder' => -1,
            'name' => 'families',
            'type' => 'child',
            'class' => 'GenomeCompareFamily',
            'module' => 'KBaseGenomes'
          }
        ];

my $subobject_map = {functions => 0, families => 1};
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
around 'functions' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('functions');
};
around 'families' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('families');
};


__PACKAGE__->meta->make_immutable;
1;
