package Bio::KBase::fbaModelServices::Client;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
use Bio::KBase::AuthToken;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

Bio::KBase::fbaModelServices::Client

=head1 DESCRIPTION


=head1 fbaModelServices

=head2 SYNOPSIS

The FBA Model Services include support related to the reconstruction, curation,
reconciliation, and analysis of metabolic models. This includes commands to:

1.) Load genome typed objects into a workspace

2.) Build a model from a genome typed object and curate the model

3.) Analyze a model with flux balance analysis

4.) Simulate and reconcile a model to an imported set of growth phenotype data

=head2 EXAMPLE OF API USE IN PERL

To use the API, first you need to instantiate a fbaModelServices client object:

my $client = Bio::KBase::fbaModelServices::Client->new;
   
Next, you can run API commands on the client object:
   
my $objmeta = $client->genome_to_workspace({
        genome => "kb|g.0",
        workspace => "myWorkspace"
});
my $objmeta = $client->genome_to_fbamodel({
        model => "myModel"
        workspace => "myWorkspace"
});

=head2 AUTHENTICATION

Each and every function in this service takes a hash reference as
its single argument. This hash reference may contain a key
C<auth> whose value is a bearer token for the user making
the request. If this is not provided a default user "public" is assumed.

=head2 WORKSPACE

A workspace is a named collection of objects owned by a specific
user, that may be viewable or editable by other users.Functions that operate
on workspaces take a C<workspace_id>, which is an alphanumeric string that
uniquely identifies a workspace among all workspaces.


=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => Bio::KBase::fbaModelServices::Client::RpcClient->new,
	url => $url,
    };

    #
    # This module requires authentication.
    #
    # We create an auth token, passing through the arguments that we were (hopefully) given.

    {
	my $token = Bio::KBase::AuthToken->new(@args);
	
	if (!$token->error_message)
	{
	    $self->{token} = $token->token;
	    $self->{client}->{token} = $token->token;
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 get_models

  $out_models = $obj->get_models($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_models_params
$out_models is a reference to a list where each element is an FBAModel
get_models_params is a reference to a hash where the following keys are defined:
	models has a value which is a reference to a list where each element is a fbamodel_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
fbamodel_id is a string
workspace_id is a string
FBAModel is a reference to a hash where the following keys are defined:
	id has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	map has a value which is a mapping_id
	map_workspace has a value which is a workspace_id
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	name has a value which is a string
	type has a value which is a string
	status has a value which is a string
	biomasses has a value which is a reference to a list where each element is a ModelBiomass
	compartments has a value which is a reference to a list where each element is a ModelCompartment
	reactions has a value which is a reference to a list where each element is a ModelReaction
	compounds has a value which is a reference to a list where each element is a ModelCompound
	fbas has a value which is a reference to a list where each element is an FBAMeta
	integrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
	unintegrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
	integrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta
	unintegrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta
genome_id is a string
mapping_id is a string
biochemistry_id is a string
ModelBiomass is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	definition has a value which is a string
	biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound
biomass_id is a string
BiomassCompound is a reference to a list containing 3 items:
	0: (modelcompound) a modelcompound_id
	1: (coefficient) a float
	2: (name) a string
modelcompound_id is a string
ModelCompartment is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
ModelReaction is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction has a value which is a reaction_id
	name has a value which is a string
	direction has a value which is a string
	equation has a value which is a string
	definition has a value which is a string
	gapfilled has a value which is a bool
	features has a value which is a reference to a list where each element is a feature_id
	compartment has a value which is a modelcompartment_id
modelreaction_id is a string
reaction_id is a string
bool is an int
feature_id is a string
ModelCompound is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	compound has a value which is a compound_id
	name has a value which is a string
	compartment has a value which is a modelcompartment_id
compound_id is a string
FBAMeta is a reference to a list containing 6 items:
	0: (id) a fba_id
	1: (workspace) a workspace_id
	2: (media) a media_id
	3: (media_workspace) a workspace_id
	4: (objective) a float
	5: (ko) a reference to a list where each element is a feature_id
fba_id is a string
media_id is a string
GapFillMeta is a reference to a list containing 6 items:
	0: (id) a gapfill_id
	1: (workspace) a workspace_id
	2: (media) a media_id
	3: (media_workspace) a workspace_id
	4: (done) a bool
	5: (ko) a reference to a list where each element is a feature_id
gapfill_id is a string
GapGenMeta is a reference to a list containing 6 items:
	0: (id) a gapgen_id
	1: (workspace) a workspace_id
	2: (media) a media_id
	3: (media_workspace) a workspace_id
	4: (done) a bool
	5: (ko) a reference to a list where each element is a feature_id
gapgen_id is a string

</pre>

=end html

=begin text

$input is a get_models_params
$out_models is a reference to a list where each element is an FBAModel
get_models_params is a reference to a hash where the following keys are defined:
	models has a value which is a reference to a list where each element is a fbamodel_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
fbamodel_id is a string
workspace_id is a string
FBAModel is a reference to a hash where the following keys are defined:
	id has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	map has a value which is a mapping_id
	map_workspace has a value which is a workspace_id
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	name has a value which is a string
	type has a value which is a string
	status has a value which is a string
	biomasses has a value which is a reference to a list where each element is a ModelBiomass
	compartments has a value which is a reference to a list where each element is a ModelCompartment
	reactions has a value which is a reference to a list where each element is a ModelReaction
	compounds has a value which is a reference to a list where each element is a ModelCompound
	fbas has a value which is a reference to a list where each element is an FBAMeta
	integrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
	unintegrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
	integrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta
	unintegrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta
genome_id is a string
mapping_id is a string
biochemistry_id is a string
ModelBiomass is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	definition has a value which is a string
	biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound
biomass_id is a string
BiomassCompound is a reference to a list containing 3 items:
	0: (modelcompound) a modelcompound_id
	1: (coefficient) a float
	2: (name) a string
modelcompound_id is a string
ModelCompartment is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
ModelReaction is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction has a value which is a reaction_id
	name has a value which is a string
	direction has a value which is a string
	equation has a value which is a string
	definition has a value which is a string
	gapfilled has a value which is a bool
	features has a value which is a reference to a list where each element is a feature_id
	compartment has a value which is a modelcompartment_id
modelreaction_id is a string
reaction_id is a string
bool is an int
feature_id is a string
ModelCompound is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	compound has a value which is a compound_id
	name has a value which is a string
	compartment has a value which is a modelcompartment_id
compound_id is a string
FBAMeta is a reference to a list containing 6 items:
	0: (id) a fba_id
	1: (workspace) a workspace_id
	2: (media) a media_id
	3: (media_workspace) a workspace_id
	4: (objective) a float
	5: (ko) a reference to a list where each element is a feature_id
fba_id is a string
media_id is a string
GapFillMeta is a reference to a list containing 6 items:
	0: (id) a gapfill_id
	1: (workspace) a workspace_id
	2: (media) a media_id
	3: (media_workspace) a workspace_id
	4: (done) a bool
	5: (ko) a reference to a list where each element is a feature_id
gapfill_id is a string
GapGenMeta is a reference to a list containing 6 items:
	0: (id) a gapgen_id
	1: (workspace) a workspace_id
	2: (media) a media_id
	3: (media_workspace) a workspace_id
	4: (done) a bool
	5: (ko) a reference to a list where each element is a feature_id
gapgen_id is a string


=end text

=item Description

Returns model data for input ids

=back

=cut

sub get_models
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_models (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_models');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_models",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_models',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_models",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_models',
				       );
    }
}



=head2 get_fbas

  $out_fbas = $obj->get_fbas($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_fbas_params
$out_fbas is a reference to a list where each element is an FBA
get_fbas_params is a reference to a hash where the following keys are defined:
	fbas has a value which is a reference to a list where each element is a fba_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
fba_id is a string
workspace_id is a string
FBA is a reference to a hash where the following keys are defined:
	id has a value which is a fba_id
	workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	objective has a value which is a float
	isComplete has a value which is a bool
	formulation has a value which is an FBAFormulation
	minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
	metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
	reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
	compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
	geneAssertions has a value which is a reference to a list where each element is a GeneAssertion
fbamodel_id is a string
bool is an int
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
MinimalMediaPrediction is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a compound_id
	essentialNutrients has a value which is a reference to a list where each element is a compound_id
MetaboliteProduction is a reference to a list containing 3 items:
	0: (maximumProduction) a float
	1: (modelcompound) a modelcompound_id
	2: (name) a string
modelcompound_id is a string
ReactionFlux is a reference to a list containing 8 items:
	0: (reaction) a modelreaction_id
	1: (value) a float
	2: (upperBound) a float
	3: (lowerBound) a float
	4: (max) a float
	5: (min) a float
	6: (type) a string
	7: (definition) a string
modelreaction_id is a string
CompoundFlux is a reference to a list containing 8 items:
	0: (compound) a modelcompound_id
	1: (value) a float
	2: (upperBound) a float
	3: (lowerBound) a float
	4: (max) a float
	5: (min) a float
	6: (type) a string
	7: (name) a string
GeneAssertion is a reference to a list containing 4 items:
	0: (feature) a feature_id
	1: (growthFraction) a float
	2: (growth) a float
	3: (isEssential) a bool

</pre>

=end html

=begin text

$input is a get_fbas_params
$out_fbas is a reference to a list where each element is an FBA
get_fbas_params is a reference to a hash where the following keys are defined:
	fbas has a value which is a reference to a list where each element is a fba_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
fba_id is a string
workspace_id is a string
FBA is a reference to a hash where the following keys are defined:
	id has a value which is a fba_id
	workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	objective has a value which is a float
	isComplete has a value which is a bool
	formulation has a value which is an FBAFormulation
	minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
	metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
	reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
	compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
	geneAssertions has a value which is a reference to a list where each element is a GeneAssertion
fbamodel_id is a string
bool is an int
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
MinimalMediaPrediction is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a compound_id
	essentialNutrients has a value which is a reference to a list where each element is a compound_id
MetaboliteProduction is a reference to a list containing 3 items:
	0: (maximumProduction) a float
	1: (modelcompound) a modelcompound_id
	2: (name) a string
modelcompound_id is a string
ReactionFlux is a reference to a list containing 8 items:
	0: (reaction) a modelreaction_id
	1: (value) a float
	2: (upperBound) a float
	3: (lowerBound) a float
	4: (max) a float
	5: (min) a float
	6: (type) a string
	7: (definition) a string
modelreaction_id is a string
CompoundFlux is a reference to a list containing 8 items:
	0: (compound) a modelcompound_id
	1: (value) a float
	2: (upperBound) a float
	3: (lowerBound) a float
	4: (max) a float
	5: (min) a float
	6: (type) a string
	7: (name) a string
GeneAssertion is a reference to a list containing 4 items:
	0: (feature) a feature_id
	1: (growthFraction) a float
	2: (growth) a float
	3: (isEssential) a bool


=end text

=item Description

Returns data for the requested flux balance analysis formulations

=back

=cut

sub get_fbas
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_fbas (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_fbas:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_fbas');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_fbas",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_fbas',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_fbas",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_fbas',
				       );
    }
}



=head2 get_gapfills

  $out_gapfills = $obj->get_gapfills($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_gapfills_params
$out_gapfills is a reference to a list where each element is a GapFill
get_gapfills_params is a reference to a hash where the following keys are defined:
	gapfills has a value which is a reference to a list where each element is a gapfill_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
gapfill_id is a string
workspace_id is a string
GapFill is a reference to a hash where the following keys are defined:
	id has a value which is a gapfill_id
	workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	isComplete has a value which is a bool
	formulation has a value which is a GapfillingFormulation
	solutions has a value which is a reference to a list where each element is a GapFillSolution
fbamodel_id is a string
bool is an int
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
compartment_id is a string
probanno_id is a string
GapFillSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapfillsolution_id
	objective has a value which is a float
	integrated has a value which is a bool
	biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
	mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
gapfillsolution_id is a string
biomassRemoval is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
mediaAddition is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
reactionAddition is a reference to a list containing 5 items:
	0: (reaction) a reaction_id
	1: (direction) a string
	2: (compartment_id) a string
	3: (equation) a string
	4: (definition) a string

</pre>

=end html

=begin text

$input is a get_gapfills_params
$out_gapfills is a reference to a list where each element is a GapFill
get_gapfills_params is a reference to a hash where the following keys are defined:
	gapfills has a value which is a reference to a list where each element is a gapfill_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
gapfill_id is a string
workspace_id is a string
GapFill is a reference to a hash where the following keys are defined:
	id has a value which is a gapfill_id
	workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	isComplete has a value which is a bool
	formulation has a value which is a GapfillingFormulation
	solutions has a value which is a reference to a list where each element is a GapFillSolution
fbamodel_id is a string
bool is an int
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
compartment_id is a string
probanno_id is a string
GapFillSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapfillsolution_id
	objective has a value which is a float
	integrated has a value which is a bool
	biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
	mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
gapfillsolution_id is a string
biomassRemoval is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
mediaAddition is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
reactionAddition is a reference to a list containing 5 items:
	0: (reaction) a reaction_id
	1: (direction) a string
	2: (compartment_id) a string
	3: (equation) a string
	4: (definition) a string


=end text

=item Description

Returns data for the requested gap filling simulations

=back

=cut

sub get_gapfills
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_gapfills (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_gapfills:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_gapfills');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_gapfills",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_gapfills',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_gapfills",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_gapfills',
				       );
    }
}



=head2 get_gapgens

  $out_gapgens = $obj->get_gapgens($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_gapgens_params
$out_gapgens is a reference to a list where each element is a GapGen
get_gapgens_params is a reference to a hash where the following keys are defined:
	gapgens has a value which is a reference to a list where each element is a gapgen_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
gapgen_id is a string
workspace_id is a string
GapGen is a reference to a hash where the following keys are defined:
	id has a value which is a gapgen_id
	workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	isComplete has a value which is a bool
	formulation has a value which is a GapgenFormulation
	solutions has a value which is a reference to a list where each element is a GapgenSolution
fbamodel_id is a string
bool is an int
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapgenSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapgensolution_id
	objective has a value which is a float
	biomassAdditions has a value which is a reference to a list where each element is a biomassAddition
	mediaRemovals has a value which is a reference to a list where each element is a mediaRemoval
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
gapgensolution_id is a string
biomassAddition is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
mediaRemoval is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
reactionRemoval is a reference to a list containing 4 items:
	0: (reaction) a modelreaction_id
	1: (direction) a string
	2: (equation) a string
	3: (definition) a string
modelreaction_id is a string

</pre>

=end html

=begin text

$input is a get_gapgens_params
$out_gapgens is a reference to a list where each element is a GapGen
get_gapgens_params is a reference to a hash where the following keys are defined:
	gapgens has a value which is a reference to a list where each element is a gapgen_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
	id_type has a value which is a string
gapgen_id is a string
workspace_id is a string
GapGen is a reference to a hash where the following keys are defined:
	id has a value which is a gapgen_id
	workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	isComplete has a value which is a bool
	formulation has a value which is a GapgenFormulation
	solutions has a value which is a reference to a list where each element is a GapgenSolution
fbamodel_id is a string
bool is an int
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapgenSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapgensolution_id
	objective has a value which is a float
	biomassAdditions has a value which is a reference to a list where each element is a biomassAddition
	mediaRemovals has a value which is a reference to a list where each element is a mediaRemoval
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
gapgensolution_id is a string
biomassAddition is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
mediaRemoval is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (name) a string
reactionRemoval is a reference to a list containing 4 items:
	0: (reaction) a modelreaction_id
	1: (direction) a string
	2: (equation) a string
	3: (definition) a string
modelreaction_id is a string


=end text

=item Description

Returns data for the requested gap generation simulations

=back

=cut

sub get_gapgens
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_gapgens (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_gapgens:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_gapgens');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_gapgens",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_gapgens',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_gapgens",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_gapgens',
				       );
    }
}



=head2 get_reactions

  $out_reactions = $obj->get_reactions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_reactions_params
$out_reactions is a reference to a list where each element is a Reaction
get_reactions_params is a reference to a hash where the following keys are defined:
	reactions has a value which is a reference to a list where each element is a reaction_id
	auth has a value which is a string
	id_type has a value which is a string
reaction_id is a string
Reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	name has a value which is a string
	abbrev has a value which is a string
	enzymes has a value which is a reference to a list where each element is a string
	direction has a value which is a string
	reversibility has a value which is a string
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	equation has a value which is a string
	definition has a value which is a string

</pre>

=end html

=begin text

$input is a get_reactions_params
$out_reactions is a reference to a list where each element is a Reaction
get_reactions_params is a reference to a hash where the following keys are defined:
	reactions has a value which is a reference to a list where each element is a reaction_id
	auth has a value which is a string
	id_type has a value which is a string
reaction_id is a string
Reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	name has a value which is a string
	abbrev has a value which is a string
	enzymes has a value which is a reference to a list where each element is a string
	direction has a value which is a string
	reversibility has a value which is a string
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	equation has a value which is a string
	definition has a value which is a string


=end text

=item Description

Returns data for the requested reactions

=back

=cut

sub get_reactions
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_reactions (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_reactions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_reactions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_reactions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_reactions",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_reactions',
				       );
    }
}



=head2 get_compounds

  $out_compounds = $obj->get_compounds($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_compounds_params
$out_compounds is a reference to a list where each element is a Compound
get_compounds_params is a reference to a hash where the following keys are defined:
	compounds has a value which is a reference to a list where each element is a compound_id
	auth has a value which is a string
	id_type has a value which is a string
compound_id is a string
Compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	abbrev has a value which is a string
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	charge has a value which is a float
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	formula has a value which is a string

</pre>

=end html

=begin text

$input is a get_compounds_params
$out_compounds is a reference to a list where each element is a Compound
get_compounds_params is a reference to a hash where the following keys are defined:
	compounds has a value which is a reference to a list where each element is a compound_id
	auth has a value which is a string
	id_type has a value which is a string
compound_id is a string
Compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	abbrev has a value which is a string
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	charge has a value which is a float
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	formula has a value which is a string


=end text

=item Description

Returns data for the requested compounds

=back

=cut

sub get_compounds
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_compounds (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_compounds:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_compounds');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_compounds",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_compounds',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_compounds",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_compounds',
				       );
    }
}



=head2 get_alias

  $output = $obj->get_alias($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_alias_params
$output is a reference to a list where each element is a get_alias_outputs
get_alias_params is a reference to a hash where the following keys are defined:
	object_type has a value which is a string
	input_id_type has a value which is a string
	output_id_type has a value which is a string
	input_ids has a value which is a reference to a list where each element is a string
	auth has a value which is a string
get_alias_outputs is a reference to a hash where the following keys are defined:
	original_id has a value which is a string
	aliases has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

$input is a get_alias_params
$output is a reference to a list where each element is a get_alias_outputs
get_alias_params is a reference to a hash where the following keys are defined:
	object_type has a value which is a string
	input_id_type has a value which is a string
	output_id_type has a value which is a string
	input_ids has a value which is a reference to a list where each element is a string
	auth has a value which is a string
get_alias_outputs is a reference to a hash where the following keys are defined:
	original_id has a value which is a string
	aliases has a value which is a reference to a list where each element is a string


=end text

=item Description

Turns one compound I into another of a different type

=back

=cut

sub get_alias
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_alias (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_alias:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_alias');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_alias",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_alias',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_alias",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_alias',
				       );
    }
}



=head2 get_aliassets

  $aliassets = $obj->get_aliassets($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_aliassets_params
$aliassets is a reference to a list where each element is a string
get_aliassets_params is a reference to a hash where the following keys are defined:
	object_type has a value which is a string
	auth has a value which is a string

</pre>

=end html

=begin text

$input is a get_aliassets_params
$aliassets is a reference to a list where each element is a string
get_aliassets_params is a reference to a hash where the following keys are defined:
	object_type has a value which is a string
	auth has a value which is a string


=end text

=item Description

Get possible types of aliases (alias sets)

=back

=cut

sub get_aliassets
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_aliassets (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_aliassets:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_aliassets');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_aliassets",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_aliassets',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_aliassets",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_aliassets',
				       );
    }
}



=head2 get_media

  $out_media = $obj->get_media($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_media_params
$out_media is a reference to a list where each element is a Media
get_media_params is a reference to a hash where the following keys are defined:
	medias has a value which is a reference to a list where each element is a media_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
media_id is a string
workspace_id is a string
Media is a reference to a hash where the following keys are defined:
	id has a value which is a media_id
	name has a value which is a string
	media_compounds has a value which is a reference to a list where each element is a MediaCompound
	pH has a value which is a float
	temperature has a value which is a float
MediaCompound is a reference to a hash where the following keys are defined:
	compound has a value which is a compound_id
	name has a value which is a string
	concentration has a value which is a float
	max_flux has a value which is a float
	min_flux has a value which is a float
compound_id is a string

</pre>

=end html

=begin text

$input is a get_media_params
$out_media is a reference to a list where each element is a Media
get_media_params is a reference to a hash where the following keys are defined:
	medias has a value which is a reference to a list where each element is a media_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
media_id is a string
workspace_id is a string
Media is a reference to a hash where the following keys are defined:
	id has a value which is a media_id
	name has a value which is a string
	media_compounds has a value which is a reference to a list where each element is a MediaCompound
	pH has a value which is a float
	temperature has a value which is a float
MediaCompound is a reference to a hash where the following keys are defined:
	compound has a value which is a compound_id
	name has a value which is a string
	concentration has a value which is a float
	max_flux has a value which is a float
	min_flux has a value which is a float
compound_id is a string


=end text

=item Description

Returns data for the requested media formulations

=back

=cut

sub get_media
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_media (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_media');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_media",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_media',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_media",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_media',
				       );
    }
}



=head2 get_biochemistry

  $out_biochemistry = $obj->get_biochemistry($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_biochemistry_params
$out_biochemistry is a Biochemistry
get_biochemistry_params is a reference to a hash where the following keys are defined:
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	id_type has a value which is a string
	auth has a value which is a string
biochemistry_id is a string
workspace_id is a string
Biochemistry is a reference to a hash where the following keys are defined:
	id has a value which is a biochemistry_id
	name has a value which is a string
	compounds has a value which is a reference to a list where each element is a compound_id
	reactions has a value which is a reference to a list where each element is a reaction_id
	media has a value which is a reference to a list where each element is a media_id
compound_id is a string
reaction_id is a string
media_id is a string

</pre>

=end html

=begin text

$input is a get_biochemistry_params
$out_biochemistry is a Biochemistry
get_biochemistry_params is a reference to a hash where the following keys are defined:
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	id_type has a value which is a string
	auth has a value which is a string
biochemistry_id is a string
workspace_id is a string
Biochemistry is a reference to a hash where the following keys are defined:
	id has a value which is a biochemistry_id
	name has a value which is a string
	compounds has a value which is a reference to a list where each element is a compound_id
	reactions has a value which is a reference to a list where each element is a reaction_id
	media has a value which is a reference to a list where each element is a media_id
compound_id is a string
reaction_id is a string
media_id is a string


=end text

=item Description

Returns biochemistry object

=back

=cut

sub get_biochemistry
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_biochemistry (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_biochemistry:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_biochemistry');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_biochemistry",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_biochemistry',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_biochemistry",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_biochemistry',
				       );
    }
}



=head2 import_probanno

  $probannoMeta = $obj->import_probanno($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an import_probanno_params
$probannoMeta is an object_metadata
import_probanno_params is a reference to a hash where the following keys are defined:
	probanno has a value which is a probanno_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	annotationProbabilities has a value which is a reference to a list where each element is an annotationProbability
	ignore_errors has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
probanno_id is a string
workspace_id is a string
genome_id is a string
annotationProbability is a reference to a list containing 3 items:
	0: (feature) a feature_id
	1: (function) a string
	2: (probability) a float
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an import_probanno_params
$probannoMeta is an object_metadata
import_probanno_params is a reference to a hash where the following keys are defined:
	probanno has a value which is a probanno_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	annotationProbabilities has a value which is a reference to a list where each element is an annotationProbability
	ignore_errors has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
probanno_id is a string
workspace_id is a string
genome_id is a string
annotationProbability is a reference to a list containing 3 items:
	0: (feature) a feature_id
	1: (function) a string
	2: (probability) a float
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Loads an input genome object into the workspace.

=back

=cut

sub import_probanno
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_probanno (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_probanno:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_probanno');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.import_probanno",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_probanno',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_probanno",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_probanno',
				       );
    }
}



=head2 genome_object_to_workspace

  $genomeMeta = $obj->genome_object_to_workspace($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_object_to_workspace_params
$genomeMeta is an object_metadata
genome_object_to_workspace_params is a reference to a hash where the following keys are defined:
	uid has a value which is a Genome_uid
	genomeobj has a value which is a GenomeObject
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
Genome_uid is a string
GenomeObject is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	source has a value which is a string
	source_id has a value which is a string
	contigs has a value which is a reference to a list where each element is a contig
	features has a value which is a reference to a list where each element is a feature
genome_id is a string
contig is a reference to a hash where the following keys are defined:
	id has a value which is a contig_id
	dna has a value which is a string
contig_id is a string
feature is a reference to a hash where the following keys are defined:
	id has a value which is a feature_id
	location has a value which is a location
	type has a value which is a feature_type
	function has a value which is a string
	alternative_functions has a value which is a reference to a list where each element is an alt_func
	protein_translation has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	annotations has a value which is a reference to a list where each element is an annotation
feature_id is a string
location is a reference to a list where each element is a region_of_dna
region_of_dna is a reference to a list containing 4 items:
	0: a contig_id
	1: (begin) an int
	2: (strand) a string
	3: (length) an int
feature_type is a string
alt_func is a reference to a list containing 2 items:
	0: (function) a string
	1: (probability) a float
gene_hit is a reference to a list containing 2 items:
	0: (gene) a feature_id
	1: (blast_score) a float
annotation is a reference to a list containing 3 items:
	0: (comment) a string
	1: (annotator) a string
	2: (annotation_time) an int
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a genome_object_to_workspace_params
$genomeMeta is an object_metadata
genome_object_to_workspace_params is a reference to a hash where the following keys are defined:
	uid has a value which is a Genome_uid
	genomeobj has a value which is a GenomeObject
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
Genome_uid is a string
GenomeObject is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	source has a value which is a string
	source_id has a value which is a string
	contigs has a value which is a reference to a list where each element is a contig
	features has a value which is a reference to a list where each element is a feature
genome_id is a string
contig is a reference to a hash where the following keys are defined:
	id has a value which is a contig_id
	dna has a value which is a string
contig_id is a string
feature is a reference to a hash where the following keys are defined:
	id has a value which is a feature_id
	location has a value which is a location
	type has a value which is a feature_type
	function has a value which is a string
	alternative_functions has a value which is a reference to a list where each element is an alt_func
	protein_translation has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	annotations has a value which is a reference to a list where each element is an annotation
feature_id is a string
location is a reference to a list where each element is a region_of_dna
region_of_dna is a reference to a list containing 4 items:
	0: a contig_id
	1: (begin) an int
	2: (strand) a string
	3: (length) an int
feature_type is a string
alt_func is a reference to a list containing 2 items:
	0: (function) a string
	1: (probability) a float
gene_hit is a reference to a list containing 2 items:
	0: (gene) a feature_id
	1: (blast_score) a float
annotation is a reference to a list containing 3 items:
	0: (comment) a string
	1: (annotator) a string
	2: (annotation_time) an int
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Loads an input genome object into the workspace.

=back

=cut

sub genome_object_to_workspace
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function genome_object_to_workspace (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to genome_object_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'genome_object_to_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.genome_object_to_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'genome_object_to_workspace',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method genome_object_to_workspace",
					    status_line => $self->{client}->status_line,
					    method_name => 'genome_object_to_workspace',
				       );
    }
}



