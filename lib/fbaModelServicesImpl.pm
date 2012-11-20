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
use KBase::ClusterService;
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

sub _getUsername {
	my ($self) = @_;
	if (!defined($self->{_currentUser})) {
		if (defined($self->{_testuser})) {
			$self->{_currentUser} = $self->{_testuser};
		} else {
			$self->{_currentUser} = "public";
		}
		
	}
	return $self->{_currentUser};
}

sub _setContext {
	my ($self,$context,$params) = @_;
    if ( defined $params->{authentication} ) {
        my $token = Bio::KBase::AuthToken->new(
            token => $params->{authentication},
        );
        if ($token->validate()) {
            $self->{_currentUser} = $token->user_id;
        } else {
            Bio::KBase::Exceptions::KBaseException->throw(error => "Invalid authorization token!",
                method_name => 'workspaceDocument::_setContext');
        }
    }
	$self->{_authentication} = $params->{authentication};
	$self->{_context} = $context;
}

sub _getContext {
	my ($self) = @_;
	return $self->{_context};
}

sub _clearContext {
	my ($self) = @_;
    delete $self->{_currentUserObj};
    delete $self->{_currentUser};
    delete $self->{_authentication};
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

sub _clusterService {
	my $self = shift;
	if (!defined($self->{_clusterservice})) {
		$self->{_clusterservice} = KBase::ClusterService->new();
	}
    return $self->{_clusterservice};
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
	my($self,$obj,$type,$ws,$id,$command,$overwrite) = @_;
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
		authentication => $self->_authentication(),
		overwrite => $overwrite
	});
	if (!defined($objmeta)) {
		my $msg = "Unable to save object:".$type."/".$ws."/".$id;
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_msobject');
	}
	return $objmeta;
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

sub _validateargs {
	my ($self,$args,$mandatoryArguments,$optionalArguments,$substitutions) = @_;
	if (!defined($args)) {
	    $args = {};
	}
	if (ref($args) ne "HASH") {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Arguments not hash",
		method_name => '_validateargs');	
	}
	if (defined($substitutions) && ref($substitutions) eq "HASH") {
		foreach my $original (keys(%{$substitutions})) {
			$args->{$original} = $args->{$substitutions->{$original}};
		}
	}
	if (defined($mandatoryArguments)) {
		for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
			if (!defined($args->{$mandatoryArguments->[$i]})) {
				push(@{$args->{_error}},$mandatoryArguments->[$i]);
			}
		}
	}
	if (defined($args->{_error})) {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Mandatory arguments ".join("; ",@{$args->{_error}})." missing.",
		method_name => '_validateargs');
	}
	if (defined($optionalArguments)) {
		foreach my $argument (keys(%{$optionalArguments})) {
			if (!defined($args->{$argument})) {
				$args->{$argument} = $optionalArguments->{$argument};
			}
		}	
	}
	return $args;
}

sub _setDefaultFBAFormulation {
	my ($self,$fbaFormulation) = @_;
	if (!defined($fbaFormulation)) {
		$fbaFormulation = {};
	}
	$fbaFormulation = $self->_validateargs($fbaFormulation,[],{
		media => "Complete",
		media_workspace => "kbasecdm",
		objfraction => 0.1,
		allreversible => 0,
		objective => "Max{(1)bio00001.biomassflux}",
		geneko => [],
		rxnko => [],
		bounds => [],
		constraints => [],
		uptakelim => {},
		defaultmaxflux => 100,
		defaultminuptake => -100,
		defaultmaxuptake => 0,
		simplethermoconst => 0,
		thermoconst => 0,
		nothermoerror => 0,
		minthermoerror => 0
	});
	return $fbaFormulation;
}

