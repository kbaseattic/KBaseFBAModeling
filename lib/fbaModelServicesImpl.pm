package fbaModelServicesImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

fbaModelServices

=head1 DESCRIPTION



=cut

#BEGIN_HEADER
use URI;
use ModelSEED::Database::MongoDBSimple;
use Bio::KBase::IDServer::Client;
use Bio::KBase::CDMI::CDMIClient;
use ModelSEED::Auth::Basic;
use ModelSEED::Store;
use Data::UUID;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Utilities::GlobalFunctions;
use ModelSEED::MS::Factories::ExchangeFormatFactory;
use ModelSEED::MS::GapfillingFormulation;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::FBAProblem;
use ModelSEED::MS::Metadata::Definitions;
use Config::Simple;
use Try::Tiny;
use Data::Dumper;

=head2 loadObject

  $output_object = $obj->loadObject($input_data,$type)

=over 4

=item Parameter and return types

=begin html

<pre>

$input_data is a JSON object formulation
$type is the type of the object
$output_object is a ModelSEED::MS::$type object

</pre>

=end html

=begin text

$input_data is a JSON object formulation
$type is the type of the object
$output_object is a ModelSEED::MS::$type object

=end text

=item Description

This function converts the input data into a ModelSEED::MS::$type object.

=back

=cut

sub loadObject {
	my $self = shift;
    my($input_data) = @_;
   	
   	my @_bad_arguments;
    (ref($input_data) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input_data\" (value was \"$input_data\")");
    if (@_bad_arguments) {
		my $msg = "Invalid arguments passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
    }
    #Pulling the type form the input data hash
    if (!defined($input_data->{objectType})) {
    	my $msg = "Type must be specified before objects can be retreived.";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
    }
    my $type = $input_data->{objectType};
    my $output_object;
    #Checking if the input data is a provenance object and includes only an ID or UUID
    my $provenanceObjs = {Model=>1,Biochemistry=>1,Annotation=>1,Mapping=>1};
    if (defined($provenanceObjs->{$type}) &&  keys(%{$input_data}) <= 3) {
    	if (defined($input_data->{id})) {
    		$output_object = $self->{_store}->get_object(lc($type)."/kbase/".$input_data->{id});
    	} elsif (defined($input_data->{uuid})) {
    		$output_object = $self->{_store}->get_object(lc($type)."/".$input_data->{uuid});
    	} else {
    		my $msg = "Insufficient data provided to load model. Must provide either an id or uuid.";
    		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
    	}
    	if (!defined($output_object)) {
    		my $msg = "Could not generate object from input data.";
    		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
    	}
    	$output_object->parent($self->{_store});
    } else {
    	my $class = "ModelSEED::MS::".$type;
    	$output_object = $class->new($input_data);
    	if (!defined($output_object)) {
    		my $msg = "Could not generate object from input data.";
    		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
    	}
    	if (defined($provenanceObjs->{$type})) {
    		$output_object->parent($self->{_store});
    	} elsif (defined($provenanceObjs->{parentUUID})) {
    		my $objects = ModelSEED::MS::Metadata::Definitions::objectDefinitions();
    		my $parentType = $objects->{$type}->{parents}->[0];
    		my $parent = $self->loadObject({uuid => $provenanceObjs->{parentUUID},objectType => $parentType});
    		if (!defined($parent)) {
    			my $msg = "Could not find parent for input data object.";
    			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
    		}
    		$output_object->parent($parent);
    	}
	}
	if (!defined($output_object)) {
		my $msg = "Input ".$type." not valid.";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'loadObject');
	}
	return $output_object;
}

=head2 objectToOutput

  $output_data = $obj->objectToOutput($input_object)

=over 4

=item Parameter and return types

=begin html

<pre>

$input_object is a ModelSEED::MS::? object
$output_data is a perl data structure

</pre>

=end html

=begin text

$input_object is a ModelSEED::MS::? object
$output_data is a perl data structure

=end text

=item Description

This function converts the input data object into a serialized data structure ready for output to KBase.

=back

=cut

sub objectToOutput {
	my $self = shift;
    my($input_object) = @_;
    #Serializing the object
	my $output_data = $input_object->serializeToDB();
    $output_data->{objectType} = $input_object->_type();
	#Setting the parent uuid
	if (defined($input_object->parent())  && ref($input_object->parent()) ne "ModelSEED::Store" && defined($input_object->parent()->uuid())) {
    	$output_data->{parentUUID} = $input_object->parent()->uuid();
    }
	return $output_data;
}

sub _setContext {
	my ($self,$context,$params) = @_;
	$self->{_authentication} = $params->{authentication};
	$self->{_context} = $context;
}

sub _getContext {
	my ($self) = @_;
	return $self->{_context};
}

sub _clearContext {
	my ($self) = @_;
	delete $self->{_context};
}

sub _translate_genome_to_annotation {
	my $self = shift;
    my($genome,$mapping) = @_;
    #Creating the annotation from the input genome object
	my $size = 0;
	my $gc   = 0;
	for ( my $i = 0 ; $i < @{ $genome->{contigs} } ; $i++ ) {
		my $dna = $genome->{contigs}->[$i]->{dna};
		$size += length($dna);
		for ( my $j = 0 ; $j < length($dna) ; $j++ ) {
			if ( substr( $dna, $j, 1 ) =~ m/[gcGC]/ ) {
				$gc++;
			}
		}
	}
	$gc = $gc / $size;
	my $annotation = ModelSEED::MS::Annotation->new({
	  name         => $genome->{scientific_name},
	  mapping_uuid => "kbase/default",
	  mapping      => $mapping,
	  genomes      => [{
		 name => $genome->{scientific_name},
		 source   => "KBase",
		 id       => $genome->{id},
		 cksum    => "unknown",
		 class    => "unknown",
		 taxonomy => $genome->{domain},
		 etcType  => "unknown",
		 size     => $size,
		 gc       => $gc
	  }]
	});
	for ( my $i = 0 ; $i < @{ $genome->{features} } ; $i++ ) {
		my $ftr = $genome->{features}->[$i];
		my $newftr = $annotation->add("features",{
			 id          => $ftr->{id},
			 type        => $ftr->{type},
			 sequence    => $ftr->{protein_translation},
			 genome_uuid => $annotation->genomes()->[0]->uuid(),
			 start       => $ftr->{location}->[0]->[1],
			 stop        =>
			   ( $ftr->{location}->[0]->[1] + $ftr->{location}->[0]->[3] ),
			 contig    => $ftr->{location}->[0]->[0],
			 direction => $ftr->{location}->[0]->[2],
		});
		my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles(
			$ftr->{function}
		);
		if ( defined( $output->{roles} ) ) {
			for ( my $j = 0 ; $j < @{ $output->{roles} } ; $j++ ) {
				my $role = $mapping->queryObject( "roles",{
					name => $output->{roles}->[$j]
				});
				if ( !defined($role) ) {
					$role = $mapping->add( "roles",{
						name => $output->{roles}->[$j]
					});
				}
				$newftr->add("featureroles",{
					 role_uuid   => $role->uuid(),
					 compartment => $output->{compartments}->[0],
					 delimiter   => $output->{delimiter},
					 comment     => $output->{comment}
				});
			}
		}
	}
	return $annotation;
}

sub _cdmi {
	my $self = shift;
	if (!defined($self->{_cdmi})) {
		$self->{_cdmi} = Bio::KBase::CDMI::CDMIClient->new_for_script();
	}
    return $self->{_cdmi};
}

sub _idServer {
	my $self = shift;
	if (!defined($self->{_idserver})) {
		$self->{_idserver} = Bio::KBase::IDServer::Client->new('http://bio-data-1.mcs.anl.gov/services/idserver');
	}
    return $self->{_idserver};
}