=head2 genome_to_workspace

  $genomeMeta = $obj->genome_to_workspace($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_to_workspace_params
$genomeMeta is an object_metadata
genome_to_workspace_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	sourceLogin has a value which is a string
	sourcePassword has a value which is a string
	source has a value which is a string
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a genome_to_workspace_params
$genomeMeta is an object_metadata
genome_to_workspace_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	sourceLogin has a value which is a string
	sourcePassword has a value which is a string
	source has a value which is a string
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Retrieves a genome from the CDM and saves it as a genome object in the workspace.

=back

=cut

sub genome_to_workspace
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function genome_to_workspace (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to genome_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'genome_to_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.genome_to_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'genome_to_workspace',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method genome_to_workspace",
					    status_line => $self->{client}->status_line,
					    method_name => 'genome_to_workspace',
				       );
    }
}



=head2 add_feature_translation

  $genomeMeta = $obj->add_feature_translation($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an add_feature_translation_params
$genomeMeta is an object_metadata
add_feature_translation_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	translations has a value which is a reference to a list where each element is a translation
	id_type has a value which is a string
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
translation is a reference to a list containing 2 items:
	0: (foreign_id) a string
	1: (feature) a feature_id
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an add_feature_translation_params
$genomeMeta is an object_metadata
add_feature_translation_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	translations has a value which is a reference to a list where each element is a translation
	id_type has a value which is a string
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
translation is a reference to a list containing 2 items:
	0: (foreign_id) a string
	1: (feature) a feature_id
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Adds a new set of alternative feature IDs to the specified genome typed object

=back

=cut

sub add_feature_translation
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function add_feature_translation (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to add_feature_translation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'add_feature_translation');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.add_feature_translation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'add_feature_translation',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method add_feature_translation",
					    status_line => $self->{client}->status_line,
					    method_name => 'add_feature_translation',
				       );
    }
}



=head2 genome_to_fbamodel

  $modelMeta = $obj->genome_to_fbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_to_fbamodel_params
$modelMeta is an object_metadata
genome_to_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	templatemodel has a value which is a template_id
	templatemodel_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	coremodel has a value which is a bool
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
template_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a genome_to_fbamodel_params
$modelMeta is an object_metadata
genome_to_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	templatemodel has a value which is a template_id
	templatemodel_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	coremodel has a value which is a bool
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
template_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Build a genome-scale metabolic model based on annotations in an input genome typed object

=back

=cut

sub genome_to_fbamodel
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function genome_to_fbamodel (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'genome_to_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.genome_to_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'genome_to_fbamodel',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method genome_to_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'genome_to_fbamodel',
				       );
    }
}



=head2 import_fbamodel

  $modelMeta = $obj->import_fbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an import_fbamodel_params
$modelMeta is an object_metadata
import_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	biomass has a value which is a string
	reactions has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: (id) a string
	1: (direction) a string
	2: (compartment) a string
	3: (gpr) a string

	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	ignore_errors has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an import_fbamodel_params
$modelMeta is an object_metadata
import_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	biomass has a value which is a string
	reactions has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: (id) a string
	1: (direction) a string
	2: (compartment) a string
	3: (gpr) a string

	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	ignore_errors has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Import a model from an input table of model and gene IDs

=back

=cut

sub import_fbamodel
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_fbamodel (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.import_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_fbamodel',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_fbamodel',
				       );
    }
}



=head2 export_fbamodel

  $output = $obj->export_fbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_fbamodel_params
$output is a string
export_fbamodel_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_fbamodel_params
$output is a string
export_fbamodel_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string


=end text

=item Description

This function exports the specified FBAModel to a specified format (sbml,html)

=back

=cut

sub export_fbamodel
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_fbamodel (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.export_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_fbamodel',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_fbamodel',
				       );
    }
}



=head2 export_object

  $output = $obj->export_object($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_object_params
$output is a string
export_object_params is a reference to a hash where the following keys are defined:
	reference has a value which is a workspace_ref
	type has a value which is a string
	format has a value which is a string
	auth has a value which is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an export_object_params
$output is a string
export_object_params is a reference to a hash where the following keys are defined:
	reference has a value which is a workspace_ref
	type has a value which is a string
	format has a value which is a string
	auth has a value which is a string
workspace_ref is a string


=end text

=item Description

This function prints the object pointed to by the input reference in the specified format

=back

=cut

sub export_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_object (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.export_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_object',
				       );
    }
}



=head2 export_genome

  $output = $obj->export_genome($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_genome_params
$output is a string
export_genome_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
genome_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_genome_params
$output is a string
export_genome_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
genome_id is a string
workspace_id is a string


=end text

=item Description

This function exports the specified FBAModel to a specified format (sbml,html)

=back

=cut

sub export_genome
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_genome (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.export_genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_genome',
				       );
    }
}



=head2 adjust_model_reaction

  $modelMeta = $obj->adjust_model_reaction($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an adjust_model_reaction_params
$modelMeta is an object_metadata
adjust_model_reaction_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	reaction has a value which is a reference to a list where each element is a reaction_id
	direction has a value which is a reference to a list where each element is a string
	compartment has a value which is a reference to a list where each element is a compartment_id
	compartmentIndex has a value which is a reference to a list where each element is an int
	gpr has a value which is a reference to a list where each element is a string
	removeReaction has a value which is a bool
	addReaction has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
reaction_id is a string
compartment_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an adjust_model_reaction_params
$modelMeta is an object_metadata
adjust_model_reaction_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	reaction has a value which is a reference to a list where each element is a reaction_id
	direction has a value which is a reference to a list where each element is a string
	compartment has a value which is a reference to a list where each element is a compartment_id
	compartmentIndex has a value which is a reference to a list where each element is an int
	gpr has a value which is a reference to a list where each element is a string
	removeReaction has a value which is a bool
	addReaction has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
reaction_id is a string
compartment_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Enables the manual addition of a reaction to model

=back

=cut

sub adjust_model_reaction
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_model_reaction (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_model_reaction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_model_reaction');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_model_reaction",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_model_reaction',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_model_reaction",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_model_reaction',
				       );
    }
}



=head2 adjust_biomass_reaction

  $modelMeta = $obj->adjust_biomass_reaction($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an adjust_biomass_reaction_params
$modelMeta is an object_metadata
adjust_biomass_reaction_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	biomass has a value which is a biomass_id
	coefficients has a value which is a reference to a list where each element is a float
	compounds has a value which is a reference to a list where each element is a compound_id
	compartments has a value which is a reference to a list where each element is a compartment_id
	compartmentIndecies has a value which is a reference to a list where each element is an int
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
biomass_id is a string
compound_id is a string
compartment_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an adjust_biomass_reaction_params
$modelMeta is an object_metadata
adjust_biomass_reaction_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	biomass has a value which is a biomass_id
	coefficients has a value which is a reference to a list where each element is a float
	compounds has a value which is a reference to a list where each element is a compound_id
	compartments has a value which is a reference to a list where each element is a compartment_id
	compartmentIndecies has a value which is a reference to a list where each element is an int
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
biomass_id is a string
compound_id is a string
compartment_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Enables the manual adjustment of model biomass reaction

=back

=cut

sub adjust_biomass_reaction
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_biomass_reaction (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_biomass_reaction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_biomass_reaction');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_biomass_reaction",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_biomass_reaction',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_biomass_reaction",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_biomass_reaction',
				       );
    }
}



=head2 addmedia

  $mediaMeta = $obj->addmedia($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an addmedia_params
$mediaMeta is an object_metadata
addmedia_params is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	name has a value which is a string
	isDefined has a value which is a bool
	isMinimal has a value which is a bool
	type has a value which is a string
	compounds has a value which is a reference to a list where each element is a string
	concentrations has a value which is a reference to a list where each element is a float
	maxflux has a value which is a reference to a list where each element is a float
	minflux has a value which is a reference to a list where each element is a float
	overwrite has a value which is a bool
	auth has a value which is a string
media_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an addmedia_params
$mediaMeta is an object_metadata
addmedia_params is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	name has a value which is a string
	isDefined has a value which is a bool
	isMinimal has a value which is a bool
	type has a value which is a string
	compounds has a value which is a reference to a list where each element is a string
	concentrations has a value which is a reference to a list where each element is a float
	maxflux has a value which is a reference to a list where each element is a float
	minflux has a value which is a reference to a list where each element is a float
	overwrite has a value which is a bool
	auth has a value which is a string
media_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Add media condition to workspace

=back

=cut

sub addmedia
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function addmedia (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to addmedia:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'addmedia');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.addmedia",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'addmedia',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method addmedia",
					    status_line => $self->{client}->status_line,
					    method_name => 'addmedia',
				       );
    }
}



=head2 export_media

  $output = $obj->export_media($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_media_params
$output is a string
export_media_params is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
media_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_media_params
$output is a string
export_media_params is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
media_id is a string
workspace_id is a string


=end text

=item Description

Exports media in specified format (html,readable)

=back

=cut

sub export_media
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_media (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_media');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.export_media",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_media',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_media",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_media',
				       );
    }
}



=head2 runfba

  $fbaMeta = $obj->runfba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a runfba_params
$fbaMeta is an object_metadata
runfba_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	fva has a value which is a bool
	simulateko has a value which is a bool
	minimizeflux has a value which is a bool
	findminmedia has a value which is a bool
	notes has a value which is a string
	fba has a value which is a fba_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
fba_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a runfba_params
$fbaMeta is an object_metadata
runfba_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	fva has a value which is a bool
	simulateko has a value which is a bool
	minimizeflux has a value which is a bool
	findminmedia has a value which is a bool
	notes has a value which is a string
	fba has a value which is a fba_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
fba_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Run flux balance analysis and return ID of FBA object with results

=back

=cut

sub runfba
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function runfba (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'runfba');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.runfba",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'runfba',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method runfba",
					    status_line => $self->{client}->status_line,
					    method_name => 'runfba',
				       );
    }
}



=head2 export_fba

  $output = $obj->export_fba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_fba_params
$output is a string
export_fba_params is a reference to a hash where the following keys are defined:
	fba has a value which is a fba_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
fba_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_fba_params
$output is a string
export_fba_params is a reference to a hash where the following keys are defined:
	fba has a value which is a fba_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
fba_id is a string
workspace_id is a string


=end text

=item Description

Export an FBA solution for viewing

=back

=cut

sub export_fba
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_fba (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_fba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_fba');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.export_fba",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_fba',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_fba",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_fba',
				       );
    }
}



=head2 import_phenotypes

  $output = $obj->import_phenotypes($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an import_phenotypes_params
$output is an object_metadata
import_phenotypes_params is a reference to a hash where the following keys are defined:
	phenotypeSet has a value which is a phenotype_set_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	phenotypes has a value which is a reference to a list where each element is a Phenotype
	name has a value which is a string
	source has a value which is a string
	ignore_errors has a value which is a bool
	auth has a value which is a string
phenotype_set_id is a string
workspace_id is a string
genome_id is a string
Phenotype is a reference to a list containing 6 items:
	0: (geneKO) a reference to a list where each element is a feature_id
	1: (baseMedia) a media_id
	2: (media_workspace) a workspace_id
	3: (additionalCpd) a reference to a list where each element is a compound_id
	4: (normalizedGrowth) a float
	5: (label) a string
feature_id is a string
media_id is a string
compound_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an import_phenotypes_params
$output is an object_metadata
import_phenotypes_params is a reference to a hash where the following keys are defined:
	phenotypeSet has a value which is a phenotype_set_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	phenotypes has a value which is a reference to a list where each element is a Phenotype
	name has a value which is a string
	source has a value which is a string
	ignore_errors has a value which is a bool
	auth has a value which is a string
phenotype_set_id is a string
workspace_id is a string
genome_id is a string
Phenotype is a reference to a list containing 6 items:
	0: (geneKO) a reference to a list where each element is a feature_id
	1: (baseMedia) a media_id
	2: (media_workspace) a workspace_id
	3: (additionalCpd) a reference to a list where each element is a compound_id
	4: (normalizedGrowth) a float
	5: (label) a string
feature_id is a string
media_id is a string
compound_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Loads the specified phenotypes into the workspace

=back

=cut

sub import_phenotypes
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_phenotypes (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_phenotypes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_phenotypes');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.import_phenotypes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_phenotypes',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_phenotypes",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_phenotypes',
				       );
    }
}



=head2 simulate_phenotypes

  $output = $obj->simulate_phenotypes($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a simulate_phenotypes_params
$output is an object_metadata
simulate_phenotypes_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
	workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
	all_transporters has a value which is a bool
	positive_transporters has a value which is a bool
fbamodel_id is a string
workspace_id is a string
phenotype_set_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
phenotypeSimulationSet_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a simulate_phenotypes_params
$output is an object_metadata
simulate_phenotypes_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
	workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
	all_transporters has a value which is a bool
	positive_transporters has a value which is a bool
fbamodel_id is a string
workspace_id is a string
phenotype_set_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
phenotypeSimulationSet_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Simulates the specified phenotype set

=back

=cut

sub simulate_phenotypes
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function simulate_phenotypes (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to simulate_phenotypes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'simulate_phenotypes');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.simulate_phenotypes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'simulate_phenotypes',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method simulate_phenotypes",
					    status_line => $self->{client}->status_line,
					    method_name => 'simulate_phenotypes',
				       );
    }
}



=head2 add_media_transporters

  $output = $obj->add_media_transporters($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an add_media_transporters_params
$output is an object_metadata
add_media_transporters_params is a reference to a hash where the following keys are defined:
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	outmodel has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
	all_transporters has a value which is a bool
	positive_transporters has a value which is a bool
phenotype_set_id is a string
workspace_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an add_media_transporters_params
$output is an object_metadata
add_media_transporters_params is a reference to a hash where the following keys are defined:
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	outmodel has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
	all_transporters has a value which is a bool
	positive_transporters has a value which is a bool
phenotype_set_id is a string
workspace_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Adds transporters for media in a PhenotypeSet to a model

=back

=cut

sub add_media_transporters
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function add_media_transporters (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to add_media_transporters:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'add_media_transporters');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.add_media_transporters",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'add_media_transporters',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method add_media_transporters",
					    status_line => $self->{client}->status_line,
					    method_name => 'add_media_transporters',
				       );
    }
}



=head2 export_phenotypeSimulationSet

  $output = $obj->export_phenotypeSimulationSet($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_phenotypeSimulationSet_params
$output is a string
export_phenotypeSimulationSet_params is a reference to a hash where the following keys are defined:
	phenotypeSimulationSet has a value which is a phenotypeSimulationSet_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
phenotypeSimulationSet_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_phenotypeSimulationSet_params
$output is a string
export_phenotypeSimulationSet_params is a reference to a hash where the following keys are defined:
	phenotypeSimulationSet has a value which is a phenotypeSimulationSet_id
	workspace has a value which is a workspace_id
	format has a value which is a string
	auth has a value which is a string
phenotypeSimulationSet_id is a string
workspace_id is a string


=end text

=item Description

Export a PhenotypeSimulationSet for viewing

=back

=cut

sub export_phenotypeSimulationSet
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_phenotypeSimulationSet (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_phenotypeSimulationSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_phenotypeSimulationSet');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.export_phenotypeSimulationSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_phenotypeSimulationSet',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_phenotypeSimulationSet",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_phenotypeSimulationSet',
				       );
    }
}



=head2 integrate_reconciliation_solutions

  $modelMeta = $obj->integrate_reconciliation_solutions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an integrate_reconciliation_solutions_params
$modelMeta is an object_metadata
integrate_reconciliation_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	gapfillSolutions has a value which is a reference to a list where each element is a gapfillsolution_id
	gapgenSolutions has a value which is a reference to a list where each element is a gapgensolution_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
gapfillsolution_id is a string
gapgensolution_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an integrate_reconciliation_solutions_params
$modelMeta is an object_metadata
integrate_reconciliation_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	gapfillSolutions has a value which is a reference to a list where each element is a gapfillsolution_id
	gapgenSolutions has a value which is a reference to a list where each element is a gapgensolution_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
gapfillsolution_id is a string
gapgensolution_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Integrates the specified gapfill and gapgen solutions into the specified model

=back

=cut

sub integrate_reconciliation_solutions
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function integrate_reconciliation_solutions (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to integrate_reconciliation_solutions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'integrate_reconciliation_solutions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.integrate_reconciliation_solutions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'integrate_reconciliation_solutions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method integrate_reconciliation_solutions",
					    status_line => $self->{client}->status_line,
					    method_name => 'integrate_reconciliation_solutions',
				       );
    }
}



=head2 queue_runfba

  $job = $obj->queue_runfba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a queue_runfba_params
$job is a JobObject
queue_runfba_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	fva has a value which is a bool
	simulateko has a value which is a bool
	minimizeflux has a value which is a bool
	findminmedia has a value which is a bool
	notes has a value which is a string
	fba has a value which is a fba_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
fba_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a queue_runfba_params
$job is a JobObject
queue_runfba_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	fva has a value which is a bool
	simulateko has a value which is a bool
	minimizeflux has a value which is a bool
	findminmedia has a value which is a bool
	notes has a value which is a string
	fba has a value which is a fba_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
fba_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues an FBA job in a single media condition

=back

=cut

sub queue_runfba
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_runfba (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_runfba');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_runfba",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_runfba',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_runfba",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_runfba',
				       );
    }
}



=head2 queue_gapfill_model

  $job = $obj->queue_gapfill_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapfill_model_params
$job is a JobObject
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	target_reactions has a value which is a reference to a list where each element is a string
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	auth has a value which is a string
	overwrite has a value which is a bool
	completeGapfill has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
compartment_id is a string
probanno_id is a string
phenotype_set_id is a string
gapfill_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a gapfill_model_params
$job is a JobObject
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	target_reactions has a value which is a reference to a list where each element is a string
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	auth has a value which is a string
	overwrite has a value which is a bool
	completeGapfill has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
compartment_id is a string
probanno_id is a string
phenotype_set_id is a string
gapfill_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues an FBAModel gapfilling job in single media condition

=back

=cut

sub queue_gapfill_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_gapfill_model (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_gapfill_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_gapfill_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_gapfill_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_gapfill_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_gapfill_model',
				       );
    }
}



=head2 gapfill_model

  $modelMeta = $obj->gapfill_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapfill_model_params
$modelMeta is an object_metadata
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	target_reactions has a value which is a reference to a list where each element is a string
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	auth has a value which is a string
	overwrite has a value which is a bool
	completeGapfill has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
compartment_id is a string
probanno_id is a string
phenotype_set_id is a string
gapfill_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a gapfill_model_params
$modelMeta is an object_metadata
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	target_reactions has a value which is a reference to a list where each element is a string
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	auth has a value which is a string
	overwrite has a value which is a bool
	completeGapfill has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
compartment_id is a string
probanno_id is a string
phenotype_set_id is a string
gapfill_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description



=back

=cut

sub gapfill_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_model (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapfill_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'gapfill_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_model',
				       );
    }
}



=head2 queue_gapgen_model

  $job = $obj->queue_gapgen_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapgen_model_params
$job is a JobObject
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
	auth has a value which is a string
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
phenotype_set_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a gapgen_model_params
$job is a JobObject
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
	auth has a value which is a string
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
phenotype_set_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues an FBAModel gapfilling job in single media condition

=back

=cut

sub queue_gapgen_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_gapgen_model (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_gapgen_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_gapgen_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_gapgen_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_gapgen_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_gapgen_model',
				       );
    }
}



=head2 gapgen_model

  $modelMeta = $obj->gapgen_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapgen_model_params
$modelMeta is an object_metadata
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
	auth has a value which is a string
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
phenotype_set_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a gapgen_model_params
$modelMeta is an object_metadata
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
	auth has a value which is a string
	timePerSolution has a value which is an int
	totalTimeLimit has a value which is an int
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
phenotype_set_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description



=back

=cut

sub gapgen_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapgen_model (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapgen_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapgen_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'gapgen_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapgen_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapgen_model',
				       );
    }
}



=head2 queue_wildtype_phenotype_reconciliation

  $job = $obj->queue_wildtype_phenotype_reconciliation($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a wildtype_phenotype_reconciliation_params
$job is a JobObject
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
compartment_id is a string
probanno_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
phenotype_set_id is a string
gapfill_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a wildtype_phenotype_reconciliation_params
$job is a JobObject
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
compartment_id is a string
probanno_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
phenotype_set_id is a string
gapfill_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_wildtype_phenotype_reconciliation
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_wildtype_phenotype_reconciliation (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_wildtype_phenotype_reconciliation');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_wildtype_phenotype_reconciliation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_wildtype_phenotype_reconciliation',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_wildtype_phenotype_reconciliation",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_wildtype_phenotype_reconciliation',
				       );
    }
}



=head2 queue_reconciliation_sensitivity_analysis

  $job = $obj->queue_reconciliation_sensitivity_analysis($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a wildtype_phenotype_reconciliation_params
$job is a JobObject
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
compartment_id is a string
probanno_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
phenotype_set_id is a string
gapfill_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a wildtype_phenotype_reconciliation_params
$job is a JobObject
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
compartment_id is a string
probanno_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
phenotype_set_id is a string
gapfill_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_reconciliation_sensitivity_analysis
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_reconciliation_sensitivity_analysis (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_reconciliation_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_reconciliation_sensitivity_analysis');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_reconciliation_sensitivity_analysis",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_reconciliation_sensitivity_analysis',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_reconciliation_sensitivity_analysis",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_reconciliation_sensitivity_analysis',
				       );
    }
}



=head2 queue_combine_wildtype_phenotype_reconciliation

  $job = $obj->queue_combine_wildtype_phenotype_reconciliation($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a combine_wildtype_phenotype_reconciliation_params
$job is a JobObject
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
compartment_id is a string
probanno_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
phenotype_set_id is a string
gapfill_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a combine_wildtype_phenotype_reconciliation_params
$job is a JobObject
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotype_set_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	auth has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
	prommodel has a value which is a prommodel_id
	prommodel_workspace has a value which is a workspace_id
	media_workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	maximizeObjective has a value which is a bool
	objectiveTerms has a value which is a reference to a list where each element is a term
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a bound
	constraints has a value which is a reference to a list where each element is a constraint
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
compound_id is a string
prommodel_id is a string
bool is an int
term is a reference to a list containing 3 items:
	0: (coefficient) a float
	1: (varType) a string
	2: (variable) a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: (min) a float
	1: (max) a float
	2: (varType) a string
	3: (variable) a string
constraint is a reference to a list containing 4 items:
	0: (rhs) a float
	1: (sign) a string
	2: (terms) a reference to a list where each element is a term
	3: (name) a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
	allowunbalanced has a value which is a bool
	activitybonus has a value which is a float
	drainpen has a value which is a float
	directionpen has a value which is a float
	nostructpen has a value which is a float
	unfavorablepen has a value which is a float
	nodeltagpen has a value which is a float
	biomasstranspen has a value which is a float
	singletranspen has a value which is a float
	transpen has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowedcmps has a value which is a reference to a list where each element is a compartment_id
	probabilisticAnnotation has a value which is a probanno_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
compartment_id is a string
probanno_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	formulation has a value which is an FBAFormulation
	refmedia has a value which is a media_id
	refmedia_workspace has a value which is a workspace_id
	num_solutions has a value which is an int
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
phenotype_set_id is a string
gapfill_id is a string
gapgen_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_combine_wildtype_phenotype_reconciliation
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_combine_wildtype_phenotype_reconciliation (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_combine_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_combine_wildtype_phenotype_reconciliation');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_combine_wildtype_phenotype_reconciliation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_combine_wildtype_phenotype_reconciliation',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_combine_wildtype_phenotype_reconciliation",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_combine_wildtype_phenotype_reconciliation',
				       );
    }
}



=head2 run_job

  $job = $obj->run_job($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a run_job_params
$job is a JobObject
run_job_params is a reference to a hash where the following keys are defined:
	job has a value which is a job_id
	auth has a value which is a string
job_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string

</pre>

=end html

=begin text

$input is a run_job_params
$job is a JobObject
run_job_params is a reference to a hash where the following keys are defined:
	job has a value which is a job_id
	auth has a value which is a string
job_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string


=end text

=item Description

Runs specified job

=back

=cut

sub run_job
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function run_job (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to run_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'run_job');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.run_job",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'run_job',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method run_job",
					    status_line => $self->{client}->status_line,
					    method_name => 'run_job',
				       );
    }
}



=head2 queue_job

  $job = $obj->queue_job($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a queue_job_params
$job is a JobObject
queue_job_params is a reference to a hash where the following keys are defined:
	method has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$input is a queue_job_params
$job is a JobObject
queue_job_params is a reference to a hash where the following keys are defined:
	method has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues the specified command to run as a job

=back

=cut

sub queue_job
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_job (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_job');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_job",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_job',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_job",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_job',
				       );
    }
}



=head2 set_cofactors

  $output = $obj->set_cofactors($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a set_cofactors_params
$output is an object_metadata
set_cofactors_params is a reference to a hash where the following keys are defined:
	cofactors has a value which is a reference to a list where each element is a compound_id
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	reset has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
compound_id is a string
biochemistry_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a set_cofactors_params
$output is an object_metadata
set_cofactors_params is a reference to a hash where the following keys are defined:
	cofactors has a value which is a reference to a list where each element is a compound_id
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	reset has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
compound_id is a string
biochemistry_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description



=back

=cut

sub set_cofactors
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_cofactors (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_cofactors:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_cofactors');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.set_cofactors",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_cofactors',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_cofactors",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_cofactors',
				       );
    }
}



=head2 find_reaction_synonyms

  $output = $obj->find_reaction_synonyms($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a find_reaction_synonyms_params
$output is an object_metadata
find_reaction_synonyms_params is a reference to a hash where the following keys are defined:
	reaction_synonyms has a value which is a reaction_synonyms_id
	workspace has a value which is a workspace_id
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
reaction_synonyms_id is a string
workspace_id is a string
biochemistry_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a find_reaction_synonyms_params
$output is an object_metadata
find_reaction_synonyms_params is a reference to a hash where the following keys are defined:
	reaction_synonyms has a value which is a reaction_synonyms_id
	workspace has a value which is a workspace_id
	biochemistry has a value which is a biochemistry_id
	biochemistry_workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
reaction_synonyms_id is a string
workspace_id is a string
biochemistry_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description



=back

=cut

sub find_reaction_synonyms
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function find_reaction_synonyms (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to find_reaction_synonyms:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'find_reaction_synonyms');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.find_reaction_synonyms",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'find_reaction_synonyms',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method find_reaction_synonyms",
					    status_line => $self->{client}->status_line,
					    method_name => 'find_reaction_synonyms',
				       );
    }
}