sub _buildFBAObject {
	my ($self,$fbaFormulation,$model) = @_;
	my $fba;
	return $fba;
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
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
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
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
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
	authentication has a value which is a string
	overwrite has a value which is a bool
genomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

</pre>

=end html

=begin text

$input is a genome_object_to_workspace_params
$genomeMeta is an object_metadata
genome_object_to_workspace_params is a reference to a hash where the following keys are defined:
	genomeobj has a value which is a genomeTO
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
genomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description

Loads an input genome object into the workspace.

=back

=cut

sub genome_object_to_workspace
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to genome_object_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_object_to_workspace');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($genomeMeta);
    #BEGIN genome_object_to_workspace
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genomeobj","workspace"],{
    	overwrite => 0
    });
    $genomeMeta = $self->_save_msobject($input->{genomeobj},"Genome",$input->{workspace},$input->{genomeobj}->{id},$input->{overwrite});
	$self->_clearContext();
    #END genome_object_to_workspace
    my @_bad_returns;
    (ref($genomeMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"genomeMeta\" (value was \"$genomeMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_object_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_object_to_workspace');
    }
    return($genomeMeta);
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
	authentication has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

</pre>

=end html

=begin text

$input is a genome_to_workspace_params
$genomeMeta is an object_metadata
genome_to_workspace_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description

Retrieves a genome from the CDM and saves it as a genome object in the workspace.

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
    my($genomeMeta);
    #BEGIN genome_to_workspace
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","workspace"],{
    	overwrite => 0
    });
    my $genomeObj = $self->_get_genomeObj_from_CDM($input->{genome});
    $genomeMeta = $self->_save_msobject($genomeObj,"Genome",$input->{workspace},$genomeObj->{id},$input->{overwrite});
	$self->_clearContext();
    #END genome_to_workspace
    my @_bad_returns;
    (ref($genomeMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"genomeMeta\" (value was \"$genomeMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_workspace');
    }
    return($genomeMeta);
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
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

</pre>

=end html

=begin text

$input is a genome_to_fbamodel_params
$modelMeta is an object_metadata
genome_to_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
fbamodel_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


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
    my($modelMeta);
    #BEGIN genome_to_fbamodel
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","genome_workspace"],{
    	model_workspace => $input->{genome_workspace},
    	model => $input->{genome}.".model",
    	overwrite => 0
    });
    #Retreiving genome object from workspace
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    #Retreiving mapping and biochemistry
    my $mapping = $self->_get_msobject("Mapping","kbase","default");
    my $biochem = $mapping->biochemistry();    
    #Translating genome to model seed annotation
    my $annotation = $self->_translate_genome_to_annotation($genomeObj,$mapping);
    my $mdl = $annotation->createStandardFBAModel( { prefix => "Kbase", } );
    #If no output model ID is provided, one is retreived from KBase
	$mdl->id($input->{model});
	$mdl->mapping_uuid($input->{model_workspace}."/".$input->{model}.".map");
	$mdl->mapping($mapping);
	$mdl->biochemistry_uuid("kbase/default");
	$mdl->biochemistry($biochem);
	$mdl->annotation_uuid($input->{model_workspace}."/".$input->{model}.".anno");
	$mdl->annotation($annotation);
	$mdl->defaultNameSpace("KBase");
	$annotation->mapping_uuid($input->{model_workspace}."/".$input->{model}.".map");
	$annotation->mapping($mapping);
	$modelMeta= $self->_save_msobject($mdl,"Model",$input->{model_workspace},$input->{model},$input->{overwrite});
	$self->_save_msobject($annotation,"Annotation",$input->{model_workspace},$input->{model}.".anno",$input->{overwrite});
	$self->_save_msobject($mapping,"Mapping",$input->{model_workspace},$input->{model}.".map",$input->{overwrite});
    $self->_clearContext();
    #END genome_to_fbamodel
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_fbamodel');
    }
    return($modelMeta);
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
	authentication has a value which is a string
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
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["model","workspace","format"],{
    	authentication => undef
    });
    my $model = $self->_get_msobject("Model",$input->{in_workspace},$input->{in_model});
    $output = $model->export({format => $input->{format}});
    $self->_clearContext();
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
	authentication has a value which is a string
media_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

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
	authentication has a value which is a string
media_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description

Add media condition to workspace

=back

=cut

sub addmedia
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to addmedia:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'addmedia');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($mediaMeta);
    #BEGIN addmedia
	$self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["media","workspace","compounds"],{
    	name => $input->{media},
    	isDefined => 0,
    	isMinimal => 0,
    	type => "custom",
    	concentrations => [],
    	maxflux => [],
    	minflux => [],
    	overwrite => 0
    });
    #Creating the media object from the specifications
    my $bio = $self->_get_msobject("Biochemistry","kbase","default");
    my $media = ModelSEED::MS::Media->new({
    	name => $input->{name},
    	isDefined => $input->{isDefined},
    	isMinimal => $input->{isMinimal},
    	type => $input->{type},
    });
    my $missing = [];
    for (my $i=0; $i < @{$input->{compounds}}; $i++) {
    	my $name = $input->{compounds}->[$i];
    	$cpdobj = $bio->searchForCompound($name);
    	if (defined($cpdobj)) {
	    	my $data = {
	    		compound_uuid => $cpdobj->uuid(),
	    		concentration => 0.001,
	    		maxFlux => 100,
	    		minFlux => -100
	    	};
	    	if (defined($input->{concentrations}->[$i])) {
	    		$data->{concentration} = $input->{concentrations}->[$i];
	    	}
	    	if (defined($input->{maxflux}->[$i])) {
	    		$data->{maxFlux} = $input->{maxflux}->[$i];
	    	}
	    	if (defined($input->{minflux}->[$i])) {
	    		$data->{minFlux} = $input->{minFlux}->[$i];
	    	}
	    	$media->add("mediacompounds",$data);
    	} else {
    		push(@{$missing},$input->{compounds}->[$i]);
    	}
    	
    }
    #Checking that all compounds specified for media were found
	if (defined($missing->[0])) {
		my $msg = "Compounds specified for media not found: ".join(";",@{$missing});
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'addmedia');
	}
    #Saving media in database
    $mediaMeta = $self->_save_msobject($media,"Media",$input->{in_workspace},$input->{in_media},"addmedia",$input->{overwrite});
	$self->_clearContext();
    #END addmedia
    my @_bad_returns;
    (ref($mediaMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"mediaMeta\" (value was \"$mediaMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to addmedia:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'addmedia');
    }
    return($mediaMeta);
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
	authentication has a value which is a string
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
	authentication has a value which is a string
media_id is a string
workspace_id is a string


=end text



=item Description

Exports media in specified format (html,readable)

=back

=cut

sub export_media
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_media');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN export_media
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["media","workspace","format"],{});
    my $med;
    if ($input->{in_workspace} eq "kbasecdm") {
    	 my $bio = $self->_get_msobject("Biochemistry","kbase","default");
    	 $med = $bio->queryObject("media",{id => $input->{in_media}});
    	 if (!defined($med)) {
    	 	my $msg = "Media ".$input->{in_media}." not found in base biochemistry!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'export_media');
    	 }
    } else {
    	$med = $self->_get_msobject("Media",$input->{in_media},$input->{in_workspace});
    }
    $output = $med->export({
	    format => $input->{format}
	});
	$self->_clearContext();
    #END export_media
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to export_media:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_media');
    }
    return($output);
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
	fba_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