sub _workspaceServices {
	my $self = shift;
	if (!defined($self->{_workspaceServices})) {
		$self->{_workspaceServices} = Bio::KBase::workspaceService->new();
	}
    return $self->{_workspaceServices};
}

sub _save_msobject {
	my($self,$obj,$type,$ws,$id,$command) = @_;
	my $data;
	if (ref($obj) eq "HASH") {
		$data = $obj;
	} else {
		$data = $obj->serializeToDB();
	}
	my $objmeta = $self->_workspaceServices()->save_object({
		id => $id,
		type => $type,
		data => $data,
		workspace => $ws,
		command => $command,
		authentication => $self->_authentication()
	});
	if (!defined($objmeta)) {
		my $msg = "Unable to save object:".$type."/".$ws."/".$id;
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_msobject');
	}
}

sub _get_msobject {
	my($self,$type,$ws,$id) = @_;
	my $output = $self->_workspaceServices()->get_object({
		id => $id,
		type => $type,
		workspace => $ws,
		authentication => $self->_authentication()
	});
	if (!defined($output->{data})) {
		my $msg = "Unable to retrieve object:".$type."/".$ws."/".$id;
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_msobject');
	}
	my $msProvTypes = {
		Biochemistry => 1,
		Model => 1,
		Annotation => 1,
		Mapping => 1
	};
	if (defined($msProvTypes->{$type})) {
		my $class = "ModelSEED::MS::".$type;
		my $obj = $class->new($output->{data});
		if ($type eq "Model") {
			my $linkid = $obj->annotation_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->annotation($self->_get_msobject("Annotation",$array->[0],$array->[1]));
			$obj->mapping($obj->annotation()->mapping());
			$obj->biochemistry($obj->mapping()->biochemistry());
		} elsif ($type eq "Annotation") {
			my $linkid = $obj->mapping_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->mapping($self->_get_msobject("Mapping",$array->[0],$array->[1]));
		} elsif ($type eq "Mapping") {
			my $linkid = $obj->biochemistry_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->biochemistry($self->_get_msobject("Biochemistry",$array->[0],$array->[1]));
		}
		return $obj;
	}
	return undef;
}

sub _get_genomeObj_from_CDM {
	my($self,$id,$asNew) = @_;
	my $cdmi = $self->_cdmi();
    my $data = $cdmi->genomes_to_genome_data([$id]);
    if (!defined($data->{$id})) {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(
    		error => "Genome ".$id." not found!",
			method_name => 'get_genomeobject'
		);
    }
    $data = $data->{$id};
    my $genomeObj = {
		id => $id,
		scientific_name => $data->{scientific_name},
		genetic_code => $data->{genetic_code},
		domain => undef,
		source => undef,
		source_id => undef,
		contigs => [],
		features => []
    };
    $data = $self->_cdmi()->get_relationship_IsComposedOf([$id],["domain","source_id"], [], ["id"]);
    if (defined($data->[0])) {
    	if (defined($data->[0]->[0]->{domain})) {
    		$genomeObj->{domain} = $data->[0]->[0]->{domain};
    	}
    	if (defined($data->[0]->[0]->{source_id})) {
    		$genomeObj->{source_id} = $data->[0]->[0]->{source_id};
    	}
    }
   	for (my $i=0; $i < @{$data}; $i++) {
    	if (defined($data->[$i]->[2]->{id})) {
	    	my $contig = {
	    		id => $data->[$i]->[2]->{id},
	    		dna => undef
	    	};
	    	my $seqData = $self->_cdmi()->contigs_to_sequences([$data->[$i]->[2]->{id}]);
	    	if (defined($seqData->{$data->[$i]->[2]->{id}})) {
	    		$contig->{dna} = $seqData->{$data->[$i]->[2]->{id}};
	    	}
	    	push(@{$genomeObj->{contigs}},$contig);
    	}
   	}
   	#$data = $self->_cdmi()->get_relationship_WasSubmittedBy([$id],[], ["id"], ["id"]);
    #if (defined($data->[0])) {
    #	if (defined($data->[0]->[2]->{id})) {
    #		$genomeObj->{source} = $data->[0]->[2]->{id};
    #	}
    #}
  	my $genomeFtrs = $self->_cdmi()->genomes_to_fids([$id],[]);
	my $features = $genomeFtrs->{$id};
  	my $fidAnnotationHash = $self->_cdmi()->fids_to_annotations($features);
  	my $fidProteinSequences = $self->_cdmi()->fids_to_protein_sequences($features);
  	my $fidDataHash = $self->_cdmi()->fids_to_feature_data($features);
  	for (my $i=0; $i < @{$features};$i++) {
  		my $ftr = $features->[$i];
  		my $ftrdata = $fidDataHash->{$ftr};
  		my $feature = {
  			id => $ftr,
  			location => $ftrdata->{feature_location},
  			function => $ftrdata->{feature_function},
  			aliases => [],
  			annotations => []
  		};
  		if (defined($fidAnnotationHash->{$ftr})) {
  			$feature->{annotations} = $fidAnnotationHash->{$ftr};
  		}
  		if (defined($fidProteinSequences->{$ftr})) {
  			$feature->{protein_translation} = $fidProteinSequences->{$ftr};
  		}
  		
  		push(@{$genomeObj->{features}},$feature);
  	}
	return $genomeObj;
}

sub _store {
	my($self) = @_;
	return $self->{_store};
}

sub _authentication {
	my($self) = @_;
	return $self->{_authentication};
}

