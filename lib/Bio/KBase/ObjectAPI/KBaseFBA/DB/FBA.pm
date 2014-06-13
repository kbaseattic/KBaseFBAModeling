########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::FBA - This is the moose object corresponding to the KBaseFBA.FBA object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::FBA;
use Bio::KBase::ObjectAPI::IndexedObject;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAMetaboliteProductionResult;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAReactionBound;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAPromResult;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAMinimalMediaResult;
use Bio::KBase::ObjectAPI::KBaseFBA::FBABiomassVariable;
use Bio::KBase::ObjectAPI::KBaseFBA::FBACompoundBound;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAMinimalReactionsResult;
use Bio::KBase::ObjectAPI::KBaseFBA::TintleProbabilitySample;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAConstraint;
use Bio::KBase::ObjectAPI::KBaseFBA::FBACompoundVariable;
use Bio::KBase::ObjectAPI::KBaseFBA::FBADeletionResult;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAReactionVariable;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::IndexedObject';


our $VERSION = 1.0;
# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has media_ref => (is => 'rw', isa => 'Str', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');
has compoundflux_objterms => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub {return {};}, type => 'attribute', metaclass => 'Typed');
has phenotypesimulationset_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has maximizeObjective => (is => 'rw', isa => 'Bool', printOrder => '-1', required => 1, default => '1', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has phenotypeset_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has geneKO_refs => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has inputfiles => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub{return {};}, type => 'attribute', metaclass => 'Typed');
has drainfluxUseVariables => (is => 'rw', isa => 'Bool', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has additionalCpd_refs => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has outputfiles => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has parameters => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub{return {};}, type => 'attribute', metaclass => 'Typed');
has noErrorThermodynamicConstraints => (is => 'rw', isa => 'Bool', printOrder => '17', default => '1', type => 'attribute', metaclass => 'Typed');
has objectiveConstraintFraction => (is => 'rw', isa => 'Num', printOrder => '0', default => 'none', type => 'attribute', metaclass => 'Typed');
has prommodel_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has minimize_reactions => (is => 'rw', isa => 'Bool', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has minimizeErrorThermodynamicConstraints => (is => 'rw', isa => 'Bool', printOrder => '18', default => '1', type => 'attribute', metaclass => 'Typed');
has uptakeLimits => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub{return {};}, type => 'attribute', metaclass => 'Typed');
has allReversible => (is => 'rw', isa => 'Bool', printOrder => '14', default => '0', type => 'attribute', metaclass => 'Typed');
has tintleKappa => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has objectiveValue => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has minimize_reaction_costs => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub {return {};}, type => 'attribute', metaclass => 'Typed');
has numberOfSolutions => (is => 'rw', isa => 'Int', printOrder => '23', default => '1', type => 'attribute', metaclass => 'Typed');
has fluxMinimization => (is => 'rw', isa => 'Bool', printOrder => '12', default => '0', type => 'attribute', metaclass => 'Typed');
has thermodynamicConstraints => (is => 'rw', isa => 'Bool', printOrder => '16', default => '1', type => 'attribute', metaclass => 'Typed');
has defaultMaxDrainFlux => (is => 'rw', isa => 'Num', printOrder => '22', required => 1, default => '1000', type => 'attribute', metaclass => 'Typed');
has reactionflux_objterms => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub {return {};}, type => 'attribute', metaclass => 'Typed');
has tintleW => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has fbamodel_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has regmodel_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has reactionKO_refs => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub{return [];}, type => 'attribute', metaclass => 'Typed');
has fluxUseVariables => (is => 'rw', isa => 'Bool', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has findMinimalMedia => (is => 'rw', isa => 'Bool', printOrder => '13', default => '0', type => 'attribute', metaclass => 'Typed');
has PROMKappa => (is => 'rw', isa => 'Num', printOrder => '19', default => '1', type => 'attribute', metaclass => 'Typed');
has simpleThermoConstraints => (is => 'rw', isa => 'Bool', printOrder => '15', default => '1', type => 'attribute', metaclass => 'Typed');
has comboDeletions => (is => 'rw', isa => 'Int', printOrder => '11', default => '0', type => 'attribute', metaclass => 'Typed');
has defaultMinDrainFlux => (is => 'rw', isa => 'Num', printOrder => '21', required => 1, default => '-1000', type => 'attribute', metaclass => 'Typed');
has fva => (is => 'rw', isa => 'Bool', printOrder => '10', default => '0', type => 'attribute', metaclass => 'Typed');
has decomposeReversibleDrainFlux => (is => 'rw', isa => 'Bool', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');
has biomassflux_objterms => (is => 'rw', isa => 'HashRef', printOrder => '-1', default => sub {return {};}, type => 'attribute', metaclass => 'Typed');
has defaultMaxFlux => (is => 'rw', isa => 'Num', printOrder => '20', required => 1, default => '1000', type => 'attribute', metaclass => 'Typed');
has decomposeReversibleFlux => (is => 'rw', isa => 'Bool', printOrder => '-1', default => '0', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has FBAMetaboliteProductionResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAMetaboliteProductionResult)', metaclass => 'Typed', reader => '_FBAMetaboliteProductionResults', printOrder => '-1');
has FBAReactionBounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAReactionBound)', metaclass => 'Typed', reader => '_FBAReactionBounds', printOrder => '-1');
has FBAPromResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAPromResult)', metaclass => 'Typed', reader => '_FBAPromResults', printOrder => '-1');
has FBAMinimalMediaResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAMinimalMediaResult)', metaclass => 'Typed', reader => '_FBAMinimalMediaResults', printOrder => '-1');
has FBABiomassVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBABiomassVariable)', metaclass => 'Typed', reader => '_FBABiomassVariables', printOrder => '-1');
has FBACompoundBounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBACompoundBound)', metaclass => 'Typed', reader => '_FBACompoundBounds', printOrder => '-1');
has FBAMinimalReactionsResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAMinimalReactionsResult)', metaclass => 'Typed', reader => '_FBAMinimalReactionsResults', printOrder => '-1');
has tintleSamples => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TintleProbabilitySample)', metaclass => 'Typed', reader => '_tintleSamples', printOrder => '-1');
has FBAConstraints => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAConstraint)', metaclass => 'Typed', reader => '_FBAConstraints', printOrder => '-1');
has FBACompoundVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBACompoundVariable)', metaclass => 'Typed', reader => '_FBACompoundVariables', printOrder => '-1');
has FBADeletionResults => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBADeletionResult)', metaclass => 'Typed', reader => '_FBADeletionResults', printOrder => '-1');
has FBAReactionVariables => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(FBAReactionVariable)', metaclass => 'Typed', reader => '_FBAReactionVariables', printOrder => '-1');