=head2 role_to_reactions

  $output = $obj->role_to_reactions($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a role_to_reactions_params
$output is a reference to a list where each element is a RoleComplexReactions
role_to_reactions_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
template_id is a string
workspace_id is a string
RoleComplexReactions is a reference to a hash where the following keys are defined:
	role has a value which is a role_id
	name has a value which is a string
	complexes has a value which is a reference to a list where each element is a ComplexReactions
role_id is a string
ComplexReactions is a reference to a hash where the following keys are defined:
	complex has a value which is a complex_id
	name has a value which is a string
	reactions has a value which is a reference to a list where each element is a TemplateReactions
complex_id is a string
TemplateReactions is a reference to a hash where the following keys are defined:
	reaction has a value which is a reaction_id
	direction has a value which is a string
	equation has a value which is a string
	compartment has a value which is a compartment_id
reaction_id is a string
compartment_id is a string

</pre>

=end html

=begin text

$params is a role_to_reactions_params
$output is a reference to a list where each element is a RoleComplexReactions
role_to_reactions_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
template_id is a string
workspace_id is a string
RoleComplexReactions is a reference to a hash where the following keys are defined:
	role has a value which is a role_id
	name has a value which is a string
	complexes has a value which is a reference to a list where each element is a ComplexReactions
role_id is a string
ComplexReactions is a reference to a hash where the following keys are defined:
	complex has a value which is a complex_id
	name has a value which is a string
	reactions has a value which is a reference to a list where each element is a TemplateReactions
complex_id is a string
TemplateReactions is a reference to a hash where the following keys are defined:
	reaction has a value which is a reaction_id
	direction has a value which is a string
	equation has a value which is a string
	compartment has a value which is a compartment_id
reaction_id is a string
compartment_id is a string


=end text

=item Description

Retrieves a list of roles mapped to reactions based on input template model

=back

=cut

sub role_to_reactions
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function role_to_reactions (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to role_to_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'role_to_reactions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.role_to_reactions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'role_to_reactions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method role_to_reactions",
					    status_line => $self->{client}->status_line,
					    method_name => 'role_to_reactions',
				       );
    }
}



=head2 reaction_sensitivity_analysis

  $output = $obj->reaction_sensitivity_analysis($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a reaction_sensitivity_analysis_params
$output is an object_metadata
reaction_sensitivity_analysis_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_ws has a value which is a workspace_id
	rxnsens_uid has a value which is a string
	workspace has a value which is a workspace_id
	reactions_to_delete has a value which is a reference to a list where each element is a reaction_id
	gapfill_solution_id has a value which is a gapfillsolution_id
	delete_noncontributing_reactions has a value which is a bool
	rxnprobs_id has a value which is a rxnprob_id
	rxnprobs_ws has a value which is a workspace_id
	type has a value which is a string
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
reaction_id is a string
gapfillsolution_id is a string
bool is an int
rxnprob_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a reaction_sensitivity_analysis_params
$output is an object_metadata
reaction_sensitivity_analysis_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_ws has a value which is a workspace_id
	rxnsens_uid has a value which is a string
	workspace has a value which is a workspace_id
	reactions_to_delete has a value which is a reference to a list where each element is a reaction_id
	gapfill_solution_id has a value which is a gapfillsolution_id
	delete_noncontributing_reactions has a value which is a bool
	rxnprobs_id has a value which is a rxnprob_id
	rxnprobs_ws has a value which is a workspace_id
	type has a value which is a string
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
reaction_id is a string
gapfillsolution_id is a string
bool is an int
rxnprob_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues a sensitivity analysis on the knockout of model reactions

=back

=cut

sub reaction_sensitivity_analysis
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function reaction_sensitivity_analysis (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to reaction_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'reaction_sensitivity_analysis');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.reaction_sensitivity_analysis",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'reaction_sensitivity_analysis',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method reaction_sensitivity_analysis",
					    status_line => $self->{client}->status_line,
					    method_name => 'reaction_sensitivity_analysis',
				       );
    }
}



=head2 filter_iterative_solutions

  $output = $obj->filter_iterative_solutions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a filter_iterative_solutions_params
$output is an object_metadata
filter_iterative_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	outmodel has a value which is a fbamodel_id
	cutoff has a value which is a float
	gapfillsln has a value which is a gapfillsolution_id
	workspace has a value which is a workspace_id
	input_model_ws has a value which is a workspace_id
	auth has a value which is a string
fbamodel_id is a string
gapfillsolution_id is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a filter_iterative_solutions_params
$output is an object_metadata
filter_iterative_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	outmodel has a value which is a fbamodel_id
	cutoff has a value which is a float
	gapfillsln has a value which is a gapfillsolution_id
	workspace has a value which is a workspace_id
	input_model_ws has a value which is a workspace_id
	auth has a value which is a string
fbamodel_id is a string
gapfillsolution_id is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Apply a cutoff to remove high-cost iterations from an iterative gapfill run.

=back

=cut

sub filter_iterative_solutions
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function filter_iterative_solutions (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to filter_iterative_solutions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'filter_iterative_solutions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.filter_iterative_solutions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'filter_iterative_solutions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method filter_iterative_solutions",
					    status_line => $self->{client}->status_line,
					    method_name => 'filter_iterative_solutions',
				       );
    }
}



=head2 delete_noncontributing_reactions

  $output = $obj->delete_noncontributing_reactions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a delete_noncontributing_reactions_params
$output is an object_metadata
delete_noncontributing_reactions_params is a reference to a hash where the following keys are defined:
	rxn_sensitivity_ws has a value which is a workspace_id
	rxn_sensitivity has a value which is a string
	workspace has a value which is a workspace_id
	new_model_uid has a value which is a fbamodel_id
	new_rxn_sensitivity_uid has a value which is a string
	auth has a value which is a string
workspace_id is a string
fbamodel_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a delete_noncontributing_reactions_params
$output is an object_metadata
delete_noncontributing_reactions_params is a reference to a hash where the following keys are defined:
	rxn_sensitivity_ws has a value which is a workspace_id
	rxn_sensitivity has a value which is a string
	workspace has a value which is a workspace_id
	new_model_uid has a value which is a fbamodel_id
	new_rxn_sensitivity_uid has a value which is a string
	auth has a value which is a string
workspace_id is a string
fbamodel_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Deleted flagged reactions from a RxnSensitivity object

=back

=cut

sub delete_noncontributing_reactions
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function delete_noncontributing_reactions (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_noncontributing_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'delete_noncontributing_reactions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.delete_noncontributing_reactions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'delete_noncontributing_reactions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method delete_noncontributing_reactions",
					    status_line => $self->{client}->status_line,
					    method_name => 'delete_noncontributing_reactions',
				       );
    }
}



=head2 annotate_workspace_Genome

  $output = $obj->annotate_workspace_Genome($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an annotate_workspace_Genome_params
$output is an object_metadata
annotate_workspace_Genome_params is a reference to a hash where the following keys are defined:
	Genome_uid has a value which is a string
	Genome_ws has a value which is a string
	new_uid has a value which is a string
	workspace has a value which is a workspace_id
	annotation_parameters has a value which is an AnnotationParameters
	auth has a value which is a string
workspace_id is a string
AnnotationParameters is a reference to a hash where the following keys are defined:
	call_genes has a value which is a bool
	annotate_genes has a value which is a bool
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an annotate_workspace_Genome_params
$output is an object_metadata
annotate_workspace_Genome_params is a reference to a hash where the following keys are defined:
	Genome_uid has a value which is a string
	Genome_ws has a value which is a string
	new_uid has a value which is a string
	workspace has a value which is a workspace_id
	annotation_parameters has a value which is an AnnotationParameters
	auth has a value which is a string
workspace_id is a string
AnnotationParameters is a reference to a hash where the following keys are defined:
	call_genes has a value which is a bool
	annotate_genes has a value which is a bool
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Create a job that runs the genome annotation pipeline on a genome object in a workspace

=back

=cut

sub annotate_workspace_Genome
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function annotate_workspace_Genome (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to annotate_workspace_Genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'annotate_workspace_Genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.annotate_workspace_Genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'annotate_workspace_Genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method annotate_workspace_Genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'annotate_workspace_Genome',
				       );
    }
}



=head2 fasta_to_ProteinSet

  $output = $obj->fasta_to_ProteinSet($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fasta_to_ProteinSet_params
$output is an object_metadata
fasta_to_ProteinSet_params is a reference to a hash where the following keys are defined:
	uid has a value which is a string
	fasta has a value which is a string
	workspace has a value which is a workspace_id
	auth has a value which is a string
	name has a value which is a string
	sourceid has a value which is a string
	source has a value which is a string
	type has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a fasta_to_ProteinSet_params
$output is an object_metadata
fasta_to_ProteinSet_params is a reference to a hash where the following keys are defined:
	uid has a value which is a string
	fasta has a value which is a string
	workspace has a value which is a workspace_id
	auth has a value which is a string
	name has a value which is a string
	sourceid has a value which is a string
	source has a value which is a string
	type has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Loads a fasta file as a ProteinSet object in the workspace

=back

=cut

sub fasta_to_ProteinSet
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fasta_to_ProteinSet (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fasta_to_ProteinSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fasta_to_ProteinSet');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fasta_to_ProteinSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'fasta_to_ProteinSet',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fasta_to_ProteinSet",
					    status_line => $self->{client}->status_line,
					    method_name => 'fasta_to_ProteinSet',
				       );
    }
}



=head2 ProteinSet_to_Genome

  $output = $obj->ProteinSet_to_Genome($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a ProteinSet_to_Genome_params
$output is an object_metadata
ProteinSet_to_Genome_params is a reference to a hash where the following keys are defined:
	ProteinSet_uid has a value which is a string
	ProteinSet_ws has a value which is a workspace_id
	workspace has a value which is a workspace_id
	uid has a value which is a string
	auth has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	annotation_parameters has a value which is an AnnotationParameters
workspace_id is a string
AnnotationParameters is a reference to a hash where the following keys are defined:
	call_genes has a value which is a bool
	annotate_genes has a value which is a bool
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a ProteinSet_to_Genome_params
$output is an object_metadata
ProteinSet_to_Genome_params is a reference to a hash where the following keys are defined:
	ProteinSet_uid has a value which is a string
	ProteinSet_ws has a value which is a workspace_id
	workspace has a value which is a workspace_id
	uid has a value which is a string
	auth has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	annotation_parameters has a value which is an AnnotationParameters
workspace_id is a string
AnnotationParameters is a reference to a hash where the following keys are defined:
	call_genes has a value which is a bool
	annotate_genes has a value which is a bool
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Creates a Genome associated with the ProteinSet object. You cannot recall genes on this genome.

=back

=cut

sub ProteinSet_to_Genome
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function ProteinSet_to_Genome (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ProteinSet_to_Genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'ProteinSet_to_Genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.ProteinSet_to_Genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'ProteinSet_to_Genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method ProteinSet_to_Genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'ProteinSet_to_Genome',
				       );
    }
}



=head2 fasta_to_ContigSet

  $output = $obj->fasta_to_ContigSet($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fasta_to_ContigSet_params
$output is an object_metadata
fasta_to_ContigSet_params is a reference to a hash where the following keys are defined:
	uid has a value which is a string
	fasta has a value which is a string
	workspace has a value which is a workspace_id
	auth has a value which is a string
	name has a value which is a string
	sourceid has a value which is a string
	source has a value which is a string
	type has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a fasta_to_ContigSet_params
$output is an object_metadata
fasta_to_ContigSet_params is a reference to a hash where the following keys are defined:
	uid has a value which is a string
	fasta has a value which is a string
	workspace has a value which is a workspace_id
	auth has a value which is a string
	name has a value which is a string
	sourceid has a value which is a string
	source has a value which is a string
	type has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Loads a fasta file as a ContigSet object in the workspace

=back

=cut

sub fasta_to_ContigSet
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fasta_to_ContigSet (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fasta_to_ContigSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fasta_to_ContigSet');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fasta_to_ContigSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'fasta_to_ContigSet',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fasta_to_ContigSet",
					    status_line => $self->{client}->status_line,
					    method_name => 'fasta_to_ContigSet',
				       );
    }
}



=head2 ContigSet_to_Genome

  $output = $obj->ContigSet_to_Genome($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a ContigSet_to_Genome_params
$output is an object_metadata
ContigSet_to_Genome_params is a reference to a hash where the following keys are defined:
	ContigSet_uid has a value which is a string
	ContigSet_ws has a value which is a workspace_id
	workspace has a value which is a workspace_id
	uid has a value which is a string
	auth has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	annotation_parameters has a value which is an AnnotationParameters
workspace_id is a string
AnnotationParameters is a reference to a hash where the following keys are defined:
	call_genes has a value which is a bool
	annotate_genes has a value which is a bool
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a ContigSet_to_Genome_params
$output is an object_metadata
ContigSet_to_Genome_params is a reference to a hash where the following keys are defined:
	ContigSet_uid has a value which is a string
	ContigSet_ws has a value which is a workspace_id
	workspace has a value which is a workspace_id
	uid has a value which is a string
	auth has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	annotation_parameters has a value which is an AnnotationParameters
workspace_id is a string
AnnotationParameters is a reference to a hash where the following keys are defined:
	call_genes has a value which is a bool
	annotate_genes has a value which is a bool
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Creates a genome associated with the ContigSet object

=back

=cut

sub ContigSet_to_Genome
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function ContigSet_to_Genome (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ContigSet_to_Genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'ContigSet_to_Genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.ContigSet_to_Genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'ContigSet_to_Genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method ContigSet_to_Genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'ContigSet_to_Genome',
				       );
    }
}



=head2 probanno_to_genome

  $output = $obj->probanno_to_genome($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a probanno_to_genome_params
$output is an object_metadata
probanno_to_genome_params is a reference to a hash where the following keys are defined:
	pa_id has a value which is a probanno_id
	pa_ws has a value which is a workspace_id
	workspace has a value which is a workspace_id
	g_id has a value which is a genome_id
	threshold has a value which is a float
	auth has a value which is a string
probanno_id is a string
workspace_id is a string
genome_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a probanno_to_genome_params
$output is an object_metadata
probanno_to_genome_params is a reference to a hash where the following keys are defined:
	pa_id has a value which is a probanno_id
	pa_ws has a value which is a workspace_id
	workspace has a value which is a workspace_id
	g_id has a value which is a genome_id
	threshold has a value which is a float
	auth has a value which is a string
probanno_id is a string
workspace_id is a string
genome_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Converts a probabilistic annotation into a genome with the same annotations

=back

=cut

sub probanno_to_genome
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function probanno_to_genome (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to probanno_to_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'probanno_to_genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.probanno_to_genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'probanno_to_genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method probanno_to_genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'probanno_to_genome',
				       );
    }
}



=head2 get_mapping

  $output = $obj->get_mapping($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_mapping_params
$output is a Mapping
get_mapping_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
Mapping is a reference to a hash where the following keys are defined:
	id has a value which is a mapping_id
	name has a value which is a string
	subsystems has a value which is a reference to a list where each element is a Subsystem
	roles has a value which is a reference to a list where each element is a FunctionalRole
	complexes has a value which is a reference to a list where each element is a Complex
Subsystem is a reference to a hash where the following keys are defined:
	id has a value which is a subsystem_id
	name has a value which is a string
	phenoclass has a value which is a string
	subclass has a value which is a string
	type has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a role_id
subsystem_id is a string
role_id is a string
FunctionalRole is a reference to a hash where the following keys are defined:
	id has a value which is a role_id
	name has a value which is a string
	feature has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	complexes has a value which is a reference to a list where each element is a complex_id
complex_id is a string
Complex is a reference to a hash where the following keys are defined:
	id has a value which is a complex_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a ComplexRole
ComplexRole is a reference to a list containing 4 items:
	0: (id) a role_id
	1: (roleType) a string
	2: (optional_role) a bool
	3: (triggering) a bool
bool is an int

</pre>

=end html

=begin text

$params is a get_mapping_params
$output is a Mapping
get_mapping_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
Mapping is a reference to a hash where the following keys are defined:
	id has a value which is a mapping_id
	name has a value which is a string
	subsystems has a value which is a reference to a list where each element is a Subsystem
	roles has a value which is a reference to a list where each element is a FunctionalRole
	complexes has a value which is a reference to a list where each element is a Complex
Subsystem is a reference to a hash where the following keys are defined:
	id has a value which is a subsystem_id
	name has a value which is a string
	phenoclass has a value which is a string
	subclass has a value which is a string
	type has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a role_id
subsystem_id is a string
role_id is a string
FunctionalRole is a reference to a hash where the following keys are defined:
	id has a value which is a role_id
	name has a value which is a string
	feature has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	complexes has a value which is a reference to a list where each element is a complex_id
complex_id is a string
Complex is a reference to a hash where the following keys are defined:
	id has a value which is a complex_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a ComplexRole
ComplexRole is a reference to a list containing 4 items:
	0: (id) a role_id
	1: (roleType) a string
	2: (optional_role) a bool
	3: (triggering) a bool
bool is an int


=end text

=item Description

Annotates contigs object creating a genome object

=back

=cut

sub get_mapping
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_mapping (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_mapping:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_mapping');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_mapping",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_mapping',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_mapping",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_mapping',
				       );
    }
}



=head2 adjust_mapping_role

  $output = $obj->adjust_mapping_role($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an adjust_mapping_role_params
$output is a FunctionalRole
adjust_mapping_role_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	role has a value which is a string
	new has a value which is a bool
	name has a value which is a string
	feature has a value which is a string
	aliasesToAdd has a value which is a reference to a list where each element is a string
	aliasesToRemove has a value which is a reference to a list where each element is a string
	delete has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
bool is an int
FunctionalRole is a reference to a hash where the following keys are defined:
	id has a value which is a role_id
	name has a value which is a string
	feature has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	complexes has a value which is a reference to a list where each element is a complex_id
role_id is a string
complex_id is a string

</pre>

=end html

=begin text

$params is an adjust_mapping_role_params
$output is a FunctionalRole
adjust_mapping_role_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	role has a value which is a string
	new has a value which is a bool
	name has a value which is a string
	feature has a value which is a string
	aliasesToAdd has a value which is a reference to a list where each element is a string
	aliasesToRemove has a value which is a reference to a list where each element is a string
	delete has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
bool is an int
FunctionalRole is a reference to a hash where the following keys are defined:
	id has a value which is a role_id
	name has a value which is a string
	feature has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	complexes has a value which is a reference to a list where each element is a complex_id
role_id is a string
complex_id is a string


=end text

=item Description

An API function supporting the curation of functional roles in a mapping object

=back

=cut

sub adjust_mapping_role
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_mapping_role (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_mapping_role:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_mapping_role');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_mapping_role",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_mapping_role',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_mapping_role",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_mapping_role',
				       );
    }
}



=head2 adjust_mapping_complex

  $output = $obj->adjust_mapping_complex($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an adjust_mapping_complex_params
$output is a Complex
adjust_mapping_complex_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	complex has a value which is a string
	new has a value which is a bool
	name has a value which is a string
	rolesToAdd has a value which is a reference to a list where each element is a string
	rolesToRemove has a value which is a reference to a list where each element is a string
	delete has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
bool is an int
Complex is a reference to a hash where the following keys are defined:
	id has a value which is a complex_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a ComplexRole
complex_id is a string
ComplexRole is a reference to a list containing 4 items:
	0: (id) a role_id
	1: (roleType) a string
	2: (optional_role) a bool
	3: (triggering) a bool
role_id is a string

</pre>

=end html

=begin text

$params is an adjust_mapping_complex_params
$output is a Complex
adjust_mapping_complex_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	complex has a value which is a string
	new has a value which is a bool
	name has a value which is a string
	rolesToAdd has a value which is a reference to a list where each element is a string
	rolesToRemove has a value which is a reference to a list where each element is a string
	delete has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
bool is an int
Complex is a reference to a hash where the following keys are defined:
	id has a value which is a complex_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a ComplexRole
complex_id is a string
ComplexRole is a reference to a list containing 4 items:
	0: (id) a role_id
	1: (roleType) a string
	2: (optional_role) a bool
	3: (triggering) a bool
role_id is a string


=end text

=item Description

An API function supporting the curation of complexes in a mapping object

=back

=cut

sub adjust_mapping_complex
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_mapping_complex (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_mapping_complex:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_mapping_complex');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_mapping_complex",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_mapping_complex',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_mapping_complex",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_mapping_complex',
				       );
    }
}



=head2 adjust_mapping_subsystem

  $output = $obj->adjust_mapping_subsystem($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an adjust_mapping_subsystem_params
$output is a Subsystem
adjust_mapping_subsystem_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	subsystem has a value which is a string
	new has a value which is a bool
	name has a value which is a string
	type has a value which is a string
	primclass has a value which is a string
	subclass has a value which is a string
	rolesToAdd has a value which is a reference to a list where each element is a string
	rolesToRemove has a value which is a reference to a list where each element is a string
	delete has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
bool is an int
Subsystem is a reference to a hash where the following keys are defined:
	id has a value which is a subsystem_id
	name has a value which is a string
	phenoclass has a value which is a string
	subclass has a value which is a string
	type has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a role_id
subsystem_id is a string
role_id is a string

</pre>

=end html

=begin text

$params is an adjust_mapping_subsystem_params
$output is a Subsystem
adjust_mapping_subsystem_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	workspace has a value which is a workspace_id
	subsystem has a value which is a string
	new has a value which is a bool
	name has a value which is a string
	type has a value which is a string
	primclass has a value which is a string
	subclass has a value which is a string
	rolesToAdd has a value which is a reference to a list where each element is a string
	rolesToRemove has a value which is a reference to a list where each element is a string
	delete has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
bool is an int
Subsystem is a reference to a hash where the following keys are defined:
	id has a value which is a subsystem_id
	name has a value which is a string
	phenoclass has a value which is a string
	subclass has a value which is a string
	type has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	roles has a value which is a reference to a list where each element is a role_id
subsystem_id is a string
role_id is a string


=end text

=item Description

An API function supporting the curation of subsystems in a mapping object

=back

=cut

sub adjust_mapping_subsystem
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_mapping_subsystem (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_mapping_subsystem:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_mapping_subsystem');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_mapping_subsystem",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_mapping_subsystem',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_mapping_subsystem",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_mapping_subsystem',
				       );
    }
}



=head2 get_template_model

  $output = $obj->get_template_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_template_model_params
$output is a TemplateModel
get_template_model_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
template_id is a string
workspace_id is a string
TemplateModel is a reference to a hash where the following keys are defined:
	id has a value which is a template_id
	name has a value which is a string
	type has a value which is a string
	domain has a value which is a string
	map has a value which is a mapping_id
	mappingws has a value which is a workspace_id
	reactions has a value which is a reference to a list where each element is a TemplateReaction
	biomasses has a value which is a reference to a list where each element is a TemplateBiomass
mapping_id is a string
TemplateReaction is a reference to a hash where the following keys are defined:
	id has a value which is a temprxn_id
	compartment has a value which is a compartment_id
	reaction has a value which is a reaction_id
	complexes has a value which is a reference to a list where each element is a complex_id
	direction has a value which is a string
	type has a value which is a string
temprxn_id is a string
compartment_id is a string
reaction_id is a string
complex_id is a string
TemplateBiomass is a reference to a hash where the following keys are defined:
	id has a value which is a tempbiomass_id
	name has a value which is a string
	type has a value which is a string
	other has a value which is a string
	protein has a value which is a string
	dna has a value which is a string
	rna has a value which is a string
	cofactor has a value which is a string
	energy has a value which is a string
	cellwall has a value which is a string
	lipid has a value which is a string
	compounds has a value which is a reference to a list where each element is a TemplateBiomassCompounds
tempbiomass_id is a string
TemplateBiomassCompounds is a reference to a list containing 7 items:
	0: (compound) a compound_id
	1: (compartment) a compartment_id
	2: (cpdclass) a string
	3: (universal) a string
	4: (coefficientType) a string
	5: (coefficient) a string
	6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
		0: (coeffficient) a string
		1: (compound) a compound_id

compound_id is a string

</pre>

=end html

=begin text

$params is a get_template_model_params
$output is a TemplateModel
get_template_model_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
template_id is a string
workspace_id is a string
TemplateModel is a reference to a hash where the following keys are defined:
	id has a value which is a template_id
	name has a value which is a string
	type has a value which is a string
	domain has a value which is a string
	map has a value which is a mapping_id
	mappingws has a value which is a workspace_id
	reactions has a value which is a reference to a list where each element is a TemplateReaction
	biomasses has a value which is a reference to a list where each element is a TemplateBiomass
mapping_id is a string
TemplateReaction is a reference to a hash where the following keys are defined:
	id has a value which is a temprxn_id
	compartment has a value which is a compartment_id
	reaction has a value which is a reaction_id
	complexes has a value which is a reference to a list where each element is a complex_id
	direction has a value which is a string
	type has a value which is a string
temprxn_id is a string
compartment_id is a string
reaction_id is a string
complex_id is a string
TemplateBiomass is a reference to a hash where the following keys are defined:
	id has a value which is a tempbiomass_id
	name has a value which is a string
	type has a value which is a string
	other has a value which is a string
	protein has a value which is a string
	dna has a value which is a string
	rna has a value which is a string
	cofactor has a value which is a string
	energy has a value which is a string
	cellwall has a value which is a string
	lipid has a value which is a string
	compounds has a value which is a reference to a list where each element is a TemplateBiomassCompounds
tempbiomass_id is a string
TemplateBiomassCompounds is a reference to a list containing 7 items:
	0: (compound) a compound_id
	1: (compartment) a compartment_id
	2: (cpdclass) a string
	3: (universal) a string
	4: (coefficientType) a string
	5: (coefficient) a string
	6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
		0: (coeffficient) a string
		1: (compound) a compound_id

compound_id is a string


=end text

=item Description

Retrieves the specified template model

=back

=cut

sub get_template_model
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_template_model (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_template_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_template_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_template_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_template_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_template_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_template_model',
				       );
    }
}



=head2 import_template_fbamodel

  $modelMeta = $obj->import_template_fbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an import_template_fbamodel_params
$modelMeta is an object_metadata
import_template_fbamodel_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	mapping_workspace has a value which is a workspace_id
	templateReactions has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (id) a string
	1: (compartment) a string
	2: (direction) a string
	3: (type) a string
	4: (complexes) a reference to a list where each element is a string

	templateBiomass has a value which is a reference to a list where each element is a reference to a list containing 11 items:
	0: (name) a string
	1: (type) a string
	2: (dna) a float
	3: (rna) a float
	4: (protein) a float
	5: (lipid) a float
	6: (cellwall) a float
	7: (cofactor) a float
	8: (energy) a float
	9: (other) a float
	10: (compounds) a reference to a list where each element is a reference to a list containing 6 items:
		0: (id) a string
		1: (compartment) a string
		2: (cpdclass) a string
		3: (coefficientType) a string
		4: (coefficient) a float
		5: (conditions) a string


	name has a value which is a string
	modelType has a value which is a string
	domain has a value which is a string
	id has a value which is a template_id
	workspace has a value which is a workspace_id
	ignore_errors has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