sub _set_authentication {
	my($self,$authentication) = @_;
	$self->{_authentication} = $authentication;
}

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    my $options = $args[0];
    if (defined($options->{workspace})) {
    	$self->{_workspaceServices} = $options->{workspace};
    }
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 get_models

  $out_models = $obj->get_models($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_models_params
$out_models is a reference to a list where each element is an FBAModel
get_models_params is a reference to a hash where the following keys are defined:
	in_model_ids has a value which is a reference to a list where each element is a fbamodel_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
fbamodel_id is a string
workspace_id is a string
FBAModel is a reference to a hash where the following keys are defined:
	id has a value which is a fbamodel_id
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
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
	biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound
biomass_id is a string
BiomassCompound is a reference to a list containing 2 items:
	0: a modelcompound_id
	1: a float
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
FBAMeta is a reference to a list containing 4 items:
	0: a fba_id
	1: a media_id
	2: a float
	3: a reference to a list where each element is a feature_id
fba_id is a string
media_id is a string
GapFillMeta is a reference to a list containing 3 items:
	0: a gapfill_id
	1: a media_id
	2: a reference to a list where each element is a feature_id
gapfill_id is a string
GapGenMeta is a reference to a list containing 3 items:
	0: a gapgen_id
	1: a media_id
	2: a reference to a list where each element is a feature_id
gapgen_id is a string

</pre>

=end html

=begin text

$input is a get_models_params
$out_models is a reference to a list where each element is an FBAModel
get_models_params is a reference to a hash where the following keys are defined:
	in_model_ids has a value which is a reference to a list where each element is a fbamodel_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
fbamodel_id is a string
workspace_id is a string
FBAModel is a reference to a hash where the following keys are defined:
	id has a value which is a fbamodel_id
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
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
	biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound
biomass_id is a string
BiomassCompound is a reference to a list containing 2 items:
	0: a modelcompound_id
	1: a float
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
FBAMeta is a reference to a list containing 4 items:
	0: a fba_id
	1: a media_id
	2: a float
	3: a reference to a list where each element is a feature_id
fba_id is a string
media_id is a string
GapFillMeta is a reference to a list containing 3 items:
	0: a gapfill_id
	1: a media_id
	2: a reference to a list where each element is a feature_id
gapfill_id is a string
GapGenMeta is a reference to a list containing 3 items:
	0: a gapgen_id
	1: a media_id
	2: a reference to a list where each element is a feature_id
gapgen_id is a string


=end text



=item Description



=back

=cut

sub get_models
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_models');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_models);
    #BEGIN get_models
    #END get_models
    my @_bad_returns;
    (ref($out_models) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_models\" (value was \"$out_models\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_models:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_models');
    }
    return($out_models);
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
	in_fba_ids has a value which is a reference to a list where each element is a fba_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
fba_id is a string
workspace_id is a string
FBA is a reference to a hash where the following keys are defined:
	id has a value which is a fba_id
	isComplete has a value which is a bool
	formulation has a value which is an FBAFormulation
	minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
	metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
	reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
	compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
	geneAssertions has a value which is a reference to a list where each element is a GeneAssertion
bool is an int
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	model has a value which is a fbamodel_id
	regmodel has a value which is a regmodel_id
	expressionData has a value which is an expression_id
	objectiveString has a value which is a string
	objective has a value which is a float
	description has a value which is a string
	uptakelimits has a value which is a string
	objectiveConstraintFraction has a value which is a float
	allReversible has a value which is a bool
	defaultMaxFlux has a value which is a float
	defaultMaxDrainFlux has a value which is a float
	defaultMinDrainFlux has a value which is a float
	numberOfSolutions has a value which is an int
	fva has a value which is a bool
	comboDeletions has a value which is an int
	fluxMinimization has a value which is a bool
	findMinimalMedia has a value which is a bool
	simpleThermoConstraints has a value which is a bool
	thermodynamicConstraints has a value which is a bool
	noErrorThermodynamicConstraints has a value which is a bool
	minimizeErrorThermodynamicConstraints has a value which is a bool
	featureKO has a value which is a reference to a list where each element is a feature_id
	reactionKO has a value which is a reference to a list where each element is a modelreaction_id
	constraints has a value which is a reference to a list where each element is a string
	bounds has a value which is a reference to a list where each element is a string
media_id is a string
fbamodel_id is a string
regmodel_id is a string
expression_id is a string
feature_id is a string
modelreaction_id is a string
MinimalMediaPrediction is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a compound_id
	essentialNutrients has a value which is a reference to a list where each element is a compound_id
compound_id is a string
MetaboliteProduction is a reference to a list containing 2 items:
	0: a float
	1: a modelcompound_id
modelcompound_id is a string
ReactionFlux is a reference to a list containing 7 items:
	0: a modelreaction_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
CompoundFlux is a reference to a list containing 7 items:
	0: a modelcompound_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
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
	in_fba_ids has a value which is a reference to a list where each element is a fba_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
fba_id is a string
workspace_id is a string
FBA is a reference to a hash where the following keys are defined:
	id has a value which is a fba_id
	isComplete has a value which is a bool
	formulation has a value which is an FBAFormulation
	minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
	metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
	reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
	compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
	geneAssertions has a value which is a reference to a list where each element is a GeneAssertion
bool is an int
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	model has a value which is a fbamodel_id
	regmodel has a value which is a regmodel_id
	expressionData has a value which is an expression_id
	objectiveString has a value which is a string
	objective has a value which is a float
	description has a value which is a string
	uptakelimits has a value which is a string
	objectiveConstraintFraction has a value which is a float
	allReversible has a value which is a bool
	defaultMaxFlux has a value which is a float
	defaultMaxDrainFlux has a value which is a float
	defaultMinDrainFlux has a value which is a float
	numberOfSolutions has a value which is an int
	fva has a value which is a bool
	comboDeletions has a value which is an int
	fluxMinimization has a value which is a bool
	findMinimalMedia has a value which is a bool
	simpleThermoConstraints has a value which is a bool
	thermodynamicConstraints has a value which is a bool
	noErrorThermodynamicConstraints has a value which is a bool
	minimizeErrorThermodynamicConstraints has a value which is a bool
	featureKO has a value which is a reference to a list where each element is a feature_id
	reactionKO has a value which is a reference to a list where each element is a modelreaction_id
	constraints has a value which is a reference to a list where each element is a string
	bounds has a value which is a reference to a list where each element is a string
media_id is a string
fbamodel_id is a string
regmodel_id is a string
expression_id is a string
feature_id is a string
modelreaction_id is a string
MinimalMediaPrediction is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a compound_id
	essentialNutrients has a value which is a reference to a list where each element is a compound_id
compound_id is a string
MetaboliteProduction is a reference to a list containing 2 items:
	0: a float
	1: a modelcompound_id
modelcompound_id is a string
ReactionFlux is a reference to a list containing 7 items:
	0: a modelreaction_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
CompoundFlux is a reference to a list containing 7 items:
	0: a modelcompound_id
	1: a float
	2: a float
	3: a float
	4: a float
	5: a float
	6: a string
GeneAssertion is a reference to a list containing 4 items:
	0: a feature_id
	1: a float
	2: a float
	3: a bool


=end text



=item Description



=back

=cut

sub get_fbas
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_fbas:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_fbas');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_fbas);
    #BEGIN get_fbas
    #END get_fbas
    my @_bad_returns;
    (ref($out_fbas) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_fbas\" (value was \"$out_fbas\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_fbas:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_fbas');
    }
    return($out_fbas);
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
	in_gapfill_ids has a value which is a reference to a list where each element is a gapfill_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
gapfill_id is a string
workspace_id is a string
GapFill is a reference to a hash where the following keys are defined:
	id has a value which is a gapfill_id
	isComplete has a value which is a bool
	formulation has a value which is a GapfillingFormulation
	biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
	mediaAdditions has a value which is a reference to a list where each element is a compound_id
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
bool is an int
GapfillingFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
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
	blacklistedrxns has a value which is a string
	gauranteedrxns has a value which is a string
	allowedcmps has a value which is a string
	probabilistic_annotation has a value which is a probabilistic_annotation_id
media_id is a string
probabilistic_annotation_id is a string
modelcompound_id is a string
compound_id is a string
reactionAddition is a reference to a list containing 2 items:
	0: a reaction_id
	1: a string
reaction_id is a string

</pre>

=end html

=begin text

$input is a get_gapfills_params
$out_gapfills is a reference to a list where each element is a GapFill
get_gapfills_params is a reference to a hash where the following keys are defined:
	in_gapfill_ids has a value which is a reference to a list where each element is a gapfill_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
gapfill_id is a string
workspace_id is a string
GapFill is a reference to a hash where the following keys are defined:
	id has a value which is a gapfill_id
	isComplete has a value which is a bool
	formulation has a value which is a GapfillingFormulation
	biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
	mediaAdditions has a value which is a reference to a list where each element is a compound_id
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
bool is an int
GapfillingFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
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
	blacklistedrxns has a value which is a string
	gauranteedrxns has a value which is a string
	allowedcmps has a value which is a string
	probabilistic_annotation has a value which is a probabilistic_annotation_id
media_id is a string
probabilistic_annotation_id is a string
modelcompound_id is a string
compound_id is a string
reactionAddition is a reference to a list containing 2 items:
	0: a reaction_id
	1: a string
reaction_id is a string


=end text



=item Description



=back

=cut

sub get_gapfills
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_gapfills:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_gapfills');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_gapfills);
    #BEGIN get_gapfills
    #END get_gapfills
    my @_bad_returns;
    (ref($out_gapfills) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_gapfills\" (value was \"$out_gapfills\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_gapfills:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_gapfills');
    }
    return($out_gapfills);
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
	in_gapgen_ids has a value which is a reference to a list where each element is a gapgen_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
gapgen_id is a string
workspace_id is a string
GapGen is a reference to a hash where the following keys are defined:
	id has a value which is a gapgen_id
	isComplete has a value which is a bool
	formulation has a value which is a GapgenFormulation
	biomassAdditions has a value which is a reference to a list where each element is a compound_id
	mediaRemovals has a value which is a reference to a list where each element is a compound_id
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
bool is an int
GapgenFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	refmedia has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
media_id is a string
compound_id is a string
reactionRemoval is a reference to a list containing 2 items:
	0: a modelreaction_id
	1: a string
modelreaction_id is a string

</pre>

=end html

=begin text

$input is a get_gapgens_params
$out_gapgens is a reference to a list where each element is a GapGen
get_gapgens_params is a reference to a hash where the following keys are defined:
	in_gapgen_ids has a value which is a reference to a list where each element is a gapgen_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	id_type has a value which is a string
gapgen_id is a string
workspace_id is a string
GapGen is a reference to a hash where the following keys are defined:
	id has a value which is a gapgen_id
	isComplete has a value which is a bool
	formulation has a value which is a GapgenFormulation
	biomassAdditions has a value which is a reference to a list where each element is a compound_id
	mediaRemovals has a value which is a reference to a list where each element is a compound_id
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
bool is an int
GapgenFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	refmedia has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
media_id is a string
compound_id is a string
reactionRemoval is a reference to a list containing 2 items:
	0: a modelreaction_id
	1: a string
modelreaction_id is a string


=end text



=item Description



=back

=cut

sub get_gapgens
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_gapgens:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_gapgens');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_gapgens);
    #BEGIN get_gapgens
    #END get_gapgens
    my @_bad_returns;
    (ref($out_gapgens) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_gapgens\" (value was \"$out_gapgens\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_gapgens:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_gapgens');
    }
    return($out_gapgens);
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
	in_reaction_ids has a value which is a reference to a list where each element is a reaction_id
	authentication has a value which is a string
	id_type has a value which is a string
reaction_id is a string
Reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	reversibility has a value which is a string
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	equation has a value which is a string

</pre>

=end html

=begin text

$input is a get_reactions_params
$out_reactions is a reference to a list where each element is a Reaction
get_reactions_params is a reference to a hash where the following keys are defined:
	in_reaction_ids has a value which is a reference to a list where each element is a reaction_id
	authentication has a value which is a string
	id_type has a value which is a string
reaction_id is a string
Reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	reversibility has a value which is a string
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	equation has a value which is a string


=end text



=item Description



=back

=cut

sub get_reactions
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_reactions');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_reactions);
    #BEGIN get_reactions
    #END get_reactions
    my @_bad_returns;
    (ref($out_reactions) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_reactions\" (value was \"$out_reactions\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_reactions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_reactions');
    }
    return($out_reactions);
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
	in_compound_ids has a value which is a reference to a list where each element is a compound_id
	authentication has a value which is a string
	id_type has a value which is a string
compound_id is a string
Compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	charge has a value which is a float
	formula has a value which is a string

</pre>

=end html

=begin text

$input is a get_compounds_params
$out_compounds is a reference to a list where each element is a Compound
get_compounds_params is a reference to a hash where the following keys are defined:
	in_compound_ids has a value which is a reference to a list where each element is a compound_id
	authentication has a value which is a string
	id_type has a value which is a string
compound_id is a string
Compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	charge has a value which is a float
	formula has a value which is a string


=end text



=item Description



=back

=cut

sub get_compounds
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_compounds:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_compounds');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_compounds);
    #BEGIN get_compounds
    #END get_compounds
    my @_bad_returns;
    (ref($out_compounds) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_compounds\" (value was \"$out_compounds\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_compounds:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_compounds');
    }
    return($out_compounds);
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
	in_media_ids has a value which is a reference to a list where each element is a media_id
	authentication has a value which is a string
	id_type has a value which is a string
media_id is a string
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
	in_media_ids has a value which is a reference to a list where each element is a media_id
	authentication has a value which is a string
	id_type has a value which is a string
media_id is a string
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



=back

=cut

sub get_media
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_media');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_media);
    #BEGIN get_media
    #END get_media
    my @_bad_returns;
    (ref($out_media) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"out_media\" (value was \"$out_media\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_media:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_media');
    }
    return($out_media);
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
	in_biochemistry has a value which is a biochemistry_id
	authentication has a value which is a string
	id_type has a value which is a string
biochemistry_id is a string
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
	in_biochemistry has a value which is a biochemistry_id
	authentication has a value which is a string
	id_type has a value which is a string
biochemistry_id is a string
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



=back

=cut

sub get_biochemistry
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_biochemistry:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_biochemistry');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_biochemistry);
    #BEGIN get_biochemistry
    #END get_biochemistry
    my @_bad_returns;
    (ref($out_biochemistry) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"out_biochemistry\" (value was \"$out_biochemistry\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_biochemistry:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_biochemistry');
    }
    return($out_biochemistry);
}