fba_id is a string
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

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
	fba_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
fba_id is a string
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description

Run flux balance analysis and return ID of FBA object with results

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
    my($fbaMeta);
    #BEGIN runfba
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["model","model_workspace"],{
		formulation => undef,
		fva => 0,
		simulateko => 0,
		minimizeflux => 0,
		findminmedia => 0,
		notes => "",
		fba_workspace => $input->{model_workspace},
		fba => undef,
		overwrite => 0
	});
	if (!defined($input->{fba})) {
		my $ids = $self->_idServer();
    	$input->{fba} = $input->{model}.".fba.".$ids->allocate_id_range( $input->{model}.".fba.", 1 ) + 0;
	}
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	#Creating FBAFormulation Object
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	my $fba = $self->_buildFBAObject($input->{formulation},$model);
	$fba->uuid($input->{fba_workspace}."/".$input->{fba});
    #Running FBA
    my $fbaResult = $fba->runFBA();
    if (!defined($fbaResult)) {
    	my $msg = "FBA failed with no solution returned!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'runfba');
    }
    print join("/",@{$model->fbaFormulation_uuids()})."\n";
	$fbaMeta = $self->_save_msobject($fba,"FBA",$input->{fba_workspace},$input->{fba},"runfba",$input->{overwrite});
    $self->_clearContext();
    #END runfba
    my @_bad_returns;
    (ref($fbaMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"fbaMeta\" (value was \"$fbaMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }
    return($fbaMeta);
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

Export an FBA solution for viewing

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
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["in_fba","in_workspace","format"],{});
    my $fba = $self->_get_msobject("FBA",$input->{in_fba},$input->{in_workspace});
    $output = $fba->export({
	    format => $input->{format}
	});
	$self->_clearContext();
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




=head2 import_phenotypes

  $output = $obj->import_phenotypes($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an import_phenotypes_params
$output is an object_metadata
import_phenotypes_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	phenotypes has a value which is a reference to a list where each element is a Phenotype
	ignore_errors has a value which is a bool
	authentication has a value which is a string
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
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

</pre>

=end html

=begin text

$input is an import_phenotypes_params
$output is an object_metadata
import_phenotypes_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	workspace has a value which is a workspace_id
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	phenotypes has a value which is a reference to a list where each element is a Phenotype
	ignore_errors has a value which is a bool
	authentication has a value which is a string
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
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description

Loads the specified phenotypes into the workspace

=back

=cut

sub import_phenotypes
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_phenotypes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_phenotypes');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN import_phenotypes
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["id","workspace","genome","genome_workspace","phenotypes"],{
		ignore_errors => 0
	});
    
    #Retrieving biochemistry
    my $bio = $self->_get_msobject("Biochemistry","kbase","default");
    #Retrieving specified genome
    my $genomeObj;
    if ($input->{genome_workspace} eq "kbasecdm") {
    	$genomeObj = $self->_get_genomeObj_from_CDM($input->{genome},0);
    } else {
    	$genomeObj = $self->_get_msobject("Genome",$input->{workspace},$input->{genome});
    }
    if (!defined($genomeObj)) {
    	my $msg = "Failed to retrieve genome ".$input->{genome_workspace}."/".$input->{genome};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
    }
    my $genehash = {};
    for (my $i=0; $i < @{$genomeObj->{features}}; $i++) {
    	my $ftr = $genomeObj->{features}->[$i];
    	$genehash->{$ftr->{id}} = $ftr->{id};
    	if (defined($ftr->{aliases})) {
    		for (my $j=0; $j < @{$ftr->{aliases}}; $j++) {
    			$genehash->{$ftr->{aliases}->[$j]} = $ftr->{id};
    		}
    	}
    }
    #Instantiating imported phenotype object
    my $object = {
    	id => $input->{id},
    	genome => $input->{genome},
    	genomeWorkspace => $input->{genome_workspace},
    	phenotypes => [],
    };
    #Validating media, genes, and compounds
    my $missingMedia = [];
    my $missingGenes = [];
    my $missingCompounds = [];
    for (my $i=0; $i < @{$input->{phenotypes}}; $i++) {
    	my $phenotype = $input->{phenotypes}->[$i];
    	#Validating gene IDs
    	my $allfound = 1;
    	for (my $j=0;$j < @{$phenotype->[0]};$j++) {
    		if (!defined($genehash->{$phenotype->[0]->[$j]})) {
    			push(@{$missingGenes},$phenotype->[0]->[$j]);
    			$allfound = 0;
    		} else {
    			$phenotype->[0]->[$j] = $genehash->{$phenotype->[0]->[$j]};
    		}
    	}
    	if ($allfound == 0) {
    		next;
    	}
    	#Validating media
    	if ($phenotype->[2] eq "kbasecdm") {
    		my $media = $bio->queryObject("media",{id => $phenotype->[1]});
    		if (!defined($media)) {
    			push(@{$missingMedia},$phenotype->[1]);
    			next;
    		}
    	} else {
    		try {
    			my $media = $self->_get_msobject("Media",$phenotype->[1],$phenotype->[2]);
	    	} catch {
	    		push(@{$missingMedia},$phenotype->[1]);
	    		next;
	    	};
    	}
    	#Validating compounds
    	$allfound = 1;
    	for (my $j=0;$j < @{$phenotype->[3]};$j++) {
    		my $cpd = $bio->searchForCompound($phenotype->[3]->[$j]);
    		if (!defined($cpd)) {
    			push(@{$missingCompounds},$phenotype->[3]->[$j]);
    			$allfound = 0;
    		} else {
    			$phenotype->[3]->[$j] = $cpd->id();
    		}
    	}
    	if ($allfound == 0) {
    		next;
    	}
    	#Adding phenotype to object
    	push(@{$object->{phenotypes}},$phenotype);
    }
    #Printing error if any entities could not be validated
    my $msg = "";
    if (@{$missingCompounds} > 0) {
    	$msg = "Could not find compounds:".join(";",@{$missingCompounds})."\n";
    }
    if (@{$missingGenes} > 0) {
    	$msg = "Could not find genes:".join(";",@{$missingGenes})."\n";
    }
    if (@{$missingMedia} > 0) {
    	$msg = "Could not find media:".join(";",@{$missingMedia})."\n";
    }
    my $meta = {};
	if (length($msg) > 0 && $input->{ignore_errors} == 0) {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
	} elsif (length($msg) > 0) {
		$object->{importErrors} => $msg;
	}
    #Saving object to database
    my $objmeta = $self->_workspaceServices()->save_object({
		id => $input->{id},
		type => "PhenotypeSet",
		data => $object,
		workspace => $input->{workspace},
		command => "import_phenotypes",
		authentication => $self->_authentication()
	});
	if (!defined($objmeta)) {
		my $msg = "Unable to save object:PhenotypeSet/".$input->{workspace}."/".$input->{id};
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
	}
	$output = $objmeta;
	$self->_clearContext();
    #END import_phenotypes
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_phenotypes:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_phenotypes');
    }
    return($output);
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
	phenotype_set has a value which is a phenotypeSet_id
	phenotype_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotype_simultation_set has a value which is a phenotypeSimulationSet_id
	out_workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	authentication has a value which is a string