template_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is an import_template_fbamodel_params
$modelMeta is an object_metadata
import_template_fbamodel_params is a reference to a hash where the following keys are defined:
	map has a value which is a mapping_id
	mapping_workspace has a value which is a workspace_id
	templateReactions has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (id) a string
	1: (compartment) a string
	2: (direction) a string
	3: (type) a string
	4: (complexes) a reference to a list where each element is a string

	templateBiomass has a value which is a reference to a list where each element is a reference to a list containing 11 items:
	0: (name) a string
	1: (type) a string
	2: (dna) a float
	3: (rna) a float
	4: (protein) a float
	5: (lipid) a float
	6: (cellwall) a float
	7: (cofactor) a float
	8: (energy) a float
	9: (other) a float
	10: (compounds) a reference to a list where each element is a reference to a list containing 6 items:
		0: (id) a string
		1: (compartment) a string
		2: (cpdclass) a string
		3: (coefficientType) a string
		4: (coefficient) a float
		5: (conditions) a string


	name has a value which is a string
	modelType has a value which is a string
	domain has a value which is a string
	id has a value which is a template_id
	workspace has a value which is a workspace_id
	ignore_errors has a value which is a bool
	auth has a value which is a string
mapping_id is a string
workspace_id is a string
template_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Import a template model from an input table of template reactions and biomass components

=back

=cut

sub import_template_fbamodel
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_template_fbamodel (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_template_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_template_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.import_template_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_template_fbamodel',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_template_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_template_fbamodel',
				       );
    }
}



=head2 adjust_template_reaction

  $modelMeta = $obj->adjust_template_reaction($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an adjust_template_reaction_params
$modelMeta is an object_metadata
adjust_template_reaction_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	reaction has a value which is a string
	clearComplexes has a value which is a bool
	new has a value which is a bool
	delete has a value which is a bool
	compartment has a value which is a compartment_id
	complexesToAdd has a value which is a reference to a list where each element is a complex_id
	complexesToRemove has a value which is a reference to a list where each element is a complex_id
	direction has a value which is a string
	type has a value which is a string
	auth has a value which is a string
template_id is a string
workspace_id is a string
bool is an int
compartment_id is a string
complex_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an adjust_template_reaction_params
$modelMeta is an object_metadata
adjust_template_reaction_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	reaction has a value which is a string
	clearComplexes has a value which is a bool
	new has a value which is a bool
	delete has a value which is a bool
	compartment has a value which is a compartment_id
	complexesToAdd has a value which is a reference to a list where each element is a complex_id
	complexesToRemove has a value which is a reference to a list where each element is a complex_id
	direction has a value which is a string
	type has a value which is a string
	auth has a value which is a string
template_id is a string
workspace_id is a string
bool is an int
compartment_id is a string
complex_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Modifies a reaction of a template model

=back

=cut

sub adjust_template_reaction
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_template_reaction (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_template_reaction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_template_reaction');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_template_reaction",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_template_reaction',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_template_reaction",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_template_reaction',
				       );
    }
}



=head2 adjust_template_biomass

  $modelMeta = $obj->adjust_template_biomass($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an adjust_template_biomass_params
$modelMeta is an object_metadata
adjust_template_biomass_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	biomass has a value which is a string
	new has a value which is a bool
	delete has a value which is a bool
	clearBiomassCompounds has a value which is a bool
	name has a value which is a string
	type has a value which is a string
	other has a value which is a string
	protein has a value which is a string
	dna has a value which is a string
	rna has a value which is a string
	cofactor has a value which is a string
	energy has a value which is a string
	cellwall has a value which is a string
	lipid has a value which is a string
	compoundsToRemove has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (compartment) a compartment_id

	compoundsToAdd has a value which is a reference to a list where each element is a reference to a list containing 7 items:
	0: (compound) a compound_id
	1: (compartment) a compartment_id
	2: (cpdclass) a string
	3: (universal) a string
	4: (coefficientType) a string
	5: (coefficient) a string
	6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
		0: (coeffficient) a string
		1: (compound) a compound_id


	auth has a value which is a string
template_id is a string
workspace_id is a string
bool is an int
compound_id is a string
compartment_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an adjust_template_biomass_params
$modelMeta is an object_metadata
adjust_template_biomass_params is a reference to a hash where the following keys are defined:
	templateModel has a value which is a template_id
	workspace has a value which is a workspace_id
	biomass has a value which is a string
	new has a value which is a bool
	delete has a value which is a bool
	clearBiomassCompounds has a value which is a bool
	name has a value which is a string
	type has a value which is a string
	other has a value which is a string
	protein has a value which is a string
	dna has a value which is a string
	rna has a value which is a string
	cofactor has a value which is a string
	energy has a value which is a string
	cellwall has a value which is a string
	lipid has a value which is a string
	compoundsToRemove has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (compound) a compound_id
	1: (compartment) a compartment_id

	compoundsToAdd has a value which is a reference to a list where each element is a reference to a list containing 7 items:
	0: (compound) a compound_id
	1: (compartment) a compartment_id
	2: (cpdclass) a string
	3: (universal) a string
	4: (coefficientType) a string
	5: (coefficient) a string
	6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
		0: (coeffficient) a string
		1: (compound) a compound_id


	auth has a value which is a string
template_id is a string
workspace_id is a string
bool is an int
compound_id is a string
compartment_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Modifies the biomass of a template model

=back

=cut

sub adjust_template_biomass
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function adjust_template_biomass (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to adjust_template_biomass:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'adjust_template_biomass');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.adjust_template_biomass",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'adjust_template_biomass',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method adjust_template_biomass",
					    status_line => $self->{client}->status_line,
					    method_name => 'adjust_template_biomass',
				       );
    }
}



=head2 add_stimuli

  $output = $obj->add_stimuli($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an add_stimuli_params
$output is an object_metadata
add_stimuli_params is a reference to a hash where the following keys are defined:
	biochemid has a value which is a string
	biochem_workspace has a value which is a string
	stimuliid has a value which is a string
	name has a value which is a string
	abbreviation has a value which is a string
	type has a value which is a string
	description has a value which is a string
	compounds has a value which is a reference to a list where each element is a string
	workspace has a value which is a string
	auth has a value which is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_id is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an add_stimuli_params
$output is an object_metadata
add_stimuli_params is a reference to a hash where the following keys are defined:
	biochemid has a value which is a string
	biochem_workspace has a value which is a string
	stimuliid has a value which is a string
	name has a value which is a string
	abbreviation has a value which is a string
	type has a value which is a string
	description has a value which is a string
	compounds has a value which is a reference to a list where each element is a string
	workspace has a value which is a string
	auth has a value which is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_id is a string
workspace_ref is a string


=end text

=item Description

Adds a stimuli either to the central database or as an object in a workspace

=back

=cut

sub add_stimuli
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function add_stimuli (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to add_stimuli:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'add_stimuli');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.add_stimuli",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'add_stimuli',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method add_stimuli",
					    status_line => $self->{client}->status_line,
					    method_name => 'add_stimuli',
				       );
    }
}



=head2 import_regulatory_model

  $output = $obj->import_regulatory_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an import_regulatory_model_params
$output is an object_metadata
import_regulatory_model_params is a reference to a hash where the following keys are defined:
	regmodel_uid has a value which is a string
	workspace has a value which is a workspace_id
	genome has a value which is a string
	genome_ws has a value which is a workspace_id
	name has a value which is a string
	type has a value which is a string
	regulons has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (name) a string
	1: (features) a reference to a list where each element is a string
	2: (stimuli) a reference to a list where each element is a reference to a list containing 6 items:
		0: (stimuli) a string
		1: (in_inhibitor) a bool
		2: (strength) a float
		3: (min_conc) a float
		4: (max_conc) a float
		5: (regulators) a reference to a list where each element is a kbase_id


	auth has a value which is a string
workspace_id is a string
bool is an int
kbase_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an import_regulatory_model_params
$output is an object_metadata
import_regulatory_model_params is a reference to a hash where the following keys are defined:
	regmodel_uid has a value which is a string
	workspace has a value which is a workspace_id
	genome has a value which is a string
	genome_ws has a value which is a workspace_id
	name has a value which is a string
	type has a value which is a string
	regulons has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (name) a string
	1: (features) a reference to a list where each element is a string
	2: (stimuli) a reference to a list where each element is a reference to a list containing 6 items:
		0: (stimuli) a string
		1: (in_inhibitor) a bool
		2: (strength) a float
		3: (min_conc) a float
		4: (max_conc) a float
		5: (regulators) a reference to a list where each element is a kbase_id


	auth has a value which is a string
workspace_id is a string
bool is an int
kbase_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Imports a regulatory model into the KBase workspace

=back

=cut

sub import_regulatory_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_regulatory_model (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_regulatory_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_regulatory_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.import_regulatory_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_regulatory_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_regulatory_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_regulatory_model',
				       );
    }
}



=head2 compare_models

  $output = $obj->compare_models($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a compare_models_params
$output is a ModelComparisonData
compare_models_params is a reference to a hash where the following keys are defined:
	models has a value which is a reference to a list where each element is a fbamodel_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
ModelComparisonData is a reference to a hash where the following keys are defined:
	model_comparisons has a value which is a reference to a list where each element is a ModelComparisonModel
	reaction_comparisons has a value which is a reference to a list where each element is a ModelCompareReaction
	auth has a value which is a string
ModelComparisonModel is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	model_name has a value which is a string
	genome has a value which is a genome_id
	genome_name has a value which is a string
	gapfilled_reactions has a value which is an int
	core_reactions has a value which is an int
	noncore_reactions has a value which is an int
genome_id is a string
ModelCompareReaction is a reference to a hash where the following keys are defined:
	reaction has a value which is a reaction_id
	compartment has a value which is a string
	equation has a value which is a string
	core has a value which is a bool
	model_features has a value which is a reference to a hash where the key is a fbamodel_id and the value is a reference to a list where each element is a feature_id
	role has a value which is a string
	subsystem has a value which is a string
	primclass has a value which is a string
	subclass has a value which is a string
	number_models has a value which is an int
	fraction_models has a value which is a float
reaction_id is a string
bool is an int
feature_id is a string

</pre>

=end html

=begin text

$params is a compare_models_params
$output is a ModelComparisonData
compare_models_params is a reference to a hash where the following keys are defined:
	models has a value which is a reference to a list where each element is a fbamodel_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
ModelComparisonData is a reference to a hash where the following keys are defined:
	model_comparisons has a value which is a reference to a list where each element is a ModelComparisonModel
	reaction_comparisons has a value which is a reference to a list where each element is a ModelCompareReaction
	auth has a value which is a string
ModelComparisonModel is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	model_name has a value which is a string
	genome has a value which is a genome_id
	genome_name has a value which is a string
	gapfilled_reactions has a value which is an int
	core_reactions has a value which is an int
	noncore_reactions has a value which is an int
genome_id is a string
ModelCompareReaction is a reference to a hash where the following keys are defined:
	reaction has a value which is a reaction_id
	compartment has a value which is a string
	equation has a value which is a string
	core has a value which is a bool
	model_features has a value which is a reference to a hash where the key is a fbamodel_id and the value is a reference to a list where each element is a feature_id
	role has a value which is a string
	subsystem has a value which is a string
	primclass has a value which is a string
	subclass has a value which is a string
	number_models has a value which is an int
	fraction_models has a value which is a float
reaction_id is a string
bool is an int
feature_id is a string


=end text

=item Description

Compares the specified models and computes unique reactions and core reactions

=back

=cut

sub compare_models
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function compare_models (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to compare_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'compare_models');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.compare_models",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'compare_models',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method compare_models",
					    status_line => $self->{client}->status_line,
					    method_name => 'compare_models',
				       );
    }
}



=head2 compare_genomes

  $output = $obj->compare_genomes($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a compare_genomes_params
$output is a GenomeComparisonData
compare_genomes_params is a reference to a hash where the following keys are defined:
	genomes has a value which is a reference to a list where each element is a genome_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
genome_id is a string
workspace_id is a string
GenomeComparisonData is a reference to a hash where the following keys are defined:
	genome_comparisons has a value which is a reference to a list where each element is a GenomeComparisonGenome
	function_comparisons has a value which is a reference to a list where each element is a GenomeCompareFunction
	auth has a value which is a string
GenomeComparisonGenome is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	genome_name has a value which is a string
	taxonomy has a value which is a string
	features has a value which is an int
	core_functions has a value which is an int
	noncore_functions has a value which is an int
GenomeCompareFunction is a reference to a hash where the following keys are defined:
	core has a value which is a bool
	genome_features has a value which is a reference to a hash where the key is a genome_id and the value is a reference to a list where each element is a feature_id
	role has a value which is a string
	subsystem has a value which is a string
	primclass has a value which is a string
	subclass has a value which is a string
	number_genomes has a value which is an int
	fraction_genomes has a value which is a float
bool is an int
feature_id is a string

</pre>

=end html

=begin text

$params is a compare_genomes_params
$output is a GenomeComparisonData
compare_genomes_params is a reference to a hash where the following keys are defined:
	genomes has a value which is a reference to a list where each element is a genome_id
	workspaces has a value which is a reference to a list where each element is a workspace_id
	auth has a value which is a string
genome_id is a string
workspace_id is a string
GenomeComparisonData is a reference to a hash where the following keys are defined:
	genome_comparisons has a value which is a reference to a list where each element is a GenomeComparisonGenome
	function_comparisons has a value which is a reference to a list where each element is a GenomeCompareFunction
	auth has a value which is a string
GenomeComparisonGenome is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	genome_name has a value which is a string
	taxonomy has a value which is a string
	features has a value which is an int
	core_functions has a value which is an int
	noncore_functions has a value which is an int
GenomeCompareFunction is a reference to a hash where the following keys are defined:
	core has a value which is a bool
	genome_features has a value which is a reference to a hash where the key is a genome_id and the value is a reference to a list where each element is a feature_id
	role has a value which is a string
	subsystem has a value which is a string
	primclass has a value which is a string
	subclass has a value which is a string
	number_genomes has a value which is an int
	fraction_genomes has a value which is a float
bool is an int
feature_id is a string


=end text

=item Description

Compares the specified genomes and computes unique features and core features

=back

=cut

sub compare_genomes
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function compare_genomes (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to compare_genomes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'compare_genomes');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.compare_genomes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'compare_genomes',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method compare_genomes",
					    status_line => $self->{client}->status_line,
					    method_name => 'compare_genomes',
				       );
    }
}



=head2 import_metagenome_annotation

  $output = $obj->import_metagenome_annotation($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an import_metagenome_annotation_params
$output is an object_metadata
import_metagenome_annotation_params is a reference to a hash where the following keys are defined:
	metaanno_uid has a value which is a string
	workspace has a value which is a workspace_id
	source_id has a value which is a string
	source has a value which is a string
	type has a value which is a string
	confidence_type has a value which is a string
	name has a value which is a string
	annotations has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (genes) a reference to a list where each element is a string
	1: (functional_role) a string
	2: (otu) a string
	3: (abundance) an int
	4: (confidence) a float

	auth has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an import_metagenome_annotation_params
$output is an object_metadata
import_metagenome_annotation_params is a reference to a hash where the following keys are defined:
	metaanno_uid has a value which is a string
	workspace has a value which is a workspace_id
	source_id has a value which is a string
	source has a value which is a string
	type has a value which is a string
	confidence_type has a value which is a string
	name has a value which is a string
	annotations has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (genes) a reference to a list where each element is a string
	1: (functional_role) a string
	2: (otu) a string
	3: (abundance) an int
	4: (confidence) a float

	auth has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Imports metagenome annotation data into a metagenome annotation object

=back

=cut

sub import_metagenome_annotation
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_metagenome_annotation (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_metagenome_annotation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_metagenome_annotation');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.import_metagenome_annotation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_metagenome_annotation',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_metagenome_annotation",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_metagenome_annotation',
				       );
    }
}



=head2 models_to_community_model

  $output = $obj->models_to_community_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an import_metagenome_annotation_params
$output is an object_metadata
import_metagenome_annotation_params is a reference to a hash where the following keys are defined:
	metaanno_uid has a value which is a string
	workspace has a value which is a workspace_id
	source_id has a value which is a string
	source has a value which is a string
	type has a value which is a string
	confidence_type has a value which is a string
	name has a value which is a string
	annotations has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (genes) a reference to a list where each element is a string
	1: (functional_role) a string
	2: (otu) a string
	3: (abundance) an int
	4: (confidence) a float

	auth has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an import_metagenome_annotation_params
$output is an object_metadata
import_metagenome_annotation_params is a reference to a hash where the following keys are defined:
	metaanno_uid has a value which is a string
	workspace has a value which is a workspace_id
	source_id has a value which is a string
	source has a value which is a string
	type has a value which is a string
	confidence_type has a value which is a string
	name has a value which is a string
	annotations has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (genes) a reference to a list where each element is a string
	1: (functional_role) a string
	2: (otu) a string
	3: (abundance) an int
	4: (confidence) a float

	auth has a value which is a string
workspace_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Combines multiple single genome models into a single community model

=back

=cut

sub models_to_community_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function models_to_community_model (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to models_to_community_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'models_to_community_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.models_to_community_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'models_to_community_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method models_to_community_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'models_to_community_model',
				       );
    }
}



