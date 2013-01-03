package Bio::KBase::fbaModelServices::Client;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

Bio::KBase::fbaModelServices::Client

=head1 DESCRIPTION





=cut

sub new
{
    my($class, $url, @args) = @_;

    my $self = {
	client => Bio::KBase::fbaModelServices::Client::RpcClient->new,
	url => $url,
    };


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
	0: a modelcompound_id
	1: a float
	2: a string
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
	features has a value which is a reference to a list where each element is a feature_id
	compartment has a value which is a modelcompartment_id
modelreaction_id is a string
reaction_id is a string
feature_id is a string
ModelCompound is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	compound has a value which is a compound_id
	name has a value which is a string
	compartment has a value which is a modelcompartment_id
compound_id is a string
FBAMeta is a reference to a list containing 6 items:
	0: a fba_id
	1: a workspace_id
	2: a media_id
	3: a workspace_id
	4: a float
	5: a reference to a list where each element is a feature_id
fba_id is a string
media_id is a string
GapFillMeta is a reference to a list containing 6 items:
	0: a gapfill_id
	1: a workspace_id
	2: a media_id
	3: a workspace_id
	4: a bool
	5: a reference to a list where each element is a feature_id
gapfill_id is a string
bool is an int
GapGenMeta is a reference to a list containing 6 items:
	0: a gapgen_id
	1: a workspace_id
	2: a media_id
	3: a workspace_id
	4: a bool
	5: a reference to a list where each element is a feature_id
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
	0: a modelcompound_id
	1: a float
	2: a string
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
	features has a value which is a reference to a list where each element is a feature_id
	compartment has a value which is a modelcompartment_id
modelreaction_id is a string
reaction_id is a string
feature_id is a string
ModelCompound is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	compound has a value which is a compound_id
	name has a value which is a string
	compartment has a value which is a modelcompartment_id
compound_id is a string
FBAMeta is a reference to a list containing 6 items:
	0: a fba_id
	1: a workspace_id
	2: a media_id
	3: a workspace_id
	4: a float
	5: a reference to a list where each element is a feature_id
fba_id is a string
media_id is a string
GapFillMeta is a reference to a list containing 6 items:
	0: a gapfill_id
	1: a workspace_id
	2: a media_id
	3: a workspace_id
	4: a bool
	5: a reference to a list where each element is a feature_id
gapfill_id is a string
bool is an int
GapGenMeta is a reference to a list containing 6 items:
	0: a gapgen_id
	1: a workspace_id
	2: a media_id
	3: a workspace_id
	4: a bool
	5: a reference to a list where each element is a feature_id
gapgen_id is a string


=end text

=item Description

Returns model data for input ids

=back

=cut

sub get_models
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_models',
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
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
MinimalMediaPrediction is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a compound_id
	essentialNutrients has a value which is a reference to a list where each element is a compound_id
MetaboliteProduction is a reference to a list containing 3 items:
	0: a float
	1: a modelcompound_id
	2: a string
modelcompound_id is a string
ReactionFlux is a reference to a list containing 8 items:
	0: a modelreaction_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
	7: a string
modelreaction_id is a string
CompoundFlux is a reference to a list containing 8 items:
	0: a modelcompound_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
	7: a string
GeneAssertion is a reference to a list containing 4 items:
	0: a feature_id
	1: a float
	2: a float
	3: a bool

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
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
MinimalMediaPrediction is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a compound_id
	essentialNutrients has a value which is a reference to a list where each element is a compound_id
MetaboliteProduction is a reference to a list containing 3 items:
	0: a float
	1: a modelcompound_id
	2: a string
modelcompound_id is a string
ReactionFlux is a reference to a list containing 8 items:
	0: a modelreaction_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
	7: a string
modelreaction_id is a string
CompoundFlux is a reference to a list containing 8 items:
	0: a modelcompound_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
	7: a string
GeneAssertion is a reference to a list containing 4 items:
	0: a feature_id
	1: a float
	2: a float
	3: a bool


=end text

=item Description

Returns data for the requested flux balance analysis formulations

=back

=cut

sub get_fbas
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_fbas',
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
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
compartment_id is a string
probanno_id is a string
GapFillSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapfillsolution_id
	objective has a value which is a float
	biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
	mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
gapfillsolution_id is a string
biomassRemoval is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
mediaAddition is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
reactionAddition is a reference to a list containing 5 items:
	0: a reaction_id
	1: a string
	2: a string
	3: a string
	4: a string

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
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
compartment_id is a string
probanno_id is a string
GapFillSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapfillsolution_id
	objective has a value which is a float
	biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
	mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
gapfillsolution_id is a string
biomassRemoval is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
mediaAddition is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
reactionAddition is a reference to a list containing 5 items:
	0: a reaction_id
	1: a string
	2: a string
	3: a string
	4: a string


=end text

=item Description

Returns data for the requested gap filling simulations

=back

=cut

sub get_gapfills
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_gapfills',
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
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
GapgenSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapgensolution_id
	objective has a value which is a float
	biomassAdditions has a value which is a reference to a list where each element is a biomassAddition
	mediaRemovals has a value which is a reference to a list where each element is a mediaRemoval
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
gapgensolution_id is a string
biomassAddition is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
mediaRemoval is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
reactionRemoval is a reference to a list containing 4 items:
	0: a modelreaction_id
	1: a string
	2: a string
	3: a string
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
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
GapgenSolution is a reference to a hash where the following keys are defined:
	id has a value which is a gapgensolution_id
	objective has a value which is a float
	biomassAdditions has a value which is a reference to a list where each element is a biomassAddition
	mediaRemovals has a value which is a reference to a list where each element is a mediaRemoval
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
gapgensolution_id is a string
biomassAddition is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
mediaRemoval is a reference to a list containing 2 items:
	0: a compound_id
	1: a string
reactionRemoval is a reference to a list containing 4 items:
	0: a modelreaction_id
	1: a string
	2: a string
	3: a string
modelreaction_id is a string


=end text

=item Description

Returns data for the requested gap generation simulations

=back

=cut

sub get_gapgens
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_gapgens',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_reactions',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_compounds',
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
	compounds has a value which is a reference to a list where each element is a compound_id
	concentrations has a value which is a reference to a list where each element is a float
	pH has a value which is a float
	temperature has a value which is a float
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
	compounds has a value which is a reference to a list where each element is a compound_id
	concentrations has a value which is a reference to a list where each element is a float
	pH has a value which is a float
	temperature has a value which is a float
compound_id is a string


=end text

=item Description

Returns data for the requested media formulations

=back

=cut

sub get_media
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_media',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'get_biochemistry',
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



=head2 genome_object_to_workspace

  $genomeMeta = $obj->genome_object_to_workspace($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_object_to_workspace_params
$genomeMeta is an object_metadata
genome_object_to_workspace_params is a reference to a hash where the following keys are defined:
	genomeobj has a value which is a genomeTO
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
	genomeobj has a value which is a genomeTO
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'genome_object_to_workspace',
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
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'genome_to_workspace',
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
	0: a string
	1: a feature_id
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
	0: a string
	1: a feature_id
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'add_feature_translation',
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
	probanno has a value which is a probanno_id
	probanno_workspace has a value which is a workspace_id
	probannoThreshold has a value which is a float
	probanno_only has a value which is a bool
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
probanno_id is a string
bool is an int
fbamodel_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
	probanno has a value which is a probanno_id
	probanno_workspace has a value which is a workspace_id
	probannoThreshold has a value which is a float
	probanno_only has a value which is a bool
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
probanno_id is a string
bool is an int
fbamodel_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

This function accepts a genome_to_fbamodel_params as input, building a new FBAModel for the genome specified by genome_id.
The function returns a genome_to_fbamodel_params as output, specifying the ID of the model generated in the model_id parameter.

=back

=cut

sub genome_to_fbamodel
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'genome_to_fbamodel',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'export_fbamodel',
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
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'addmedia',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'export_media',
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
fba_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
fba_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'runfba',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'export_fba',
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
	phenotypeSet has a value which is a phenotypeSet_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	phenotypes has a value which is a reference to a list where each element is a Phenotype
	ignore_errors has a value which is a bool
	auth has a value which is a string
phenotypeSet_id is a string
workspace_id is a string
genome_id is a string
Phenotype is a reference to a list containing 5 items:
	0: a reference to a list where each element is a feature_id
	1: a media_id
	2: a workspace_id
	3: a reference to a list where each element is a compound_id
	4: a float
feature_id is a string
media_id is a string
compound_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
	phenotypeSet has a value which is a phenotypeSet_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	phenotypes has a value which is a reference to a list where each element is a Phenotype
	ignore_errors has a value which is a bool
	auth has a value which is a string
phenotypeSet_id is a string
workspace_id is a string
genome_id is a string
Phenotype is a reference to a list containing 5 items:
	0: a reference to a list where each element is a feature_id
	1: a media_id
	2: a workspace_id
	3: a reference to a list where each element is a compound_id
	4: a float
feature_id is a string
media_id is a string
compound_id is a string
bool is an int
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'import_phenotypes',
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
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
	workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
phenotypeSet_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
phenotypeSimulationSet_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
	workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
phenotypeSet_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
phenotypeSimulationSet_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'simulate_phenotypes',
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'export_phenotypeSimulationSet',
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
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
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

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'integrate_reconciliation_solutions',
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

  $output = $obj->queue_runfba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a queue_runfba_params
$output is an object_metadata
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
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
fba_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a queue_runfba_params
$output is an object_metadata
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
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
fba_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues an FBA job in a single media condition

=back

=cut

sub queue_runfba
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'queue_runfba',
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

  $output = $obj->queue_gapfill_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapfill_model_params
$output is an object_metadata
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
	gapFill_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
compartment_id is a string
probanno_id is a string
phenotypeSet_id is a string
gapfill_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a gapfill_model_params
$output is an object_metadata
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
	gapFill_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
compartment_id is a string
probanno_id is a string
phenotypeSet_id is a string
gapfill_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues an FBAModel gapfilling job in single media condition

=back

=cut

sub queue_gapfill_model
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'queue_gapfill_model',
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



=head2 queue_gapgen_model

  $output = $obj->queue_gapgen_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapgen_model_params
$output is an object_metadata
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
	gapGen_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
phenotypeSet_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a gapgen_model_params
$output is an object_metadata
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
	gapGen_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
phenotypeSet_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues an FBAModel gapfilling job in single media condition

=back

=cut

sub queue_gapgen_model
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'queue_gapgen_model',
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



=head2 queue_wildtype_phenotype_reconciliation

  $output = $obj->queue_wildtype_phenotype_reconciliation($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a wildtype_phenotype_reconciliation_params
$output is an object_metadata
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	gapFill_workspace has a value which is a workspace_id
	gapGen_workspace has a value which is a workspace_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
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
phenotypeSet_id is a string
gapfill_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a wildtype_phenotype_reconciliation_params
$output is an object_metadata
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	gapFill_workspace has a value which is a workspace_id
	gapGen_workspace has a value which is a workspace_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
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
phenotypeSet_id is a string
gapfill_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_wildtype_phenotype_reconciliation
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'queue_wildtype_phenotype_reconciliation',
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

  $output = $obj->queue_reconciliation_sensitivity_analysis($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a wildtype_phenotype_reconciliation_params
$output is an object_metadata
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	gapFill_workspace has a value which is a workspace_id
	gapGen_workspace has a value which is a workspace_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
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
phenotypeSet_id is a string
gapfill_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a wildtype_phenotype_reconciliation_params
$output is an object_metadata
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	gapFill_workspace has a value which is a workspace_id
	gapGen_workspace has a value which is a workspace_id
	queueSensitivityAnalysis has a value which is a bool
	queueReconciliationCombination has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
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
phenotypeSet_id is a string
gapfill_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_reconciliation_sensitivity_analysis
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'queue_reconciliation_sensitivity_analysis',
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



=head2 queue_combine_wildtype_phenotype_reconciliation_params

  $output = $obj->queue_combine_wildtype_phenotype_reconciliation_params($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a combine_wildtype_phenotype_reconciliation_params
$output is an object_metadata
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	gapFill_workspace has a value which is a workspace_id
	gapGen_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
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
phenotypeSet_id is a string
gapfill_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a combine_wildtype_phenotype_reconciliation_params
$output is an object_metadata
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	gapFill_workspace has a value which is a workspace_id
	gapGen_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	additionalcpds has a value which is a reference to a list where each element is a compound_id
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
bool is an int
term is a reference to a list containing 3 items:
	0: a float
	1: a string
	2: a string
feature_id is a string
reaction_id is a string
bound is a reference to a list containing 4 items:
	0: a float
	1: a float
	2: a string
	3: a string
constraint is a reference to a list containing 4 items:
	0: a float
	1: a string
	2: a reference to a list where each element is a term
	3: a string
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
phenotypeSet_id is a string
gapfill_id is a string
gapgen_id is a string
object_metadata is a reference to a list containing 9 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_combine_wildtype_phenotype_reconciliation_params
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_combine_wildtype_phenotype_reconciliation_params (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_combine_wildtype_phenotype_reconciliation_params:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_combine_wildtype_phenotype_reconciliation_params');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.queue_combine_wildtype_phenotype_reconciliation_params",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'queue_combine_wildtype_phenotype_reconciliation_params',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_combine_wildtype_phenotype_reconciliation_params",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_combine_wildtype_phenotype_reconciliation_params',
				       );
    }
}



=head2 jobs_done

  $output = $obj->jobs_done($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a jobs_done_params
$output is a JobObject
jobs_done_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a job_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	workspace has a value which is a workspace_id
	clusterjobs has a value which is a reference to a list where each element is a clusterjob
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
	queuing_command has a value which is a string
	clustermem has a value which is a float
	clustertime has a value which is an int
	clustertoken has a value which is a string
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	owner has a value which is a string
clusterjob is a reference to a hash where the following keys are defined:
	auth has a value which is a string
CommandArguments is a reference to a hash where the following keys are defined:
	auth has a value which is a string
bool is an int

</pre>

=end html

=begin text

$input is a jobs_done_params
$output is a JobObject
jobs_done_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a job_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	workspace has a value which is a workspace_id
	clusterjobs has a value which is a reference to a list where each element is a clusterjob
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
	queuing_command has a value which is a string
	clustermem has a value which is a float
	clustertime has a value which is an int
	clustertoken has a value which is a string
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	owner has a value which is a string
clusterjob is a reference to a hash where the following keys are defined:
	auth has a value which is a string
CommandArguments is a reference to a hash where the following keys are defined:
	auth has a value which is a string
bool is an int


=end text

=item Description

Mark specified job as complete and run postprocessing

=back

=cut

sub jobs_done
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function jobs_done (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to jobs_done:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'jobs_done');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.jobs_done",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'jobs_done',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method jobs_done",
					    status_line => $self->{client}->status_line,
					    method_name => 'jobs_done',
				       );
    }
}



=head2 check_job

  $output = $obj->check_job($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a check_job_params
$output is a JobObject
check_job_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a job_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	workspace has a value which is a workspace_id
	clusterjobs has a value which is a reference to a list where each element is a clusterjob
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
	queuing_command has a value which is a string
	clustermem has a value which is a float
	clustertime has a value which is an int
	clustertoken has a value which is a string
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	owner has a value which is a string
clusterjob is a reference to a hash where the following keys are defined:
	auth has a value which is a string
CommandArguments is a reference to a hash where the following keys are defined:
	auth has a value which is a string
bool is an int

</pre>

=end html

=begin text

$input is a check_job_params
$output is a JobObject
check_job_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a job_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	workspace has a value which is a workspace_id
	clusterjobs has a value which is a reference to a list where each element is a clusterjob
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
	queuing_command has a value which is a string
	clustermem has a value which is a float
	clustertime has a value which is an int
	clustertoken has a value which is a string
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	owner has a value which is a string
clusterjob is a reference to a hash where the following keys are defined:
	auth has a value which is a string
CommandArguments is a reference to a hash where the following keys are defined:
	auth has a value which is a string
bool is an int


=end text

=item Description

Retreives job data given a job ID

=back

=cut

sub check_job
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function check_job (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to check_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'check_job');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.check_job",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'check_job',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method check_job",
					    status_line => $self->{client}->status_line,
					    method_name => 'check_job',
				       );
    }
}