fbamodel_id is a string
workspace_id is a string
phenotypeSet_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
phenotypeSimulationSet_id is a string
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

</pre>

=end html

=begin text

$input is a simulate_phenotypes_params
$output is an object_metadata
simulate_phenotypes_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	phenotype_set has a value which is a phenotypeSet_id
	phenotype_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotype_simultation_set has a value which is a phenotypeSimulationSet_id
	out_workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	authentication has a value which is a string
fbamodel_id is a string
workspace_id is a string
phenotypeSet_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
phenotypeSimulationSet_id is a string
object_metadata is a reference to a list containing 7 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description

Simulates the specified phenotype set

=back

=cut

sub simulate_phenotypes
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to simulate_phenotypes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'simulate_phenotypes');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN simulate_phenotypes
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["phenotypeSet","phenotype_workspace","model"],{
		model_workspace => $input->{phenotype_workspace},
		formulation => undef,
		notes => "",
		phenotype_simultation_set => $input->{phenotype_set}.".simulation",
		out_workspace => $input->{phenotype_workspace},
		overwrite => 0
	});
	#Retrieving phenotypes
	my $pheno = $self->_get_msobject("PhenotypeSet",$input->{phenotype_workspace},$input->{phenotype_set});
	#Retrieving model
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	#Creating FBAFormulation Object
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $fba = $self->_buildFBAObject($input->{formulation});
	#Translating phenotypes to fbaformulation
	my $bio = $self->_get_msobject("Biochemistry","kbase","default");
	for (my $i=0; $i < @{$pheno->{phenotypes}};$i++) {
		my $media = $pheno->{phenotypes}->[$i]->[2]."/".$pheno->{phenotypes}->[$i]->[1]; 
		if ($pheno->{phenotypes}->[$i]->[2] eq "kbasecdm") {
			$media = $pheno->{phenotypes}->[$i]->[1];
		} else {
			my $mediaobj = $self->_get_msobject("Media",$pheno->{phenotypes}->[$i]->[2],$pheno->{phenotypes}->[$i]->[1]);
			$bio->add("media",$mediaobj);
		}
		my $newpheno = {
			label => $i,
			media => $media,
			geneKOs => $pheno->{phenotypes}->[$i]->[0],
			reactionKOs => [],
			additionalCpds => $pheno->{phenotypes}->[$i]->[3],
			pH => 7,
			temperature => 303,
			growth => $pheno->{phenotypes}->[$i]->[4]
		};
		$fba->add("fbaPhenotypeSimulations",$newpheno);
	}
	#Running FBA
	my $fbaResult = $fba->runFBA();
	if (!defined($fbaResult) || @{$fbaResult->fbaPhenotypeSimultationResults()} == 0) {
    	my $msg = "Simulation of phenotypes failed to return results from FBA!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'simulate_phenotypes');
    }
	#Converting FBA results into simulated phenotype
    my $object = {
    	id => $input->{phenotypeSimultationSet},
    	model => $input->{model},
    	modelWorkspace => $input->{model_workspace},
    	phenotypeSimulations => []
    };
    my $phenoresults = $fbaResult->fbaPhenotypeSimultationResults();
    for (my $i=0; $i < @{$pheno->{phenotypes}};$i++) {
    	my $phenoResult = $phenoresults->[$i];
    	my $phenosim = [
    		$pheno->{phenotypes}->[$i],
    		$phenoResult->simulatedGrowth(),
    		$phenoResult->simulatedGrowthFraction(),
    		$phenoResult->class()
    	];
    	push(@{$object->{phenotypeSimulations}},$phenosim);
    }
    #Saving object to database
    my $objmeta = $self->_workspaceServices()->save_object({
		id => $input->{phenotypeSimultationSet},
		type => "PhenotypeSimulationSet",
		data => $object,
		workspace => $input->{out_workspace},
		command => "simulate_phenotypes",
		authentication => $self->_authentication(),
		overwrite => $input->{overwrite}
	});
	$output = $objmeta;
	$self->_clearContext();
    #END simulate_phenotypes
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to simulate_phenotypes:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'simulate_phenotypes');
    }
    return($output);
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
	authentication has a value which is a string
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
	authentication has a value which is a string