=head2 metagenome_to_fbamodels

  $outputs = $obj->metagenome_to_fbamodels($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a metagenome_to_fbamodels_params
$outputs is a reference to a list where each element is an object_metadata
metagenome_to_fbamodels_params is a reference to a hash where the following keys are defined:
	model_uids has a value which is a reference to a hash where the key is a string and the value is a string
	workspace has a value which is a workspace_id
	metaanno_uid has a value which is a string
	metaanno_ws has a value which is a workspace_id
	min_abundance has a value which is a float
	confidence_threshold has a value which is a float
	max_otu_models has a value which is an int
	min_reactions has a value which is an int
	templates has a value which is a reference to a hash where the key is a string and the value is a reference to a list containing 2 items:
	0: (template_ws) a workspace_id
	1: (template_uid) a template_id

	auth has a value which is a string
workspace_id is a string
template_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a metagenome_to_fbamodels_params
$outputs is a reference to a list where each element is an object_metadata
metagenome_to_fbamodels_params is a reference to a hash where the following keys are defined:
	model_uids has a value which is a reference to a hash where the key is a string and the value is a string
	workspace has a value which is a workspace_id
	metaanno_uid has a value which is a string
	metaanno_ws has a value which is a workspace_id
	min_abundance has a value which is a float
	confidence_threshold has a value which is a float
	max_otu_models has a value which is an int
	min_reactions has a value which is an int
	templates has a value which is a reference to a hash where the key is a string and the value is a reference to a list containing 2 items:
	0: (template_ws) a workspace_id
	1: (template_uid) a template_id

	auth has a value which is a string
workspace_id is a string
template_id is a string
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Constructs models from metagenome annotation OTUs

=back

=cut

sub metagenome_to_fbamodels
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function metagenome_to_fbamodels (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to metagenome_to_fbamodels:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'metagenome_to_fbamodels');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.metagenome_to_fbamodels",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'metagenome_to_fbamodels',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method metagenome_to_fbamodels",
					    status_line => $self->{client}->status_line,
					    method_name => 'metagenome_to_fbamodels',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "fbaModelServices.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'metagenome_to_fbamodels',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method metagenome_to_fbamodels",
            status_line => $self->{client}->status_line,
            method_name => 'metagenome_to_fbamodels',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for Bio::KBase::fbaModelServices::Client\n";
    }
    if ($sMajor == 0) {
        warn "Bio::KBase::fbaModelServices::Client version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 bool

=over 4



=item Description

********************************************************************************
    Universal simple type definitions
   	********************************************************************************


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 mdlrxn_kbid

=over 4



=item Description

KBase ID for a model reaction


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ws_ref

=over 4



=item Description

A string specifying a full workspace ID


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 kbase_id

=over 4



=item Description

A string specifying a KBase ID


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 workspace_id

=over 4



=item Description

A string used as an ID for a workspace. Any string consisting of alphanumeric characters and "-" is acceptable


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 complex_id

=over 4



=item Description

A string used as an ID for a complex.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 template_id

=over 4



=item Description

A string used as an ID for a complex.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 role_id

=over 4



=item Description

A string used as an ID for a complex.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 object_type

=over 4



=item Description

A string indicating the "type" of an object stored in a workspace. Acceptable types are returned by the "get_types()" command in the workspace_service


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 object_id

=over 4



=item Description

ID of an object stored in the workspace. Any string consisting of alphanumeric characters and "-" is acceptable


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 username

=over 4



=item Description

Login name of KBase useraccount to which permissions for workspaces are mapped


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 timestamp

=over 4



=item Description

Exact time for workspace operations. e.g. 2012-12-17T23:24:06


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 compound_id

=over 4



=item Description

An identifier for compounds in the KBase biochemistry database. e.g. cpd00001


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 biochemistry_id

=over 4



=item Description

A string used to identify a particular biochemistry database object in KBase. e.g. "default" is the ID of the standard KBase biochemistry


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 genome_id

=over 4



=item Description

A string identifier for a genome in KBase. e.g. "kb|g.0" is the ID for E. coli


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 prommodel_id

=over 4



=item Description

A string identifier for a prommodel in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 contig_id

=over 4



=item Description

A string identifier for a contiguous piece of DNA in KBase, representing a chromosome or an assembled fragment


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 feature_type

=over 4



=item Description

A string specifying the type of genome features in KBase


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 modelcompartment_id

=over 4



=item Description

A string identifier used for compartments in models in KBase. Compartments could represet organelles in a eukaryotic model, or entire cells in a community model


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 modelcompound_id

=over 4



=item Description

A string identifier used for compounds in models in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 feature_id

=over 4



=item Description

A string identifier used for a feature in a genome.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 reaction_id

=over 4



=item Description

A string identifier used for a reaction in a KBase biochemistry.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 modelreaction_id

=over 4



=item Description

A string identifier used for a reaction in a model in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 biomass_id

=over 4



=item Description

A string identifier used for a biomass reaction in a KBase model.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 media_id

=over 4



=item Description

A string identifier used for a media condition in the KBase database.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 fba_id

=over 4



=item Description

A string identifier used for a flux balance analysis study in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 gapgen_id

=over 4



=item Description

A string identifier for a gap generation study in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 gapfill_id

=over 4



=item Description

A string identifier for a gap filling study in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 gapgensolution_id

=over 4



=item Description

A string identifier for a solution from a gap generation study in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 gapfillsolution_id

=over 4



=item Description

A string identifier for a solution from a gap filling study in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 fbamodel_id

=over 4



=item Description

A string identifier for a metabolic model in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 mapping_id

=over 4



=item Description

A string identifier for a Mapping object in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 regmodel_id

=over 4



=item Description

A string identifier for a regulatory model in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 compartment_id

=over 4



=item Description

A string identifier for a compartment in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 expression_id

=over 4



=item Description

A string identifier for an expression dataset in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 phenotype_set_id

=over 4



=item Description

A string identifier used for a set of phenotype data loaded into KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 workspace_ref

=over 4



=item Description

A permanent reference to an object in a workspace.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 probanno_id

=over 4



=item Description

A string identifier used for a probabilistic annotation in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 reaction_synonyms_id

=over 4



=item Description

A string identifier for a reaction synonyms in KBase.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 Genome_uid

=over 4



=item Description

A user ID for a genome in KBase


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 object_metadata

=over 4



=item Description

********************************************************************************
    Object type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a list containing 11 items:
0: (id) an object_id
1: (type) an object_type
2: (moddate) a timestamp
3: (instance) an int
4: (command) a string
5: (lastmodifier) a username
6: (owner) a username
7: (workspace) a workspace_id
8: (ref) a workspace_ref
9: (chsum) a string
10: (metadata) a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a list containing 11 items:
0: (id) an object_id
1: (type) an object_type
2: (moddate) a timestamp
3: (instance) an int
4: (command) a string
5: (lastmodifier) a username
6: (owner) a username
7: (workspace) a workspace_id
8: (ref) a workspace_ref
9: (chsum) a string
10: (metadata) a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 md5

=over 4



=item Description

********************************************************************************
    Probabilistic Annotation type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 md5s

=over 4



=item Definition

=begin html

<pre>
a reference to a list where each element is a md5
</pre>

=end html

=begin text

a reference to a list where each element is a md5

=end text

=back



=head2 region_of_dna

=over 4



=item Description

A region of DNA is maintained as a tuple of four components:

        the contig
        the beginning position (from 1)
        the strand
        the length

        We often speak of "a region".  By "location", we mean a sequence
        of regions from the same genome (perhaps from distinct contigs).


=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: a contig_id
1: (begin) an int
2: (strand) a string
3: (length) an int

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a contig_id
1: (begin) an int
2: (strand) a string
3: (length) an int


=end text

=back



=head2 location

=over 4



=item Description

a "location" refers to a sequence of regions


=item Definition

=begin html

<pre>
a reference to a list where each element is a region_of_dna
</pre>

=end html

=begin text

a reference to a list where each element is a region_of_dna

=end text

=back



=head2 annotation

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (comment) a string
1: (annotator) a string
2: (annotation_time) an int

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (comment) a string
1: (annotator) a string
2: (annotation_time) an int


=end text

=back



=head2 gene_hit

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (gene) a feature_id
1: (blast_score) a float

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (gene) a feature_id
1: (blast_score) a float


=end text

=back



=head2 alt_func

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (function) a string
1: (probability) a float
2: (gene_hits) a reference to a list where each element is a gene_hit

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (function) a string
1: (probability) a float
2: (gene_hits) a reference to a list where each element is a gene_hit


=end text

=back



=head2 feature

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a feature_id
location has a value which is a location
type has a value which is a feature_type
function has a value which is a string
alternative_functions has a value which is a reference to a list where each element is an alt_func
protein_translation has a value which is a string
aliases has a value which is a reference to a list where each element is a string
annotations has a value which is a reference to a list where each element is an annotation

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a feature_id
location has a value which is a location
type has a value which is a feature_type
function has a value which is a string
alternative_functions has a value which is a reference to a list where each element is an alt_func
protein_translation has a value which is a string
aliases has a value which is a reference to a list where each element is a string
annotations has a value which is a reference to a list where each element is an annotation


=end text

=back



=head2 contig

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a contig_id
dna has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a contig_id
dna has a value which is a string


=end text

=back



=head2 GenomeObject

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a genome_id
scientific_name has a value which is a string
domain has a value which is a string
genetic_code has a value which is an int
source has a value which is a string
source_id has a value which is a string
contigs has a value which is a reference to a list where each element is a contig
features has a value which is a reference to a list where each element is a feature

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a genome_id
scientific_name has a value which is a string
domain has a value which is a string
genetic_code has a value which is an int
source has a value which is a string
source_id has a value which is a string
contigs has a value which is a reference to a list where each element is a contig
features has a value which is a reference to a list where each element is a feature


=end text

=back



=head2 annotationProbability

=over 4



=item Description

Data structures to hold a single annotation probability for a single gene

feature_id feature - feature the annotation is associated with
string function - the name of the functional role being annotated to the feature
float probability - the probability that the functional role is associated with the feature


=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (feature) a feature_id
1: (function) a string
2: (probability) a float

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (feature) a feature_id
1: (function) a string
2: (probability) a float


=end text

=back



=head2 probanno_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 alt_func

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (function) a string
1: (probability) a float

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (function) a string
1: (probability) a float


=end text

=back



=head2 ProbAnnoFeature

=over 4



=item Description

Object to carry alternative functions for each feature
    
feature_id id
ID of the feature. Required.
    
string function
Primary annotated function of the feature in the genome annotation. Required.
    
list<alt_func> alternative_functions
List of tuples containing alternative functions and probabilities. Required.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a feature_id
alternative_functions has a value which is a reference to a list where each element is an alt_func

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a feature_id
alternative_functions has a value which is a reference to a list where each element is an alt_func


=end text

=back



=head2 ProbabilisticAnnotation

=over 4



=item Description

Object to carry alternative functions and probabilities for genes in a genome

    probanno_id id - ID of the probabilistic annotation object. Required.    
    genome_id genome - ID of the genome the probabilistic annotation was built for. Required.
    workspace_ref genome_uuid - Reference to retrieve genome from workspace service. Required.
    list<ProbAnnoFeature> featureAlternativeFunctions - List of ProbAnnoFeature objects holding alternative functions for features. Required.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a probanno_id
genome has a value which is a genome_id
genome_uuid has a value which is a workspace_ref
featureAlternativeFunctions has a value which is a reference to a list where each element is a ProbAnnoFeature

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a probanno_id
genome has a value which is a genome_id
genome_uuid has a value which is a workspace_ref
featureAlternativeFunctions has a value which is a reference to a list where each element is a ProbAnnoFeature


=end text

=back



=head2 ReactionProbability

=over 4



=item Description

Data structure to hold probability of a reaction

        reaction_id reaction - ID of the reaction
        float probability - Probability of the reaction
        string gene_list - List of genes most likely to be attached to reaction


=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (reaction) a reaction_id
1: (probability) a float
2: (gene_list) a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (reaction) a reaction_id
1: (probability) a float
2: (gene_list) a string


=end text

=back



=head2 Biochemistry

=over 4



=item Description

********************************************************************************
    Biochemistry type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a biochemistry_id
name has a value which is a string
compounds has a value which is a reference to a list where each element is a compound_id
reactions has a value which is a reference to a list where each element is a reaction_id
media has a value which is a reference to a list where each element is a media_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a biochemistry_id
name has a value which is a string
compounds has a value which is a reference to a list where each element is a compound_id
reactions has a value which is a reference to a list where each element is a reaction_id
media has a value which is a reference to a list where each element is a media_id


=end text

=back



=head2 MediaCompound

=over 4



=item Description

Data structures for media compound formulation

compound_id compound - ID of compound in media
string name - name of compound in media
float concentration - concentration of compound in media
float maxFlux - maximum flux of compound in media
float minFlux - minimum flux of compound in media


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compound has a value which is a compound_id
name has a value which is a string
concentration has a value which is a float
max_flux has a value which is a float
min_flux has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compound has a value which is a compound_id
name has a value which is a string
concentration has a value which is a float
max_flux has a value which is a float
min_flux has a value which is a float


=end text

=back



=head2 Media

=over 4



=item Description

Data structures for media formulation

media_id id - ID of media formulation
string name - name of media formulaiton
list<MediaCompound> media_compounds - list of compounds in media formulation
float pH - pH of media condition
float temperature - temperature of media condition


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a media_id
name has a value which is a string
media_compounds has a value which is a reference to a list where each element is a MediaCompound
pH has a value which is a float
temperature has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a media_id
name has a value which is a string
media_compounds has a value which is a reference to a list where each element is a MediaCompound
pH has a value which is a float
temperature has a value which is a float


=end text

=back



=head2 Compound

=over 4



=item Description

Data structures for media formulation

compound_id id - ID of compound
string abbrev - abbreviated name of compound
string name - primary name of compound
list<string> aliases - list of aliases for compound
float charge - molecular charge of compound
float deltaG - estimated compound delta G
float deltaGErr - uncertainty in estimated compound delta G
string formula - molecular formula of compound


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a compound_id
abbrev has a value which is a string
name has a value which is a string
aliases has a value which is a reference to a list where each element is a string
charge has a value which is a float
deltaG has a value which is a float
deltaGErr has a value which is a float
formula has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a compound_id
abbrev has a value which is a string
name has a value which is a string
aliases has a value which is a reference to a list where each element is a string
charge has a value which is a float
deltaG has a value which is a float
deltaGErr has a value which is a float
formula has a value which is a string


=end text

=back



=head2 Reaction

=over 4



=item Description

Data structures for media formulation

reaction_id id - ID of reaction
string name - primary name of reaction
string abbrev - abbreviated name of reaction
list<string> enzymes - list of EC numbers for reaction
string direction - directionality of reaction
string reversibility - reversibility of reaction
float deltaG - estimated delta G of reaction
float deltaGErr - uncertainty in estimated delta G of reaction
string equation - reaction equation in terms of compound IDs
string definition - reaction equation in terms of compound names


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
name has a value which is a string
abbrev has a value which is a string
enzymes has a value which is a reference to a list where each element is a string
direction has a value which is a string
reversibility has a value which is a string
deltaG has a value which is a float
deltaGErr has a value which is a float
equation has a value which is a string
definition has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
name has a value which is a string
abbrev has a value which is a string
enzymes has a value which is a reference to a list where each element is a string
direction has a value which is a string
reversibility has a value which is a string
deltaG has a value which is a float
deltaGErr has a value which is a float
equation has a value which is a string
definition has a value which is a string


=end text

=back



=head2 ModelCompartment

=over 4



=item Description

********************************************************************************
    FBAModel type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a modelcompartment_id
name has a value which is a string
pH has a value which is a float
potential has a value which is a float
index has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelcompartment_id
name has a value which is a string
pH has a value which is a float
potential has a value which is a float
index has a value which is an int


=end text

=back



=head2 ModelCompound

=over 4



=item Description

Data structures for a compound in a model

modelcompound_id id - ID of the specific instance of the compound in the model
compound_id compound - ID of the compound associated with the model compound
string name - name of the compound associated with the model compound
modelcompartment_id compartment - ID of the compartment containing the compound


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a modelcompound_id
compound has a value which is a compound_id
name has a value which is a string
compartment has a value which is a modelcompartment_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelcompound_id
compound has a value which is a compound_id
name has a value which is a string
compartment has a value which is a modelcompartment_id


=end text

=back



=head2 ModelReaction

=over 4



=item Description

Data structures for a reaction in a model

modelreaction_id id - ID of the specific instance of the reaction in the model
reaction_id reaction - ID of the reaction
string name - name of the reaction
string direction - directionality of the reaction
string equation - stoichiometric equation of the reaction in terms of compound IDs
string definition - stoichiometric equation of the reaction in terms of compound names
list<feature_id> features - list of features associated with the reaction
modelcompartment_id compartment - ID of the compartment containing the reaction


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a modelreaction_id
reaction has a value which is a reaction_id
name has a value which is a string
direction has a value which is a string
equation has a value which is a string
definition has a value which is a string
gapfilled has a value which is a bool
features has a value which is a reference to a list where each element is a feature_id
compartment has a value which is a modelcompartment_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelreaction_id
reaction has a value which is a reaction_id
name has a value which is a string
direction has a value which is a string
equation has a value which is a string
definition has a value which is a string
gapfilled has a value which is a bool
features has a value which is a reference to a list where each element is a feature_id
compartment has a value which is a modelcompartment_id


=end text

=back



=head2 BiomassCompound

=over 4



=item Description

Data structures for a reaction in a model

modelcompound_id modelcompound - ID of model compound in biomass reaction
float coefficient - coefficient of compound in biomass reaction
string name - name of compound in biomass reaction


=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (modelcompound) a modelcompound_id
1: (coefficient) a float
2: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (modelcompound) a modelcompound_id
1: (coefficient) a float
2: (name) a string


=end text

=back



=head2 ModelBiomass

=over 4



=item Description

Data structures for a reaction in a model

biomass_id id - ID of biomass reaction
string name - name of biomass reaction
string definition - stoichiometric equation of biomass reaction in terms of compound names
list<BiomassCompound> biomass_compounds - list of compounds in biomass reaction


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
name has a value which is a string
definition has a value which is a string
biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
name has a value which is a string
definition has a value which is a string
biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound


=end text

=back



=head2 FBAMeta

=over 4



=item Description

Data structures for a reaction in a model

fba_id id - ID of the FBA object
workspace_id workspace - ID of the workspace containing the FBA object
media_id media - ID of the media the FBA was performed in
workspace_id media_workspace - ID of the workspace containing the media formulation
float objective - optimized objective value of the FBA study
list<feature_id> ko - list of genes knocked out in the FBA study


=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: (id) a fba_id
1: (workspace) a workspace_id
2: (media) a media_id
3: (media_workspace) a workspace_id
4: (objective) a float
5: (ko) a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: (id) a fba_id
1: (workspace) a workspace_id
2: (media) a media_id
3: (media_workspace) a workspace_id
4: (objective) a float
5: (ko) a reference to a list where each element is a feature_id


=end text

=back



=head2 GapGenMeta

=over 4



=item Description

Metadata object providing a summary of a gapgen simulation

gapgen_id id - ID of gapgen study object
workspace_id workspace - workspace containing gapgen study
media_id media - media formulation for gapgen study
workspace_id media_workspace - ID of the workspace containing the media formulation
bool done - boolean indicating if gapgen study is complete
list<feature_id> ko - list of genes knocked out in gapgen study


=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: (id) a gapgen_id
1: (workspace) a workspace_id
2: (media) a media_id
3: (media_workspace) a workspace_id
4: (done) a bool
5: (ko) a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: (id) a gapgen_id
1: (workspace) a workspace_id
2: (media) a media_id
3: (media_workspace) a workspace_id
4: (done) a bool
5: (ko) a reference to a list where each element is a feature_id


=end text

=back



=head2 GapFillMeta

=over 4



=item Description

Metadata object providing a summary of a gapfilling simulation

gapfill_id id - ID of gapfill study object
workspace_id workspace - workspace containing gapfill study
media_id media - media formulation for gapfill study
workspace_id media_workspace - ID of the workspace containing the media formulation
bool done - boolean indicating if gapfill study is complete
list<feature_id> ko - list of genes knocked out in gapfill study


=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: (id) a gapfill_id
1: (workspace) a workspace_id
2: (media) a media_id
3: (media_workspace) a workspace_id
4: (done) a bool
5: (ko) a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: (id) a gapfill_id
1: (workspace) a workspace_id
2: (media) a media_id
3: (media_workspace) a workspace_id
4: (done) a bool
5: (ko) a reference to a list where each element is a feature_id


=end text

=back



=head2 FBAModel

=over 4



=item Description

Data structure holding data for metabolic model

fbamodel_id id - ID of model
workspace_id workspace - workspace containing model
genome_id genome - ID of associated genome
workspace_id genome_workspace - workspace with associated genome
mapping_id map - ID of associated mapping database
workspace_id map_workspace - workspace with associated mapping database
biochemistry_id biochemistry - ID of associated biochemistry database
workspace_id biochemistry_workspace - workspace with associated biochemistry database
string name - name of the model
string type - type of model (e.g. single genome, community)
string status - status of model (e.g. under construction)
list<ModelBiomass> biomasses - list of biomass reactions in model
list<ModelCompartment> compartments - list of compartments in model
list<ModelReaction> reactions - list of reactions in model
list<ModelCompound> compounds - list of compounds in model
list<FBAMeta> fbas - list of flux balance analysis studies for model
list<GapFillMeta> integrated_gapfillings - list of integrated gapfilling solutions
list<GapFillMeta> unintegrated_gapfillings - list of unintegrated gapfilling solutions
list<GapGenMeta> integrated_gapgenerations - list of integrated gapgen solutions
list<GapGenMeta> unintegrated_gapgenerations - list of unintegrated gapgen solutions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a fbamodel_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
map has a value which is a mapping_id
map_workspace has a value which is a workspace_id
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
name has a value which is a string
type has a value which is a string
status has a value which is a string
biomasses has a value which is a reference to a list where each element is a ModelBiomass
compartments has a value which is a reference to a list where each element is a ModelCompartment
reactions has a value which is a reference to a list where each element is a ModelReaction
compounds has a value which is a reference to a list where each element is a ModelCompound
fbas has a value which is a reference to a list where each element is an FBAMeta
integrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
unintegrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
integrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta
unintegrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a fbamodel_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
map has a value which is a mapping_id
map_workspace has a value which is a workspace_id
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
name has a value which is a string
type has a value which is a string
status has a value which is a string
biomasses has a value which is a reference to a list where each element is a ModelBiomass
compartments has a value which is a reference to a list where each element is a ModelCompartment
reactions has a value which is a reference to a list where each element is a ModelReaction
compounds has a value which is a reference to a list where each element is a ModelCompound
fbas has a value which is a reference to a list where each element is an FBAMeta
integrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
unintegrated_gapfillings has a value which is a reference to a list where each element is a GapFillMeta
integrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta
unintegrated_gapgenerations has a value which is a reference to a list where each element is a GapGenMeta


=end text

=back



=head2 GeneAssertion

=over 4



=item Description

********************************************************************************
    Flux Balance Analysis type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (feature) a feature_id
1: (growthFraction) a float
2: (growth) a float
3: (isEssential) a bool

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (feature) a feature_id
1: (growthFraction) a float
2: (growth) a float
3: (isEssential) a bool


=end text

=back



=head2 CompoundFlux

=over 4



=item Description

Compound variable in FBA solution

modelcompound_id compound - ID of compound in model in FBA solution
float value - flux uptake of compound in FBA solution
float upperBound - maximum uptake of compoundin FBA simulation
float lowerBound - minimum uptake of compoundin FBA simulation
float max - maximum uptake of compoundin FBA simulation
float min - minimum uptake of compoundin FBA simulation
string type - type of compound variable
string name - name of compound


=item Definition

=begin html

<pre>
a reference to a list containing 8 items:
0: (compound) a modelcompound_id
1: (value) a float
2: (upperBound) a float
3: (lowerBound) a float
4: (max) a float
5: (min) a float
6: (type) a string
7: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 8 items:
0: (compound) a modelcompound_id
1: (value) a float
2: (upperBound) a float
3: (lowerBound) a float
4: (max) a float
5: (min) a float
6: (type) a string
7: (name) a string


=end text

=back



=head2 ReactionFlux

=over 4



=item Description

Reaction variable in FBA solution

modelreaction_id reaction - ID of reaction in model in FBA solution
float value - flux through reaction in FBA solution
float upperBound - maximum flux through reaction in FBA simulation
float lowerBound -  minimum flux through reaction in FBA simulation
float max - maximum flux through reaction in FBA simulation
float min - minimum flux through reaction in FBA simulation
string type - type of reaction variable
string definition - stoichiometry of solution reaction in terms of compound names


=item Definition

=begin html

<pre>
a reference to a list containing 8 items:
0: (reaction) a modelreaction_id
1: (value) a float
2: (upperBound) a float
3: (lowerBound) a float
4: (max) a float
5: (min) a float
6: (type) a string
7: (definition) a string

</pre>

=end html

=begin text

a reference to a list containing 8 items:
0: (reaction) a modelreaction_id
1: (value) a float
2: (upperBound) a float
3: (lowerBound) a float
4: (max) a float
5: (min) a float
6: (type) a string
7: (definition) a string


=end text

=back



=head2 MetaboliteProduction

=over 4



=item Description

Maximum production of compound in FBA simulation

float maximumProduction - maximum production of compound
modelcompound_id modelcompound - ID of compound with production maximized
string name - name of compound with simulated production


=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (maximumProduction) a float
1: (modelcompound) a modelcompound_id
2: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (maximumProduction) a float
1: (modelcompound) a modelcompound_id
2: (name) a string


=end text

=back



=head2 MinimalMediaPrediction

=over 4



=item Description

Data structures for gapfilling solution

list<compound_id> optionalNutrients - list of optional nutrients
list<compound_id> essentialNutrients - list of essential nutrients


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
optionalNutrients has a value which is a reference to a list where each element is a compound_id
essentialNutrients has a value which is a reference to a list where each element is a compound_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
optionalNutrients has a value which is a reference to a list where each element is a compound_id
essentialNutrients has a value which is a reference to a list where each element is a compound_id


=end text

=back



=head2 bound

=over 4



=item Description

Term of constraint or objective in FBA simulation

float min - minimum value of custom bound
float max - maximum value of custom bound
string varType - type of variable for custom bound
string variable - variable ID for custom bound


=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (min) a float
1: (max) a float
2: (varType) a string
3: (variable) a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (min) a float
1: (max) a float
2: (varType) a string
3: (variable) a string


=end text

=back



=head2 term

=over 4



=item Description

Term of constraint or objective in FBA simulation

float coefficient - coefficient of term in objective or constraint
string varType - type of variable for term in objective or constraint
string variable - variable ID for term in objective or constraint


=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (coefficient) a float
1: (varType) a string
2: (variable) a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (coefficient) a float
1: (varType) a string
2: (variable) a string


=end text

=back



=head2 constraint

=over 4



=item Description

Custom constraint in FBA simulation

float rhs - right hand side of custom constraint
string sign - sign of custom constraint (e.g. <, >)
list<term> terms - terms in custom constraint
string name - name of custom constraint


=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (rhs) a float
1: (sign) a string
2: (terms) a reference to a list where each element is a term
3: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (rhs) a float
1: (sign) a string
2: (terms) a reference to a list where each element is a term
3: (name) a string


=end text

=back



=head2 FBAFormulation

=over 4



=item Description

Data structures for gapfilling solution

media_id media - ID of media formulation to be used
list<compound_id> additionalcpds - list of additional compounds to allow update
prommodel_id prommodel - ID of prommodel
workspace_id prommodel_workspace - workspace containing prommodel
workspace_id media_workspace - workspace containing media for FBA study
float objfraction - fraction of objective to use for constraints
bool allreversible - flag indicating if all reactions should be reversible
bool maximizeObjective - flag indicating if objective should be maximized
list<term> objectiveTerms - list of terms of objective function
list<feature_id> geneko - list of gene knockouts
list<reaction_id> rxnko - list of reaction knockouts
list<bound> bounds - list of custom bounds
list<constraint> constraints - list of custom constraints
mapping<string,float> uptakelim - hash of maximum uptake for elements
float defaultmaxflux - default maximum intracellular flux
float defaultminuptake - default minimum nutrient uptake
float defaultmaxuptake - default maximum nutrient uptake
bool simplethermoconst - flag indicating if simple thermodynamic constraints should be used
bool thermoconst - flag indicating if thermodynamic constraints should be used
bool nothermoerror - flag indicating if no error should be allowed in thermodynamic constraints
bool minthermoerror - flag indicating if error should be minimized in thermodynamic constraints


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
additionalcpds has a value which is a reference to a list where each element is a compound_id
prommodel has a value which is a prommodel_id
prommodel_workspace has a value which is a workspace_id
media_workspace has a value which is a workspace_id
objfraction has a value which is a float
allreversible has a value which is a bool
maximizeObjective has a value which is a bool
objectiveTerms has a value which is a reference to a list where each element is a term
geneko has a value which is a reference to a list where each element is a feature_id
rxnko has a value which is a reference to a list where each element is a reaction_id
bounds has a value which is a reference to a list where each element is a bound
constraints has a value which is a reference to a list where each element is a constraint
uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
defaultmaxflux has a value which is a float
defaultminuptake has a value which is a float
defaultmaxuptake has a value which is a float
simplethermoconst has a value which is a bool
thermoconst has a value which is a bool
nothermoerror has a value which is a bool
minthermoerror has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
additionalcpds has a value which is a reference to a list where each element is a compound_id
prommodel has a value which is a prommodel_id
prommodel_workspace has a value which is a workspace_id
media_workspace has a value which is a workspace_id
objfraction has a value which is a float
allreversible has a value which is a bool
maximizeObjective has a value which is a bool
objectiveTerms has a value which is a reference to a list where each element is a term
geneko has a value which is a reference to a list where each element is a feature_id
rxnko has a value which is a reference to a list where each element is a reaction_id
bounds has a value which is a reference to a list where each element is a bound
constraints has a value which is a reference to a list where each element is a constraint
uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
defaultmaxflux has a value which is a float
defaultminuptake has a value which is a float
defaultmaxuptake has a value which is a float
simplethermoconst has a value which is a bool
thermoconst has a value which is a bool
nothermoerror has a value which is a bool
minthermoerror has a value which is a bool


=end text

=back



=head2 FBA

=over 4



=item Description

Data structures for gapfilling solution

fba_id id - ID of FBA study
workspace_id workspace - workspace containing FBA study
        fbamodel_id model - ID of model FBA was run on
        workspace_id model_workspace - workspace with FBA model
        float objective - objective value of FBA study
        bool isComplete - flag indicating if job is complete
FBAFormulation formulation - specs for FBA study
list<MinimalMediaPrediction> minimalMediaPredictions - list of minimal media formulation
list<MetaboliteProduction> metaboliteProductions - list of biomass component production
list<ReactionFlux> reactionFluxes - list of reaction fluxes
list<CompoundFlux> compoundFluxes - list of compound uptake fluxes
list<GeneAssertion> geneAssertions - list of gene assertions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a fba_id
workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
objective has a value which is a float
isComplete has a value which is a bool
formulation has a value which is an FBAFormulation
minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
geneAssertions has a value which is a reference to a list where each element is a GeneAssertion

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a fba_id
workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
objective has a value which is a float
isComplete has a value which is a bool
formulation has a value which is an FBAFormulation
minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
geneAssertions has a value which is a reference to a list where each element is a GeneAssertion


=end text

=back



=head2 GapfillingFormulation

=over 4



=item Description

********************************************************************************
    Gapfilling type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
nomediahyp has a value which is a bool
nobiomasshyp has a value which is a bool
nogprhyp has a value which is a bool
nopathwayhyp has a value which is a bool
allowunbalanced has a value which is a bool
activitybonus has a value which is a float
drainpen has a value which is a float
directionpen has a value which is a float
nostructpen has a value which is a float
unfavorablepen has a value which is a float
nodeltagpen has a value which is a float
biomasstranspen has a value which is a float
singletranspen has a value which is a float
transpen has a value which is a float
blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
allowedcmps has a value which is a reference to a list where each element is a compartment_id
probabilisticAnnotation has a value which is a probanno_id
probabilisticAnnotation_workspace has a value which is a workspace_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
nomediahyp has a value which is a bool
nobiomasshyp has a value which is a bool
nogprhyp has a value which is a bool
nopathwayhyp has a value which is a bool
allowunbalanced has a value which is a bool
activitybonus has a value which is a float
drainpen has a value which is a float
directionpen has a value which is a float
nostructpen has a value which is a float
unfavorablepen has a value which is a float
nodeltagpen has a value which is a float
biomasstranspen has a value which is a float
singletranspen has a value which is a float
transpen has a value which is a float
blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
allowedcmps has a value which is a reference to a list where each element is a compartment_id
probabilisticAnnotation has a value which is a probanno_id
probabilisticAnnotation_workspace has a value which is a workspace_id


=end text

=back



=head2 reactionAddition

=over 4



=item Description

Reactions removed in gapgen solution

modelreaction_id reaction - ID of the removed reaction
string direction - direction of reaction removed in gapgen solution
string equation - stoichiometry of removed reaction in terms of compound IDs
string definition - stoichiometry of removed reaction in terms of compound names


=item Definition

=begin html

<pre>
a reference to a list containing 5 items:
0: (reaction) a reaction_id
1: (direction) a string
2: (compartment_id) a string
3: (equation) a string
4: (definition) a string

</pre>

=end html

=begin text

a reference to a list containing 5 items:
0: (reaction) a reaction_id
1: (direction) a string
2: (compartment_id) a string
3: (equation) a string
4: (definition) a string


=end text

=back



=head2 biomassRemoval

=over 4



=item Description

Biomass component removed in gapfill solution

compound_id compound - ID of biomass component removed
string name - name of biomass component removed


=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string


=end text

=back



=head2 mediaAddition

=over 4



=item Description

Media component added in gapfill solution

compound_id compound - ID of media component added
string name - name of media component added


=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string


=end text

=back



=head2 GapFillSolution

=over 4



=item Description

Data structures for gapfilling solution

gapfillsolution_id id - ID of gapfilling solution
        float objective - cost of gapfilling solution
list<biomassRemoval> biomassRemovals - list of biomass components being removed
list<mediaAddition> mediaAdditions - list of media components being added
list<reactionAddition> reactionAdditions - list of reactions being added


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapfillsolution_id
objective has a value which is a float
integrated has a value which is a bool
biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapfillsolution_id
objective has a value which is a float
integrated has a value which is a bool
biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition


=end text

=back



=head2 GapFill

=over 4



=item Description

Data structures for gapfilling analysis

gapfill_id id - ID of gapfill analysis
workspace_id workspace - workspace containing gapfill analysis
fbamodel_id model - ID of model being gapfilled
        workspace_id model_workspace - workspace containing model
        bool isComplete - indicates if gapfilling is complete
GapfillingFormulation formulation - formulation of gapfilling analysis
list<GapFillSolution> solutions - list of gapfilling solutions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapfill_id
workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
isComplete has a value which is a bool
formulation has a value which is a GapfillingFormulation
solutions has a value which is a reference to a list where each element is a GapFillSolution

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapfill_id
workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
isComplete has a value which is a bool
formulation has a value which is a GapfillingFormulation
solutions has a value which is a reference to a list where each element is a GapFillSolution


=end text

=back



=head2 GapgenFormulation

=over 4



=item Description

********************************************************************************
    Gap Generation type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
formulation has a value which is an FBAFormulation
refmedia has a value which is a media_id
refmedia_workspace has a value which is a workspace_id
num_solutions has a value which is an int
nomediahyp has a value which is a bool
nobiomasshyp has a value which is a bool
nogprhyp has a value which is a bool
nopathwayhyp has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
formulation has a value which is an FBAFormulation
refmedia has a value which is a media_id
refmedia_workspace has a value which is a workspace_id
num_solutions has a value which is an int
nomediahyp has a value which is a bool
nobiomasshyp has a value which is a bool
nogprhyp has a value which is a bool
nopathwayhyp has a value which is a bool


=end text

=back



=head2 reactionRemoval

=over 4



=item Description

Reactions removed in gapgen solution

modelreaction_id reaction - ID of the removed reaction
string direction - direction of reaction removed in gapgen solution
string equation - stoichiometry of removed reaction in terms of compound IDs
string definition - stoichiometry of removed reaction in terms of compound names


=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (reaction) a modelreaction_id
1: (direction) a string
2: (equation) a string
3: (definition) a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (reaction) a modelreaction_id
1: (direction) a string
2: (equation) a string
3: (definition) a string


=end text

=back



=head2 biomassAddition

=over 4



=item Description

Compounds added to biomass in gapgen solution

compound_id compound - ID of biomass compound added
string name - name of biomass compound added


=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string


=end text

=back



=head2 mediaRemoval

=over 4



=item Description

Media components removed in gapgen solution

compound_id compound - ID of media component removed
string name - name of media component removed


=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (compound) a compound_id
1: (name) a string


=end text

=back



=head2 GapgenSolution

=over 4



=item Description

Data structures for gap generation solution

gapgensolution_id id - ID of gapgen solution
        float objective - cost of gapgen solution
list<biomassAddition> biomassAdditions - list of components added to biomass
list<mediaRemoval> mediaRemovals - list of media components removed
list<reactionRemoval> reactionRemovals - list of reactions removed


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapgensolution_id
objective has a value which is a float
biomassAdditions has a value which is a reference to a list where each element is a biomassAddition
mediaRemovals has a value which is a reference to a list where each element is a mediaRemoval
reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapgensolution_id
objective has a value which is a float
biomassAdditions has a value which is a reference to a list where each element is a biomassAddition
mediaRemovals has a value which is a reference to a list where each element is a mediaRemoval
reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval


=end text

=back



=head2 GapGen

=over 4



=item Description

Data structures for gap generation analysis

gapgen_id id - ID of gapgen object
workspace_id workspace - workspace containing gapgen object
fbamodel_id model - ID of model being gap generated
        workspace_id model_workspace - workspace containing model
        bool isComplete - flag indicating if gap generation is complete
GapgenFormulation formulation - formulation of gap generation analysis
list<GapgenSolution> solutions - list of gap generation solutions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapgen_id
workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
isComplete has a value which is a bool
formulation has a value which is a GapgenFormulation
solutions has a value which is a reference to a list where each element is a GapgenSolution

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapgen_id
workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
isComplete has a value which is a bool
formulation has a value which is a GapgenFormulation
solutions has a value which is a reference to a list where each element is a GapgenSolution


=end text

=back



=head2 Phenotype

=over 4



=item Description

********************************************************************************
    Phenotype type definitions
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: (geneKO) a reference to a list where each element is a feature_id
1: (baseMedia) a media_id
2: (media_workspace) a workspace_id
3: (additionalCpd) a reference to a list where each element is a compound_id
4: (normalizedGrowth) a float
5: (label) a string

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: (geneKO) a reference to a list where each element is a feature_id
1: (baseMedia) a media_id
2: (media_workspace) a workspace_id
3: (additionalCpd) a reference to a list where each element is a compound_id
4: (normalizedGrowth) a float
5: (label) a string


=end text

=back



=head2 PhenotypeSet

=over 4



=item Description

Data structures for set of growth phenotype observations

phenotype_set_id id - ID of the phenotype set
genome_id genome - ID of the genome for the strain used with the growth phenotypes
workspace_id genome_workspace - workspace containing the genome object
list<Phenotype> phenotypes - list of phenotypes included in the phenotype set
string importErrors - list of errors encountered during the import of the phenotype set
string source - source of the phenotype set
string name - name of the phenotype set


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotype_set_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
source has a value which is a string
name has a value which is a string
importErrors has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotype_set_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
source has a value which is a string
name has a value which is a string
importErrors has a value which is a string


=end text

=back



=head2 phenotypeSimulationSet_id

=over 4



=item Description

ID of the phenotype simulation object


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 PhenotypeSimulation

=over 4



=item Description

Data structures for a phenotype simulation

Phenotype phenotypeData - actual phenotype data simulated
float simulatedGrowth - actual simulated growth rate
float simulatedGrowthFraction - fraction of wildtype simulated growth rate
string phenoclass - class of the phenotype simulation (i.e. 'CP' - correct positive, 'CN' - correct negative, 'FP' - false positive, 'FN' - false negative)


=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (phenotypeData) a Phenotype
1: (simulatedGrowth) a float
2: (simulatedGrowthFraction) a float
3: (phenoclass) a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (phenotypeData) a Phenotype
1: (simulatedGrowth) a float
2: (simulatedGrowthFraction) a float
3: (phenoclass) a string


=end text

=back



=head2 PhenotypeSimulationSet

=over 4



=item Description

Data structures for phenotype simulations of a set of phenotype data

phenotypeSimulationSet_id id - ID for the phenotype simulation set object
fbamodel_id model - ID of the model used to simulate all phenotypes
workspace_id model_workspace - workspace containing the model used for the simulation
phenotype_set_id phenotypeSet - set of observed phenotypes that were simulated
list<PhenotypeSimulation> phenotypeSimulations - list of simulated phenotypes


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSimulationSet_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotype_set_id
phenotypeSimulations has a value which is a reference to a list where each element is a PhenotypeSimulation

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSimulationSet_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotype_set_id
phenotypeSimulations has a value which is a reference to a list where each element is a PhenotypeSimulation


=end text

=back



=head2 reactionSpecification

=over 4



=item Description

Data structure for holding gapfill or gapgen solution reaction information

string direction - direction of gapfilled or gapgen reaction
string reactionID - ID of gapfilled or gapgen reaction


=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (direction) a string
1: (reactionID) a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (direction) a string
1: (reactionID) a string


=end text

=back



=head2 PhenotypeSensitivityAnalysis

=over 4



=item Description

list<string id, string solutionIndex, list<reactionSpecification> reactionList, list<string> biomassEdits,list<tuple<float simulatedGrowth,float simulatedGrowthFraction,string phenoclass>> PhenotypeSimulations> reconciliationSolutionSimulations;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
wildtypePhenotypeSimulations has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (simulatedGrowth) a float
1: (simulatedGrowthFraction) a float
2: (phenoclass) a string


</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
wildtypePhenotypeSimulations has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (simulatedGrowth) a float
1: (simulatedGrowthFraction) a float
2: (phenoclass) a string



=end text

=back



=head2 job_id

=over 4



=item Description

********************************************************************************
    Job object type definitions
   	********************************************************************************


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 CommandArguments

=over 4



=item Description

Object to hold the arguments to be submitted to the post process command


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
auth has a value which is a string


=end text

=back



=head2 clusterjob

=over 4



=item Description

Object to hold data required to run cluster job


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
auth has a value which is a string


=end text

=back



=head2 JobObject

=over 4



=item Description

Data structures for a job object

job_id id - ID of the job object
string type - type of the job
string auth - authentication token of job owner
string status - current status of job
mapping<string,string> jobdata;
string queuetime - time when job was queued
string starttime - time when job started running
string completetime - time when the job was completed
string owner - owner of the job
string queuecommand - command used to queue job


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a job_id
type has a value which is a string
auth has a value which is a string
status has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string
queuetime has a value which is a string
starttime has a value which is a string
completetime has a value which is a string
owner has a value which is a string
queuecommand has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a job_id
type has a value which is a string
auth has a value which is a string
status has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string
queuetime has a value which is a string
starttime has a value which is a string
completetime has a value which is a string
owner has a value which is a string
queuecommand has a value which is a string


=end text

=back



=head2 ETCNodes

=over 4



=item Description

********************************************************************************
    ETC object type definitions
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
resp has a value which is a string
y has a value which is an int
x has a value which is an int
width has a value which is an int
height has a value which is an int
shape has a value which is a string
label has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
resp has a value which is a string
y has a value which is an int
x has a value which is an int
width has a value which is an int
height has a value which is an int
shape has a value which is a string
label has a value which is a string


=end text

=back



=head2 ETCDiagramSpecs

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
nodes has a value which is a reference to a list where each element is an ETCNodes
media has a value which is a string
growth has a value which is a string
organism has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
nodes has a value which is a reference to a list where each element is an ETCNodes
media has a value which is a string
growth has a value which is a string
organism has a value which is a string


=end text

=back



=head2 TemplateReactions

=over 4



=item Description

********************************************************************************
	  AutoRecon type definitions
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reaction has a value which is a reaction_id
direction has a value which is a string
equation has a value which is a string
compartment has a value which is a compartment_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reaction has a value which is a reaction_id
direction has a value which is a string
equation has a value which is a string
compartment has a value which is a compartment_id


=end text

=back



=head2 ComplexReactions

=over 4



=item Description

Information on complexes in a template model

        complex_id complex - ID of the associated complex
        list<TemplateReactions> reactions - List of template models associated with complex


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
complex has a value which is a complex_id
name has a value which is a string
reactions has a value which is a reference to a list where each element is a TemplateReactions

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
complex has a value which is a complex_id
name has a value which is a string
reactions has a value which is a reference to a list where each element is a TemplateReactions


=end text

=back



=head2 RoleComplexReactions

=over 4



=item Description

Information on complexes in a template model

        complex_id complex - ID of the associated complex
        list<TemplateReactions> reactions - List of template models associated with complex


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
role has a value which is a role_id
name has a value which is a string
complexes has a value which is a reference to a list where each element is a ComplexReactions

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
role has a value which is a role_id
name has a value which is a string
complexes has a value which is a reference to a list where each element is a ComplexReactions


=end text

=back



=head2 ReactionDefinition

=over 4



=item Description

Reaction definition

        reaction_id id - ID of reaction
        string name - name of reaction
        string definition - stoichiometric equation of reaction in terms of compound names


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
name has a value which is a string
definition has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
name has a value which is a string
definition has a value which is a string


=end text

=back



=head2 ReactionSynonyms

=over 4



=item Description

Reaction synonyms

        reaction_id primary - ID of primary reaction
        list<ReactionDefinition> synonyms - list of synonym reactions to the primary reaction (including itself)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
primary has a value which is a reaction_id
synonyms has a value which is a reference to a list where each element is a ReactionDefinition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
primary has a value which is a reaction_id
synonyms has a value which is a reference to a list where each element is a ReactionDefinition


=end text

=back



=head2 ReactionSynonymsObject

=over 4



=item Description

Reaction synonyms object

        int version - version number of object
        biochemistry_id biochemistry - ID of associated biochemistry database
        workspace_id biochemistry_workspace - workspace with associated biochemistry database
        list<ReactionSynonyms> synonym_list - list of all reaction synonyms from a biochemistry database
        list<ReactionDefinition> excluded_list - list of reactions excluded because all compounds are cofactors


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
version has a value which is an int
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
synonyms_list has a value which is a reference to a list where each element is a ReactionSynonyms
excluded_list has a value which is a reference to a list where each element is a ReactionDefinition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
version has a value which is an int
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
synonyms_list has a value which is a reference to a list where each element is a ReactionSynonyms
excluded_list has a value which is a reference to a list where each element is a ReactionDefinition


=end text

=back



=head2 get_models_params

=over 4



=item Description

********************************************************************************
    Function definitions relating to data retrieval for Model Objects
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
models has a value which is a reference to a list where each element is a fbamodel_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
models has a value which is a reference to a list where each element is a fbamodel_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_fbas_params

=over 4



=item Description

Input parameters for the "get_fbas" function.

        list<fba_id> fbas - a list of the FBA study IDs for the FBA studies to be returned (a required argument)
        list<workspace_id> workspaces - a list of the workspaces contianing the FBA studies to be returned (a required argument)
string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbas has a value which is a reference to a list where each element is a fba_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbas has a value which is a reference to a list where each element is a fba_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_gapfills_params

=over 4



=item Description

Input parameters for the "get_gapfills" function.

        list<gapfill_id> gapfills - a list of the gapfill study IDs for the gapfill studies to be returned (a required argument)
        list<workspace_id> workspaces - a list of the workspaces contianing the gapfill studies to be returned (a required argument)
string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
gapfills has a value which is a reference to a list where each element is a gapfill_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
gapfills has a value which is a reference to a list where each element is a gapfill_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_gapgens_params

=over 4



=item Description

Input parameters for the "get_gapgens" function.

        list<gapgen_id> gapgens - a list of the gapgen study IDs for the gapgen studies to be returned (a required argument)
        list<workspace_id> workspaces - a list of the workspaces contianing the gapgen studies to be returned (a required argument)
string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
gapgens has a value which is a reference to a list where each element is a gapgen_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
gapgens has a value which is a reference to a list where each element is a gapgen_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_reactions_params

=over 4



=item Description

Input parameters for the "get_reactions" function.

        list<reaction_id> reactions - a list of the reaction IDs for the reactions to be returned (a required argument)
        string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reactions has a value which is a reference to a list where each element is a reaction_id
auth has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reactions has a value which is a reference to a list where each element is a reaction_id
auth has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_compounds_params

=over 4



=item Description

Input parameters for the "get_compounds" function.        
list<compound_id> compounds - a list of the compound IDs for the compounds to be returned (a required argument)
string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compounds has a value which is a reference to a list where each element is a compound_id
auth has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compounds has a value which is a reference to a list where each element is a compound_id
auth has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_alias_params

=over 4



=item Description

Input parameters for the get_alias function

                string object_type    - The type of object (e.g. Compound or Reaction)
                string input_id_type - The type (e.g. ModelSEED) of alias to be inputted
                string output_id_type - The type (e.g. KEGG) of alias to be outputted
                list<string> input_ids - A list of input IDs
                string auth; - The authentication token of the KBase account (optional)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
object_type has a value which is a string
input_id_type has a value which is a string
output_id_type has a value which is a string
input_ids has a value which is a reference to a list where each element is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
object_type has a value which is a string
input_id_type has a value which is a string
output_id_type has a value which is a string
input_ids has a value which is a reference to a list where each element is a string
auth has a value which is a string


=end text

=back



=head2 get_alias_outputs

=over 4



=item Description

Output for get_alias function

              string original_id - The original ID
              list<string> aliases - Aliases for the original ID in the new format


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
original_id has a value which is a string
aliases has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
original_id has a value which is a string
aliases has a value which is a reference to a list where each element is a string


=end text

=back



=head2 get_aliassets_params

=over 4



=item Description

Input parameters for the get_aliassets function

              string auth; - The authentication token of the KBase account (optional)
              string object_type; - The type of object (e.g. Compound or Reaction)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
object_type has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
object_type has a value which is a string
auth has a value which is a string


=end text

=back



=head2 get_media_params

=over 4



=item Description

Input parameters for the "get_media" function.

        list<media_id> medias - a list of the media IDs for the media to be returned (a required argument)
        string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
medias has a value which is a reference to a list where each element is a media_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
medias has a value which is a reference to a list where each element is a media_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string


=end text

=back



=head2 get_biochemistry_params

=over 4



=item Description

Input parameters for the "get_biochemistry" function.

        biochemistry_id biochemistry - ID of the biochemistry database to be returned (a required argument)
        workspace_id biochemistry_workspace - workspace containing the biochemistry database to be returned (a required argument)
        string id_type - the type of ID that should be used in the output data (a optional argument; default is 'ModelSEED')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
id_type has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
id_type has a value which is a string
auth has a value which is a string


=end text

=back



=head2 import_probanno_params

=over 4



=item Description

********************************************************************************
    Code relating to reconstruction of metabolic models
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
probanno has a value which is a probanno_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
annotationProbabilities has a value which is a reference to a list where each element is an annotationProbability
ignore_errors has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
probanno has a value which is a probanno_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
annotationProbabilities has a value which is a reference to a list where each element is an annotationProbability
ignore_errors has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 Genome_uid

=over 4



=item Description

Input parameters for the "genome_object_to_workspace" function.

        Genome_uid uid - ID to use when saving genome to workspace
        GenomeObject genomeobj - full genome typed object to be loaded into the workspace (a required argument)
        workspace_id workspace - ID of the workspace into which the genome typed object is to be loaded (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 genome_object_to_workspace_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
uid has a value which is a Genome_uid
genomeobj has a value which is a GenomeObject
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
uid has a value which is a Genome_uid
genomeobj has a value which is a GenomeObject
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 genome_to_workspace_params

=over 4



=item Description

Input parameters for the "genome_to_workspace" function.

        genome_id genome - ID of the CDM genome that is to be loaded into the workspace (a required argument)
        string sourceLogin - login to pull private genome from source database
        string sourcePassword - password to pull private genome from source database
        string source - Source database for genome (i.e. seed, rast, kbase)
        workspace_id workspace - ID of the workspace into which the genome typed object is to be loaded (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
sourceLogin has a value which is a string
sourcePassword has a value which is a string
source has a value which is a string
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
sourceLogin has a value which is a string
sourcePassword has a value which is a string
source has a value which is a string
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 translation

=over 4



=item Description

A link between a KBase gene ID and the ID for the same gene in another database

        string foreign_id - ID of the gene in another database
        feature_id feature - ID of the gene in KBase


=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: (foreign_id) a string
1: (feature) a feature_id

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (foreign_id) a string
1: (feature) a feature_id


=end text

=back



=head2 add_feature_translation_params

=over 4



=item Description

Input parameters for the "add_feature_translation" function.

        genome_id genome - ID of the genome into which the new aliases are to be loaded (a required argument)
        workspace_id workspace - ID of the workspace containing the target genome (a required argument)
        list<translation> translations - list of translations between KBase gene IDs and gene IDs in another database (a required argument)
        string id_type - type of the IDs being loaded (e.g. KEGG, NCBI) (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
translations has a value which is a reference to a list where each element is a translation
id_type has a value which is a string
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
translations has a value which is a reference to a list where each element is a translation
id_type has a value which is a string
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 genome_to_fbamodel_params

=over 4



=item Description

Input parameters for the "genome_to_fbamodel" function.

        genome_id genome - ID of the genome for which a model is to be built (a required argument)
        workspace_id genome_workspace - ID of the workspace containing the target genome (an optional argument; default is the workspace argument)
        template_id templatemodel - 
        workspace_id templatemodel_workspace - 
        bool probannoOnly - a boolean indicating if only the probabilistic annotation should be used in building the model (an optional argument; default is '0')
        fbamodel_id model - ID that should be used for the newly constructed model (an optional argument; default is 'undef')
        bool coremodel - indicates that a core model should be constructed instead of a genome scale model (an optional argument; default is '0')
        workspace_id workspace - ID of the workspace where the newly developed model will be stored; also the default assumed workspace for input objects (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
templatemodel has a value which is a template_id
templatemodel_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
coremodel has a value which is a bool
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
templatemodel has a value which is a template_id
templatemodel_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
coremodel has a value which is a bool
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 import_fbamodel_params

=over 4



=item Description

Input parameters for the "import_fbamodel" function.

        genome_id genome - ID of the genome for which a model is to be built (a required argument)
        workspace_id genome_workspace - ID of the workspace containing the target genome (an optional argument; default is the workspace argument)
        string biomass - biomass equation for model (an essential argument)
        list<tuple<string id,string direction,string compartment,string gpr> reactions - list of reactions to appear in imported model (an essential argument)
        fbamodel_id model - ID that should be used for the newly imported model (an optional argument; default is 'undef')
        workspace_id workspace - ID of the workspace where the newly developed model will be stored; also the default assumed workspace for input objects (a required argument)
        bool ignore_errors - ignores missing genes or reactions and imports model anyway
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
biomass has a value which is a string
reactions has a value which is a reference to a list where each element is a reference to a list containing 4 items:
0: (id) a string
1: (direction) a string
2: (compartment) a string
3: (gpr) a string

model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
ignore_errors has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
biomass has a value which is a string
reactions has a value which is a reference to a list where each element is a reference to a list containing 4 items:
0: (id) a string
1: (direction) a string
2: (compartment) a string
3: (gpr) a string

model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
ignore_errors has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 export_fbamodel_params

=over 4



=item Description

Input parameters for the "export_fbamodel" function.

        fbamodel_id model - ID of the model to be exported (a required argument)
        workspace_id workspace - workspace containing the model to be exported (a required argument)
        string format - format to which the model should be exported (sbml, html, json, readable, cytoseed) (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string


=end text

=back



=head2 export_object_params

=over 4



=item Description

Input parameters for the "export_object" function.

        workspace_ref reference - reference of object to print in html (a required argument)
        string type - type of the object to be exported (a required argument)
        string format - format to which data should be exported (an optional argument; default is html)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
type has a value which is a string
format has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
type has a value which is a string
format has a value which is a string
auth has a value which is a string


=end text

=back



=head2 export_genome_params

=over 4



=item Description

Input parameters for the "export_genome" function.

        genome_id genome - ID of the genome to be exported (a required argument)
        workspace_id workspace - workspace containing the model to be exported (a required argument)
        string format - format to which the model should be exported (sbml, html, json, readable, cytoseed) (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string


=end text

=back



=head2 adjust_model_reaction_params

=over 4



=item Description

Input parameters for the "adjust_model_reaction" function.

        fbamodel_id model - ID of model to be adjusted
        workspace_id workspace - workspace containing model to be adjusted
        list<reaction_id> reaction - List of IDs of reactions to be added, removed, or adjusted
        list<string> direction - directions to set for reactions being added or adjusted
        list<compartment_id> compartment - IDs of compartment containing reaction being added or adjusted
        list<int> compartmentIndex - indexes of compartment containing reaction being altered or adjusted
        list<string> gpr - array specifying gene-protein-reaction association(s)
        bool removeReaction - boolean indicating listed reaction(s) should be removed
        bool addReaction - boolean indicating reaction(s) should be added
        bool overwrite - boolean indicating whether or not to overwrite model object in the workspace
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)

        For all of the lists above, if only one element is specified it is assumed the user wants to apply the same
        to all the listed reactions.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
reaction has a value which is a reference to a list where each element is a reaction_id
direction has a value which is a reference to a list where each element is a string
compartment has a value which is a reference to a list where each element is a compartment_id
compartmentIndex has a value which is a reference to a list where each element is an int
gpr has a value which is a reference to a list where each element is a string
removeReaction has a value which is a bool
addReaction has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
reaction has a value which is a reference to a list where each element is a reaction_id
direction has a value which is a reference to a list where each element is a string
compartment has a value which is a reference to a list where each element is a compartment_id
compartmentIndex has a value which is a reference to a list where each element is an int
gpr has a value which is a reference to a list where each element is a string
removeReaction has a value which is a bool
addReaction has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 adjust_biomass_reaction_params

=over 4



=item Description

Input parameters for the "adjust_biomass_reaction" function.

        fbamodel_id model - ID of model to be adjusted
        workspace_id workspace - workspace containing model to be adjusted
        biomass_id biomass - ID of biomass reaction to adjust
        list<float> coefficients - coefficient of biomass compound
        list<compound_id> compounds - ID of biomass compound to adjust in biomass
        list<compartment_id> compartments - ID of compartment containing compound to adjust in biomass
        list<int> compartmentIndecies - index of compartment containing compound to adjust in biomass
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
biomass has a value which is a biomass_id
coefficients has a value which is a reference to a list where each element is a float
compounds has a value which is a reference to a list where each element is a compound_id
compartments has a value which is a reference to a list where each element is a compartment_id
compartmentIndecies has a value which is a reference to a list where each element is an int
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
biomass has a value which is a biomass_id
coefficients has a value which is a reference to a list where each element is a float
compounds has a value which is a reference to a list where each element is a compound_id
compartments has a value which is a reference to a list where each element is a compartment_id
compartmentIndecies has a value which is a reference to a list where each element is an int
auth has a value which is a string


=end text

=back



=head2 addmedia_params

=over 4



=item Description

********************************************************************************
    Code relating to flux balance analysis
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
workspace has a value which is a workspace_id
name has a value which is a string
isDefined has a value which is a bool
isMinimal has a value which is a bool
type has a value which is a string
compounds has a value which is a reference to a list where each element is a string
concentrations has a value which is a reference to a list where each element is a float
maxflux has a value which is a reference to a list where each element is a float
minflux has a value which is a reference to a list where each element is a float
overwrite has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
workspace has a value which is a workspace_id
name has a value which is a string
isDefined has a value which is a bool
isMinimal has a value which is a bool
type has a value which is a string
compounds has a value which is a reference to a list where each element is a string
concentrations has a value which is a reference to a list where each element is a float
maxflux has a value which is a reference to a list where each element is a float
minflux has a value which is a reference to a list where each element is a float
overwrite has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 export_media_params

=over 4



=item Description

Input parameters for the "export_media" function.

        media_id media - ID of the media to be exported (a required argument)
        workspace_id workspace - workspace containing the media to be exported (a required argument)
        string format - format to which the media should be exported (html, json, readable) (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string


=end text

=back



=head2 runfba_params

=over 4



=item Description

Input parameters for the "addmedia" function.

        fbamodel_id model - ID of the model that FBA should be run on (a required argument)
        workspace_id model_workspace - workspace where model for FBA should be run (an optional argument; default is the value of the workspace argument)
        FBAFormulation formulation - a hash specifying the parameters for the FBA study (an optional argument)
        bool fva - a flag indicating if flux variability should be run (an optional argument: default is '0')
        bool simulateko - a flag indicating if flux variability should be run (an optional argument: default is '0')
        bool minimizeflux - a flag indicating if flux variability should be run (an optional argument: default is '0')
        bool findminmedia - a flag indicating if flux variability should be run (an optional argument: default is '0')
        string notes - a string of notes to attach to the FBA study (an optional argument; defaul is '')
        fba_id fba - ID under which the FBA results should be saved (an optional argument; defaul is 'undef')
        workspace_id workspace - workspace where FBA results will be saved (a required argument)
        bool add_to_model - a flag indicating if the FBA study should be attached to the model to support viewing results (an optional argument: default is '0')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
fva has a value which is a bool
simulateko has a value which is a bool
minimizeflux has a value which is a bool
findminmedia has a value which is a bool
notes has a value which is a string
fba has a value which is a fba_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
add_to_model has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
fva has a value which is a bool
simulateko has a value which is a bool
minimizeflux has a value which is a bool
findminmedia has a value which is a bool
notes has a value which is a string
fba has a value which is a fba_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
add_to_model has a value which is a bool


=end text

=back



=head2 export_fba_params

=over 4



=item Description

Input parameters for the "addmedia" function.

        fba_id fba - ID of the FBA study to be exported (a required argument)
        workspace_id workspace - workspace where FBA study is stored (a required argument)
        string format - format to which the FBA study should be exported (i.e. html, json, readable) (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fba has a value which is a fba_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fba has a value which is a fba_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string


=end text

=back



=head2 import_phenotypes_params

=over 4



=item Description

********************************************************************************
    Code relating to phenotype simulation and reconciliation
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotype_set_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
name has a value which is a string
source has a value which is a string
ignore_errors has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotype_set_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
name has a value which is a string
source has a value which is a string
ignore_errors has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 simulate_phenotypes_params

=over 4



=item Description

Input parameters for the "simulate_phenotypes" function.

        fbamodel_id model - ID of the model to be used for the simulation (a required argument)
        workspace_id model_workspace - workspace containing the model for the simulation (an optional argument: default is value of workspace argument)
        phenotype_set_id phenotypeSet - ID of the phenotypes set to be simulated (a required argument)
        workspace_id phenotypeSet_workspace - workspace containing the phenotype set to be simulated (an optional argument: default is value of workspace argument)
        FBAFormulation formulation - parameters for the simulation flux balance analysis (an optional argument: default is 'undef')
        string notes - string of notes to associate with the phenotype simulation (an optional argument: default is '')
        phenotypeSimulationSet_id phenotypeSimultationSet - ID of the phenotype simulation set to be generated (an optional argument: default is 'undef')
        workspace_id workspace - workspace where the phenotype simulation set should be saved (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)
        bool all_transporters - Set to TRUE if you want to add transporters for ALL media in the phenotypeset before simulating
        bool positive_transporters - Set to TRUE if you want to add transporters for POSITIVE (non-zero growth) media only before simulating


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
notes has a value which is a string
phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string
all_transporters has a value which is a bool
positive_transporters has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
notes has a value which is a string
phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string
all_transporters has a value which is a bool
positive_transporters has a value which is a bool


=end text

=back



=head2 add_media_transporters_params

=over 4



=item Description

Input parameters for the add_media_transporters function.

              phenotype_set_id phenotypeSet - ID for a phenotype set (required)
              workspace_id phenotypeSet_workspace - ID for the workspace in which the phenotype set is found
              fbamodel_id model - Model to which to add the transport reactions (required)
              workspace_id model_workspace - workspace containing the input model
              fbamodel_id outmodel - Name of output model (with transporters added)
              workspace_id workspace - workspace where the modified model should be saved
              bool overwrite - Overwrite or not
              stirng auth - Auth string
              bool all_transporters - Add transporters for ALL media in the phenotypeset
              bool positive_transporters - Add transporters for only POSITIVE (non-zero growth) media in the phenotype set


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
outmodel has a value which is a fbamodel_id
workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string
all_transporters has a value which is a bool
positive_transporters has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
outmodel has a value which is a fbamodel_id
workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string
all_transporters has a value which is a bool
positive_transporters has a value which is a bool


=end text

=back



=head2 export_phenotypeSimulationSet_params

=over 4



=item Description

Input parameters for the "export_phenotypeSimulationSet" function.

        phenotypeSimulationSet_id phenotypeSimultationSet - ID of the phenotype simulation set to be exported (a required argument)
        workspace_id workspace - workspace where the phenotype simulation set is stored (a required argument)
        string format - format to which phenotype simulation set should be exported (html, json)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
phenotypeSimulationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotypeSimulationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
format has a value which is a string
auth has a value which is a string


=end text

=back



=head2 integrate_reconciliation_solutions_params

=over 4



=item Description

Input parameters for the "integrate_reconciliation_solutions" function.

        fbamodel_id model - ID of model for which reconciliation solutions should be integrated (a required argument)
        workspace_id model_workspace - workspace containing model for which solutions should be integrated (an optional argument: default is value of workspace argument)
        list<gapfillsolution_id> gapfillSolutions - list of gapfill solutions to be integrated (a required argument)
        list<gapgensolution_id> gapgenSolutions - list of gapgen solutions to be integrated (a required argument)
        fbamodel_id out_model - ID to which modified model should be saved (an optional argument: default is value of workspace argument)
        workspace_id workspace - workspace where modified model should be saved (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
gapfillSolutions has a value which is a reference to a list where each element is a gapfillsolution_id
gapgenSolutions has a value which is a reference to a list where each element is a gapgensolution_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
gapfillSolutions has a value which is a reference to a list where each element is a gapfillsolution_id
gapgenSolutions has a value which is a reference to a list where each element is a gapgensolution_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 queue_runfba_params

=over 4



=item Description

********************************************************************************
    Code relating to queuing long running jobs
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
fva has a value which is a bool
simulateko has a value which is a bool
minimizeflux has a value which is a bool
findminmedia has a value which is a bool
notes has a value which is a string
fba has a value which is a fba_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
add_to_model has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
fva has a value which is a bool
simulateko has a value which is a bool
minimizeflux has a value which is a bool
findminmedia has a value which is a bool
notes has a value which is a string
fba has a value which is a fba_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
add_to_model has a value which is a bool


=end text

=back



=head2 gapfill_model_params

=over 4



=item Description

Input parameters for the "queue_gapfill_model" function.

        fbamodel_id model - ID of the model that gapfill should be run on (a required argument)
        workspace_id model_workspace - workspace where model for gapfill should be run (an optional argument; default is the value of the workspace argument)
        GapfillingFormulation formulation - a hash specifying the parameters for the gapfill study (an optional argument)
        phenotype_set_id phenotypeSet - ID of a phenotype set against which gapfilled model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        bool integrate_solution - a flag indicating if the first solution should be integrated in the model (an optional argument: default is '0')
        list<string> target_reactions - a list of reactions to activate with gapfilling
        fbamodel_id out_model - ID where the gapfilled model will be saved (an optional argument: default is 'undef')
        gapfill_id gapFill - ID to which gapfill solution will be saved (an optional argument: default is 'undef')
        workspace_id workspace - workspace where gapfill results will be saved (a required argument)
        int timePerSolution - maximum time to spend to obtain each solution
        int totalTimeLimit - maximum time to spend to obtain all solutions
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)
        bool completeGapfill - boolean indicating that all inactive reactions should be gapfilled


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapfillingFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
target_reactions has a value which is a reference to a list where each element is a string
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFill has a value which is a gapfill_id
timePerSolution has a value which is an int
totalTimeLimit has a value which is an int
auth has a value which is a string
overwrite has a value which is a bool
completeGapfill has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapfillingFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
target_reactions has a value which is a reference to a list where each element is a string
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFill has a value which is a gapfill_id
timePerSolution has a value which is an int
totalTimeLimit has a value which is an int
auth has a value which is a string
overwrite has a value which is a bool
completeGapfill has a value which is a bool


=end text

=back



=head2 gapgen_model_params

=over 4



=item Description

Input parameters for the "queue_gapgen_model" function.

        fbamodel_id model - ID of the model that gapgen should be run on (a required argument)
        workspace_id model_workspace - workspace where model for gapgen should be run (an optional argument; default is the value of the workspace argument)
        GapgenFormulation formulation - a hash specifying the parameters for the gapgen study (an optional argument)
        phenotype_set_id phenotypeSet - ID of a phenotype set against which gapgened model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        bool integrate_solution - a flag indicating if the first solution should be integrated in the model (an optional argument: default is '0')
        fbamodel_id out_model - ID where the gapgened model will be saved (an optional argument: default is 'undef')
        gapgen_id gapGen - ID to which gapgen solution will be saved (an optional argument: default is 'undef')
        workspace_id workspace - workspace where gapgen results will be saved (a required argument)
        int timePerSolution - maximum time to spend to obtain each solution
        int totalTimeLimit - maximum time to spend to obtain all solutions
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapGen has a value which is a gapgen_id
auth has a value which is a string
timePerSolution has a value which is an int
totalTimeLimit has a value which is an int
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapGen has a value which is a gapgen_id
auth has a value which is a string
timePerSolution has a value which is an int
totalTimeLimit has a value which is an int
overwrite has a value which is a bool


=end text

=back



=head2 wildtype_phenotype_reconciliation_params

=over 4



=item Description

Input parameters for the "queue_wildtype_phenotype_reconciliation" function.

        fbamodel_id model - ID of the model that reconciliation should be run on (a required argument)
        workspace_id model_workspace - workspace where model for reconciliation should be run (an optional argument; default is the value of the workspace argument)
        FBAFormulation formulation - a hash specifying the parameters for the reconciliation study (an optional argument)
        GapfillingFormulation gapfill_formulation - a hash specifying the parameters for the gapfill study (an optional argument)
        GapgenFormulation gapgen_formulation - a hash specifying the parameters for the gapgen study (an optional argument)
        phenotype_set_id phenotypeSet - ID of a phenotype set against which reconciled model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        fbamodel_id out_model - ID where the reconciled model will be saved (an optional argument: default is 'undef')
        list<gapgen_id> gapGens - IDs of gapgen solutions (an optional argument: default is 'undef')
        list<gapfill_id> gapFills - IDs of gapfill solutions (an optional argument: default is 'undef')
        bool queueSensitivityAnalysis - flag indicating if sensitivity analysis should be queued to run on solutions (an optional argument: default is '0')
        bool queueReconciliationCombination - flag indicating if reconcilication combination should be queued to run on solutions (an optional argument: default is '0')
        workspace_id workspace - workspace where reconciliation results will be saved (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
queueSensitivityAnalysis has a value which is a bool
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
queueSensitivityAnalysis has a value which is a bool
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 queue_reconciliation_sensitivity_analysis_params

=over 4



=item Description

Input parameters for the "queue_reconciliation_sensitivity_analysis" function.

        fbamodel_id model - ID of the model that sensitivity analysis should be run on (a required argument)
        workspace_id model_workspace - workspace where model for sensitivity analysis should be run (an optional argument; default is the value of the workspace argument)
        FBAFormulation formulation - a hash specifying the parameters for the sensitivity analysis study (an optional argument)
        GapfillingFormulation gapfill_formulation - a hash specifying the parameters for the gapfill study (an optional argument)
        GapgenFormulation gapgen_formulation - a hash specifying the parameters for the gapgen study (an optional argument)
        phenotype_set_id phenotypeSet - ID of a phenotype set against which sensitivity analysis model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        fbamodel_id out_model - ID where the sensitivity analysis model will be saved (an optional argument: default is 'undef')
        list<gapgen_id> gapGens - IDs of gapgen solutions (an optional argument: default is 'undef')
        list<gapfill_id> gapFills - IDs of gapfill solutions (an optional argument: default is 'undef')
        bool queueReconciliationCombination - flag indicating if sensitivity analysis combination should be queued to run on solutions (an optional argument: default is '0')
        workspace_id workspace - workspace where sensitivity analysis results will be saved (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotype_set_id
fba_formulation has a value which is an FBAFormulation
model_workspace has a value which is a workspace_id
phenotypeSet_workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotype_set_id
fba_formulation has a value which is an FBAFormulation
model_workspace has a value which is a workspace_id
phenotypeSet_workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 combine_wildtype_phenotype_reconciliation_params

=over 4



=item Description

Input parameters for the "queue_combine_wildtype_phenotype_reconciliation" function.

        fbamodel_id model - ID of the model that solution combination should be run on (a required argument)
        workspace_id model_workspace - workspace where model for solution combination should be run (an optional argument; default is the value of the workspace argument)
        FBAFormulation formulation - a hash specifying the parameters for the solution combination study (an optional argument)
        GapfillingFormulation gapfill_formulation - a hash specifying the parameters for the gapfill study (an optional argument)
        GapgenFormulation gapgen_formulation - a hash specifying the parameters for the gapgen study (an optional argument)
        phenotype_set_id phenotypeSet - ID of a phenotype set against which solution combination model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        fbamodel_id out_model - ID where the solution combination model will be saved (an optional argument: default is 'undef')
        list<gapgen_id> gapGens - IDs of gapgen solutions (an optional argument: default is 'undef')
        list<gapfill_id> gapFills - IDs of gapfill solutions (an optional argument: default is 'undef')
        workspace_id workspace - workspace where solution combination results will be saved (a required argument)
        int timePerSolution - maximum time spent per solution
        int totalTimeLimit - maximum time allowed to work on problem
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotype_set_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 run_job_params

=over 4



=item Description

Input parameters for the "run_job" function.

        job_id job - ID of the job object (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
job has a value which is a job_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
job has a value which is a job_id
auth has a value which is a string


=end text

=back



=head2 queue_job_params

=over 4



=item Description

Input parameters for the "queue_job" function.

        string method;
        mapping<string,string> parameters;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
method has a value which is a string
parameters has a value which is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
method has a value which is a string
parameters has a value which is a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 set_cofactors_params

=over 4



=item Description

Input parameters for the "set_cofactors" function.

        list<compound_id> cofactors - list of compounds that are universal cofactors (required)
        biochemistry_id biochemistry - ID of biochemistry database (optional, default is "default") 
        workspace_id biochemistry_workspace - ID of workspace containing biochemistry database (optional, default is current workspace)
        bool reset - true to reset (turn off) compounds as universal cofactors (optional, default is false)
        bool overwrite - true to overwrite existing object (optional, default is false)
        string auth - the authentication token of the KBase account (optional, default user is "public")


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
cofactors has a value which is a reference to a list where each element is a compound_id
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
reset has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
cofactors has a value which is a reference to a list where each element is a compound_id
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
reset has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 find_reaction_synonyms_params

=over 4



=item Description

Input parameters for the "find_reaction_synonyms" function.

        reaction_synonyms - ID of reaction synonyms object (required argument)
        workspace_id workspace - ID of workspace for storing objects (optional argument, default is current workspace)
        biochemistry_id biochemistry - ID of the biochemistry database (optional argument, default is default)
        workspace_id biochemistry_workspace - ID of workspace containing biochemistry database (optional argument, default is kbase)
        overwrite - True to overwrite existing object (optional argument, default is false)
        string auth - the authentication token of the KBase account (optional argument, default user is "public")


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reaction_synonyms has a value which is a reaction_synonyms_id
workspace has a value which is a workspace_id
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reaction_synonyms has a value which is a reaction_synonyms_id
workspace has a value which is a workspace_id
biochemistry has a value which is a biochemistry_id
biochemistry_workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 role_to_reactions_params

=over 4



=item Description

Input parameters for the "role_to_reactions" function.

        template_id templateModel - ID of the template model to be used to determine mapping (default is '')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 kb_sub_id

=over 4



=item Description

********************************************************************************
	Code relating to assessing model sensitivity to reaction knockouts
   	********************************************************************************


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 kb_id

=over 4



=item Description

@id kb


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ws_id

=over 4



=item Description

@id ws


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ws_sub_id

=over 4



=item Description

@id wssub


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ReactionSensitivityAnalysisCorrectedReaction

=over 4



=item Description

ReactionSensitivityAnalysisCorrectedReaction object

kb_sub_id kbid - KBase ID for reaction knockout corrected reaction
ws_sub_id model_reaction_wsid - ID of model reaction
float normalized_required_reaction_count - Normalized count of reactions required for this reaction to function
list<ws_sub_id> required_reactions - list of reactions required for this reaction to function

@searchable ws_subset kbid model_reaction_kbid required_reactions
@optional


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kb_sub_id
model_reaction_wsid has a value which is a ws_sub_id
normalized_required_reaction_count has a value which is a float
required_reactions has a value which is a reference to a list where each element is a ws_sub_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kb_sub_id
model_reaction_wsid has a value which is a ws_sub_id
normalized_required_reaction_count has a value which is a float
required_reactions has a value which is a reference to a list where each element is a ws_sub_id


=end text

=back



=head2 ReactionSensitivityAnalysisReaction

=over 4



=item Description

Object for holding reaction knockout sensitivity reaction data

kb_sub_id kbid - KBase ID for reaction knockout sensitivity reaction
ws_sub_id model_reaction_wsid - ID of model reaction
bool delete - indicates if reaction is to be deleted
bool deleted - indicates if the reaction has been deleted
float growth_fraction - Fraction of wild-type growth after knockout
float normalized_activated_reaction_count - Normalized number of activated reactions
list<ws_sub_id> biomass_compounds  - List of biomass compounds that depend on the reaction
list<ws_sub_id> new_inactive_rxns - List of new reactions dependant upon reaction KO
list<ws_sub_id> new_essentials - List of new essential genes with reaction knockout


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kb_sub_id
model_reaction_wsid has a value which is a ws_sub_id
growth_fraction has a value which is a float
delete has a value which is a bool
deleted has a value which is a bool
normalized_activated_reaction_count has a value which is a float
biomass_compounds has a value which is a reference to a list where each element is a ws_sub_id
new_inactive_rxns has a value which is a reference to a list where each element is a ws_sub_id
new_essentials has a value which is a reference to a list where each element is a ws_sub_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kb_sub_id
model_reaction_wsid has a value which is a ws_sub_id
growth_fraction has a value which is a float
delete has a value which is a bool
deleted has a value which is a bool
normalized_activated_reaction_count has a value which is a float
biomass_compounds has a value which is a reference to a list where each element is a ws_sub_id
new_inactive_rxns has a value which is a reference to a list where each element is a ws_sub_id
new_essentials has a value which is a reference to a list where each element is a ws_sub_id


=end text

=back



=head2 ReactionSensitivityAnalysis

=over 4



=item Description

Object for holding reaction knockout sensitivity results

        kb_id kbid - KBase ID of reaction sensitivity object
        ws_id model_wsid - Workspace reference to associated model
        string type - type of reaction KO sensitivity object
        bool deleted_noncontributing_reactions - boolean indicating if noncontributing reactions were deleted
        bool integrated_deletions_in_model - boolean indicating if deleted reactions were implemented in the model
        list<ReactionSensitivityAnalysisReaction> reactions - list of sensitivity data for tested reactions
        list<ReactionSensitivityAnalysisCorrectedReaction> corrected_reactions - list of reactions dependant upon tested reactions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kb_id
model_wsid has a value which is a ws_id
type has a value which is a string
deleted_noncontributing_reactions has a value which is a bool
integrated_deletions_in_model has a value which is a bool
reactions has a value which is a reference to a list where each element is a ReactionSensitivityAnalysisReaction
corrected_reactions has a value which is a reference to a list where each element is a ReactionSensitivityAnalysisCorrectedReaction

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kb_id
model_wsid has a value which is a ws_id
type has a value which is a string
deleted_noncontributing_reactions has a value which is a bool
integrated_deletions_in_model has a value which is a bool
reactions has a value which is a reference to a list where each element is a ReactionSensitivityAnalysisReaction
corrected_reactions has a value which is a reference to a list where each element is a ReactionSensitivityAnalysisCorrectedReaction


=end text

=back



=head2 rxnprob_id

=over 4



=item Description

ID for a RxnProbs T.O. (defined in the probabilistic annotation spec)


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 reaction_sensitivity_analysis_params

=over 4



=item Description

Input parameters for the "reaction_sensitivity_analysis" function.

        fbamodel_id model - ID of model to be analyzed (a required argument)
        workspace_id model_ws - ID of workspace with model to be analyzed (an optional argument - default is value of workspace argument)
        string rxnsens_uid - Name of RxnSensitivity object in workspace (an optional argument - default is KBase ID)
        workspace_id workspace - ID of workspace where output and default inputs will be selected from (a required argument)
        list<reaction_id> reactions_to_delete - list of reactions to delete in sensitiviity analysis; note, order of the reactions matters (a required argument unless gapfill solution ID is provided)                
        gapfillsolution_id gapfill_solution_id - A Gapfill solution ID. If provided, all reactions in the provided solution will be tested for deletion.
        bool delete_noncontributing_reactions - a boolean indicating if unuseful reactions should be deleted when running the analysis (an optional argument - default is "0")
        rxnprob_id rxnprobs_id - ID for a RxnProbs object in a workspace. If provided less likely reactions will be tested for deletion first in the sensitivity analysis (optional).
        workspace_id rxnprobs_ws - Workspace in which the RxnProbs object is located (optional - default is the value of the workspace argument).
        string type - type of Reaction sensitivity analysis (an optional argument - default is "unknown")
        string auth  - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_ws has a value which is a workspace_id
rxnsens_uid has a value which is a string
workspace has a value which is a workspace_id
reactions_to_delete has a value which is a reference to a list where each element is a reaction_id
gapfill_solution_id has a value which is a gapfillsolution_id
delete_noncontributing_reactions has a value which is a bool
rxnprobs_id has a value which is a rxnprob_id
rxnprobs_ws has a value which is a workspace_id
type has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_ws has a value which is a workspace_id
rxnsens_uid has a value which is a string
workspace has a value which is a workspace_id
reactions_to_delete has a value which is a reference to a list where each element is a reaction_id
gapfill_solution_id has a value which is a gapfillsolution_id
delete_noncontributing_reactions has a value which is a bool
rxnprobs_id has a value which is a rxnprob_id
rxnprobs_ws has a value which is a workspace_id
type has a value which is a string
auth has a value which is a string


=end text

=back



=head2 filter_iterative_solutions_params

=over 4



=item Description

Input parameters for the "filter_iterative_solutions" function.
fbamodel_id model - Model ID for which to filter iterative gapfill solutions (a required argument)
fbamodel_id outmodel - ModelID to which to save the filtered results (by default the filtered model is given the same ID as the input model)
float cutoff - Cutoff for cost per reaction above which to remove iterative gapfill solution reactions (a required argument)
gapfillsolution_id gapfillsln - Gapfill_solution ID (UUID.solution.#) containing the iterative gapfill solutions to filter (a required argument)
string auth - The authorization token of the KBase account with workspace permissions.
workspace_id workspace - ID of workspace where output and default inputs will be selected from (a required argument)
workspace_id input_model_ws - ID of workspace containing the input model


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
outmodel has a value which is a fbamodel_id
cutoff has a value which is a float
gapfillsln has a value which is a gapfillsolution_id
workspace has a value which is a workspace_id
input_model_ws has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
outmodel has a value which is a fbamodel_id
cutoff has a value which is a float
gapfillsln has a value which is a gapfillsolution_id
workspace has a value which is a workspace_id
input_model_ws has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 delete_noncontributing_reactions_params

=over 4



=item Description

Input parameters for the "delete_noncontributing_reactions" function.
workspace_id workspae - Workspace for outputs and default inputs (a required argument)
workspace_id rxn_sensitivity_ws - Workspace for reaction sensitivity object used as input
string rxn_sensitivity - Reaction sensitivity ID
fbamodel_id new_model_uid - ID for output model with noncontributing reactions deleted
string new_rxn_sensitivity_uid - ID for rxnsensitivity object with bits set to indicate reactions were deleted
string auth - Authorization token for user (must have appropriate permissions to read and write objects)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
rxn_sensitivity_ws has a value which is a workspace_id
rxn_sensitivity has a value which is a string
workspace has a value which is a workspace_id
new_model_uid has a value which is a fbamodel_id
new_rxn_sensitivity_uid has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
rxn_sensitivity_ws has a value which is a workspace_id
rxn_sensitivity has a value which is a string
workspace has a value which is a workspace_id
new_model_uid has a value which is a fbamodel_id
new_rxn_sensitivity_uid has a value which is a string
auth has a value which is a string


=end text

=back



=head2 AnnotationParameters

=over 4



=item Description

********************************************************************************
	Code relating to workspace versions of genome analysis algorithms
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
call_genes has a value which is a bool
annotate_genes has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
call_genes has a value which is a bool
annotate_genes has a value which is a bool


=end text

=back



=head2 annotate_workspace_Genome_params

=over 4



=item Description

Input parameters for the "annotate_workspace_Genome" function.

string Genome_uid - user ID to be assigned to the Genome (required argument)
string Genome_ws - workspace with genome for annotation (optional; workspace argument will be used if no genome workspace is provided)
string new_uid - new ID to assign to annotated genome (optional; original genome will be overwritten if no new uid is provided)
workspace_id workspace - ID of workspace with Genome (required argument)
AnnotationParameters parameters - parameters for running annotation job
string auth - the authentication token of the KBase account changing workspace permissions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
Genome_uid has a value which is a string
Genome_ws has a value which is a string
new_uid has a value which is a string
workspace has a value which is a workspace_id
annotation_parameters has a value which is an AnnotationParameters
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
Genome_uid has a value which is a string
Genome_ws has a value which is a string
new_uid has a value which is a string
workspace has a value which is a workspace_id
annotation_parameters has a value which is an AnnotationParameters
auth has a value which is a string


=end text

=back



=head2 fasta_to_ProteinSet_params

=over 4



=item Description

********************************************************************************
	Code relating to import and analysis of ProteinSets
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
uid has a value which is a string
fasta has a value which is a string
workspace has a value which is a workspace_id
auth has a value which is a string
name has a value which is a string
sourceid has a value which is a string
source has a value which is a string
type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
uid has a value which is a string
fasta has a value which is a string
workspace has a value which is a workspace_id
auth has a value which is a string
name has a value which is a string
sourceid has a value which is a string
source has a value which is a string
type has a value which is a string


=end text

=back



=head2 ProteinSet_to_Genome_params

=over 4



=item Description

Input parameters for the "ProteinSet_to_Genome" function.

        string ProteinSet_uid - ID to be assigned to the ProteinSet (required argument)
        workspace_id ProteinSet_ws - ID of workspace with the ProteinSet (optional argument; default is value of workspace argument)
        string uid - user assigned ID for the Genome (optional)
        workspace_id workspace - ID of workspace for storing objects (required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)
        string scientific_name - scientific name to assign to genome
        string domain - domain of life for genome
        int genetic_code - genetic code to assign to genome


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ProteinSet_uid has a value which is a string
ProteinSet_ws has a value which is a workspace_id
workspace has a value which is a workspace_id
uid has a value which is a string
auth has a value which is a string
scientific_name has a value which is a string
domain has a value which is a string
annotation_parameters has a value which is an AnnotationParameters

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ProteinSet_uid has a value which is a string
ProteinSet_ws has a value which is a workspace_id
workspace has a value which is a workspace_id
uid has a value which is a string
auth has a value which is a string
scientific_name has a value which is a string
domain has a value which is a string
annotation_parameters has a value which is an AnnotationParameters


=end text

=back



=head2 fasta_to_ContigSet_params

=over 4



=item Description

********************************************************************************
	Code relating to import and analysis of Contigs
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
uid has a value which is a string
fasta has a value which is a string
workspace has a value which is a workspace_id
auth has a value which is a string
name has a value which is a string
sourceid has a value which is a string
source has a value which is a string
type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
uid has a value which is a string
fasta has a value which is a string
workspace has a value which is a workspace_id
auth has a value which is a string
name has a value which is a string
sourceid has a value which is a string
source has a value which is a string
type has a value which is a string


=end text

=back



=head2 ContigSet_to_Genome_params

=over 4



=item Description

Input parameters for the "ContigSet_to_Genome" function.

        string ContigSet_uid - ID to be assigned to the ContigSet (required argument)
        workspace_id ContigSet_ws - ID of workspace with the ContigSet (optional argument; default is value of workspace argument)
        string uid - user assigned ID for the Genome (optional)
        workspace_id workspace - ID of workspace for storing objects (required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)
        string scientific_name - scientific name to assign to genome
        string domain - domain of life for genome
        int genetic_code - genetic code to assign to genome
        AnnotationParameters annotation_parameters - parameters for annotation of the genome


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ContigSet_uid has a value which is a string
ContigSet_ws has a value which is a workspace_id
workspace has a value which is a workspace_id
uid has a value which is a string
auth has a value which is a string
scientific_name has a value which is a string
domain has a value which is a string
genetic_code has a value which is an int
annotation_parameters has a value which is an AnnotationParameters

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ContigSet_uid has a value which is a string
ContigSet_ws has a value which is a workspace_id
workspace has a value which is a workspace_id
uid has a value which is a string
auth has a value which is a string
scientific_name has a value which is a string
domain has a value which is a string
genetic_code has a value which is an int
annotation_parameters has a value which is an AnnotationParameters


=end text

=back



=head2 probanno_to_genome_params

=over 4



=item Description

********************************************************************************
	Code relating to analysis of probabilistic annotations
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
pa_id has a value which is a probanno_id
pa_ws has a value which is a workspace_id
workspace has a value which is a workspace_id
g_id has a value which is a genome_id
threshold has a value which is a float
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
pa_id has a value which is a probanno_id
pa_ws has a value which is a workspace_id
workspace has a value which is a workspace_id
g_id has a value which is a genome_id
threshold has a value which is a float
auth has a value which is a string


=end text

=back



=head2 FunctionalRole

=over 4



=item Description

********************************************************************************
	Code relating to loading, retrieval, and curation of mappings
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a role_id
name has a value which is a string
feature has a value which is a string
aliases has a value which is a reference to a list where each element is a string
complexes has a value which is a reference to a list where each element is a complex_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a role_id
name has a value which is a string
feature has a value which is a string
aliases has a value which is a reference to a list where each element is a string
complexes has a value which is a reference to a list where each element is a complex_id


=end text

=back



=head2 ComplexRole

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (id) a role_id
1: (roleType) a string
2: (optional_role) a bool
3: (triggering) a bool

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (id) a role_id
1: (roleType) a string
2: (optional_role) a bool
3: (triggering) a bool


=end text

=back



=head2 Complex

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a complex_id
name has a value which is a string
aliases has a value which is a reference to a list where each element is a string
roles has a value which is a reference to a list where each element is a ComplexRole

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a complex_id
name has a value which is a string
aliases has a value which is a reference to a list where each element is a string
roles has a value which is a reference to a list where each element is a ComplexRole


=end text

=back



=head2 subsystem_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 Subsystem

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a subsystem_id
name has a value which is a string
phenoclass has a value which is a string
subclass has a value which is a string
type has a value which is a string
aliases has a value which is a reference to a list where each element is a string
roles has a value which is a reference to a list where each element is a role_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a subsystem_id
name has a value which is a string
phenoclass has a value which is a string
subclass has a value which is a string
type has a value which is a string
aliases has a value which is a reference to a list where each element is a string
roles has a value which is a reference to a list where each element is a role_id


=end text

=back



=head2 Mapping

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a mapping_id
name has a value which is a string
subsystems has a value which is a reference to a list where each element is a Subsystem
roles has a value which is a reference to a list where each element is a FunctionalRole
complexes has a value which is a reference to a list where each element is a Complex

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a mapping_id
name has a value which is a string
subsystems has a value which is a reference to a list where each element is a Subsystem
roles has a value which is a reference to a list where each element is a FunctionalRole
complexes has a value which is a reference to a list where each element is a Complex


=end text

=back



=head2 get_mapping_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 adjust_mapping_role_params

=over 4



=item Description

Input parameters for the "adjust_mapping_role" function.

        mapping_id map - ID of the mapping object to be edited
        workspace_id workspace - ID of workspace containing mapping to be edited
        string role - identifier for role to be edited
        bool new - boolean indicating that a new role is being added
        string name - new name for the role
        string feature - representative feature MD5
        list<string> aliasesToAdd - list of new aliases for the role
        list<string> aliasesToRemove - list of aliases to remove for role
        bool delete - boolean indicating that role should be deleted
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
role has a value which is a string
new has a value which is a bool
name has a value which is a string
feature has a value which is a string
aliasesToAdd has a value which is a reference to a list where each element is a string
aliasesToRemove has a value which is a reference to a list where each element is a string
delete has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
role has a value which is a string
new has a value which is a bool
name has a value which is a string
feature has a value which is a string
aliasesToAdd has a value which is a reference to a list where each element is a string
aliasesToRemove has a value which is a reference to a list where each element is a string
delete has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 adjust_mapping_complex_params

=over 4



=item Description

Input parameters for the "adjust_mapping_complex" function.

        mapping_id map - ID of the mapping object to be edited
        workspace_id workspace - ID of workspace containing mapping to be edited
        string complex - identifier for complex to be edited
        bool new - boolean indicating that a new complex is being added
        string name - new name for the role
        string feature - representative feature MD5
        list<string> rolesToAdd - roles to add to the complex
        list<string> rolesToRemove - roles to remove from the complex
        bool delete - boolean indicating that complex should be deleted
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
complex has a value which is a string
new has a value which is a bool
name has a value which is a string
rolesToAdd has a value which is a reference to a list where each element is a string
rolesToRemove has a value which is a reference to a list where each element is a string
delete has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
complex has a value which is a string
new has a value which is a bool
name has a value which is a string
rolesToAdd has a value which is a reference to a list where each element is a string
rolesToRemove has a value which is a reference to a list where each element is a string
delete has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 adjust_mapping_subsystem_params

=over 4



=item Description

Input parameters for the "adjust_mapping_subsystem" function.

        mapping_id map - ID of the mapping object to be edited
        workspace_id workspace - ID of workspace containing mapping to be edited
        string subsystem - identifier for subsystem to be edited
        bool new - boolean indicating that a new subsystem is being added
        string name - new name for the subsystem
        string type - new type for the subsystem
        string primclass - new class for the subsystem
        string subclass - new subclass for the subsystem
        list<string> rolesToAdd - roles to add to the subsystem
        list<string> rolesToRemove - roles to remove from the subsystem
        bool delete - boolean indicating that subsystem should be deleted
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
subsystem has a value which is a string
new has a value which is a bool
name has a value which is a string
type has a value which is a string
primclass has a value which is a string
subclass has a value which is a string
rolesToAdd has a value which is a reference to a list where each element is a string
rolesToRemove has a value which is a reference to a list where each element is a string
delete has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
workspace has a value which is a workspace_id
subsystem has a value which is a string
new has a value which is a bool
name has a value which is a string
type has a value which is a string
primclass has a value which is a string
subclass has a value which is a string
rolesToAdd has a value which is a reference to a list where each element is a string
rolesToRemove has a value which is a reference to a list where each element is a string
delete has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 temprxn_id

=over 4



=item Description

********************************************************************************
	Code relating to loading, retrieval, and curation of template models
   	********************************************************************************


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 TemplateReaction

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a temprxn_id
compartment has a value which is a compartment_id
reaction has a value which is a reaction_id
complexes has a value which is a reference to a list where each element is a complex_id
direction has a value which is a string
type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a temprxn_id
compartment has a value which is a compartment_id
reaction has a value which is a reaction_id
complexes has a value which is a reference to a list where each element is a complex_id
direction has a value which is a string
type has a value which is a string


=end text

=back



=head2 TemplateBiomassCompounds

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 7 items:
0: (compound) a compound_id
1: (compartment) a compartment_id
2: (cpdclass) a string
3: (universal) a string
4: (coefficientType) a string
5: (coefficient) a string
6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
	0: (coeffficient) a string
	1: (compound) a compound_id


</pre>

=end html

=begin text

a reference to a list containing 7 items:
0: (compound) a compound_id
1: (compartment) a compartment_id
2: (cpdclass) a string
3: (universal) a string
4: (coefficientType) a string
5: (coefficient) a string
6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
	0: (coeffficient) a string
	1: (compound) a compound_id



=end text

=back



=head2 tempbiomass_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 TemplateBiomass

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a tempbiomass_id
name has a value which is a string
type has a value which is a string
other has a value which is a string
protein has a value which is a string
dna has a value which is a string
rna has a value which is a string
cofactor has a value which is a string
energy has a value which is a string
cellwall has a value which is a string
lipid has a value which is a string
compounds has a value which is a reference to a list where each element is a TemplateBiomassCompounds

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a tempbiomass_id
name has a value which is a string
type has a value which is a string
other has a value which is a string
protein has a value which is a string
dna has a value which is a string
rna has a value which is a string
cofactor has a value which is a string
energy has a value which is a string
cellwall has a value which is a string
lipid has a value which is a string
compounds has a value which is a reference to a list where each element is a TemplateBiomassCompounds


=end text

=back



=head2 TemplateModel

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a template_id
name has a value which is a string
type has a value which is a string
domain has a value which is a string
map has a value which is a mapping_id
mappingws has a value which is a workspace_id
reactions has a value which is a reference to a list where each element is a TemplateReaction
biomasses has a value which is a reference to a list where each element is a TemplateBiomass

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a template_id
name has a value which is a string
type has a value which is a string
domain has a value which is a string
map has a value which is a mapping_id
mappingws has a value which is a workspace_id
reactions has a value which is a reference to a list where each element is a TemplateReaction
biomasses has a value which is a reference to a list where each element is a TemplateBiomass


=end text

=back



=head2 get_template_model_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 import_template_fbamodel_params

=over 4



=item Description

Input parameters for the "import_template_fbamodel" function.

        mapping_id map - ID of the mapping to associate the template model with (an optional argument; default is 'default')
        workspace_id mapping_workspace - ID of the workspace where the associated mapping is found (an optional argument; default is 'kbase')
        list<tuple<string id,string compartment,string direction,string type,list<string complex> complexes>> templateReactions - list of reactions to include in template model
        list<tuple<string name,string type,float dna,float rna,float protein,float lipid,float cellwall,float cofactor,float energy,float other,list<tuple<string id,string compartment,string cpdclass,string coefficientType,float coefficient,string conditions>> compounds>> templateBiomass - list of template biomass reactions for template model
        string name - name for template model
        string modelType - type of model constructed by template
        string domain - domain of template model
        template_id id - ID that should be used for the newly imported template model (an optional argument; default is 'undef')
        workspace_id workspace - ID of the workspace where the newly developed template model will be stored; also the default assumed workspace for input objects (a required argument)
        bool ignore_errors - ignores missing roles or reactions and imports template model anyway
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
mapping_workspace has a value which is a workspace_id
templateReactions has a value which is a reference to a list where each element is a reference to a list containing 5 items:
0: (id) a string
1: (compartment) a string
2: (direction) a string
3: (type) a string
4: (complexes) a reference to a list where each element is a string

templateBiomass has a value which is a reference to a list where each element is a reference to a list containing 11 items:
0: (name) a string
1: (type) a string
2: (dna) a float
3: (rna) a float
4: (protein) a float
5: (lipid) a float
6: (cellwall) a float
7: (cofactor) a float
8: (energy) a float
9: (other) a float
10: (compounds) a reference to a list where each element is a reference to a list containing 6 items:
	0: (id) a string
	1: (compartment) a string
	2: (cpdclass) a string
	3: (coefficientType) a string
	4: (coefficient) a float
	5: (conditions) a string


name has a value which is a string
modelType has a value which is a string
domain has a value which is a string
id has a value which is a template_id
workspace has a value which is a workspace_id
ignore_errors has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
map has a value which is a mapping_id
mapping_workspace has a value which is a workspace_id
templateReactions has a value which is a reference to a list where each element is a reference to a list containing 5 items:
0: (id) a string
1: (compartment) a string
2: (direction) a string
3: (type) a string
4: (complexes) a reference to a list where each element is a string

templateBiomass has a value which is a reference to a list where each element is a reference to a list containing 11 items:
0: (name) a string
1: (type) a string
2: (dna) a float
3: (rna) a float
4: (protein) a float
5: (lipid) a float
6: (cellwall) a float
7: (cofactor) a float
8: (energy) a float
9: (other) a float
10: (compounds) a reference to a list where each element is a reference to a list containing 6 items:
	0: (id) a string
	1: (compartment) a string
	2: (cpdclass) a string
	3: (coefficientType) a string
	4: (coefficient) a float
	5: (conditions) a string


name has a value which is a string
modelType has a value which is a string
domain has a value which is a string
id has a value which is a template_id
workspace has a value which is a workspace_id
ignore_errors has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 adjust_template_reaction_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
reaction has a value which is a string
clearComplexes has a value which is a bool
new has a value which is a bool
delete has a value which is a bool
compartment has a value which is a compartment_id
complexesToAdd has a value which is a reference to a list where each element is a complex_id
complexesToRemove has a value which is a reference to a list where each element is a complex_id
direction has a value which is a string
type has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
reaction has a value which is a string
clearComplexes has a value which is a bool
new has a value which is a bool
delete has a value which is a bool
compartment has a value which is a compartment_id
complexesToAdd has a value which is a reference to a list where each element is a complex_id
complexesToRemove has a value which is a reference to a list where each element is a complex_id
direction has a value which is a string
type has a value which is a string
auth has a value which is a string


=end text

=back



=head2 adjust_template_biomass_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
biomass has a value which is a string
new has a value which is a bool
delete has a value which is a bool
clearBiomassCompounds has a value which is a bool
name has a value which is a string
type has a value which is a string
other has a value which is a string
protein has a value which is a string
dna has a value which is a string
rna has a value which is a string
cofactor has a value which is a string
energy has a value which is a string
cellwall has a value which is a string
lipid has a value which is a string
compoundsToRemove has a value which is a reference to a list where each element is a reference to a list containing 2 items:
0: (compound) a compound_id
1: (compartment) a compartment_id

compoundsToAdd has a value which is a reference to a list where each element is a reference to a list containing 7 items:
0: (compound) a compound_id
1: (compartment) a compartment_id
2: (cpdclass) a string
3: (universal) a string
4: (coefficientType) a string
5: (coefficient) a string
6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
	0: (coeffficient) a string
	1: (compound) a compound_id


auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
templateModel has a value which is a template_id
workspace has a value which is a workspace_id
biomass has a value which is a string
new has a value which is a bool
delete has a value which is a bool
clearBiomassCompounds has a value which is a bool
name has a value which is a string
type has a value which is a string
other has a value which is a string
protein has a value which is a string
dna has a value which is a string
rna has a value which is a string
cofactor has a value which is a string
energy has a value which is a string
cellwall has a value which is a string
lipid has a value which is a string
compoundsToRemove has a value which is a reference to a list where each element is a reference to a list containing 2 items:
0: (compound) a compound_id
1: (compartment) a compartment_id

compoundsToAdd has a value which is a reference to a list where each element is a reference to a list containing 7 items:
0: (compound) a compound_id
1: (compartment) a compartment_id
2: (cpdclass) a string
3: (universal) a string
4: (coefficientType) a string
5: (coefficient) a string
6: (linkedCompounds) a reference to a list where each element is a reference to a list containing 2 items:
	0: (coeffficient) a string
	1: (compound) a compound_id


auth has a value which is a string


=end text

=back



=head2 add_stimuli_params

=over 4



=item Description

********************************************************************************
    Code relating to reconstruction, import, and analysis of regulatory models
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
biochemid has a value which is a string
biochem_workspace has a value which is a string
stimuliid has a value which is a string
name has a value which is a string
abbreviation has a value which is a string
type has a value which is a string
description has a value which is a string
compounds has a value which is a reference to a list where each element is a string
workspace has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
biochemid has a value which is a string
biochem_workspace has a value which is a string
stimuliid has a value which is a string
name has a value which is a string
abbreviation has a value which is a string
type has a value which is a string
description has a value which is a string
compounds has a value which is a reference to a list where each element is a string
workspace has a value which is a string
auth has a value which is a string


=end text

=back



=head2 Stimuli

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
name has a value which is a string
abbreviation has a value which is a string
description has a value which is a string
type has a value which is a string
compound_kbids has a value which is a reference to a list where each element is a kbase_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
name has a value which is a string
abbreviation has a value which is a string
description has a value which is a string
type has a value which is a string
compound_kbids has a value which is a reference to a list where each element is a kbase_id


=end text

=back



=head2 RegulatoryModelRegulonStimuli

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
stimuli_kbid has a value which is a kbase_id
is_inhibitor has a value which is a bool
strength has a value which is a float
min_concentration has a value which is a float
max_concentration has a value which is a float
regulator_kbids has a value which is a reference to a list where each element is a kbase_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
stimuli_kbid has a value which is a kbase_id
is_inhibitor has a value which is a bool
strength has a value which is a float
min_concentration has a value which is a float
max_concentration has a value which is a float
regulator_kbids has a value which is a reference to a list where each element is a kbase_id


=end text

=back



=head2 RegulatoryModelRegulon

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
name has a value which is a string
feature_kbids has a value which is a reference to a list where each element is a kbase_id
stimuli has a value which is a reference to a list where each element is a RegulatoryModelRegulonStimuli

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
name has a value which is a string
feature_kbids has a value which is a reference to a list where each element is a kbase_id
stimuli has a value which is a reference to a list where each element is a RegulatoryModelRegulonStimuli


=end text

=back



=head2 RegulatoryModel

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
name has a value which is a string
type has a value which is a string
genome_wsid has a value which is a ws_ref
regulons has a value which is a reference to a list where each element is a RegulatoryModelRegulon

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a kbase_id
name has a value which is a string
type has a value which is a string
genome_wsid has a value which is a ws_ref
regulons has a value which is a reference to a list where each element is a RegulatoryModelRegulon


=end text

=back



=head2 import_regulatory_model_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
regmodel_uid has a value which is a string
workspace has a value which is a workspace_id
genome has a value which is a string
genome_ws has a value which is a workspace_id
name has a value which is a string
type has a value which is a string
regulons has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (name) a string
1: (features) a reference to a list where each element is a string
2: (stimuli) a reference to a list where each element is a reference to a list containing 6 items:
	0: (stimuli) a string
	1: (in_inhibitor) a bool
	2: (strength) a float
	3: (min_conc) a float
	4: (max_conc) a float
	5: (regulators) a reference to a list where each element is a kbase_id


auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
regmodel_uid has a value which is a string
workspace has a value which is a workspace_id
genome has a value which is a string
genome_ws has a value which is a workspace_id
name has a value which is a string
type has a value which is a string
regulons has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (name) a string
1: (features) a reference to a list where each element is a string
2: (stimuli) a reference to a list where each element is a reference to a list containing 6 items:
	0: (stimuli) a string
	1: (in_inhibitor) a bool
	2: (strength) a float
	3: (min_conc) a float
	4: (max_conc) a float
	5: (regulators) a reference to a list where each element is a kbase_id


auth has a value which is a string


=end text

=back



=head2 compare_models_params

=over 4



=item Description

********************************************************************************
    Functions relating to comparison of models
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
models has a value which is a reference to a list where each element is a fbamodel_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
models has a value which is a reference to a list where each element is a fbamodel_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string


=end text

=back



=head2 ModelComparisonModel

=over 4



=item Description

Data structure to hold model comparison data

        fbamodel_id model - id of the fba model
        workspace_id workspace - id of workspace with model
        string model_name - name of the fba model
        genome_id genome - id of the genome for the fba model
        string genome_name - name of the genome for the fba model
        int core_reactions - number of core reactions in the fba model
        int unique_reactions - number of unique reactions in the fba model


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
model_name has a value which is a string
genome has a value which is a genome_id
genome_name has a value which is a string
gapfilled_reactions has a value which is an int
core_reactions has a value which is an int
noncore_reactions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
model_name has a value which is a string
genome has a value which is a genome_id
genome_name has a value which is a string
gapfilled_reactions has a value which is an int
core_reactions has a value which is an int
noncore_reactions has a value which is an int


=end text

=back



=head2 ModelCompareReaction

=over 4



=item Description

Data structure to hold model reaction comparison data

        reaction_id reaction - id of the reaction
        compartment_id compartment - id of the reaction compartment
        string equation - equation for the reaction
        bool core - boolean indicating if the reaction is core
        mapping<fbamodel_id,list<feature_id> > model_features - map of models and features for reaction
        string role - role associated with the reaction
        string subsytem - subsystem associated with role
        string primclass - class one of the subsystem
        string subclass - class two of the subsystem
        int number_models - number of models with reaction
        float fraction_models - fraction of models with reaction


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reaction has a value which is a reaction_id
compartment has a value which is a string
equation has a value which is a string
core has a value which is a bool
model_features has a value which is a reference to a hash where the key is a fbamodel_id and the value is a reference to a list where each element is a feature_id
role has a value which is a string
subsystem has a value which is a string
primclass has a value which is a string
subclass has a value which is a string
number_models has a value which is an int
fraction_models has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reaction has a value which is a reaction_id
compartment has a value which is a string
equation has a value which is a string
core has a value which is a bool
model_features has a value which is a reference to a hash where the key is a fbamodel_id and the value is a reference to a list where each element is a feature_id
role has a value which is a string
subsystem has a value which is a string
primclass has a value which is a string
subclass has a value which is a string
number_models has a value which is an int
fraction_models has a value which is a float


=end text

=back



=head2 ModelComparisonData

=over 4



=item Description

Output structure for the "compare_models" function.

        list<ModelComparisonModel> model_comparisons;
        list<ModelCompareReaction> reaction_comparisons;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model_comparisons has a value which is a reference to a list where each element is a ModelComparisonModel
reaction_comparisons has a value which is a reference to a list where each element is a ModelCompareReaction
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model_comparisons has a value which is a reference to a list where each element is a ModelComparisonModel
reaction_comparisons has a value which is a reference to a list where each element is a ModelCompareReaction
auth has a value which is a string


=end text

=back



=head2 compare_genomes_params

=over 4



=item Description

********************************************************************************
    Functions relating to comparison of genomes
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genomes has a value which is a reference to a list where each element is a genome_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genomes has a value which is a reference to a list where each element is a genome_id
workspaces has a value which is a reference to a list where each element is a workspace_id
auth has a value which is a string


=end text

=back



=head2 GenomeComparisonGenome

=over 4



=item Description

Data structure to hold genome comparison data

        genome_id genome;
        workspace_id workspace;
        string genome_name;
        string taxonomy;
        int features;
        int core_functions;
        int noncore_functions;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
genome_name has a value which is a string
taxonomy has a value which is a string
features has a value which is an int
core_functions has a value which is an int
noncore_functions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
genome_name has a value which is a string
taxonomy has a value which is a string
features has a value which is an int
core_functions has a value which is an int
noncore_functions has a value which is an int


=end text

=back



=head2 GenomeCompareFunction

=over 4



=item Description

Data structure to hold model reaction comparison data

        string role
        bool core - boolean indicating if the function is core
        mapping<genome_id,list<feature_id> > genome_features
        string subsytem - subsystem associated with role
        string primclass - class one of the subsystem
        string subclass - class two of the subsystem
        int number_genomes - number of genomes with function
        float fraction_genomes - fraction of genomes with function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
core has a value which is a bool
genome_features has a value which is a reference to a hash where the key is a genome_id and the value is a reference to a list where each element is a feature_id
role has a value which is a string
subsystem has a value which is a string
primclass has a value which is a string
subclass has a value which is a string
number_genomes has a value which is an int
fraction_genomes has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
core has a value which is a bool
genome_features has a value which is a reference to a hash where the key is a genome_id and the value is a reference to a list where each element is a feature_id
role has a value which is a string
subsystem has a value which is a string
primclass has a value which is a string
subclass has a value which is a string
number_genomes has a value which is an int
fraction_genomes has a value which is a float


=end text

=back



=head2 GenomeComparisonData

=over 4



=item Description

Output structure for the "compare_genomes" function.

        list<GenomeComparisonGenome> genome_comparisons;
        list<GenomeCompareFunction> function_comparisons;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome_comparisons has a value which is a reference to a list where each element is a GenomeComparisonGenome
function_comparisons has a value which is a reference to a list where each element is a GenomeCompareFunction
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome_comparisons has a value which is a reference to a list where each element is a GenomeComparisonGenome
function_comparisons has a value which is a reference to a list where each element is a GenomeCompareFunction
auth has a value which is a string


=end text

=back



=head2 MetagenomeAnnotationOTUFunction

=over 4



=item Description

********************************************************************************
    Functions relating to construction of community models
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbid has a value which is a string
reference_genes has a value which is a reference to a list where each element is a string
functional_role has a value which is a string
abundance has a value which is an int
confidence has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbid has a value which is a string
reference_genes has a value which is a reference to a list where each element is a string
functional_role has a value which is a string
abundance has a value which is an int
confidence has a value which is a float


=end text

=back



=head2 MetagenomeAnnotationOTU

=over 4



=item Description

Structure for the "MetagenomeAnnotationOTU" object

        string name - name of metagenome OTU
        string kbid - KBase ID of OTU of metagenome object
        string source_id - ID used for OTU in metagenome source
        string source - source OTU ID
        list<MetagenomeAnnotationOTUFunction> functions - list of functions in OTU


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ave_confidence has a value which is a float
ave_coverage has a value which is a float
kbid has a value which is a string
name has a value which is a string
source_id has a value which is a string
source has a value which is a string
functions has a value which is a reference to a list where each element is a MetagenomeAnnotationOTUFunction

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ave_confidence has a value which is a float
ave_coverage has a value which is a float
kbid has a value which is a string
name has a value which is a string
source_id has a value which is a string
source has a value which is a string
functions has a value which is a reference to a list where each element is a MetagenomeAnnotationOTUFunction


=end text

=back



=head2 MetagenomeAnnotation

=over 4



=item Description

Structure for the "MetagenomeAnnotation" object

        string type - type of metagenome object
        string name - name of metagenome object
        string kbid - KBase ID of metagenome object
        string source_id - ID used in metagenome source
        string source - source of metagenome data
        string confidence_type - type of confidence score
        list<MetagenomeAnnotationOTU> otus - list of otus in metagenome


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
type has a value which is a string
name has a value which is a string
kbid has a value which is a string
source_id has a value which is a string
source has a value which is a string
confidence_type has a value which is a string
otus has a value which is a reference to a list where each element is a MetagenomeAnnotationOTU

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
type has a value which is a string
name has a value which is a string
kbid has a value which is a string
source_id has a value which is a string
source has a value which is a string
confidence_type has a value which is a string
otus has a value which is a reference to a list where each element is a MetagenomeAnnotationOTU


=end text

=back



=head2 import_metagenome_annotation_params

=over 4



=item Description

Input parameters for the "import_metagenome_annotation" function.

        string metaanno_uid - ID to save metagenome in workspace
        workspace_id workspace - ID of workspace for metagenome object
        string source_id - ID used in metagenome data source
        string source - metagenome data source
        string type - type of metagenome
        string confidence_type - type of confidence score
        string name - name of metagenome
        list<tuple<list<string> genes,string functional_role,string otu,int abundance,float confidence,string confidence_type>> annotations;
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
metaanno_uid has a value which is a string
workspace has a value which is a workspace_id
source_id has a value which is a string
source has a value which is a string
type has a value which is a string
confidence_type has a value which is a string
name has a value which is a string
annotations has a value which is a reference to a list where each element is a reference to a list containing 5 items:
0: (genes) a reference to a list where each element is a string
1: (functional_role) a string
2: (otu) a string
3: (abundance) an int
4: (confidence) a float

auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
metaanno_uid has a value which is a string
workspace has a value which is a workspace_id
source_id has a value which is a string
source has a value which is a string
type has a value which is a string
confidence_type has a value which is a string
name has a value which is a string
annotations has a value which is a reference to a list where each element is a reference to a list containing 5 items:
0: (genes) a reference to a list where each element is a string
1: (functional_role) a string
2: (otu) a string
3: (abundance) an int
4: (confidence) a float

auth has a value which is a string


=end text

=back



=head2 models_to_community_model_params

=over 4



=item Description

Input parameters for the "models_to_community_model" function.

        string model_uid - ID of community model
        workspace_id workspace - workspace where community model should be saved
        string name - name of community model
        list<tuple<string model_uid,string model_ws,float abundance>> models - models to be merged into community model
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model_uid has a value which is a string
workspace has a value which is a workspace_id
name has a value which is a string
models has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (model_uid) a string
1: (model_ws) a string
2: (abundance) a float

auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model_uid has a value which is a string
workspace has a value which is a workspace_id
name has a value which is a string
models has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (model_uid) a string
1: (model_ws) a string
2: (abundance) a float

auth has a value which is a string


=end text

=back



=head2 metagenome_to_fbamodels_params

=over 4



=item Description

Input parameters for the "metagenome_to_fbamodel" function.

        string model_uid - ID of community model
        workspace_id workspace - workspace where community model should be saved
        string name - name of community model
        list<tuple<string model_uid,workspace_id model_ws,float abundance>> models - models to be merged into community model
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model_uids has a value which is a reference to a hash where the key is a string and the value is a string
workspace has a value which is a workspace_id
metaanno_uid has a value which is a string
metaanno_ws has a value which is a workspace_id
min_abundance has a value which is a float
confidence_threshold has a value which is a float
max_otu_models has a value which is an int
min_reactions has a value which is an int
templates has a value which is a reference to a hash where the key is a string and the value is a reference to a list containing 2 items:
0: (template_ws) a workspace_id
1: (template_uid) a template_id

auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model_uids has a value which is a reference to a hash where the key is a string and the value is a string
workspace has a value which is a workspace_id
metaanno_uid has a value which is a string
metaanno_ws has a value which is a workspace_id
min_abundance has a value which is a float
confidence_threshold has a value which is a float
max_otu_models has a value which is an int
min_reactions has a value which is an int
templates has a value which is a reference to a hash where the key is a string and the value is a reference to a list containing 2 items:
0: (template_ws) a workspace_id
1: (template_uid) a template_id

auth has a value which is a string


=end text

=back



=cut

package Bio::KBase::fbaModelServices::Client::RpcClient;
use base 'JSON::RPC::Client';

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $obj) = @_;
    my $result;

    if ($uri =~ /\?/) {
       $result = $self->_get($uri);
    }
    else {
        Carp::croak "not hashref." unless (ref $obj eq 'HASH');
        $result = $self->_post($uri, $obj);
    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;