=head2 run_job

  $output = $obj->run_job($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a run_job_params
$output is a JobObject
run_job_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a job_id
	workspace has a value which is a workspace_id
	index has a value which is an int
	auth has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	workspace has a value which is a workspace_id
	clusterjobs has a value which is a reference to a list where each element is a clusterjob
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
	queuing_command has a value which is a string
	clustermem has a value which is a float
	clustertime has a value which is an int
	clustertoken has a value which is a string
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	owner has a value which is a string
clusterjob is a reference to a hash where the following keys are defined:
	auth has a value which is a string
CommandArguments is a reference to a hash where the following keys are defined:
	auth has a value which is a string
bool is an int

</pre>

=end html

=begin text

$input is a run_job_params
$output is a JobObject
run_job_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a job_id
	workspace has a value which is a workspace_id
	index has a value which is an int
	auth has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	workspace has a value which is a workspace_id
	clusterjobs has a value which is a reference to a list where each element is a clusterjob
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
	queuing_command has a value which is a string
	clustermem has a value which is a float
	clustertime has a value which is an int
	clustertoken has a value which is a string
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	owner has a value which is a string
clusterjob is a reference to a hash where the following keys are defined:
	auth has a value which is a string
CommandArguments is a reference to a hash where the following keys are defined:
	auth has a value which is a string
bool is an int


=end text

=item Description

Runs specified job

=back

=cut

sub run_job
{
    my($self, @args) = @_;

# Authentication: none

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
					       code => $result->content->{code},
					       method_name => 'run_job',
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
                method_name => 'run_job',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method run_job",
            status_line => $self->{client}->status_line,
            method_name => 'run_job',
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



=head2 phenotypeSet_id

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



=head2 object_metadata

=over 4



=item Description

********************************************************************************
    Object type definition
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a list containing 9 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a string
5: a username
6: a username
7: a workspace_id
8: a workspace_ref

</pre>

=end html

=begin text

a reference to a list containing 9 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a string
5: a username
6: a username
7: a workspace_id
8: a workspace_ref


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
1: an int
2: a string
3: an int

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a contig_id
1: an int
2: a string
3: an int


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
0: a string
1: a string
2: an int

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a string
1: a string
2: an int


=end text

=back



=head2 gene_hit

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a feature_id
1: a float

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a feature_id
1: a float


=end text

=back



=head2 alt_func

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: a string
1: a float
2: a reference to a list where each element is a gene_hit

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a string
1: a float
2: a reference to a list where each element is a gene_hit


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



=head2 Media

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a media_id
name has a value which is a string
compounds has a value which is a reference to a list where each element is a compound_id
concentrations has a value which is a reference to a list where each element is a float
pH has a value which is a float
temperature has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a media_id
name has a value which is a string
compounds has a value which is a reference to a list where each element is a compound_id
concentrations has a value which is a reference to a list where each element is a float
pH has a value which is a float
temperature has a value which is a float


=end text

=back



=head2 Compound

=over 4



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
features has a value which is a reference to a list where each element is a feature_id
compartment has a value which is a modelcompartment_id


=end text

=back



=head2 BiomassCompound

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: a modelcompound_id
1: a float
2: a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a modelcompound_id
1: a float
2: a string


=end text

=back



=head2 ModelBiomass

=over 4



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



=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: a fba_id
1: a workspace_id
2: a media_id
3: a workspace_id
4: a float
5: a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: a fba_id
1: a workspace_id
2: a media_id
3: a workspace_id
4: a float
5: a reference to a list where each element is a feature_id


=end text

=back



=head2 GapGenMeta

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: a gapgen_id
1: a workspace_id
2: a media_id
3: a workspace_id
4: a bool
5: a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: a gapgen_id
1: a workspace_id
2: a media_id
3: a workspace_id
4: a bool
5: a reference to a list where each element is a feature_id


=end text

=back



=head2 GapFillMeta

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: a gapfill_id
1: a workspace_id
2: a media_id
3: a workspace_id
4: a bool
5: a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: a gapfill_id
1: a workspace_id
2: a media_id
3: a workspace_id
4: a bool
5: a reference to a list where each element is a feature_id


=end text

=back



=head2 FBAModel

=over 4



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
0: a feature_id
1: a float
2: a float
3: a bool

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a feature_id
1: a float
2: a float
3: a bool


=end text

=back



=head2 CompoundFlux

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 8 items:
0: a modelcompound_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string
7: a string

</pre>

=end html

=begin text

a reference to a list containing 8 items:
0: a modelcompound_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string
7: a string


=end text

=back



=head2 ReactionFlux

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 8 items:
0: a modelreaction_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string
7: a string

</pre>

=end html

=begin text

a reference to a list containing 8 items:
0: a modelreaction_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string
7: a string


=end text

=back



=head2 MetaboliteProduction

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: a float
1: a modelcompound_id
2: a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a float
1: a modelcompound_id
2: a string


=end text

=back



=head2 compound_id

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



=head2 MinimalMediaPrediction

=over 4



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



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: a float
1: a float
2: a string
3: a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a float
1: a float
2: a string
3: a string


=end text

=back



=head2 term

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: a float
1: a string
2: a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a float
1: a string
2: a string


=end text

=back



=head2 constraint

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: a float
1: a string
2: a reference to a list where each element is a term
3: a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a float
1: a string
2: a reference to a list where each element is a term
3: a string


=end text

=back



=head2 FBAFormulation

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
additionalcpds has a value which is a reference to a list where each element is a compound_id
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



=item Definition

=begin html

<pre>
a reference to a list containing 5 items:
0: a reaction_id
1: a string
2: a string
3: a string
4: a string

</pre>

=end html

=begin text

a reference to a list containing 5 items:
0: a reaction_id
1: a string
2: a string
3: a string
4: a string


=end text

=back



=head2 biomassRemoval

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a compound_id
1: a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a compound_id
1: a string


=end text

=back



=head2 mediaAddition

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a compound_id
1: a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a compound_id
1: a string


=end text

=back



=head2 GapFillSolution

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapfillsolution_id
objective has a value which is a float
biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapfillsolution_id
objective has a value which is a float
biomassRemovals has a value which is a reference to a list where each element is a biomassRemoval
mediaAdditions has a value which is a reference to a list where each element is a mediaAddition
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition


=end text

=back



=head2 GapFill

=over 4



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



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: a modelreaction_id
1: a string
2: a string
3: a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a modelreaction_id
1: a string
2: a string
3: a string


=end text

=back



=head2 biomassAddition

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a compound_id
1: a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a compound_id
1: a string


=end text

=back



=head2 mediaRemoval

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a compound_id
1: a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a compound_id
1: a string


=end text

=back



=head2 GapgenSolution

=over 4



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



=head2 get_media_params

=over 4



=item Description

This function returns media data for input ids


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



=head2 workspace_id

=over 4



=item Description

********************************************************************************
    Code relating to reconstruction of metabolic models
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



=head2 genomeTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a genome_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a genome_id


=end text

=back



=head2 genome_object_to_workspace_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genomeobj has a value which is a genomeTO
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genomeobj has a value which is a genomeTO
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 genome_to_workspace_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 translation

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a string
1: a feature_id

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a string
1: a feature_id


=end text

=back



=head2 add_feature_translation_params

=over 4



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

A set of paramters for the genome_to_fbamodel method. This is a mapping
where the keys in the map are named 'in_genome', 'in_workspace', 'out_model',
and 'out_workspace'. Values for each are described below.
    
genome_id in_genome
This parameter specifies the ID of the genome for which a model is to be built. This parameter is required.
    
workspace_id in_workspace
This parameter specifies the ID of the workspace containing the specified genome object. This parameter is also required.
    
fbamodel_id out_model
This parameter specifies the ID to which the generated model should be save. This is optional.
If unspecified, a new KBase model ID will be checked out for the model.
    
workspace_id out_workspace
This parameter specifies the ID of the workspace where the model should be save. This is optional.
If unspecified, this parameter will be set to the value of "in_workspace".


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
probanno has a value which is a probanno_id
probanno_workspace has a value which is a workspace_id
probannoThreshold has a value which is a float
probanno_only has a value which is a bool
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
probanno has a value which is a probanno_id
probanno_workspace has a value which is a workspace_id
probannoThreshold has a value which is a float
probanno_only has a value which is a bool
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 export_fbamodel_params

=over 4



=item Description

NEED DOCUMENTATION


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

NEED DOCUMENTATION


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



=head2 Phenotype

=over 4



=item Description

********************************************************************************
    Code relating to phenotype simulation and reconciliation
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a list containing 5 items:
0: a reference to a list where each element is a feature_id
1: a media_id
2: a workspace_id
3: a reference to a list where each element is a compound_id
4: a float

</pre>

=end html

=begin text

a reference to a list containing 5 items:
0: a reference to a list where each element is a feature_id
1: a media_id
2: a workspace_id
3: a reference to a list where each element is a compound_id
4: a float


=end text

=back



=head2 PhenotypeSet

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
importErrors has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
importErrors has a value which is a string


=end text

=back



=head2 phenotypeSimulationSet_id

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



=head2 PhenotypeSimulation

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: a Phenotype
1: a float
2: a float
3: a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a Phenotype
1: a float
2: a float
3: a string


=end text

=back



=head2 PhenotypeSimulationSet

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSimulationSet_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSimulations has a value which is a reference to a list where each element is a PhenotypeSimulation

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSimulationSet_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSimulations has a value which is a reference to a list where each element is a PhenotypeSimulation


=end text

=back



=head2 import_phenotypes_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotypeSet_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
ignore_errors has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotypeSet has a value which is a phenotypeSet_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
ignore_errors has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 simulate_phenotypes_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
notes has a value which is a string
phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
notes has a value which is a string
phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
overwrite has a value which is a bool
auth has a value which is a string


=end text

=back



=head2 export_phenotypeSimulationSet_params

=over 4



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



=head2 job_id

=over 4



=item Description

********************************************************************************
    Code relating to queuing long running jobs
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



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a job_id
workspace has a value which is a workspace_id
clusterjobs has a value which is a reference to a list where each element is a clusterjob
postprocess_command has a value which is a string
postprocess_args has a value which is a reference to a list where each element is a CommandArguments
queuing_command has a value which is a string
clustermem has a value which is a float
clustertime has a value which is an int
clustertoken has a value which is a string
queuetime has a value which is a string
completetime has a value which is a string
complete has a value which is a bool
owner has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a job_id
workspace has a value which is a workspace_id
clusterjobs has a value which is a reference to a list where each element is a clusterjob
postprocess_command has a value which is a string
postprocess_args has a value which is a reference to a list where each element is a CommandArguments
queuing_command has a value which is a string
clustermem has a value which is a float
clustertime has a value which is an int
clustertoken has a value which is a string
queuetime has a value which is a string
completetime has a value which is a string
complete has a value which is a bool
owner has a value which is a string


=end text

=back



=head2 queue_runfba_params

=over 4



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
donot_submit_job has a value which is a bool

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
donot_submit_job has a value which is a bool


=end text

=back



=head2 gapfill_model_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapfillingFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFill has a value which is a gapfill_id
gapFill_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapfillingFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFill has a value which is a gapfill_id
gapFill_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 gapgen_model_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapGen has a value which is a gapgen_id
gapGen_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapGen has a value which is a gapgen_id
gapGen_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 wildtype_phenotype_reconciliation_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
gapGen_workspace has a value which is a workspace_id
queueSensitivityAnalysis has a value which is a bool
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
gapGen_workspace has a value which is a workspace_id
queueSensitivityAnalysis has a value which is a bool
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 queue_reconciliation_sensitivity_analysis_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
gapGen_workspace has a value which is a workspace_id
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
gapGen_workspace has a value which is a workspace_id
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 combine_wildtype_phenotype_reconciliation_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
gapGen_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
fba_formulation has a value which is an FBAFormulation
gapfill_formulation has a value which is a GapfillingFormulation
gapgen_formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
gapGen_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 job_id

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



=head2 jobs_done_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 check_job_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 run_job_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
workspace has a value which is a workspace_id
index has a value which is an int
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
workspace has a value which is a workspace_id
index has a value which is an int
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
        $obj->{id} = $self->id if (defined $self->id);
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