=head2 genome_to_workspace

  $output = $obj->genome_to_workspace($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_to_workspace_params
$output is a genome_to_workspace_params
genome_to_workspace_params is a reference to a hash where the following keys are defined:
	in_genomeobj has a value which is a genomeTO
	in_genome has a value which is a genome_id
	out_genome has a value which is a genome_id
	out_workspace has a value which is a workspace_id
	as_new_genome has a value which is a bool
	authentication has a value which is a string
genomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
genome_id is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$input is a genome_to_workspace_params
$output is a genome_to_workspace_params
genome_to_workspace_params is a reference to a hash where the following keys are defined:
	in_genomeobj has a value which is a genomeTO
	in_genome has a value which is a genome_id
	out_genome has a value which is a genome_id
	out_workspace has a value which is a workspace_id
	as_new_genome has a value which is a bool
	authentication has a value which is a string
genomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
genome_id is a string
workspace_id is a string
bool is an int


=end text



=item Description

This function either retrieves a genome from the CDM by a specified genome ID, or it loads an input genome object.
The loaded or retrieved genome is placed in the specified workspace with the specified ID.

=back

=cut

sub genome_to_workspace
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to genome_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_workspace');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN genome_to_workspace
    $self->_setContext($ctx,$input);
    #Checking workspace specified for loading of genome
    if (!defined($input->{out_workspace})) {
    	my $msg = "User must provide workspace for import of genome.";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_workspace');
    }
    my $outwsmeta;
    try {
    	$outwsmeta = $self->_workspaceServices()->get_workspacemeta({workspace => $input->{out_workspace}});
    } catch {
    	$outwsmeta = $self->_workspaceServices()->create_workspace({workspace => $input->{out_workspace}});
    };
    if ($outwsmeta->[4] ne "w" && $outwsmeta->[4] ne "a") {
    	my $msg = "User does not have permission to write to output workspace: ".$input->{out_workspace};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_workspace');
    }
    #Retrieving genome object
    my $genomeObj;
    if (defined($input->{in_genomeobj})) {
    	$genomeObj = $input->{in_genomeobj};
    } elsif (defined($input->{in_genome})) {
    	$genomeObj = $self->_get_genomeObj_from_CDM($input->{in_genome},$input->{as_new_genome});
    } else {
    	my $msg = "User must specify genome to be imported to workspace";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_fbamodel');
    }
    if (!defined($input->{out_genome})) {
    	$input->{out_genome} = $genomeObj->{id};
    }
    #Saving genome object
    $self->_save_msobject($genomeObj,"Genome",$input->{out_workspace},$input->{out_genome});
	$output = $input;
	$self->_clearContext();
    #END genome_to_workspace
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_workspace');
    }
    return($output);
}




=head2 genome_to_fbamodel

  $output = $obj->genome_to_fbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_to_fbamodel_params
$output is a genome_to_fbamodel_params
genome_to_fbamodel_params is a reference to a hash where the following keys are defined:
	in_genome has a value which is a genome_id
	in_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