phenotypeSimulationSet_id is a string
workspace_id is a string


=end text



=item Description

Export a PhenotypeSimulationSet for viewing

=back

=cut

sub export_phenotypeSimulationSet
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_phenotypeSimulationSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_phenotypeSimulationSet');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN export_phenotypeSimulationSet
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["phenotypeSimulationSet","workspace","format"],{});
	my $obj = $self->_get_msobject("PhenotypeSimulationSet",$input->{workspace},$input->{phenotypeSimulationSet});
	my $output;
	if ($input->{format} eq "text") {
		$output = "Base media\tAdditional compounds\tGene KO\tGrowth\tSimulated growth\tSimulated growth fraction\tClass\n";
		for (my $i=0; $i < @{$obj->{phenotypeSimulations}}; $i++) {
			my $phenosim = $obj->{phenotypeSimulations}->[$i];
			$output .= 	$phenosim->[0]->[1]."\t".
						join(";",@{$phenosim->[0]->[3]})."\t".
						join(";",@{$phenosim->[0]->[0]})."\t".
						$phenosim->[0]->[4]."\t".
						$phenosim->[1]."\t".
						$phenosim->[2]."\t".
						$phenosim->[3]."\n";
		}
	} else {
		my $msg = "Specified format ".$input->{format}." not recognized!\n";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'export_phenotypeSimulationSet');
	}
	$self->_clearContext();
    #END export_phenotypeSimulationSet
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to export_phenotypeSimulationSet:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_phenotypeSimulationSet');
    }
    return($output);
}




=head2 queue_runfba

  $output = $obj->queue_runfba($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a runfba_params
$output is a JobObject
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
	fba_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
fba_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string

</pre>

=end html

=begin text

$input is a runfba_params
$output is a JobObject
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
	fba_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
fba_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string


=end text



=item Description

Queues an FBA job in a single media condition

=back

=cut

sub queue_runfba
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_runfba');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN queue_runfba
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","model_workspace"],{
		formulation => undef,
		fva => 0,
		simulateko => 0,
		minimizeflux => 0,
		findminmedia => 0,
		notes => "",
		fba_workspace => $input->{model_workspace},
		fba => undef
	});
	#Creating FBAFormulation Object
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $fba = $self->_buildFBAObject($input->{formulation});
	#Saving FBAFormulation to database
	$self->_save_msobject($fba,"FBA",$input->{fba},$input->{fba},"queue_runfba")
	my $job = {
		id => Data::UUID->new()->create_str(),
		queuetime => DateTime->now()->datetime();
		complete => 0,
		type => "FBA",
		arguments => {
			fba_id => $input->{fba},
			fba_workspace => $input->{fba_workspace},
		},
		owner => $self->_getUsername(),
		queuing_command => "queue_runfba";
		queuing_service => "fbaModelServicesClient";
		postprocess_command => "";
		postprocess_args => [];
	};
	$self->_save_msobject($job,"JobObject",$input->{fba_workspace},$job->{id},"queue_runfba");
	$output = $job;
	$self->_clearContext();
    #END queue_runfba
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_runfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_runfba');
    }
    return($output);
}




=head2 queue_gapfill_model

  $output = $obj->queue_gapfill_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapfill_model_params
$output is a JobObject
gapfill_model_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	no_media_hypothesis has a value which is a bool
	no_biomass_hypothesis has a value which is a bool
	no_gpr_hypothesis has a value which is a bool
	no_pathway_hypothesis has a value which is a bool
	allow_unbalanced has a value which is a bool
	activity_bonus has a value which is a float
	drain_penalty has a value which is a float
	direction_penalty has a value which is a float
	no_structure_penalty has a value which is a float
	unfavorable_penalty has a value which is a float
	no_deltag_penalty has a value which is a float
	biomass_transport_penalty has a value which is a float
	single_transport_penalty has a value which is a float
	transport_penalty has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowed_compartments has a value which is a reference to a list where each element is a string
	integrate_solution has a value which is a bool
	notes has a value which is a string
	prob_anno has a value which is a genome_id
	prob_anno_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
	gapfilling_index has a value which is an int
	job has a value which is a job_id
phenotypeSet_id is a string
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
genome_id is a string
job_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string

</pre>

=end html

=begin text

$input is a gapfill_model_params
$output is a JobObject
gapfill_model_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	no_media_hypothesis has a value which is a bool
	no_biomass_hypothesis has a value which is a bool
	no_gpr_hypothesis has a value which is a bool
	no_pathway_hypothesis has a value which is a bool
	allow_unbalanced has a value which is a bool
	activity_bonus has a value which is a float
	drain_penalty has a value which is a float
	direction_penalty has a value which is a float
	no_structure_penalty has a value which is a float
	unfavorable_penalty has a value which is a float
	no_deltag_penalty has a value which is a float
	biomass_transport_penalty has a value which is a float
	single_transport_penalty has a value which is a float
	transport_penalty has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowed_compartments has a value which is a reference to a list where each element is a string
	integrate_solution has a value which is a bool
	notes has a value which is a string
	prob_anno has a value which is a genome_id
	prob_anno_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
	gapfilling_index has a value which is an int
	job has a value which is a job_id
