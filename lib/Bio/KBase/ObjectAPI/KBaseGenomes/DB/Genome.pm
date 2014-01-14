########################################################################
# Bio::KBase::ObjectAPI::KBaseGenomes::DB::Genome - This is the moose object corresponding to the KBaseGenomes.Genome object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseGenomes::DB::Genome;
use Bio::KBase::ObjectAPI::IndexedObject;
use Bio::KBase::ObjectAPI::KBaseGenomes::Feature;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::IndexedObject';


our $VERSION = 1.0;
# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has source => (is => 'rw', isa => 'Str', printOrder => '8', required => 1, type => 'attribute', metaclass => 'Typed');
has transcriptset_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has contigset_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has dna_size => (is => 'rw', isa => 'Int', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has domain => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has contig_lengths => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has contig_ids => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has proteinset_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has publications => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');
has num_contigs => (is => 'rw', isa => 'Int', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has source_id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has gc_content => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has taxonomy => (is => 'rw', isa => 'Str', printOrder => '4', default => '', type => 'attribute', metaclass => 'Typed');
has scientific_name => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has genetic_code => (is => 'rw', isa => 'Int', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has md5 => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has complete => (is => 'rw', isa => 'Int', printOrder => '-1', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has features => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(Feature)', metaclass => 'Typed', reader => '_features', printOrder => '-1');


# LINKS:
has transcriptset => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,TranscriptSet,transcriptset_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_transcriptset', clearer => 'clear_transcriptset', isa => 'Ref', weak_ref => 1);
has contigset => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,ContigSet,contigset_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_contigset', clearer => 'clear_contigset', isa => 'Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet', weak_ref => 1);
has proteinset => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,ProteinSet,proteinset_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_proteinset', clearer => 'clear_proteinset', isa => 'Ref', weak_ref => 1);


# BUILDERS:
sub _build_reference { return my ($self) = @_;$self->uuid(); }
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_transcriptset {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->transcriptset_ref());
}
sub _build_contigset {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->contigset_ref());
}
sub _build_proteinset {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->proteinset_ref());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'KBaseGenomes.Genome'; }
sub _module { return 'KBaseGenomes'; }
sub _class { return 'Genome'; }
sub _top { return 1; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => 8,
            'name' => 'source',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'transcriptset_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'contigset_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'dna_size',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'domain',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'contig_lengths',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'contig_ids',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'proteinset_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'publications',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'id',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'num_contigs',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'source_id',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'gc_content',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 4,
            'name' => 'taxonomy',
            'default' => '',
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'scientific_name',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'genetic_code',
            'type' => 'Int',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'md5',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'complete',
            'type' => 'Int',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {source => 0, transcriptset_ref => 1, contigset_ref => 2, dna_size => 3, domain => 4, contig_lengths => 5, contig_ids => 6, proteinset_ref => 7, publications => 8, id => 9, num_contigs => 10, source_id => 11, gc_content => 12, taxonomy => 13, scientific_name => 14, genetic_code => 15, md5 => 16, complete => 17};
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
            'attribute' => 'transcriptset_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_transcriptset',
            'name' => 'transcriptset',
            'method' => 'TranscriptSet',
            'class' => 'TranscriptSet',
            'module' => undef
          },
          {
            'attribute' => 'contigset_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_contigset',
            'name' => 'contigset',
            'method' => 'ContigSet',
            'class' => 'Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet',
            'module' => 'KBaseGenomes'
          },
          {
            'attribute' => 'proteinset_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_proteinset',
            'name' => 'proteinset',
            'method' => 'ProteinSet',
            'class' => 'ProteinSet',
            'module' => undef
          }
        ];

my $link_map = {transcriptset => 0, contigset => 1, proteinset => 2};
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
            'name' => 'features',
            'type' => 'child',
            'class' => 'Feature',
            'module' => 'KBaseGenomes'
          }
        ];

my $subobject_map = {features => 0};
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
around 'features' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('features');
};


__PACKAGE__->meta->make_immutable;
1;
