########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelTemplate - This is the moose object corresponding to the KBaseFBA.ModelTemplate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelTemplate;
use Bio::KBase::ObjectAPI::IndexedObject;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateBiomass;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateReaction;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::IndexedObject';


our $VERSION = 1.0;
# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has biochemistry_ref => (is => 'rw', isa => 'Str', printOrder => '-1', default => 'kbase/default', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');
has domain => (is => 'rw', isa => 'Str', printOrder => '2', required => 1, type => 'attribute', metaclass => 'Typed');
has mapping_ref => (is => 'rw', isa => 'Str', printOrder => '3', required => 1, type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has modelType => (is => 'rw', isa => 'Str', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has templateBiomasses => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateBiomass)', metaclass => 'Typed', reader => '_templateBiomasses', printOrder => '0');
has templateReactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateReaction)', metaclass => 'Typed', reader => '_templateReactions', printOrder => '0');


# LINKS:
has biochemistry => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,Biochemistry,biochemistry_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_biochemistry', clearer => 'clear_biochemistry', isa => 'Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry', weak_ref => 1);
has mapping => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,Mapping,mapping_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_mapping', clearer => 'clear_mapping', isa => 'Bio::KBase::ObjectAPI::KBaseOntology::Mapping', weak_ref => 1);


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->uuid(); }
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_biochemistry {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->biochemistry_ref());
}
sub _build_mapping {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->mapping_ref());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'KBaseFBA.ModelTemplate'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'ModelTemplate'; }
sub _top { return 1; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'biochemistry_ref',
            'default' => 'kbase/default',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'name',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 2,
            'name' => 'domain',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 3,
            'name' => 'mapping_ref',
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
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'modelType',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          }
        ];

my $attribute_map = {biochemistry_ref => 0, name => 1, domain => 2, mapping_ref => 3, id => 4, modelType => 5};
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
            'attribute' => 'biochemistry_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_biochemistry',
            'name' => 'biochemistry',
            'method' => 'Biochemistry',
            'class' => 'Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry',
            'module' => 'KBaseBiochem'
          },
          {
            'attribute' => 'mapping_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_mapping',
            'name' => 'mapping',
            'method' => 'Mapping',
            'class' => 'Bio::KBase::ObjectAPI::KBaseOntology::Mapping',
            'module' => 'KBaseOntology'
          }
        ];

my $link_map = {biochemistry => 0, mapping => 1};
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
            'req' => undef,
            'printOrder' => 0,
            'name' => 'templateBiomasses',
            'default' => undef,
            'description' => undef,
            'class' => 'TemplateBiomass',
            'type' => 'child',
            'module' => 'KBaseFBA'
          },
          {
            'req' => undef,
            'printOrder' => 0,
            'name' => 'templateReactions',
            'default' => undef,
            'description' => undef,
            'class' => 'TemplateReaction',
            'type' => 'child',
            'module' => 'KBaseFBA'
          }
        ];

my $subobject_map = {templateBiomasses => 0, templateReactions => 1};
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
around 'templateBiomasses' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('templateBiomasses');
};
around 'templateReactions' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('templateReactions');
};


__PACKAGE__->meta->make_immutable;
1;