phenotypeSet_id is a string
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
genome_id is a string
job_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string


=end text



=item Description

Queues an FBAModel gapfilling job in single media condition

=back

=cut

sub queue_gapfill_model
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_gapfill_model');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN queue_gapfill_model
    #END queue_gapfill_model
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_gapfill_model');
    }
    return($output);
}




=head2 queue_gapgen_model

  $output = $obj->queue_gapgen_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapgen_model_params
$output is a JobObject
gapgen_model_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	no_media_hypothesis has a value which is a bool
	no_biomass_hypothesis has a value which is a bool
	no_gpr_hypothesis has a value which is a bool
	no_pathway_hypothesis has a value which is a bool
	integrate_solution has a value which is a bool
	notes has a value which is a string
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
	gapgen_index has a value which is an int
phenotypeSet_id is a string
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string

</pre>

=end html

=begin text

$input is a gapgen_model_params
$output is a JobObject
gapgen_model_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	no_media_hypothesis has a value which is a bool
	no_biomass_hypothesis has a value which is a bool
	no_gpr_hypothesis has a value which is a bool
	no_pathway_hypothesis has a value which is a bool
	integrate_solution has a value which is a bool
	notes has a value which is a string
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
	gapgen_index has a value which is an int
phenotypeSet_id is a string
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string


=end text



=item Description

Queues an FBAModel gapfilling job in single media condition

=back

=cut

sub queue_gapgen_model
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_gapgen_model');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN queue_gapgen_model
    #END queue_gapgen_model
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_gapgen_model');
    }
    return($output);
}




=head2 queue_wildtype_phenotype_reconciliation

  $output = $obj->queue_wildtype_phenotype_reconciliation($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a wildtype_phenotype_reconciliation_params
$output is a JobObject
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	no_media_hypothesis has a value which is a bool
	no_biomass_hypothesis has a value which is a bool
	no_gpr_hypothesis has a value which is a bool
	no_pathway_hypothesis has a value which is a bool
	allow_unbalanced has a value which is a bool
	activity_bonus has a value which is a float
	drain_penalty has a value which is a float
	direction_penalty has a value which is a float
	no_structure_penalty has a value which is a float
	unfavorable_penalty has a value which is a float
	no_deltag_penalty has a value which is a float
	biomass_transport_penalty has a value which is a float
	single_transport_penalty has a value which is a float
	transport_penalty has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowed_compartments has a value which is a reference to a list where each element is a string
	notes has a value which is a string
	prob_anno has a value which is a genome_id
	prob_anno_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
	all_gapgen_indecies has a value which is a reference to a list where each element is an int
	all_gapfill_indecies has a value which is a reference to a list where each element is an int
	gapgen_index has a value which is an int
	gapfill_index has a value which is an int
phenotypeSet_id is a string
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
genome_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string

</pre>

=end html

=begin text

$input is a wildtype_phenotype_reconciliation_params
$output is a JobObject
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	id has a value which is a phenotypeSet_id
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	no_media_hypothesis has a value which is a bool
	no_biomass_hypothesis has a value which is a bool
	no_gpr_hypothesis has a value which is a bool
	no_pathway_hypothesis has a value which is a bool
	allow_unbalanced has a value which is a bool
	activity_bonus has a value which is a float
	drain_penalty has a value which is a float
	direction_penalty has a value which is a float
	no_structure_penalty has a value which is a float
	unfavorable_penalty has a value which is a float
	no_deltag_penalty has a value which is a float
	biomass_transport_penalty has a value which is a float
	single_transport_penalty has a value which is a float
	transport_penalty has a value which is a float
	blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
	gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
	allowed_compartments has a value which is a reference to a list where each element is a string
	notes has a value which is a string
	prob_anno has a value which is a genome_id
	prob_anno_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
	all_gapgen_indecies has a value which is a reference to a list where each element is an int
	all_gapfill_indecies has a value which is a reference to a list where each element is an int
	gapgen_index has a value which is an int
	gapfill_index has a value which is an int
phenotypeSet_id is a string
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
genome_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string


=end text



=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_wildtype_phenotype_reconciliation
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_wildtype_phenotype_reconciliation');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN queue_wildtype_phenotype_reconciliation
    #END queue_wildtype_phenotype_reconciliation
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_wildtype_phenotype_reconciliation');
    }
    return($output);
}




=head2 queue_combine_wildtype_phenotype_reconciliation_params

  $output = $obj->queue_combine_wildtype_phenotype_reconciliation_params($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a combine_wildtype_phenotype_reconciliation_params
$output is a JobObject
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	integrate_solution has a value which is a bool
	notes has a value which is a string
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string

</pre>

=end html

=begin text

$input is a combine_wildtype_phenotype_reconciliation_params
$output is a JobObject
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	in_model has a value which is a fbamodel_id
	in_workspace has a value which is a workspace_id
	in_formulation has a value which is an FBAFormulation
	num_solutions has a value which is an int
	integrate_solution has a value which is a bool
	notes has a value which is a string
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	authentication has a value which is a string
	overwrite has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	workspace has a value which is a workspace_id
	objfraction has a value which is a float
	allreversible has a value which is a bool
	objective has a value which is a string
	geneko has a value which is a reference to a list where each element is a feature_id
	rxnko has a value which is a reference to a list where each element is a reaction_id
	bounds has a value which is a reference to a list where each element is a string
	constraints has a value which is a reference to a list where each element is a string
	uptakelim has a value which is a reference to a hash where the key is a string and the value is a float
	defaultmaxflux has a value which is a float
	defaultminuptake has a value which is a float
	defaultmaxuptake has a value which is a float
	simplethermoconst has a value which is a bool
	thermoconst has a value which is a bool
	nothermoerror has a value which is a bool
	minthermoerror has a value which is a bool
media_id is a string
bool is an int
feature_id is a string
reaction_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
job_id is a string
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string


=end text



=item Description

Queues an FBAModel reconciliation job

=back

=cut

sub queue_combine_wildtype_phenotype_reconciliation_params
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_combine_wildtype_phenotype_reconciliation_params:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_combine_wildtype_phenotype_reconciliation_params');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN queue_combine_wildtype_phenotype_reconciliation_params
    #END queue_combine_wildtype_phenotype_reconciliation_params
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_combine_wildtype_phenotype_reconciliation_params:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_combine_wildtype_phenotype_reconciliation_params');
    }
    return($output);
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
	job has a value which is a job_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