genome_id is a string
workspace_id is a string
fbamodel_id is a string

</pre>

=end html

=begin text

$input is a genome_to_fbamodel_params
$output is a genome_to_fbamodel_params
genome_to_fbamodel_params is a reference to a hash where the following keys are defined:
	in_genome has a value which is a genome_id
	in_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
genome_id is a string
workspace_id is a string
fbamodel_id is a string


=end text



=item Description

This function accepts a genome_to_fbamodel_params as input, building a new FBAModel for the genome specified by genome_id.
The function returns a genome_to_fbamodel_params as output, specifying the ID of the model generated in the model_id parameter.

=back

=cut

sub genome_to_fbamodel
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_fbamodel');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN genome_to_fbamodel
    $self->_setContext($ctx,$input);
    #Checking arguments
    if (!defined($input->{in_genome})) {
    	my $msg = "in_genome must be specified for genome_to_fbamodel to run";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_fbamodel');
    }
    if (!defined($input->{in_workspace})) {
    	my $msg = "in_workspace must be specified for genome_to_fbamodel to run";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_fbamodel');
    }
    if (!defined($input->{out_workspace})) {
    	$input->{out_workspace} = $input->{in_workspace};
    }
    #Retrieving workspace
    my $wss = $self->_workspaceServices();
    my $wsmeta = $wss->get_workspacemeta({workspace => $input->{in_workspace}});
    if ($wsmeta->[4] eq "n") {
    	my $msg = "User does not have permission to access specified workspace: ".$input->{in_workspace};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_fbamodel');
    }
    my $outwsmeta = $wsmeta;
    if ($input->{out_workspace} ne $input->{in_workspace}) {
    	try {
    		$outwsmeta = $wss->get_workspacemeta({workspace => $input->{out_workspace}});
	    } catch {
	    	$outwsmeta = $wss->create_workspace({workspace => $input->{out_workspace}});
	    };
    }
    if ($outwsmeta->[4] ne "w" && $outwsmeta->[4] ne "a") {
    	my $msg = "User does not have permission to write to output workspace: ".$input->{out_workspace};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_fbamodel');
    }
    #Retrieving genome object
    my $output = $wss->get_object({
    	id => $input->{in_genome},
    	type => "Genome",
    	workspace => $input->{in_workspace}
    });
    my $genomeObj = $output->{data};
    my $genomeMeta = $output->{metadata};
    if (!defined($genomeObj)) {
    	my $msg = "Workspace does not contain the genome object: ".$input->{in_genome};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'genome_to_fbamodel');
    }
    #Retreiving mapping and biochemistry
    my $mapping = $self->_get_msobject("Mapping","kbase","default");
    my $biochem = $mapping->biochemistry();    
    #Translating genome to model seed annotation
    my $annotation = $self->_translate_genome_to_annotation($genomeObj,$mapping);
    my $mdl = $annotation->createStandardFBAModel( { prefix => "Kbase", } );
    #If no output model ID is provided, one is retreived from KBase
    if (!defined($input->{out_model})) {
    	my $ids = $self->_idServer();
    	$input->{out_model} = "kb|fm.".$ids->allocate_id_range( "fbamod", 1 ) + 0;
    }
	$mdl->id($input->{out_model});
	$mdl->mapping_uuid($input->{out_workspace}."/".$input->{out_model}.".map");
	$mdl->mapping($mapping);
	$mdl->biochemistry_uuid("kbase/default");
	$mdl->biochemistry($biochem);
	$mdl->annotation_uuid($input->{out_workspace}."/".$input->{out_model}.".anno");
	$mdl->annotation($annotation);
	$mdl->defaultNameSpace("KBase");
	$annotation->mapping_uuid($input->{out_workspace}."/".$input->{out_model}.".map");
	$annotation->mapping($mapping);
	$self->_save_msobject($mdl,"Model",$input->{out_workspace},$input->{out_model});
	$self->_save_msobject($annotation,"Annotation",$input->{out_workspace},$input->{out_model}.".anno");
	$self->_save_msobject($mapping,"Mapping",$input->{out_workspace},$input->{out_model}.".map");
	$output = $input;
    $self->_clearContext();
    #END genome_to_fbamodel
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_fbamodel');
    }
    return($output);
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
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	format has a value which is a string
	authentication has a value which is a string
fbamodel_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_fbamodel_params
$output is a string
export_fbamodel_params is a reference to a hash where the following keys are defined:
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	format has a value which is a string
	authentication has a value which is a string
fbamodel_id is a string
workspace_id is a string


=end text



=item Description

This function exports the specified FBAModel to a specified format (sbml,html)

=back

=cut

sub export_fbamodel
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_fbamodel');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN export_fbamodel
    #END export_fbamodel
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to export_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_fbamodel');
    }
    return($output);
}




=head2 runfba

  $output = $obj->runfba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a runfba_params
$output is a runfba_params
runfba_params is a reference to a hash where the following keys are defined:
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	out_fba has a value which is a fba_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
fbamodel_id is a string
workspace_id is a string
fba_id is a string

</pre>

=end html

=begin text

$input is a runfba_params
$output is a runfba_params
runfba_params is a reference to a hash where the following keys are defined:
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	out_fba has a value which is a fba_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
fbamodel_id is a string
workspace_id is a string
fba_id is a string


=end text



=item Description

This function runs flux balance analysis on the input FBAModel and produces HTML as output

=back

=cut

sub runfba
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN runfba
    #Retreiving the model
#    my $in_model = $input;
#    my $model = $self->loadObject($in_model);
#	#Creating FBA formulation
#	my $input = {model => $model};
#	my $overrideList = {
#		media => "media",notes => "notes",fva => "fva",simulateko => "comboDeletions",
#		minimizeflux => "fluxMinimization",findminmedia => "findMinimalMedia",objfraction => "objectiveConstraintFraction",
#		allreversible => "allReversible",objective => "objectiveString",rxnko => "geneKO",geneko => "reactionKO",uptakelim => "uptakeLimits",
#		defaultmaxflux => "defaultMaxFlux",defaultminuptake => "defaultMinDrainFlux",defaultmaxuptake => "defaultMaxDrainFlux",
#		simplethermoconst => "simpleThermoConstraints",thermoconst => "thermodynamicConstraints",nothermoerror => "noErrorThermodynamicConstraints",
#		minthermoerror => "minimizeErrorThermodynamicConstraints",fbaPhenotypeSimulations => "fbaPhenotypeSimulations",
#	};
#	foreach my $argument (keys(%{$overrideList})) {
#		if (defined($in_formulation->{$argument})) {
#			$input->{overrides}->{$overrideList->{$argument}} = $in_formulation->{$argument};
#		}
#	}
#	my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
#	my $fbaform = $exchange_factory->buildFBAFormulation($input);
#    #Running FBA
#    my $fbaResult = $fbaform->runFBA();
#    if (!defined($fbaResult)) {
#    	my $msg = "FBA failed with no solution returned!";
#    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'runfba');
#    }
#    my $store = $self->{_store};
#    if ($overwrite == 1) {
#    	$model->add("fbaFormulations",$fbaform);
#	    $store->save_object("model/kbase/".$model->id(),$model);
#    } elsif (length($save) > 0) {
#    	$model->add("fbaFormulations",$fbaform);
#    	$model->id($save);
#		$store->save_object("model/kbase/".$save,$model);
#    }
#    if (@{$fbaform->fbaResults()->[0]->fbaPhenotypeSimultationResults()} > 0) {
#    	$out_solution = $self->objectToOutput($fbaform);
#    } else {
#    	$out_solution = $fbaform->createHTML();
#    }
    #END runfba
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }
    return($output);
}