# LINKS:
has media => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,Media,media_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_media', clearer => 'clear_media', isa => 'Bio::KBase::ObjectAPI::KBaseBiochem::Media', weak_ref => 1);
has phenotypesimulationset => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,PhenotypeSimulationSet,phenotypesimulationset_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_phenotypesimulationset', clearer => 'clear_phenotypesimulationset', isa => 'Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSimulationSet', weak_ref => 1);
has phenotypeset => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,PhenotypeSet,phenotypeset_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_phenotypeset', clearer => 'clear_phenotypeset', isa => 'Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSet', weak_ref => 1);
has geneKOs => (is => 'rw', type => 'link(Genome,features,geneKO_refs)', metaclass => 'Typed', lazy => 1, builder => '_build_geneKOs', clearer => 'clear_geneKOs', isa => 'ArrayRef');
has additionalCpds => (is => 'rw', type => 'link(FBAModel,modelcompounds,additionalCpd_refs)', metaclass => 'Typed', lazy => 1, builder => '_build_additionalCpds', clearer => 'clear_additionalCpds', isa => 'ArrayRef');
has prommodel => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,PromConstraint,prommodel_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_prommodel', clearer => 'clear_prommodel', isa => 'Bio::KBase::ObjectAPI::KBaseFBA::PromConstraint', weak_ref => 1);
has fbamodel => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,FBAModel,fbamodel_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_fbamodel', clearer => 'clear_fbamodel', isa => 'Bio::KBase::ObjectAPI::KBaseFBA::FBAModel', weak_ref => 1);
has regmodel => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,RegModel,regmodel_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_regmodel', clearer => 'clear_regmodel', isa => 'Ref', weak_ref => 1);
has reactionKOs => (is => 'rw', type => 'link(FBAModel,modelreactions,reactionKO_refs)', metaclass => 'Typed', lazy => 1, builder => '_build_reactionKOs', clearer => 'clear_reactionKOs', isa => 'ArrayRef');


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->uuid(); }
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_media {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->media_ref());
}
sub _build_phenotypesimulationset {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->phenotypesimulationset_ref());
}
sub _build_phenotypeset {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->phenotypeset_ref());
}
sub _build_geneKOs {
	 my ($self) = @_;
	 return $self->getLinkedObjectArray($self->geneKO_refs());
}
sub _build_additionalCpds {
	 my ($self) = @_;
	 return $self->getLinkedObjectArray($self->additionalCpd_refs());
}
sub _build_prommodel {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->prommodel_ref());
}
sub _build_fbamodel {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->fbamodel_ref());
}
sub _build_regmodel {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->regmodel_ref());
}
sub _build_reactionKOs {
	 my ($self) = @_;
	 return $self->getLinkedObjectArray($self->reactionKO_refs());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'KBaseFBA.FBA'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'FBA'; }