bool is an int
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string

</pre>

=end html

=begin text

$input is a check_job_params
$output is a JobObject
check_job_params is a reference to a hash where the following keys are defined:
	job has a value which is a job_id
	workspace has a value which is a workspace_id
	authentication has a value which is a string
job_id is a string
workspace_id is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	queuetime has a value which is a string
	completetime has a value which is a string
	complete has a value which is a bool
	object has a value which is a string
	workspace has a value which is a string
	type has a value which is a string
	owner has a value which is a string
	queuing_command has a value which is a string
	queuing_service has a value which is a string
	postprocess_command has a value which is a string
	postprocess_args has a value which is a reference to a list where each element is a CommandArguments
bool is an int
CommandArguments is a reference to a hash where the following keys are defined:
	authentication has a value which is a string


=end text



=item Description

Retreives job data given a job ID

=back

=cut

sub check_job
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to check_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'check_job');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($output);
    #BEGIN check_job
    #END check_job
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to check_job:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'check_job');
    }
    return($output);
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



=head2 object_type

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



=head2 object_id

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



=head2 username

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



=head2 timestamp

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



=head2 object_metadata

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 7 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a string
5: a username
6: a username

</pre>

=end html

=begin text

a reference to a list containing 7 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a string
5: a username
6: a username


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
authentication has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genomeobj has a value which is a genomeTO
workspace has a value which is a workspace_id
authentication has a value which is a string
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
authentication has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
workspace has a value which is a workspace_id
authentication has a value which is a string
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
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
authentication has a value which is a string
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
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string


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
authentication has a value which is a string

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
authentication has a value which is a string


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
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a media_id
workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string


=end text

=back



=head2 FBAFormulation

=over 4



=item Description

NEED DOCUMENTATION


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a media_id
workspace has a value which is a workspace_id
objfraction has a value which is a float
allreversible has a value which is a bool
objective has a value which is a string
geneko has a value which is a reference to a list where each element is a feature_id
rxnko has a value which is a reference to a list where each element is a reaction_id
bounds has a value which is a reference to a list where each element is a string
constraints has a value which is a reference to a list where each element is a string
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
workspace has a value which is a workspace_id
objfraction has a value which is a float
allreversible has a value which is a bool
objective has a value which is a string
geneko has a value which is a reference to a list where each element is a feature_id
rxnko has a value which is a reference to a list where each element is a reaction_id
bounds has a value which is a reference to a list where each element is a string
constraints has a value which is a reference to a list where each element is a string
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



=head2 runfba_params

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
fba_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool

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
fba_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 export_fba_params

=over 4



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



=head2 phenotypeSet_id

=over 4



=item Description

********************************************************************************
    Code relating to phenotype simulation and reconciliation
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



=head2 Phenotype

=over 4



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
genomeWorkspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
importErrors has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
genome has a value which is a genome_id
genomeWorkspace has a value which is a workspace_id
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
modelWorkspace has a value which is a workspace_id
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSimulations has a value which is a reference to a list where each element is a PhenotypeSimulation

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSimulationSet_id
model has a value which is a fbamodel_id
modelWorkspace has a value which is a workspace_id
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
id has a value which is a phenotypeSet_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
ignore_errors has a value which is a bool
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
workspace has a value which is a workspace_id
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
phenotypes has a value which is a reference to a list where each element is a Phenotype
ignore_errors has a value which is a bool
authentication has a value which is a string


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
phenotype_set has a value which is a phenotypeSet_id
phenotype_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
notes has a value which is a string
phenotype_simultation_set has a value which is a phenotypeSimulationSet_id
out_workspace has a value which is a workspace_id
overwrite has a value which is a bool
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
phenotype_set has a value which is a phenotypeSet_id
phenotype_workspace has a value which is a workspace_id
formulation has a value which is an FBAFormulation
notes has a value which is a string
phenotype_simultation_set has a value which is a phenotypeSimulationSet_id
out_workspace has a value which is a workspace_id
overwrite has a value which is a bool
authentication has a value which is a string


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
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotypeSimulationSet has a value which is a phenotypeSimulationSet_id
workspace has a value which is a workspace_id
format has a value which is a string
authentication has a value which is a string


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
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
authentication has a value which is a string


=end text

=back



=head2 JobObject

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a job_id
queuetime has a value which is a string
completetime has a value which is a string
complete has a value which is a bool
object has a value which is a string
workspace has a value which is a string
type has a value which is a string
owner has a value which is a string
queuing_command has a value which is a string
queuing_service has a value which is a string
postprocess_command has a value which is a string
postprocess_args has a value which is a reference to a list where each element is a CommandArguments

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a job_id
queuetime has a value which is a string
completetime has a value which is a string
complete has a value which is a bool
object has a value which is a string
workspace has a value which is a string
type has a value which is a string
owner has a value which is a string
queuing_command has a value which is a string
queuing_service has a value which is a string
postprocess_command has a value which is a string
postprocess_args has a value which is a reference to a list where each element is a CommandArguments