=head2 checkfba

  $is_done = $obj->checkfba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a checkfba_params
$is_done is a bool
checkfba_params is a reference to a hash where the following keys are defined:
	in_fba has a value which is a fba_id
	in_workspace has a value which is a workspace_id
	authentication has a value which is a string
fba_id is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$input is a checkfba_params
$is_done is a bool
checkfba_params is a reference to a hash where the following keys are defined:
	in_fba has a value which is a fba_id
	in_workspace has a value which is a workspace_id
	authentication has a value which is a string
fba_id is a string
workspace_id is a string
bool is an int


=end text



=item Description

This function checks if the specified FBA study is complete.

=back

=cut

sub checkfba
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to checkfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'checkfba');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($is_done);
    #BEGIN checkfba
    #END checkfba
    my @_bad_returns;
    (!ref($is_done)) or push(@_bad_returns, "Invalid type for return variable \"is_done\" (value was \"$is_done\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to checkfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'checkfba');
    }
    return($is_done);
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
	in_fba has a value which is a fba_id
	in_workspace has a value which is a workspace_id
	format has a value which is a string
	authentication has a value which is a string
fba_id is a string
workspace_id is a string

</pre>

=end html

=begin text

$input is an export_fba_params
$output is a string
export_fba_params is a reference to a hash where the following keys are defined:
	in_fba has a value which is a fba_id
	in_workspace has a value which is a workspace_id
	format has a value which is a string
	authentication has a value which is a string
fba_id is a string
workspace_id is a string


=end text



=item Description

This function exports the specified FBA object to the specified format (e.g. html)

=back

=cut

sub export_fba
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_fba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_fba');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN export_fba
    #END export_fba
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to export_fba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_fba');
    }
    return($output);
}




=head2 gapfill_model

  $out_gapfill = $obj->gapfill_model($in_model, $formulation)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is a fbamodel_id
$formulation is a GapfillingFormulation
$out_gapfill is a gapfill_id
fbamodel_id is a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
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
	blacklistedrxns has a value which is a string
	gauranteedrxns has a value which is a string
	allowedcmps has a value which is a string
	probabilistic_annotation has a value which is a probabilistic_annotation_id
media_id is a string
bool is an int
probabilistic_annotation_id is a string
gapfill_id is a string

</pre>

=end html

=begin text

$in_model is a fbamodel_id
$formulation is a GapfillingFormulation
$out_gapfill is a gapfill_id
fbamodel_id is a string
GapfillingFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
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
	blacklistedrxns has a value which is a string
	gauranteedrxns has a value which is a string
	allowedcmps has a value which is a string
	probabilistic_annotation has a value which is a probabilistic_annotation_id
media_id is a string
bool is an int
probabilistic_annotation_id is a string
gapfill_id is a string


=end text



=item Description



=back

=cut