sub _top { return 1; }

my $attributes = [
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'media_ref',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'compoundflux_objterms',
            'default' => 'sub {return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'phenotypesimulationset_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'maximizeObjective',
            'default' => 1,
            'type' => 'Bool',
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
            'req' => 0,
            'printOrder' => -1,
            'name' => 'phenotypeset_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'geneKO_refs',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'inputfiles',
            'default' => 'sub{return {};}',
            'type' => 'HashRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'drainfluxUseVariables',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'additionalCpd_refs',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'outputfiles',
            'default' => 'sub{return [];}',
            'type' => 'HashRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'parameters',
            'default' => 'sub{return {};}',
            'type' => 'HashRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 17,
            'name' => 'noErrorThermodynamicConstraints',
            'default' => 1,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 0,
            'name' => 'objectiveConstraintFraction',
            'default' => 'none',
            'type' => 'Num',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'prommodel_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'minimize_reactions',
            'default' => 0,
            'type' => 'Bool',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 18,
            'name' => 'minimizeErrorThermodynamicConstraints',
            'default' => 1,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'uptakeLimits',
            'default' => 'sub{return {};}',
            'type' => 'HashRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 14,
            'name' => 'allReversible',
            'default' => '0',
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'tintleKappa',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'objectiveValue',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'minimize_reaction_costs',
            'default' => 'sub {return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 23,
            'name' => 'numberOfSolutions',
            'default' => 1,
            'type' => 'Int',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => undef,
            'printOrder' => 12,
            'name' => 'fluxMinimization',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 16,
            'name' => 'thermodynamicConstraints',
            'default' => 1,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 22,
            'name' => 'defaultMaxDrainFlux',
            'default' => 1000,
            'type' => 'Num',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'reactionflux_objterms',
            'default' => 'sub {return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'tintleW',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'fbamodel_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'regmodel_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'reactionKO_refs',
            'default' => 'sub{return [];}',
            'type' => 'ArrayRef',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'fluxUseVariables',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => undef,
            'printOrder' => 13,
            'name' => 'findMinimalMedia',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 19,
            'name' => 'PROMKappa',
            'default' => 1,
            'type' => 'Num',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 15,
            'name' => 'simpleThermoConstraints',
            'default' => 1,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => undef,
            'printOrder' => 11,
            'name' => 'comboDeletions',
            'default' => 0,
            'type' => 'Int',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 21,
            'name' => 'defaultMinDrainFlux',
            'default' => -1000,
            'type' => 'Num',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => undef,
            'printOrder' => 10,
            'name' => 'fva',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'decomposeReversibleDrainFlux',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'biomassflux_objterms',
            'default' => 'sub {return {};}',
            'type' => 'HashRef',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 20,
            'name' => 'defaultMaxFlux',
            'default' => 1000,
            'type' => 'Num',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'decomposeReversibleFlux',
            'default' => 0,
            'type' => 'Bool',
            'description' => undef,
            'perm' => 'rw'
          }
        ];

