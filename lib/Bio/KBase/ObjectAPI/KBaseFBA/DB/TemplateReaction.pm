########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction - This is the moose object corresponding to the KBaseFBA.TemplateReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction;
use Bio::KBase::ObjectAPI::BaseObject;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has GapfillDirection => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed', default => "=");
has reverse_penalty => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has compartment_ref => (is => 'rw', isa => 'Str', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');
has base_cost => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has reaction_ref => (is => 'rw', isa => 'Str', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');
has complex_refs => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has direction => (is => 'rw', isa => 'Str', printOrder => '1', type => 'attribute', metaclass => 'Typed');
has forward_penalty => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', printOrder => '1', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has compartment => (is => 'rw', type => 'link(Biochemistry,compartments,compartment_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_compartment', clearer => 'clear_compartment', isa => 'Bio::KBase::ObjectAPI::KBaseBiochem::Compartment', weak_ref => 1);
has reaction => (is => 'rw', type => 'link(Biochemistry,reactions,reaction_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_reaction', clearer => 'clear_reaction', isa => 'Bio::KBase::ObjectAPI::KBaseBiochem::Reaction', weak_ref => 1);
has complexs => (is => 'rw', type => 'link(Mapping,complexes,complex_refs)', metaclass => 'Typed', lazy => 1, builder => '_build_complexs', clearer => 'clear_complexs', isa => 'ArrayRef');


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->parent()->_reference().'/templateReactions/id/'.$self->id(); }
sub _build_uuid { my ($self) = @_;return $self->_reference(); }
sub _build_compartment {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->compartment_ref());
}
sub _build_reaction {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->reaction_ref());
}
sub _build_complexs {
	 my ($self) = @_;
	 return $self->getLinkedObjectArray($self->complex_refs());
}


# CONSTANTS:
sub _type { return 'KBaseFBA.TemplateReaction'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'TemplateReaction'; }
sub _top { return 0; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'GapfillDirection',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'reverse_penalty',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'compartment_ref',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'base_cost',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'reaction_ref',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'complex_refs',
            'default' => undef,
            'type' => 'ArrayRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'direction',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'forward_penalty',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'type',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'id',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {GapfillDirection => 0, reverse_penalty => 1, compartment_ref => 2, base_cost => 3, reaction_ref => 4, complex_refs => 5, direction => 6, forward_penalty => 7, type => 8, id => 9};
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
            'parent' => 'Biochemistry',
            'name' => 'compartment',
            'attribute' => 'compartment_ref',
            'clearer' => 'clear_compartment',
            'class' => 'Bio::KBase::ObjectAPI::KBaseBiochem::Compartment',
            'method' => 'compartments',
            'module' => 'KBaseBiochem',
            'field' => 'id'
          },
          {
            'parent' => 'Biochemistry',
            'name' => 'reaction',
            'attribute' => 'reaction_ref',
            'clearer' => 'clear_reaction',
            'class' => 'Bio::KBase::ObjectAPI::KBaseBiochem::Reaction',
            'method' => 'reactions',
            'module' => 'KBaseBiochem',
            'field' => 'id'
          },
          {
            'parent' => 'Mapping',
            'name' => 'complexs',
            'attribute' => 'complex_refs',
            'array' => 1,
            'clearer' => 'clear_complexs',
            'class' => 'Bio::KBase::ObjectAPI::KBaseOntology::Complex',
            'method' => 'complexes',
            'module' => 'KBaseOntology',
            'field' => 'id'
          }
        ];

my $link_map = {compartment => 0, reaction => 1, complexs => 2};
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

my $subobjects = [];

my $subobject_map = {};
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
__PACKAGE__->meta->make_immutable;
1;