sub gapfill_model
{
    my $self = shift;
    my($in_model, $formulation) = @_;

    my @_bad_arguments;
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    (ref($formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"formulation\" (value was \"$formulation\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_model');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_gapfill);
    #BEGIN gapfill_model
    #END gapfill_model
    my @_bad_returns;
    (!ref($out_gapfill)) or push(@_bad_returns, "Invalid type for return variable \"out_gapfill\" (value was \"$out_gapfill\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_model');
    }
    return($out_gapfill);
}




=head2 gapfill_check_results

  $is_done = $obj->gapfill_check_results($in_gapfill)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapfill is a gapfill_id
$is_done is a bool
gapfill_id is a string
bool is an int

</pre>

=end html

=begin text

$in_gapfill is a gapfill_id
$is_done is a bool
gapfill_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub gapfill_check_results
{
    my $self = shift;
    my($in_gapfill) = @_;

    my @_bad_arguments;
    (!ref($in_gapfill)) or push(@_bad_arguments, "Invalid type for argument \"in_gapfill\" (value was \"$in_gapfill\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_check_results:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_check_results');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($is_done);
    #BEGIN gapfill_check_results
    #END gapfill_check_results
    my @_bad_returns;
    (!ref($is_done)) or push(@_bad_returns, "Invalid type for return variable \"is_done\" (value was \"$is_done\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapfill_check_results:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_check_results');
    }
    return($is_done);
}




=head2 gapfill_to_html

  $html_string = $obj->gapfill_to_html($in_gapfill)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapfill is a gapfill_id
$html_string is an HTML
gapfill_id is a string
HTML is a string

</pre>

=end html

=begin text

$in_gapfill is a gapfill_id
$html_string is an HTML
gapfill_id is a string
HTML is a string


=end text



=item Description



=back

=cut

sub gapfill_to_html
{
    my $self = shift;
    my($in_gapfill) = @_;

    my @_bad_arguments;
    (!ref($in_gapfill)) or push(@_bad_arguments, "Invalid type for argument \"in_gapfill\" (value was \"$in_gapfill\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_to_html');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($html_string);
    #BEGIN gapfill_to_html
    #END gapfill_to_html
    my @_bad_returns;
    (!ref($html_string)) or push(@_bad_returns, "Invalid type for return variable \"html_string\" (value was \"$html_string\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapfill_to_html:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_to_html');
    }
    return($html_string);
}




=head2 gapfill_integrate

  $obj->gapfill_integrate($in_gapfill, $in_model)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapfill is a gapfill_id
$in_model is a fbamodel_id
gapfill_id is a string
fbamodel_id is a string

</pre>

=end html

=begin text

$in_gapfill is a gapfill_id
$in_model is a fbamodel_id
gapfill_id is a string
fbamodel_id is a string


=end text



=item Description



=back

=cut

sub gapfill_integrate
{
    my $self = shift;
    my($in_gapfill, $in_model) = @_;

    my @_bad_arguments;
    (!ref($in_gapfill)) or push(@_bad_arguments, "Invalid type for argument \"in_gapfill\" (value was \"$in_gapfill\")");
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_integrate:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_integrate');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    #BEGIN gapfill_integrate
    #END gapfill_integrate
    return();
}




=head2 gapgen_model

  $out_gapgen = $obj->gapgen_model($in_model, $formulation)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is a fbamodel_id
$formulation is a GapgenFormulation
$out_gapgen is a gapgen_id
fbamodel_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	refmedia has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
media_id is a string
bool is an int
gapgen_id is a string

</pre>

=end html

=begin text

$in_model is a fbamodel_id
$formulation is a GapgenFormulation
$out_gapgen is a gapgen_id
fbamodel_id is a string
GapgenFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	refmedia has a value which is a media_id
	notes has a value which is a string
	objective has a value which is a string
	objfraction has a value which is a float
	rxnko has a value which is a string
	geneko has a value which is a string
	uptakelim has a value which is a string
	defaultmaxflux has a value which is a float
	defaultmaxuptake has a value which is a float
	defaultminuptake has a value which is a float
	nomediahyp has a value which is a bool
	nobiomasshyp has a value which is a bool
	nogprhyp has a value which is a bool
	nopathwayhyp has a value which is a bool
media_id is a string
bool is an int
gapgen_id is a string


=end text



=item Description

These functions run gapgeneration on the input FBAModel and produce gapgen objects as output

=back

=cut

sub gapgen_model
{
    my $self = shift;
    my($in_model, $formulation) = @_;

    my @_bad_arguments;
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    (ref($formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"formulation\" (value was \"$formulation\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_model');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_gapgen);
    #BEGIN gapgen_model
    #END gapgen_model
    my @_bad_returns;
    (!ref($out_gapgen)) or push(@_bad_returns, "Invalid type for return variable \"out_gapgen\" (value was \"$out_gapgen\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_model');
    }
    return($out_gapgen);
}




=head2 gapgen_check_results

  $is_done = $obj->gapgen_check_results($in_gapgen)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapgen is a gapgen_id
$is_done is a bool
gapgen_id is a string
bool is an int

</pre>

=end html

=begin text

$in_gapgen is a gapgen_id
$is_done is a bool
gapgen_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub gapgen_check_results
{
    my $self = shift;
    my($in_gapgen) = @_;

    my @_bad_arguments;
    (!ref($in_gapgen)) or push(@_bad_arguments, "Invalid type for argument \"in_gapgen\" (value was \"$in_gapgen\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapgen_check_results:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_check_results');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($is_done);
    #BEGIN gapgen_check_results
    #END gapgen_check_results
    my @_bad_returns;
    (!ref($is_done)) or push(@_bad_returns, "Invalid type for return variable \"is_done\" (value was \"$is_done\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapgen_check_results:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_check_results');
    }
    return($is_done);
}




=head2 gapgen_to_html

  $html_string = $obj->gapgen_to_html($in_gapgen)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapgen is a gapgen_id
$html_string is an HTML
gapgen_id is a string
HTML is a string

</pre>

=end html

=begin text

$in_gapgen is a gapgen_id
$html_string is an HTML
gapgen_id is a string
HTML is a string


=end text



=item Description



=back

=cut

sub gapgen_to_html
{
    my $self = shift;
    my($in_gapgen) = @_;

    my @_bad_arguments;
    (!ref($in_gapgen)) or push(@_bad_arguments, "Invalid type for argument \"in_gapgen\" (value was \"$in_gapgen\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapgen_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_to_html');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($html_string);
    #BEGIN gapgen_to_html
    #END gapgen_to_html
    my @_bad_returns;
    (!ref($html_string)) or push(@_bad_returns, "Invalid type for return variable \"html_string\" (value was \"$html_string\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapgen_to_html:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_to_html');
    }
    return($html_string);
}




=head2 gapgen_integrate

  $obj->gapgen_integrate($in_gapgen, $in_model)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapgen is a gapgen_id
$in_model is a fbamodel_id
gapgen_id is a string
fbamodel_id is a string

</pre>

=end html

=begin text

$in_gapgen is a gapgen_id
$in_model is a fbamodel_id
gapgen_id is a string
fbamodel_id is a string


=end text



=item Description



=back

=cut

sub gapgen_integrate
{
    my $self = shift;
    my($in_gapgen, $in_model) = @_;

    my @_bad_arguments;
    (!ref($in_gapgen)) or push(@_bad_arguments, "Invalid type for argument \"in_gapgen\" (value was \"$in_gapgen\")");
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapgen_integrate:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_integrate');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    #BEGIN gapgen_integrate
    #END gapgen_integrate
    return();
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 bool

=over 4



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



=head2 md5

=over 4



=item Description

IMPORT FROM probabilistic_annotation/ProbabilisticAnnotation.spec


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



=head2 genome_id

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



=head2 feature_id

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



=head2 contig_id

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



=head2 feature_type

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



=head2 reaction_id

=over 4



=item Description

BIOCHEMISTRY SPEC


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



=head2 Biochemistry

=over 4



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
name has a value which is a string
aliases has a value which is a reference to a list where each element is a string
charge has a value which is a float
formula has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a compound_id
name has a value which is a string
aliases has a value which is a reference to a list where each element is a string
charge has a value which is a float
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
reversibility has a value which is a string
deltaG has a value which is a float
deltaGErr has a value which is a float
equation has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
reversibility has a value which is a string
deltaG has a value which is a float
deltaGErr has a value which is a float
equation has a value which is a string


=end text

=back



=head2 modelcompartment_id

=over 4



=item Description

FBAMODEL SPEC


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



=head2 ModelCompartment

=over 4



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



=head2 modelcompound_id

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



=head2 feature_id

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



=head2 reaction_id

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



=head2 modelreaction_id

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
features has a value which is a reference to a list where each element is a feature_id
compartment has a value which is a modelcompartment_id


=end text

=back



=head2 BiomassCompound

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a modelcompound_id
1: a float

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a modelcompound_id
1: a float


=end text

=back



=head2 biomass_id

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



=head2 ModelBiomass

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
name has a value which is a string
biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
name has a value which is a string
biomass_compounds has a value which is a reference to a list where each element is a BiomassCompound


=end text

=back



=head2 media_id

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



=head2 fba_id

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



=head2 FBAMeta

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: a fba_id
1: a media_id
2: a float
3: a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: a fba_id
1: a media_id
2: a float
3: a reference to a list where each element is a feature_id


=end text

=back



=head2 gapgen_id

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



=head2 GapGenMeta

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: a gapgen_id
1: a media_id
2: a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a gapgen_id
1: a media_id
2: a reference to a list where each element is a feature_id


=end text

=back



=head2 gapfill_id

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



=head2 GapFillMeta

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: a gapfill_id
1: a media_id
2: a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a gapfill_id
1: a media_id
2: a reference to a list where each element is a feature_id


=end text

=back



=head2 fbamodel_id

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



=head2 genome_id

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



=head2 biochemistry_id

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



=head2 mapping_id

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



=head2 FBAModel

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a fbamodel_id
genome has a value which is a genome_id
map has a value which is a mapping_id
biochemistry has a value which is a biochemistry_id
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
genome has a value which is a genome_id
map has a value which is a mapping_id
biochemistry has a value which is a biochemistry_id
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



=head2 media_id

=over 4



=item Description

GAPFILLING FORMULATION SPEC


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



=head2 probabilistic_annotation_id

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



=head2 GapfillingFormulation

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
notes has a value which is a string
objective has a value which is a string
objfraction has a value which is a float
rxnko has a value which is a string
geneko has a value which is a string
uptakelim has a value which is a string
defaultmaxflux has a value which is a float
defaultmaxuptake has a value which is a float
defaultminuptake has a value which is a float
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
blacklistedrxns has a value which is a string
gauranteedrxns has a value which is a string
allowedcmps has a value which is a string
probabilistic_annotation has a value which is a probabilistic_annotation_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
notes has a value which is a string
objective has a value which is a string
objfraction has a value which is a float
rxnko has a value which is a string
geneko has a value which is a string
uptakelim has a value which is a string
defaultmaxflux has a value which is a float
defaultmaxuptake has a value which is a float
defaultminuptake has a value which is a float
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
blacklistedrxns has a value which is a string
gauranteedrxns has a value which is a string
allowedcmps has a value which is a string
probabilistic_annotation has a value which is a probabilistic_annotation_id


=end text

=back



=head2 reactionAddition

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a reaction_id
1: a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a reaction_id
1: a string


=end text

=back



=head2 GapFill

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapfill_id
isComplete has a value which is a bool
formulation has a value which is a GapfillingFormulation
biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
mediaAdditions has a value which is a reference to a list where each element is a compound_id
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapfill_id
isComplete has a value which is a bool
formulation has a value which is a GapfillingFormulation
biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
mediaAdditions has a value which is a reference to a list where each element is a compound_id
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition


=end text

=back



=head2 GapgenFormulation

=over 4



=item Description

GAPGEN FORMULATION SPEC


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
refmedia has a value which is a media_id
notes has a value which is a string
objective has a value which is a string
objfraction has a value which is a float
rxnko has a value which is a string
geneko has a value which is a string
uptakelim has a value which is a string
defaultmaxflux has a value which is a float
defaultmaxuptake has a value which is a float
defaultminuptake has a value which is a float
nomediahyp has a value which is a bool
nobiomasshyp has a value which is a bool
nogprhyp has a value which is a bool
nopathwayhyp has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
refmedia has a value which is a media_id
notes has a value which is a string
objective has a value which is a string
objfraction has a value which is a float
rxnko has a value which is a string
geneko has a value which is a string
uptakelim has a value which is a string
defaultmaxflux has a value which is a float
defaultmaxuptake has a value which is a float
defaultminuptake has a value which is a float
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
a reference to a list containing 2 items:
0: a modelreaction_id
1: a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a modelreaction_id
1: a string


=end text

=back



=head2 GapGen

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gapgen_id
isComplete has a value which is a bool
formulation has a value which is a GapgenFormulation
biomassAdditions has a value which is a reference to a list where each element is a compound_id
mediaRemovals has a value which is a reference to a list where each element is a compound_id
reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapgen_id
isComplete has a value which is a bool
formulation has a value which is a GapgenFormulation
biomassAdditions has a value which is a reference to a list where each element is a compound_id
mediaRemovals has a value which is a reference to a list where each element is a compound_id
reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval


=end text

=back



=head2 feature_id

=over 4



=item Description

FBA FORMULATION SPEC


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



=head2 GeneAssertion

=over 4



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



=head2 modelcompound_id

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



=head2 CompoundFlux

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 7 items:
0: a modelcompound_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string

</pre>

=end html

=begin text

a reference to a list containing 7 items:
0: a modelcompound_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string


=end text

=back



=head2 modelreaction_id

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



=head2 ReactionFlux

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 7 items:
0: a modelreaction_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string

</pre>

=end html

=begin text

a reference to a list containing 7 items:
0: a modelreaction_id
1: a float
2: a float
3: a float
4: a float
5: a float
6: a string


=end text

=back



=head2 MetaboliteProduction

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 2 items:
0: a float
1: a modelcompound_id

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a float
1: a modelcompound_id


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



=head2 fba_id

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



=head2 media_id

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



=head2 fbamodel_id

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



=head2 regmodel_id

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



=head2 expression_id

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



=head2 FBAFormulation

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
model has a value which is a fbamodel_id
regmodel has a value which is a regmodel_id
expressionData has a value which is an expression_id
objectiveString has a value which is a string
objective has a value which is a float
description has a value which is a string
uptakelimits has a value which is a string
objectiveConstraintFraction has a value which is a float
allReversible has a value which is a bool
defaultMaxFlux has a value which is a float
defaultMaxDrainFlux has a value which is a float
defaultMinDrainFlux has a value which is a float
numberOfSolutions has a value which is an int
fva has a value which is a bool
comboDeletions has a value which is an int
fluxMinimization has a value which is a bool
findMinimalMedia has a value which is a bool
simpleThermoConstraints has a value which is a bool
thermodynamicConstraints has a value which is a bool
noErrorThermodynamicConstraints has a value which is a bool
minimizeErrorThermodynamicConstraints has a value which is a bool
featureKO has a value which is a reference to a list where each element is a feature_id
reactionKO has a value which is a reference to a list where each element is a modelreaction_id
constraints has a value which is a reference to a list where each element is a string
bounds has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
model has a value which is a fbamodel_id
regmodel has a value which is a regmodel_id
expressionData has a value which is an expression_id
objectiveString has a value which is a string
objective has a value which is a float
description has a value which is a string
uptakelimits has a value which is a string
objectiveConstraintFraction has a value which is a float
allReversible has a value which is a bool
defaultMaxFlux has a value which is a float
defaultMaxDrainFlux has a value which is a float
defaultMinDrainFlux has a value which is a float
numberOfSolutions has a value which is an int
fva has a value which is a bool
comboDeletions has a value which is an int
fluxMinimization has a value which is a bool
findMinimalMedia has a value which is a bool
simpleThermoConstraints has a value which is a bool
thermodynamicConstraints has a value which is a bool
noErrorThermodynamicConstraints has a value which is a bool
minimizeErrorThermodynamicConstraints has a value which is a bool
featureKO has a value which is a reference to a list where each element is a feature_id
reactionKO has a value which is a reference to a list where each element is a modelreaction_id
constraints has a value which is a reference to a list where each element is a string
bounds has a value which is a reference to a list where each element is a string


=end text

=back



=head2 FBA

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a fba_id
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
isComplete has a value which is a bool
formulation has a value which is an FBAFormulation
minimalMediaPredictions has a value which is a reference to a list where each element is a MinimalMediaPrediction
metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
geneAssertions has a value which is a reference to a list where each element is a GeneAssertion


=end text

=back



=head2 workspace_id

=over 4



=item Description

END FBA FORMULATION SPEC


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



=head2 get_models_params

=over 4



=item Description

This function returns model data for input ids


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_model_ids has a value which is a reference to a list where each element is a fbamodel_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_model_ids has a value which is a reference to a list where each element is a fbamodel_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_fbas_params

=over 4



=item Description

This function returns fba data for input ids


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_fba_ids has a value which is a reference to a list where each element is a fba_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_fba_ids has a value which is a reference to a list where each element is a fba_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_gapfills_params

=over 4



=item Description

This function returns gapfill data for input ids


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_gapfill_ids has a value which is a reference to a list where each element is a gapfill_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_gapfill_ids has a value which is a reference to a list where each element is a gapfill_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_gapgens_params

=over 4



=item Description

This function returns gapgen data for input ids


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_gapgen_ids has a value which is a reference to a list where each element is a gapgen_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_gapgen_ids has a value which is a reference to a list where each element is a gapgen_id
workspace has a value which is a workspace_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_reactions_params

=over 4



=item Description

This function returns reaction data for input ids


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_reaction_ids has a value which is a reference to a list where each element is a reaction_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_reaction_ids has a value which is a reference to a list where each element is a reaction_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_compounds_params

=over 4



=item Description

This function returns compound data for input ids


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_compound_ids has a value which is a reference to a list where each element is a compound_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_compound_ids has a value which is a reference to a list where each element is a compound_id
authentication has a value which is a string
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
in_media_ids has a value which is a reference to a list where each element is a media_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_media_ids has a value which is a reference to a list where each element is a media_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 get_biochemistry_params

=over 4



=item Description

This function returns biochemistry object


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_biochemistry has a value which is a biochemistry_id
authentication has a value which is a string
id_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_biochemistry has a value which is a biochemistry_id
authentication has a value which is a string
id_type has a value which is a string


=end text

=back



=head2 workspace_id

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



=head2 genome_to_workspace_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_genomeobj has a value which is a genomeTO
in_genome has a value which is a genome_id
out_genome has a value which is a genome_id
out_workspace has a value which is a workspace_id
as_new_genome has a value which is a bool
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_genomeobj has a value which is a genomeTO
in_genome has a value which is a genome_id
out_genome has a value which is a genome_id
out_workspace has a value which is a workspace_id
as_new_genome has a value which is a bool
authentication has a value which is a string


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
    
model_id out_model
This parameter specifies the ID to which the generated model should be save. This is optional.
If unspecified, a new KBase model ID will be checked out for the model.
    
workspace_id out_workspace
This parameter specifies the ID of the workspace where the model should be save. This is optional.
If unspecified, this parameter will be set to the value of "in_workspace".


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_genome has a value which is a genome_id
in_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_genome has a value which is a genome_id
in_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string


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
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string


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
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
out_fba has a value which is a fba_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
out_fba has a value which is a fba_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string


=end text

=back



=head2 checkfba_params

=over 4



=item Description

NEED DOCUMENTATION


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_fba has a value which is a fba_id
in_workspace has a value which is a workspace_id
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_fba has a value which is a fba_id
in_workspace has a value which is a workspace_id
authentication has a value which is a string


=end text

=back



=head2 export_fba_params

=over 4



=item Description

NEED DOCUMENTATION


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_fba has a value which is a fba_id
in_workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_fba has a value which is a fba_id
in_workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string


=end text

=back



=head2 HTML

=over 4



=item Description

These functions run gapfilling on the input FBAModel and produce gapfill objects as output


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



=cut

1;