my $attribute_map = {media_ref => 0, compoundflux_objterms => 1, phenotypesimulationset_ref => 2, maximizeObjective => 3, id => 4, phenotypeset_ref => 5, geneKO_refs => 6, inputfiles => 7, drainfluxUseVariables => 8, additionalCpd_refs => 9, outputfiles => 10, parameters => 11, noErrorThermodynamicConstraints => 12, objectiveConstraintFraction => 13, prommodel_ref => 14, minimize_reactions => 15, minimizeErrorThermodynamicConstraints => 16, uptakeLimits => 17, allReversible => 18, tintleKappa => 19, objectiveValue => 20, minimize_reaction_costs => 21, numberOfSolutions => 22, fluxMinimization => 23, thermodynamicConstraints => 24, defaultMaxDrainFlux => 25, reactionflux_objterms => 26, tintleW => 27, fbamodel_ref => 28, regmodel_ref => 29, reactionKO_refs => 30, fluxUseVariables => 31, findMinimalMedia => 32, PROMKappa => 33, simpleThermoConstraints => 34, comboDeletions => 35, defaultMinDrainFlux => 36, fva => 37, decomposeReversibleDrainFlux => 38, biomassflux_objterms => 39, defaultMaxFlux => 40, decomposeReversibleFlux => 41};
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
            'attribute' => 'media_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_media',
            'name' => 'media',
            'method' => 'Media',
            'class' => 'Bio::KBase::ObjectAPI::KBaseBiochem::Media',
            'module' => 'KBaseBiochem'
          },
          {
            'attribute' => 'phenotypesimulationset_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_phenotypesimulationset',
            'name' => 'phenotypesimulationset',
            'method' => 'PhenotypeSimulationSet',
            'class' => 'Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSimulationSet',
            'module' => 'KBasePhenotypes'
          },
          {
            'attribute' => 'phenotypeset_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_phenotypeset',
            'name' => 'phenotypeset',
            'method' => 'PhenotypeSet',
            'class' => 'Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSet',
            'module' => 'KBasePhenotypes'
          },
          {
            'parent' => 'Genome',
            'name' => 'geneKOs',
            'attribute' => 'geneKO_refs',
            'array' => 1,
            'clearer' => 'clear_geneKOs',
            'class' => 'Bio::KBase::ObjectAPI::KBaseGenomes::Feature',
            'method' => 'features',
            'module' => 'KBaseGenomes',
            'field' => 'id'
          },
          {
            'parent' => 'FBAModel',
            'name' => 'additionalCpds',
            'attribute' => 'additionalCpd_refs',
            'array' => 1,
            'clearer' => 'clear_additionalCpds',
            'class' => 'Bio::KBase::ObjectAPI::KBaseFBA::ModelCompound',
            'method' => 'modelcompounds',
            'module' => 'KBaseFBA',
            'field' => 'id'
          },
          {
            'attribute' => 'prommodel_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_prommodel',
            'name' => 'prommodel',
            'method' => 'PromConstraint',
            'class' => 'Bio::KBase::ObjectAPI::KBaseFBA::PromConstraint',
            'module' => 'KBaseFBA'
          },
          {
            'attribute' => 'fbamodel_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_fbamodel',
            'name' => 'fbamodel',
            'method' => 'FBAModel',
            'class' => 'Bio::KBase::ObjectAPI::KBaseFBA::FBAModel',
            'module' => 'KBaseFBA'
          },
          {
            'attribute' => 'regmodel_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_regmodel',
            'name' => 'regmodel',
            'method' => 'RegModel',
            'class' => 'RegModel',
            'module' => undef
          },
          {
            'parent' => 'FBAModel',
            'name' => 'reactionKOs',
            'attribute' => 'reactionKO_refs',
            'array' => 1,
            'clearer' => 'clear_reactionKOs',
            'class' => 'Bio::KBase::ObjectAPI::KBaseFBA::ModelReaction',
            'method' => 'modelreactions',
            'module' => 'KBaseFBA',
            'field' => 'id'
          }
        ];