=end text

=back



=head2 gapfill_model_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
no_media_hypothesis has a value which is a bool
no_biomass_hypothesis has a value which is a bool
no_gpr_hypothesis has a value which is a bool
no_pathway_hypothesis has a value which is a bool
allow_unbalanced has a value which is a bool
activity_bonus has a value which is a float
drain_penalty has a value which is a float
direction_penalty has a value which is a float
no_structure_penalty has a value which is a float
unfavorable_penalty has a value which is a float
no_deltag_penalty has a value which is a float
biomass_transport_penalty has a value which is a float
single_transport_penalty has a value which is a float
transport_penalty has a value which is a float
blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
allowed_compartments has a value which is a reference to a list where each element is a string
integrate_solution has a value which is a bool
notes has a value which is a string
prob_anno has a value which is a genome_id
prob_anno_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool
gapfilling_index has a value which is an int
job has a value which is a job_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
no_media_hypothesis has a value which is a bool
no_biomass_hypothesis has a value which is a bool
no_gpr_hypothesis has a value which is a bool
no_pathway_hypothesis has a value which is a bool
allow_unbalanced has a value which is a bool
activity_bonus has a value which is a float
drain_penalty has a value which is a float
direction_penalty has a value which is a float
no_structure_penalty has a value which is a float
unfavorable_penalty has a value which is a float
no_deltag_penalty has a value which is a float
biomass_transport_penalty has a value which is a float
single_transport_penalty has a value which is a float
transport_penalty has a value which is a float
blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
allowed_compartments has a value which is a reference to a list where each element is a string
integrate_solution has a value which is a bool
notes has a value which is a string
prob_anno has a value which is a genome_id
prob_anno_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool
gapfilling_index has a value which is an int
job has a value which is a job_id


=end text

=back



=head2 gapgen_model_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
no_media_hypothesis has a value which is a bool
no_biomass_hypothesis has a value which is a bool
no_gpr_hypothesis has a value which is a bool
no_pathway_hypothesis has a value which is a bool
integrate_solution has a value which is a bool
notes has a value which is a string
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool
gapgen_index has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
no_media_hypothesis has a value which is a bool
no_biomass_hypothesis has a value which is a bool
no_gpr_hypothesis has a value which is a bool
no_pathway_hypothesis has a value which is a bool
integrate_solution has a value which is a bool
notes has a value which is a string
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool
gapgen_index has a value which is an int


=end text

=back



=head2 wildtype_phenotype_reconciliation_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
no_media_hypothesis has a value which is a bool
no_biomass_hypothesis has a value which is a bool
no_gpr_hypothesis has a value which is a bool
no_pathway_hypothesis has a value which is a bool
allow_unbalanced has a value which is a bool
activity_bonus has a value which is a float
drain_penalty has a value which is a float
direction_penalty has a value which is a float
no_structure_penalty has a value which is a float
unfavorable_penalty has a value which is a float
no_deltag_penalty has a value which is a float
biomass_transport_penalty has a value which is a float
single_transport_penalty has a value which is a float
transport_penalty has a value which is a float
blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
allowed_compartments has a value which is a reference to a list where each element is a string
notes has a value which is a string
prob_anno has a value which is a genome_id
prob_anno_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool
all_gapgen_indecies has a value which is a reference to a list where each element is an int
all_gapfill_indecies has a value which is a reference to a list where each element is an int
gapgen_index has a value which is an int
gapfill_index has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a phenotypeSet_id
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
no_media_hypothesis has a value which is a bool
no_biomass_hypothesis has a value which is a bool
no_gpr_hypothesis has a value which is a bool
no_pathway_hypothesis has a value which is a bool
allow_unbalanced has a value which is a bool
activity_bonus has a value which is a float
drain_penalty has a value which is a float
direction_penalty has a value which is a float
no_structure_penalty has a value which is a float
unfavorable_penalty has a value which is a float
no_deltag_penalty has a value which is a float
biomass_transport_penalty has a value which is a float
single_transport_penalty has a value which is a float
transport_penalty has a value which is a float
blacklistedrxns has a value which is a reference to a list where each element is a reaction_id
gauranteedrxns has a value which is a reference to a list where each element is a reaction_id
allowed_compartments has a value which is a reference to a list where each element is a string
notes has a value which is a string
prob_anno has a value which is a genome_id
prob_anno_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool
all_gapgen_indecies has a value which is a reference to a list where each element is an int
all_gapfill_indecies has a value which is a reference to a list where each element is an int
gapgen_index has a value which is an int
gapfill_index has a value which is an int


=end text

=back



=head2 combine_wildtype_phenotype_reconciliation_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
integrate_solution has a value which is a bool
notes has a value which is a string
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
in_model has a value which is a fbamodel_id
in_workspace has a value which is a workspace_id
in_formulation has a value which is an FBAFormulation
num_solutions has a value which is an int
integrate_solution has a value which is a bool
notes has a value which is a string
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
authentication has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 check_job_params

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
job has a value which is a job_id
workspace has a value which is a workspace_id
authentication has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
job has a value which is a job_id
workspace has a value which is a workspace_id
authentication has a value which is a string


=end text

=back



=cut

1;