my $link_map = {media => 0, phenotypesimulationset => 1, phenotypeset => 2, geneKOs => 3, additionalCpds => 4, prommodel => 5, fbamodel => 6, regmodel => 7, reactionKOs => 8};
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
            'name' => 'FBAMetaboliteProductionResults',
            'type' => 'child',
            'class' => 'FBAMetaboliteProductionResult',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBAReactionBounds',
            'type' => 'child',
            'class' => 'FBAReactionBound',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBAPromResults',
            'type' => 'child',
            'class' => 'FBAPromResult',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBAMinimalMediaResults',
            'type' => 'child',
            'class' => 'FBAMinimalMediaResult',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBABiomassVariables',
            'type' => 'child',
            'class' => 'FBABiomassVariable',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBACompoundBounds',
            'type' => 'child',
            'class' => 'FBACompoundBound',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBAMinimalReactionsResults',
            'type' => 'child',
            'class' => 'FBAMinimalReactionsResult',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'tintleSamples',
            'type' => 'child',
            'class' => 'TintleProbabilitySample',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBAConstraints',
            'type' => 'child',
            'class' => 'FBAConstraint',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBACompoundVariables',
            'type' => 'child',
            'class' => 'FBACompoundVariable',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBADeletionResults',
            'type' => 'child',
            'class' => 'FBADeletionResult',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'FBAReactionVariables',
            'type' => 'child',
            'class' => 'FBAReactionVariable',
            'module' => 'KBaseFBA'
          }
        ];

my $subobject_map = {FBAMetaboliteProductionResults => 0, FBAReactionBounds => 1, FBAPromResults => 2, FBAMinimalMediaResults => 3, FBABiomassVariables => 4, FBACompoundBounds => 5, FBAMinimalReactionsResults => 6, tintleSamples => 7, FBAConstraints => 8, FBACompoundVariables => 9, FBADeletionResults => 10, FBAReactionVariables => 11};
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
around 'FBAMetaboliteProductionResults' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAMetaboliteProductionResults');
};
around 'FBAReactionBounds' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAReactionBounds');
};
around 'FBAPromResults' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAPromResults');
};
around 'FBAMinimalMediaResults' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAMinimalMediaResults');
};
around 'FBABiomassVariables' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBABiomassVariables');
};
around 'FBACompoundBounds' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBACompoundBounds');
};
around 'FBAMinimalReactionsResults' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAMinimalReactionsResults');
};
around 'tintleSamples' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('tintleSamples');
};
around 'FBAConstraints' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAConstraints');
};
around 'FBACompoundVariables' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBACompoundVariables');
};
around 'FBADeletionResults' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBADeletionResults');
};
around 'FBAReactionVariables' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('FBAReactionVariables');
};


__PACKAGE__->meta->make_immutable;
1;
