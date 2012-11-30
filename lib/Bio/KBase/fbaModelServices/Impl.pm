package Bio::KBase::fbaModelServices::Impl;
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
use Bio::KBase::IDServer::Client;
use Bio::KBase::CDMI::CDMIClient;
use KBase::ClusterService;
use Bio::KBase::workspaceService::Client;
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
use ModelSEED::MS::GapgenFormulation;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::FBAProblem;
use ModelSEED::MS::Metadata::Definitions;
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
    if ( defined $params->{auth} ) {
        my $token = Bio::KBase::AuthToken->new(
            token => $params->{auth},
        );
        if ($token->validate()) {
            $self->{_currentUser} = $token->user_id;
        } else {
            Bio::KBase::Exceptions::KBaseException->throw(error => "Invalid authorization token!",
                method_name => 'workspaceDocument::_setContext');
        }
    }
	$self->{_authentication} = $params->{auth};
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
	if ($size == 0) {
		$gc = 0.5;
		$size = 0;
	} else {
		$gc = $gc / $size;
	}
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
	if (defined($obj->{_kbaseWSMeta})) {
		delete $obj->{_kbaseWSMeta};
	}
	if ($type eq "Genome" && defined($obj->{contigs})) {
		$obj->{contigs} = [];
	}
	if ($type eq "Model") {
		$obj->{uuid} = $ws."/".$id;
	}
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
		auth => $self->_authentication(),
		overwrite => $overwrite
	});
	if (!defined($objmeta)) {
		my $msg = "Unable to save object:".$type."/".$ws."/".$id;
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_msobject');
	}
	$obj->{_kbaseWSMeta}->{wsid} = $id;
	$obj->{_kbaseWSMeta}->{ws} = $ws;
	$obj->{_kbaseWSMeta}->{wsinst} = $objmeta->[3];	
	return $objmeta;
}

sub _get_msobject {
	my($self,$type,$ws,$id,$cache) = @_;
	if (defined($cache->{$type}->{$ws}->{$id})) {
		return $cache->{$type}->{$ws}->{$id};
	}
	my $output = $self->_workspaceServices()->get_object({
		id => $id,
		type => $type,
		workspace => $ws,
		auth => $self->_authentication()
	});
	if (!defined($output->{data})) {
		my $msg = "Unable to retrieve object:".$type."/".$ws."/".$id;
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_msobject');
	}
	my $msProvTypes = {
		Biochemistry => "Biochemistry",
		Model => "Model",
		Annotation => "Annotation",
		Mapping => "Mapping",
		FBA => "FBAFormulation",
		Media => "Media",
		GapFill => "GapfillingFormulation",
		GapGen => "GapgenFormulation",
		PROMModel => "PROMModel"
	};
	my $obj;
	if (defined($msProvTypes->{$type})) {
		my $class = "ModelSEED::MS::".$msProvTypes->{$type};
		$obj = $class->new($output->{data});
		$cache->{$type}->{$ws}->{$id} = $obj;
		if ($type eq "Model") {
			my $linkid = $obj->annotation_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->annotation($self->_get_msobject("Annotation",$array->[0],$array->[1],$cache));
			$obj->mapping($obj->annotation()->mapping());
			$obj->biochemistry($obj->mapping()->biochemistry());
			my $subobjs = {
				fbaFormulation_uuids => ["fbaFormulations","FBA"],
				unintegratedGapfilling_uuids => ["unintegratedGapfillings","GapFill"],
				integratedGapfilling_uuids => ["integratedGapfillings","GapFill"],
				unintegratedGapgen_uuids => ["unintegratedGapgens","GapGen"],
				integratedGapgen_uuids => ["integratedGapgens","GapGen"]
			};
			foreach my $attribute (keys(%{$subobjs})) {
				my $link = $subobjs->{$attribute}->[0];
				my $linkType = $subobjs->{$attribute}->[1];
				my $array = [];
				for (my $i=0; $i < @{$obj->$attribute()}; $i++) {
					my $linkid = $obj->$attribute()->[$i];
					my $array = [split(/\//,$linkid)];
					my $object = $self->_get_msobject($linkType,$array->[0],$array->[1],$cache);
					$array->[$i] = $object;
				}
				if (@{$array} > 0) {
					$obj->$link($array);
				}
			}
		} elsif ($type eq "Annotation") {
			my $linkid = $obj->mapping_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->mapping($self->_get_msobject("Mapping",$array->[0],$array->[1],$cache));
		} elsif ($type eq "Mapping") {
			my $linkid = $obj->biochemistry_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->biochemistry($self->_get_msobject("Biochemistry",$array->[0],$array->[1],$cache));
		} elsif ($type eq "FBA") {
			my $linkid = $obj->model_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->model($self->_get_msobject("Model",$array->[0],$array->[1],$cache));
			my $mediauuids = $obj->mediaUUIDs();
			foreach my $media (@{$mediauuids}) {
				if ($media =~ m/(.+)\/(.+)/) {
					my $mediaobj = $self->_get_msobject("Media",$1,$2,$cache);
					$obj->model()->biochemistry()->add("media",$mediaobj);
				}
			}
		} elsif ($type eq "GapFill") {
			my $linkid = $obj->fbaFormulation_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->fbaFormulation($self->_get_msobject("FBA",$array->[0],$array->[1],$cache));
			$obj->model($obj->fbaFormulation()->model());
		} elsif ($type eq "GapGen") {
			my $linkid = $obj->fbaFormulation_uuid();
			my $array = [split(/\//,$linkid)];
			$obj->fbaFormulation($self->_get_msobject("FBA",$array->[0],$array->[1],$cache));
			$obj->model($obj->fbaFormulation()->model());
		}
		delete $cache->{$type}->{$ws}->{$id};
	} else {
		$obj = $output->{data};
	}
	$obj->{_kbaseWSMeta}->{wsid} = $id;
	$obj->{_kbaseWSMeta}->{ws} = $ws;
	$obj->{_kbaseWSMeta}->{wsinst} = $output->{metadata}->[3];	
	return $obj;
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
		maximizeObjective => 1,
		objectiveTerms => [
			[1,"biomassflux","bio1"]
		],
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
	my ($self,$fbaFormulation,$model,$workspace,$id) = @_;
	#Parsing media
	my $media;
	if ($fbaFormulation->{media_workspace} ne "kbasecdm") {
		my $mediaobj = $self->_get_msobject("Media",$fbaFormulation->{media_workspace},$fbaFormulation->{media});
		$model->biochemistry()->add("media",$mediaobj);
		$media = $fbaFormulation->{media_workspace}."/".$fbaFormulation->{media};
	} else {
		my $mediaObj = $model->biochemistry()->queryObject("media",{
			id => $fbaFormulation->{media}
		});
		if (!defined($mediaObj)) {
			my $msg = "Media object ".$fbaFormulation->{media}." not found in biochemistry!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
		}
		$media = $mediaObj->uuid();
	}
	#Building FBAFormulation object
	my $form = ModelSEED::MS::FBAFormulation->new({
		uuid => $workspace."/".$id,
		model_uuid => $model->uuid(),
		model => $model,
		media_uuid => $media,
		type => "singlegrowth",
		notes => "",
		simpleThermoConstraints => $fbaFormulation->{simplethermoconst},
		thermodynamicConstraints => $fbaFormulation->{thermoconst},
		noErrorThermodynamicConstraints => $fbaFormulation->{nothermoerror},
		minimizeErrorThermodynamicConstraints => $fbaFormulation->{minthermoerror},
		fva => 0,
		comboDeletions => 0,
		fluxMinimization => 0,
		findMinimalMedia => 0,
		objectiveConstraintFraction => $fbaFormulation->{objfraction},
		allReversible => $fbaFormulation->{allreversible},
		uptakeLimits => $fbaFormulation->{uptakelim},
		defaultMaxFlux => $fbaFormulation->{defaultmaxflux},
		defaultMaxDrainFlux => $fbaFormulation->{defaultmaxuptake},
		defaultMinDrainFlux => $fbaFormulation->{defaultminuptake},
		maximizeObjective => $fbaFormulation->{maximizeObjective},
		decomposeReversibleFlux => 0,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 0,
		drainfluxUseVariables => 0,
		parameters => {},
		numberOfSolutions => 1,
	});
	$form->{_kbaseWSMeta}->{wsid} = $id;
	$form->{_kbaseWSMeta}->{ws} = $workspace;
	#Parse objective equation
	foreach my $term (@{$fbaFormulation->{objectiveTerms}}) {
		my $output = $self->_parseTerm($term,$model);
		$form->add("fbaObjectiveTerms",{
			coefficient => $output->{coef},
			variableType => $output->{vartype},
			entityType => $output->{enttype},
			entity_uuid => $output->{uuid},
		});
	}
	#Parse constraints
	foreach my $constraint (@{$fbaFormulation->{constraints}}) {
		my $const = $form->add("fbaConstraints",{
			name => $constraint->[3],
			rhs => $constraint->[0],
			sign => $constraint->[1],
		});
		foreach my $term (@{$const->[2]}) {
			my $output = $self->_parseTerm($term,$model);
			$const->add("fbaConstraintVariables",{
				coefficient => $output->{coef},
				variableType => $output->{vartype},
				entityType => $output->{enttype},
				entity_uuid => $output->{uuid},
			});
		}
	}
	#Parse bounds
	foreach my $bound (@{$fbaFormulation->{bounds}}) {
		my $bound = $self->_parseBound($bound);
		$form->add($bound->{boundtype},{
			modelreaction_uuid => $bound->{uuid},
			variableType => $bound->{vartype},
			upperBound => $bound->{upperbound},
			lowerBound => $bound->{lowerbound}
		});
	}
	#Parsing gene KO
	my $anno = $model->annotation();
	foreach my $gene (@{$fbaFormulation->{geneko}}) {
		my $geneObj = $anno->queryObject("features",{id => $gene});
		if (defined($geneObj)) {
			$form->addLinkArrayItem("geneKOs",$geneObj);
		}
	}
	#Parsing reaction KO
	foreach my $reaction (@{$fbaFormulation->{reactionKO}}) {
		my $rxnObj = $model->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$form->addLinkArrayItem("reactionKOs",$rxnObj);
		}
	}
	return $form;
}

sub _setDefaultGapfillFormulation {
	my ($self,$formulation) = @_;
	if (!defined($formulation)) {
		$formulation = {};
	}
	$formulation = $self->_validateargs($formulation,[],{
		formulation => undef,
		num_solutions => 1,
		nomediahyp => 0,
		nobiomasshyp => 0,
		nogprhyp => 0,
		nopathwayhyp => 0,
		allowunbalanced => 0,
		activitybonus => 0,
		drainpen => 1,
		directionpen => 1,
		nostructpen => 1,
		unfavorablepen => 1,
		nodeltagpen => 1,
		biomasstranspen => 1,
		singletranspen => 1,
		transpen => 1,
		blacklistedrxns => [qw(
rxn12985 rxn00238 rxn07058 rxn05305 rxn00154 rxn09037 rxn10643
rxn11317 rxn05254 rxn05257 rxn05258 rxn05259 rxn05264 rxn05268
rxn05269 rxn05270 rxn05271 rxn05272 rxn05273 rxn05274 rxn05275
rxn05276 rxn05277 rxn05278 rxn05279 rxn05280 rxn05281 rxn05282
rxn05283 rxn05284 rxn05285 rxn05286 rxn05963 rxn05964 rxn05971
rxn05989 rxn05990 rxn06041 rxn06042 rxn06043 rxn06044 rxn06045
rxn06046 rxn06079 rxn06080 rxn06081 rxn06086 rxn06087 rxn06088
rxn06089 rxn06090 rxn06091 rxn06092 rxn06138 rxn06139 rxn06140
rxn06141 rxn06145 rxn06217 rxn06218 rxn06219 rxn06220 rxn06221
rxn06222 rxn06223 rxn06235 rxn06362 rxn06368 rxn06378 rxn06474
rxn06475 rxn06502 rxn06562 rxn06569 rxn06604 rxn06702 rxn06706
rxn06715 rxn06803 rxn06811 rxn06812 rxn06850 rxn06901 rxn06971
rxn06999 rxn07123 rxn07172 rxn07254 rxn07255 rxn07269 rxn07451
rxn09037 rxn10018 rxn10077 rxn10096 rxn10097 rxn10098 rxn10099
rxn10101 rxn10102 rxn10103 rxn10104 rxn10105 rxn10106 rxn10107
rxn10109 rxn10111 rxn10403 rxn10410 rxn10416 rxn11313 rxn11316
rxn11318 rxn11353 rxn05224 rxn05795 rxn05796 rxn05797 rxn05798
rxn05799 rxn05801 rxn05802 rxn05803 rxn05804 rxn05805 rxn05806
rxn05808 rxn05812 rxn05815 rxn05832 rxn05836 rxn05851 rxn05857
rxn05869 rxn05870 rxn05884 rxn05888 rxn05896 rxn05898 rxn05900
rxn05903 rxn05904 rxn05905 rxn05911 rxn05921 rxn05925 rxn05936
rxn05947 rxn05956 rxn05959 rxn05960 rxn05980 rxn05991 rxn05992
rxn05999 rxn06001 rxn06014 rxn06017 rxn06021 rxn06026 rxn06027
rxn06034 rxn06048 rxn06052 rxn06053 rxn06054 rxn06057 rxn06059
rxn06061 rxn06102 rxn06103 rxn06127 rxn06128 rxn06129 rxn06130
rxn06131 rxn06132 rxn06137 rxn06146 rxn06161 rxn06167 rxn06172
rxn06174 rxn06175 rxn06187 rxn06189 rxn06203 rxn06204 rxn06246
rxn06261 rxn06265 rxn06266 rxn06286 rxn06291 rxn06294 rxn06310
rxn06320 rxn06327 rxn06334 rxn06337 rxn06339 rxn06342 rxn06343
rxn06350 rxn06352 rxn06358 rxn06361 rxn06369 rxn06380 rxn06395
rxn06415 rxn06419 rxn06420 rxn06421 rxn06423 rxn06450 rxn06457
rxn06463 rxn06464 rxn06466 rxn06471 rxn06482 rxn06483 rxn06486
rxn06492 rxn06497 rxn06498 rxn06501 rxn06505 rxn06506 rxn06521
rxn06534 rxn06580 rxn06585 rxn06593 rxn06609 rxn06613 rxn06654
rxn06667 rxn06676 rxn06693 rxn06730 rxn06746 rxn06762 rxn06779
rxn06790 rxn06791 rxn06792 rxn06793 rxn06794 rxn06795 rxn06796
rxn06797 rxn06821 rxn06826 rxn06827 rxn06829 rxn06839 rxn06841
rxn06842 rxn06851 rxn06866 rxn06867 rxn06873 rxn06885 rxn06891
rxn06892 rxn06896 rxn06938 rxn06939 rxn06944 rxn06951 rxn06952
rxn06955 rxn06957 rxn06960 rxn06964 rxn06965 rxn07086 rxn07097
rxn07103 rxn07104 rxn07105 rxn07106 rxn07107 rxn07109 rxn07119
rxn07179 rxn07186 rxn07187 rxn07188 rxn07195 rxn07196 rxn07197
rxn07198 rxn07201 rxn07205 rxn07206 rxn07210 rxn07244 rxn07245
rxn07253 rxn07275 rxn07299 rxn07302 rxn07651 rxn07723 rxn07736
rxn07878 rxn11417 rxn11582 rxn11593 rxn11597 rxn11615 rxn11617
rxn11619 rxn11620 rxn11624 rxn11626 rxn11638 rxn11648 rxn11651
rxn11665 rxn11666 rxn11667 rxn11698 rxn11983 rxn11986 rxn11994
rxn12006 rxn12007 rxn12014 rxn12017 rxn12022 rxn12160 rxn12161
rxn01267 )],
		gauranteedrxns => [qw(
rxn1 rxn2 rxn3 rxn4 rxn5 rxn6 rxn7 rxn8
rxn13782 rxn13783 rxn13784 rxn05294 rxn05295 rxn05296 rxn10002
rxn10088 rxn11921 rxn11922 rxn10200 rxn11923 rxn05029 )],
		allowedcmps => ["c","e","p"]
	});
	$formulation->{formulation} = $self->_setDefaultFBAFormulation($formulation->{formulation});
	return $formulation;
}

sub _buildGapfillObject {
	my ($self,$formulation,$model,$workspace,$id) = @_;
	my $fbaid = $self->_get_new_id($id.".fba.");
	my $gapform = ModelSEED::MS::GapfillingFormulation->new({
		uuid => $workspace."/".$id,
		model_uuid => $model->uuid(),
		model => $model,
		fbaFormulation_uuid => $workspace."/".$fbaid,
		fbaFormulation => $self->_buildFBAObject($formulation->{formulation},$model,$workspace,$fbaid),
		balancedReactionsOnly => $self->_invert_boolean($formulation->{allowunbalanced}),
		reactionActivationBonus => $formulation->{activitybonus},
		drainFluxMultiplier => $formulation->{drainpen},
		directionalityMultiplier => $formulation->{directionpen},
		deltaGMultiplier => $formulation->{unfavorablepen},
		noStructureMultiplier => $formulation->{nostructpen},
		noDeltaGMultiplier => $formulation->{nodeltagpen},
		biomassTransporterMultiplier => $formulation->{biomasstranspen},
		singleTransporterMultiplier => $formulation->{singletranspen},
		transporterMultiplier => $formulation->{transpen},
		mediaHypothesis => $self->_invert_boolean($formulation->{nomediahyp}),
		biomassHypothesis => $self->_invert_boolean($formulation->{nobiomasshyp}),
		gprHypothesis => $self->_invert_boolean($formulation->{nogprhyp}),
		reactionAdditionHypothesis => $self->_invert_boolean($formulation->{nopathwayhyp}),
	});
	foreach my $reaction (@{$formulation->{gauranteedrxns}}) {
		my $rxnObj = $model->biochemistry()->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$gapform->addLinkArrayItem("guaranteedReactions",$rxnObj);
		}
	}
	foreach my $reaction (@{$formulation->{blacklistedrxns}}) {
		my $rxnObj = $model->biochemistry()->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$gapform->addLinkArrayItem("blacklistedReactions",$rxnObj);
		}
	}
	foreach my $comp (@{$formulation->{allowedcmps}}) {
		my $compObj = $model->biochemistry()->queryObject("compartments",{id => $comp});
		if (defined($compObj)) {
			$gapform->addLinkArrayItem("allowableCompartments",$compObj);
		}
	}
	$gapform->prepareFBAFormulation();
	$gapform->{_kbaseWSMeta}->{wsid} = $id;
	$gapform->{_kbaseWSMeta}->{ws} = $workspace;
	$gapform->fbaFormulation()->numberOfSolutions($formulation->{num_solutions});
	return $gapform;
}

sub _setDefaultGapGenFormulation {
	my ($self,$formulation) = @_;
	if (!defined($formulation)) {
		$formulation = {};
	}
	$formulation = $self->_validateargs($formulation,[],{
		formulation => undef,
		refmedia => "Carbon-D-Glucose",
		refmedia_workspace => "kbasecdm",
		num_solutions => 1,
		nomediahyp => 0,
		nobiomasshyp => 0,
		nogprhyp => 0,
		nopathwayhyp => 0,
	});
	$formulation->{formulation} = $self->_setDefaultFBAFormulation($formulation->{formulation});
	return $formulation;
}

sub _buildGapGenObject {
	my ($self,$formulation,$model,$workspace,$id) = @_;
	#Parsing media
	my $media;
	my $mediaobj;
	if ($formulation->{refmedia_workspace} ne "kbasecdm") {
		$mediaobj = $self->_get_msobject("Media",$formulation->{refmedia_workspace},$formulation->{refmedia});
		$model->biochemistry()->add("media",$mediaobj);
		$media = $formulation->{refmedia_workspace}."/".$formulation->{refmedia};
	} else {
		$mediaobj = $model->biochemistry()->queryObject("media",{
			id => $formulation->{refmedia}
		});
		if (!defined($mediaobj)) {
			my $msg = "Media object ".$formulation->{refmedia}." not found in biochemistry!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
		}
		$media = $mediaobj->uuid();
	}
	my $fbaid = $self->_get_new_id($id.".fba.");
	my $gapform = ModelSEED::MS::GapgenFormulation->new({
		uuid => $workspace."/".$id,
		model_uuid => $model->uuid(),
		model => $model,
		fbaFormulation_uuid => $workspace."/".$fbaid,
		fbaFormulation => $self->_buildFBAObject($formulation->{formulation},$model,$workspace,$fbaid),
		mediaHypothesis => $self->_invert_boolean($formulation->{nomediahyp}),
		biomassHypothesis => $self->_invert_boolean($formulation->{nobiomasshyp}),
		gprHypothesis => $self->_invert_boolean($formulation->{nogprhyp}),
		reactionAdditionHypothesis => $self->_invert_boolean($formulation->{nopathwayhyp}),
		referenceMedia_uuid => $media,
		referenceMedia => $mediaobj
	});
	$gapform->{_kbaseWSMeta}->{wsid} = $id;
	$gapform->{_kbaseWSMeta}->{ws} = $workspace;
	$gapform->prepareFBAFormulation();
	$gapform->fbaFormulation()->numberOfSolutions($formulation->{num_solutions});
	return $gapform;
}

sub _parseTerm {
	my ($self,$term,$model) = @_;	
	my $output = {
		coef => $term->[0],
		vartype => $term->[1],
		enttype => undef,
		uuid => undef
	};
	my $obj;
	if ($term->[1] eq "flux") {
		$output->{vartype} = "flux";
		$output->{enttype} = "Reaction";
		$obj = $model->searchForReaction("reactions",{id => $term->[2]});
	} elsif ($term->[1] eq "biomassflux") {
		$output->{vartype} = "flux";
		$output->{enttype} = "Biomass";
		$obj = $model->searchForBiomass("biomasses",{id => $term->[2]});
		if (!defined($obj)) {
			$obj = $model->biomasses()->[0];
		}
	} elsif ($term->[1] eq "drainflux") {
		$output->{vartype} = "drainflux";
		$output->{enttype} = "Compound";
		$obj = $model->searchForCompound("compounds",{id => $term->[2]});
	} else {
		my $msg = "Variable type ".$term->[1]." not recognized!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
	}
	if (!defined($obj)) {
		my $msg = "Variable ".$term->[2]." not found!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
	}
	$output->{uuid} = $obj->uuid(); 
	return $output;
}

sub _parseBound {
	my ($self,$bound,$model) = @_;
	my $output = {
		lowerbound => $bound->[0],
		upperbound => $bound->[1],
		vartype => $bound->[2]
	};
	my $obj;
	if ($bound->[2] eq "flux") {
		$output->{boundtype} = "fbaReactionBounds";
		$obj = $model->searchForReaction($bound->[3]);
	} elsif ($bound->[2] eq "drainflux") {
		$output->{boundtype} = "fbaCompoundBounds";
		$obj = $model->searchForCompound($bound->[3]);
	} else {
		my $msg = "Variable type ".$bound->[2]." not recognized!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
	}
	if (!defined($obj)) {
		my $msg = "Bound variable ".$bound->[3]." not found!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
	}
	$output->{uuid} = $obj->uuid(); 
	return $output;
}

sub _create_job {
	my ($self,$args) = @_;
	$args = $self->_validateargs($args,["queuing_command","clusterjobs","workspace"],{
		clustermem => 2000,
		clustertime => 14400,
		postprocess_command => undef,
		postprocess_args => undef
	});
	my $jobid = Data::UUID->new()->create_str();
	return {
		workspace => $args->{workspace},
		clustermem => $args->{clustermem},
		clustertime => $args->{clustertime},
		id => $jobid,
		queuetime => DateTime->now()->datetime(),
		complete => 0,
		clusterjobs => $args->{clusterjobs},
		clustertoken => undef,
		postprocess_command => $args->{postprocess_command},
		postprocess_args => $args->{postprocess_args},
		owner => $self->_getUsername(),
		queuing_command => $args->{queuing_command},
	};
}

sub _submit_job {
	my ($self,$job) = @_;
	my $clusterJob = $self->_clusterService()->Submit({
		mem => $job->{clustermem},
		"time" => $job->{clustertime},
		jobid => $job->{id},
		auth => $self->_authentication(),
		application => "fba",
		jobs => $job->{clusterjobs}
	});
	$job->{clustertoken} = $clusterJob->{ID};
	return $job;
};

sub _cancel_job {
	my ($self,$job) = @_;
	my $clusterjob = $self->_clusterService()->Job($job->{clustertoken},$self->_clusterService());
	return $self->_clusterService()->Cancel($clusterjob);
};

sub _check_job {
	my ($self,$job) = @_;
	my $clusterjob = $self->_clusterService()->Job($job->{clustertoken},$self->_clusterService());
	return $self->_clusterService()->Done($clusterjob);
};

sub _get_new_id {
	my ($self,$prefix) = @_;
	my $id = $self->_idServer()->allocate_id_range( $prefix, 1 );
	if (!defined($id) || $id eq "") {
    	$id = "0";
    }
    $id = $prefix.$id;
	return $id;
};

sub _phenotypeSimulationSet_to_html {
	my ($self,$obj) = @_;
	my $htmlArray = [
		'<!doctype HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">',
		'<html><head>',
		'<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>',
		'    <script type="text/javascript">',
		'        function UpdateTableHeaders() {',
		'            $("div.divTableWithFloatingHeader").each(function() {',
		'                var originalHeaderRow = $(".tableFloatingHeaderOriginal", this);',
		'                var floatingHeaderRow = $(".tableFloatingHeader", this);',
		'                var offset = $(this).offset();',
		'                var scrollTop = $(window).scrollTop();',
		'                if ((scrollTop > offset.top) && (scrollTop < offset.top + $(this).height())) {',
		'                    floatingHeaderRow.css("visibility", "visible");',
		'                    floatingHeaderRow.css("top", Math.min(scrollTop - offset.top, $(this).height() - floatingHeaderRow.height()) + "px");',
		'                    // Copy row width from whole table',
		'                    floatingHeaderRow.css(\'width\', "1200px");',
		'                    // Copy cell widths from original header',
		'                    $("th", floatingHeaderRow).each(function(index) {',
		'                        var cellWidth = $("th", originalHeaderRow).eq(index).css(\'width\');',
		'                        $(this).css(\'width\', cellWidth);',
		'                    });',
		'                }',
		'                else {',
		'                    floatingHeaderRow.css("visibility", "hidden");',
		'                    floatingHeaderRow.css("top", "0px");',
		'                }',
		'            });',
		'        }',
		'        $(document).ready(function() {',
		'            $("table.tableWithFloatingHeader").each(function() {',
		'                $(this).wrap("<div class=\"divTableWithFloatingHeader\" style=\"position:relative\"></div>");',
		'                var originalHeaderRow = $("tr:first", this)',
		'                originalHeaderRow.before(originalHeaderRow.clone());',
		'                var clonedHeaderRow = $("tr:first", this)',
		'                clonedHeaderRow.addClass("tableFloatingHeader");',
		'                clonedHeaderRow.css("position", "absolute");',
		'                clonedHeaderRow.css("top", "0px");',
		'                clonedHeaderRow.css("left", $(this).css("margin-left"));',
		'                clonedHeaderRow.css("visibility", "hidden");',
		'                originalHeaderRow.addClass("tableFloatingHeaderOriginal");',
		'            });',
		'            UpdateTableHeaders();',
		'            $(window).scroll(UpdateTableHeaders);',
		'            $(window).resize(UpdateTableHeaders);',
		'        });',
		'    </script>',
		'<style type="text/css">',
		'h1 {',
		'    font-size: 16px;',
		'}',
		'table.tableWithFloatingHeader {',
		'    font-size: 12px;',
		'    text-align: left;',
		'	 border: 0;',
		'	 width: 1200px;',
		'}',
		'th {',
		'    font-size: 14px;',
		'    background: #ddd;',
		'	 border: 1px solid black;',
		'    vertical-align: top;',
		'    padding: 5px 5px 5px 5px;',
		'}',
		'td {',
		'   font-size: 16px;',
		'	vertical-align: top;',
		'	border: 1px solid black;',
		'}',
		'</style></head>',
		'<h2>Phenotype simulation set attributes</h2>',
		'<table>',
		"<tr><th>ID</th><td style='font-size:16px;border: 1px solid black;'>".$obj->{id}."</td></tr>",
		"<tr><th>Model</th><td style='font-size:16px;border: 1px solid black;'>".$obj->{model_workspace}."/".$obj->{model}."</td></tr>",		
		'</table>',
		'<h2>Simulated phenotypes</h2>',
		'<table class="tableWithFloatingHeader">',
		'<tr><th>Base media</th><th>Additional compounds</th><th>Gene KO</th><th>Growth</th><th>Simulated growth</th><th>Simulated growth fraction</th><th>Class</th></tr>',
	];
	foreach my $phenotype (@{$obj->{phenotypeSimulations}}) {
		push(@{$htmlArray},
			'<tr><td>'.$phenotype->[0]->[2]."/".$phenotype->[0]->[1].'</td>'.
			'<td>'.join(", ",@{$phenotype->[0]->[3]}).'</td>'.
			'<td>'.join(", ",@{$phenotype->[0]->[0]}).'</td>'.
			'<td>'.$phenotype->[0]->[4].'</td>'.
			'<td>'.$phenotype->[1].'</td>'.
			'<td>'.$phenotype->[2].'</td>'.
			'<td>'.$phenotype->[3].'</td></tr>'
		);
	}
	push(@{$htmlArray},'</table>');
	push(@{$htmlArray},'</html>');
	return join("\n",@{$htmlArray});
};

sub _generate_fbameta {
	my ($self,$obj) = @_;
	my $objective;
	if (defined($obj->fbaResults()->[0])) {
		$objective = $obj->fbaResults()->[0]->objectiveValue();
	}
	my $idarray = [split(/\//,$obj->uuid())];
	(my $mediaid,my $mediaws);
	if ($obj->media_uuid() =~ m/(.+)\/(.+)/) {
		$mediaws = $1;
		$mediaid = $2;
	} else {
		$mediaws = "kbasecdm";
		$mediaid = $obj->media()->id();
	}
	my $kos = [];
	foreach my $gene ($obj->geneKOs()) {
		push(@{$kos},$gene->id());
	}
	return [
		$idarray->[1],
		$idarray->[0],
		$mediaid,
		$mediaws,
		$objective,
		$kos
	];
}

sub _generate_gapmeta {
	my ($self,$obj) = @_;
	my $idarray = [split(/\//,$obj->uuid())];
	my $done = 0;
	if ($obj->_type() eq "GapfillingFormulation" && defined($obj->gapfillingSolutions())) {
		$done = 1;
	} elsif ($obj->_type() eq "GapgenFormulation" && defined($obj->gapgenSolutions())) {
		$done = 1;
	}
	(my $mediaid,my $mediaws);
	if ($obj->fbaFormulation()->media_uuid() =~ m/(.+)\/(.+)/) {
		$mediaws = $1;
		$mediaid = $2;
	} else {
		$mediaws = "kbasecdm";
		$mediaid = $obj->fbaFormulation()->media()->id();
	}
	my $kos = [];
	foreach my $gene ($obj->fbaFormulation()->geneKOs()) {
		push(@{$kos},$gene->id());
	}
	return [
		$idarray->[1],
		$idarray->[0],
		$mediaid,
		$mediaws,
		$done,
		$kos
	];
}

sub _FBA_to_FBAFormulation {
	my ($self,$obj) = @_;
	my $media;
	my $media_workspace = "kbasecdm";
	if ($obj->media_uuid() =~ m/(.+)\/(.+)/) {
		$media_workspace = $1;
		$media = $2;
	} else {
		$media = $obj->media()->id();
	}
	my $form = {
		media => $media,
		media_workspace => $media_workspace,
		objfraction => $obj->objectiveConstraintFraction(),
		allreversible => $obj->allReversible(),
		maximizeObjective => $obj->maximizeObjective(),
		objectiveTerms => [],
		geneko => [],
		rxnko => [],
		bounds => [],
		constraints => [],
		uptakelim => $obj->uptakeLimits(),
		defaultmaxflux => $obj->defaultMaxFlux(),
		defaultminuptake => $obj->defaultMinDrainFlux(),
		defaultmaxuptake => $obj->defaultMaxDrainFlux(),
		simplethermoconst => $obj->simpleThermoConstraints(),
		thermoconst => $obj->thermodynamicConstraints(),
		nothermoerror => $obj->noErrorThermodynamicConstraints(),
		minthermoerror => $obj->minimizeErrorThermodynamicConstraints()
	};
	foreach my $ko (@{$obj->geneKOs()}) {
		push(@{$form->{geneko}},$ko->id());
	}
	foreach my $ko (@{$obj->reactionKOs()}) {
		push(@{$form->{rxnko}},$ko->id());
	}
	foreach my $const (@{$obj->fbaConstraints()}) {
		my $terms = [];
		foreach my $term (@{$const->fbaConstraintVariables()}) {
			push(@{$terms},[$term->coefficient(),$term->variableType(),$term->entity()->id()]);
		}
		push(@{$form->{constraints}},[$const->rhs(),$const->sign(),$terms,$const->name()]);
	}
	foreach my $bound (@{$obj->fbaReactionBounds()}) {
		push(@{$form->{bounds}},[$bound->lowerBound(),$bound->upperBound(),$bound->variableType(),$bound->modelreaction()->id()]);
	}
	foreach my $bound (@{$obj->fbaCompoundBounds()}) {
		push(@{$form->{bounds}},[$bound->lowerBound(),$bound->upperBound(),$bound->variableType(),$bound->modelcompound()->id()]);
	}
	foreach my $term (@{$obj->fbaObjectiveTerms()}) {
		push(@{$form->{objectiveTerms}},[$term->coefficient(),$term->variableType(),$term->entity()->id()]);
	}
	return $form;
}

sub _FBA_to_FBAdata {
	my ($self,$obj) = @_;
	my $array = [split(/\//,$obj->uuid())];
	my $mdlarray = [split(/\//,$obj->model()->uuid())];
	my $fbadata = {
    	id => $array->[1],
    	workspace => $array->[0],
    	model => $mdlarray->[1],
    	model_workspace => $mdlarray->[0],
    	isComplete => 0,
    	objective => undef,
    	formulation => $self->_FBA_to_FBAFormulation($obj),
    	minimalMediaPredictions => [],
		metaboliteProductions => [],
		reactionFluxes => [],
		compoundFluxes => [],
		geneAssertions => []
	};
    if (defined($obj->fbaResults()->[0])) {
		$fbadata->{isComplete} = 1;
		my $result = $obj->fbaResults()->[0];
		$fbadata->{objective} = $result->objectiveValue();
		foreach my $var (@{$result->fbaCompoundVariables()}) {
			push(@{$fbadata->{compoundFluxes}},[
				$var->modelcompound()->id(),
				$var->value(),
				$var->upperBound(),
				$var->lowerBound(),
				$var->max(),
				$var->min(),
				$var->variableType()
			]);
		}
		foreach my $var (@{$result->fbaReactionVariables()}) {
			push(@{$fbadata->{reactionFluxes}},[
				$var->modelreaction()->id(),
				$var->value(),
				$var->upperBound(),
				$var->lowerBound(),
				$var->max(),
				$var->min(),
				$var->variableType()
			]);
		}
		foreach my $var (@{$result->fbaBiomassVariables()}) {
			push(@{$fbadata->{reactionFluxes}},[
				$var->biomass()->id(),
				$var->value(),
				$var->upperBound(),
				$var->lowerBound(),
				$var->max(),
				$var->min(),
				$var->variableType()
			]);
		}
		foreach my $var (@{$result->fbaDeletionResults()}) {
			my $essential = 1;
			if ($var->growthFraction() > 0.05) {
				$essential = 0;
			}
			push(@{$fbadata->{geneAssertions}},[
				$var->genekos()->[0]->id(),
				$var->growthFraction(),
				($var->growthFraction()*$fbadata->{objective}),
				$essential
			]);
		}
		foreach my $var (@{$result->fbaMetaboliteProductionResults()}) {
			push(@{$fbadata->{metaboliteProductions}},[
				$var->maximumProduction(),
				$var->modelCompound()->id()
			]);
		}
		foreach my $minmedia (@{$result->minimalMediaResults()}) {
			my $data = {
				optionalNutrients => [],
				essentialNutrients => []
			};
			foreach my $cpd (@{$result->essentialNutrients()}) {
				push(@{$data->{essentialNutrients}},$cpd->id())
			}
			foreach my $cpd (@{$result->optionalNutrients()}) {
				push(@{$data->{optionalNutrients}},$cpd->id())
			}
			push(@{$fbadata->{minimalMediaPredictions}},$data);	
		}
    }
    return $fbadata;
}

sub _invert_boolean {
	my ($self,$input) = @_;
	if ($input == 1) {
		return 0;
	}
	return 1;
}

sub _GapFill_to_GapFillFormulation {
	my ($self,$obj) = @_;
	my $form = {
		formulation => $self->_FBA_to_FBAFormulation($obj->fbaFormulation()),
		nomediahyp => $self->_invert_boolean($obj->mediaHypothesis()),
		nobiomasshyp => $self->_invert_boolean($obj->biomassHypothesis()),
		nogprhyp => $self->_invert_boolean($obj->gprHypothesis()),
		nopathwayhyp => $self->_invert_boolean($obj->reactionAdditionHypothesis()),
		allowunbalanced => $self->_invert_boolean($obj->balancedReactionsOnly()),
		activitybonus => $obj->reactionActivationBonus(),
		drainpen => $obj->drainFluxMultiplier(),
		directionpen => $obj->directionalityMultiplier(),
		nostructpen => $obj->noStructureMultiplier(),
		unfavorablepen => $obj->deltaGMultiplier(),
		nodeltagpen => $obj->noDeltaGMultiplier(),
		biomasstranspen => $obj->biomassTransporterMultiplier(),
		singletranspen => $obj->singleTransporterMultiplier(),
		transpen => $obj->transporterMultiplier(),
		blacklistedrxns => [],
		gauranteedrxns => [],
		allowedcmps => [],
		probabilistic_annotation => undef
	};
	foreach my $rxn (@{$obj->blacklistedReactions()}) {
		push(@{$form->{blacklistedrxns}},$rxn->id());
	}
	foreach my $rxn (@{$obj->guaranteedReactions()}) {
		push(@{$form->{gauranteedrxns}},$rxn->id());
	}
	foreach my $comp (@{$obj->allowableCompartments()}) {
		push(@{$form->{allowedcmps}},$comp->id());
	}
	return $form;
}

sub _GapFill_to_GapFillData {
	my ($self,$obj) = @_;
	my $array = [split(/\//,$obj->uuid())];
	my $mdlarray = [split(/\//,$obj->model()->uuid())];
	my $data = {
    	id => $array->[1],
    	workspace => $array->[0],
    	model => $mdlarray->[1],
    	model_workspace => $mdlarray->[0],
    	isComplete => 0,
    	formulation => $self->_GapFill_to_GapFillFormulation($obj),
    	solutions => []
	};
    if (defined($obj->fbaFormulation()->fbaResults()->[0])) {
		$data->{isComplete} = 1;
		#TODO
	}
    return $data;
}

sub _GapGen_to_GapGenData {
	my ($self,$obj) = @_;
	my $array = [split(/\//,$obj->uuid())];
	my $mdlarray = [split(/\//,$obj->model()->uuid())];
	my $data = {
    	id => $array->[1],
    	workspace => $array->[0],
    	model => $mdlarray->[1],
    	model_workspace => $mdlarray->[0],
    	isComplete => 0,
    	formulation => {
    		formulation => $self->_FBA_to_FBAFormulation($obj->fbaFormulation()),
    		nomediahyp => $self->_invert_boolean($obj->mediaHypothesis()),
			nobiomasshyp => $self->_invert_boolean($obj->biomassHypothesis()),
			nogprhyp => $self->_invert_boolean($obj->gprHypothesis()),
			nopathwayhyp => $self->_invert_boolean($obj->reactionRemovalHypothesis())
    	},
    	solutions => []
	};
    if (defined($obj->fbaFormulation()->fbaResults()->[0])) {
		$data->{isComplete} = 1;
		#TODO
    }
    return $data;
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
	equation has a value which is a string
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
	equation has a value which is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_models');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_models);
    #BEGIN get_models
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["models","workspaces"],{
		id_type => "ModelSEED"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase","default")
			}
		}
	};
    for (my $i=0; $i < @{$input->{models}}; $i++) {
    	my $id = $input->{models}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $model = $self->_get_msobject("Model",$input->{workspaces}->[$i],$input->{models}->[$i],$cache);
    	my $genomeArray = [split(/\//,$model->{annotation_uuid})];
    	my $mdldata = {
    		id => $input->{models}->[$i],
    		workspace => $input->{workspaces}->[$i],
    		genome => $genomeArray->[1],
    		genome_workspace => $genomeArray->[0],
    		"map" => "default",
    		map_workspace => "kbase",
    		biochemistry => "default",
    		biochemistry_workspace => "kbase",
    		name => $model->name(),
    		type => $model->type(),
    		status => $model->status(),
    		biomasses => [],
    		compartments => [],
    		reactions => [],
    		compounds => [],
    		fbas => [],
    		integrated_gapfillings => [],
    		unintegrated_gapfillings => [],
    		integrated_gapgenerations => [],
    		unintegrated_gapgenerations => []
    	};
    	#Creating model biomasses
    	foreach my $bio (@{$model->biomasses()}) {
    		my $biodata = {
    			id => $bio->id(),
    			name => $bio->name()
    		};
    		push(@{$mdldata->{biomasses}},$biodata);
    	}
    	#Creating model compartments
    	foreach my $comp (@{$model->modelcompartments()}) {
    		my $compdata = {
    			id => $comp->label(),
    			name => $comp->label(),
    			pH => $comp->pH(),
    			potential => $comp->potential(),
    			"index" => $comp->compartmentIndex()
    		};
    		push(@{$mdldata->{compartments}},$compdata);
    	}
    	#Creating model compounds
    	foreach my $cpd (@{$model->modelcompounds()}) {
    		my $cpddata = {
    			id => $cpd->id(),
    			compound => $cpd->compound()->id(),
    			name => $cpd->compound()->name(),
    			compartment => $cpd->modelcompartment()->label()
    		};
    		push(@{$mdldata->{compounds}},$cpddata);
    	}
    	#Creating model reactions
    	foreach my $rxn (@{$model->modelreactions()}) {
    		my $rxndata = {
    			id => $rxn->id(),
    			reaction => $rxn->reaction()->id(),
    			name => $rxn->reaction()->name(),
    			direction => $rxn->direction(),
    			features => $rxn->featureIDs(),
    			compartment => $rxn->modelcompartment()->label(),
    			equation => $rxn->equation()
    		};
    		push(@{$mdldata->{reactions}},$rxndata);
    	}
    	#Creating fbas, gapfills, and gapgens
    	foreach my $obj (@{$model->fbaFormulations()}) {
    		push(@{$mdldata->{fbas}},$self->_generate_fbameta($obj));
    	}
    	foreach my $obj (@{$model->integratedGapfillings()}) {
    		push(@{$mdldata->{integrated_gapfillings}},$self->_generate_gapmeta($obj));
    	}
    	foreach my $obj (@{$model->unintegratedGapfillings()}) {
    		push(@{$mdldata->{unintegrated_gapfillings}},$self->_generate_gapmeta($obj));
    	}
    	foreach my $obj (@{$model->integratedGapgens()}) {
    		push(@{$mdldata->{integrated_gapgenerations}},$self->_generate_gapmeta($obj));
    	}
    	foreach my $obj (@{$model->unintegratedGapgens()}) {
    		push(@{$mdldata->{unintegrated_gapgenerations}},$self->_generate_gapmeta($obj));
    	}
    	push(@{$out_models},$mdldata);
    }
	$self->_clearContext();
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
modelreaction_id is a string
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
modelreaction_id is a string
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

Returns data for the requested flux balance analysis formulations

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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_fbas);
    #BEGIN get_fbas
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["fbas","workspaces"],{
		id_type => "ModelSEED"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase","default")
			}
		}
	};
    for (my $i=0; $i < @{$input->{fbas}}; $i++) {
    	my $id = $input->{fbas}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $fba = $self->_get_msobject("FBA",$ws,$id,$cache);
    	my $fbadata = $self->_FBA_to_FBAdata($fba);
    	$cache->{FBA}->{$ws}->{$id} = $fba;
    	$cache->{Model}->{$fbadata->{model_workspace}}->{$fbadata->{model}} = $fba->model();
    	push(@{$out_fbas},$fbadata);
    }
	$self->_clearContext();
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
	probabilisticAnnotation has a value which is a probabilisticAnnotation_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
probabilisticAnnotation_id is a string
GapFillSolution is a reference to a hash where the following keys are defined:
	objective has a value which is a float
	biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
	mediaAdditions has a value which is a reference to a list where each element is a compound_id
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
modelcompound_id is a string
compound_id is a string
reactionAddition is a reference to a list containing 2 items:
	0: a reaction_id
	1: a string

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
	probabilisticAnnotation has a value which is a probabilisticAnnotation_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
probabilisticAnnotation_id is a string
GapFillSolution is a reference to a hash where the following keys are defined:
	objective has a value which is a float
	biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
	mediaAdditions has a value which is a reference to a list where each element is a compound_id
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
modelcompound_id is a string
compound_id is a string
reactionAddition is a reference to a list containing 2 items:
	0: a reaction_id
	1: a string


=end text



=item Description

Returns data for the requested gap filling simulations

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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_gapfills);
    #BEGIN get_gapfills
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["gapfills","workspaces"],{
		id_type => "ModelSEED"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase","default")
			}
		}
	};
    for (my $i=0; $i < @{$input->{gapfills}}; $i++) {
    	my $id = $input->{gapfills}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $obj = $self->_get_msobject("GapFill",$ws,$id,$cache);
    	my $data = $self->_GapFill_to_GapFillData($obj);
    	$cache->{GapFill}->{$ws}->{$id} = $obj;
    	$cache->{Model}->{$data->{model_workspace}}->{$data->{model}} = $obj->model();
    	push(@{$out_gapfills},$data);
    }
	$self->_clearContext();
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
	objective has a value which is a float
	biomassAdditions has a value which is a reference to a list where each element is a compound_id
	mediaRemovals has a value which is a reference to a list where each element is a compound_id
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
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
	objective has a value which is a float
	biomassAdditions has a value which is a reference to a list where each element is a compound_id
	mediaRemovals has a value which is a reference to a list where each element is a compound_id
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
compound_id is a string
reactionRemoval is a reference to a list containing 2 items:
	0: a modelreaction_id
	1: a string
modelreaction_id is a string


=end text



=item Description

Returns data for the requested gap generation simulations

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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_gapgens);
    #BEGIN get_gapgens
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["gapgens","workspaces"],{
		id_type => "ModelSEED"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase","default")
			}
		}
	};
    for (my $i=0; $i < @{$input->{gapgens}}; $i++) {
    	my $id = $input->{gapgens}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $obj = $self->_get_msobject("GapGen",$ws,$id,$cache);
    	my $data = $self->_GapGen_to_GapGenData($obj);
    	$cache->{GapGen}->{$ws}->{$id} = $obj;
    	$cache->{Model}->{$data->{model_workspace}}->{$data->{model}} = $obj->model();
    	push(@{$out_gapgens},$data);
    }
	$self->_clearContext();
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


=end text



=item Description

Returns data for the requested reactions

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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_reactions);
    #BEGIN get_reactions
	$self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["reactions"],{
    	id_type => "ModelSEED"
    });
	my $biochem = $self->_get_msobject("Biochemistry","kbase","default");
	$out_reactions = [];
	for (my $i=0; $i < @{$input->{reactions}}; $i++) {
		my $rxn = $input->{reactions}->[$i];
		my $obj = $biochem->getObjectByAlias("reactions",$rxn,$input->{id_type});
		my $new;
		if (defined($obj)) {
			$new = {
                id => $obj->id(),
                abbrev => $obj->abbreviation(),
                name => $obj->name(),
                enzymes => $obj->getAliases("Enzyme Class"),
                direction => $obj->direction(),
                reversibility => $obj->thermoReversibility(),
                deltaG => $obj->deltaG(),
                deltaGErr => $obj->deltaGErr(),
                equation => $obj->equation(),
			};
		}
		push(@{$out_reactions},$new);
	}
	$self->_clearContext();
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_compounds:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_compounds');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_compounds);
    #BEGIN get_compounds
	$self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["compounds"],{
    	id_type => "ModelSEED"
    });
	my $biochem = $self->_get_msobject("Biochemistry","kbase","default");
	$out_compounds = [];
	for (my $i=0; $i < @{$input->{compounds}}; $i++) {
		my $cpd = $input->{compounds}->[$i];
		my $obj = $biochem->getObjectByAlias("compounds",$cpd,$input->{id_type});
		my $new;
		if (defined($obj)) {
			$new = {
                id => $obj->id(),
                name => $obj->name(),
                abbrev => $obj->abbreviation(),
                aliases => $obj->getAliases("name"),
                charge => $obj->defaultCharge,
                formula => $obj->formula,
                deltaG => $obj->deltaG(),
                deltaGErr => $obj->deltaGErr()
			};
		}
		push(@{$out_compounds},$new);
	}
	$self->_clearContext();
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_media');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_media);
    #BEGIN get_media
	$self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["medias","workspaces"],{});
	my $biochem = $self->_get_msobject("Biochemistry","kbase","default");
	$out_media = [];
	for (my $i=0; $i < @{$input->{medias}}; $i++) {
		my $media = $input->{medias}->[$i];
		my $workspace = $input->{workspaces}->[$i];
		my $obj;
		if (!defined($workspace) || $workspace eq "kbasecdm") {
			$obj = $biochem->queryObject("media",{id => $media});
		} else {
			$obj = $self->_get_msobject("Media",$workspace,$media);
			$biochem->add("media",$obj);
		}
		my $new;
		if (defined($obj)) {
			$new = {
                id => $obj->id(),
                name => $obj->name(),
                pH => 7,
                temperature => 298,
                compounds => [],
                concentrations => []
            };
            foreach my $mediaCompound (@{$obj->mediacompounds}) {
                push(@{$new->{compounds}}, $mediaCompound->compound()->id());
                push(@{$new->{concentrations}}, $mediaCompound->concentration());
            }
		}
		push(@{$out_media},$new);
	}
	$self->_clearContext();
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_biochemistry:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_biochemistry');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($out_biochemistry);
    #BEGIN get_biochemistry
	$self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,[],{
		biochemistry => "default",
		biochemistry_workspace => "kbase",
		id_type => "ModelSEED"
	});
    my $biochem = $self->_get_msobject("Biochemistry","kbase","default");
    
    my $compounds = [];
    my $reactions = [];
    my $media = [];

    $out_biochemistry = {
        id => $biochem->uuid,
        name => $biochem->name,
        compounds => $compounds,
        reactions => $reactions,
        media => $media
    };

    # the following is very dependent upon the internal data representation
    # of the MS subobjects, and needs to be changed if this representation changes
	
	my $aliasset = $biochem->queryObject("aliasSets",{
		name => $input->{id_type},
		attribute => "compounds"
	});
	if (!defined($aliasset)) {
		my $msg = "id_type ".$input->{id_type}." not found for biochemistry compounds!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'get_biochemistry');
	}
	my $aliases = $aliasset->aliasesByuuid();
    foreach my $cpd_info (@{$biochem->_compounds}) {
        my $uuid;
        if ($cpd_info->{created} == 1) {
            $uuid = $cpd_info->{object}->uuid;
        } else {
        	$uuid = $cpd_info->{data}->{uuid};
        }
        if (defined($aliases->{$uuid})) {
        	push(@{$compounds},$aliases->{$uuid}->[0]);
        } else {
        	push(@{$compounds},$uuid);
        }
    }
   	
	$aliasset = $biochem->queryObject("aliasSets",{
		name => $input->{id_type},
		attribute => "reactions"
	});
	if (!defined($aliasset)) {
		my $msg = "id_type ".$input->{id_type}." not found for biochemistry reactions!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'get_biochemistry');
	}
	my $aliases = $aliasset->aliasesByuuid();
    foreach my $rxn_info (@{$biochem->_reactions}) {
        my $uuid;
        if ($rxn_info->{created} == 1) {
            $uuid = $rxn_info->{object}->uuid;
        } else {
            $uuid = $rxn_info->{data}->{uuid};
        }
        if (defined($aliases->{$uuid})) {
        	push(@{$reactions},$aliases->{$uuid}->[0]);
        } else {
        	push(@{$reactions},$uuid);
        }
    }

    foreach my $media_info (@{$biochem->_media}) {
        if ($media_info->{created} == 1) {
            push(@$media, $media_info->{object}->id);
        } else {
            push(@$media, $media_info->{data}->{id});
        }
    }
	$self->_clearContext();
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
	auth has a value which is a string
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
	auth has a value which is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
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
	auth has a value which is a string
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
	auth has a value which is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
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
	auth has a value which is a string
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
	auth has a value which is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN genome_to_fbamodel
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","genome_workspace"],{
    	model_workspace => $input->{genome_workspace},
    	model => undef,
    	overwrite => 0
    });
    #Determining model ID
    my $genome = $input->{genome};
    if (!defined($input->{model})) {
    	$input->{model} = $self->_get_new_id($input->{genome}.".fbamdl.")
    }
    #Retreiving genome object from workspace
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    #Retreiving mapping and biochemistry
    my $mapping = $self->_get_msobject("Mapping","kbase","default");
    my $biochem = $mapping->biochemistry();    
    #Translating genome to model seed annotation
    my $annotation = $self->_translate_genome_to_annotation($genome,$mapping);
    my $mdl = $annotation->createStandardFBAModel( { prefix => "Kbase", } );
    #If no output model ID is provided, one is retreived from KBase
	$mdl->uuid($input->{model_workspace}."/".$input->{model});
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_fbamodel');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN export_fbamodel
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["model","workspace","format"],{});
    my $model = $self->_get_msobject("Model",$input->{workspace},$input->{model});
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
	auth has a value which is a string
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
	auth has a value which is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
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
    	uuid => $input->{workspace}."/".$input->{media},
    	id => $input->{media},
    	name => $input->{name},
    	isDefined => $input->{isDefined},
    	isMinimal => $input->{isMinimal},
    	type => $input->{type},
    });
    my $missing = [];
    for (my $i=0; $i < @{$input->{compounds}}; $i++) {
    	my $name = $input->{compounds}->[$i];
    	my $cpdobj = $bio->searchForCompound($name);
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
	    		$data->{minFlux} = $input->{minflux}->[$i];
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
    $mediaMeta = $self->_save_msobject($media,"Media",$input->{workspace},$input->{media},"addmedia",$input->{overwrite});
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_media');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN export_media
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["media","workspace","format"],{});
    my $med;
    my $bio = $self->_get_msobject("Biochemistry","kbase","default");
    if ($input->{workspace} eq "kbasecdm") {
    	 $med = $bio->queryObject("media",{id => $input->{media}});
    	 if (!defined($med)) {
    	 	my $msg = "Media ".$input->{media}." not found in base biochemistry!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'export_media');
    	 }
    } else {
    	$med = $self->_get_msobject("Media",$input->{workspace},$input->{media});
    	$med->parent($bio);
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
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
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
		add_to_model => 0,
		overwrite => 0
	});
	if (!defined($input->{fba})) {
		$input->{fba} = $self->_get_new_id($input->{model}.".fba.");
	}
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	#Creating FBAFormulation Object
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{fba_workspace},$input->{fba});
	$fba->fva($input->{fva});
	$fba->comboDeletions($input->{simulateko});
	$fba->fluxMinimization($input->{minimizeflux});
	$fba->findMinimalMedia($input->{findminmedia});
    #Running FBA
    my $fbaResult = $fba->runFBA();
    if (!defined($fbaResult)) {
    	my $msg = "FBA failed with no solution returned!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'runfba');
    }
    if ($input->{add_to_model} == 1) {
    	$model->addLinkArrayItem("fbaFormulations",$fba);
    	$self->_save_msobject($model,"Model",$input->{model_workspace},$input->{model},"runfba");
    }
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_fba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_fba');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN export_fba
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["fba","workspace","format"],{});
    my $fba = $self->_get_msobject("FBA",$input->{workspace},$input->{fba});
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
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
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
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN import_phenotypes
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["phenotypeSet_workspace","genome","phenotypes"],{
		phenotypeSet => undef,
		genome_workspace => $input->{phenotypeSet_workspace},
		ignore_errors => 0
	});
    if (!defined($input->{phenotypeSet})) {
    	$input->{phenotypeSet} = $self->_get_new_id($input->{genome}.".phenos.");
    }
    
    #Retrieving biochemistry
    my $bio = $self->_get_msobject("Biochemistry","kbase","default");
    #Retrieving specified genome
    my $genomeObj;
    if ($input->{genome_workspace} eq "kbasecdm") {
    	$genomeObj = $self->_get_genomeObj_from_CDM($input->{genome},0);
    } else {
    	$genomeObj = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
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
    	id => $input->{phenotypeSet},
    	genome => $input->{genome},
    	genome_workspace => $input->{genome_workspace},
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
    			my $media = $self->_get_msobject("Media",$phenotype->[2],$phenotype->[1]);
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
		id => $input->{phenotypeSet},
		type => "PhenotypeSet",
		data => $object,
		workspace => $input->{phenotypeSet_workspace},
		command => "import_phenotypes",
		auth => $self->_authentication()
	});
	if (!defined($objmeta)) {
		my $msg = "Unable to save object:PhenotypeSet/".$input->{phenotypeSet_workspace}."/".$input->{id};
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
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
	phenotypeSimultationSet_workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
phenotypeSet_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	formulation has a value which is an FBAFormulation
	notes has a value which is a string
	phenotypeSimultationSet has a value which is a phenotypeSimulationSet_id
	phenotypeSimultationSet_workspace has a value which is a workspace_id
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
phenotypeSet_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN simulate_phenotypes
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["phenotypeSet","phenotypeSet_workspace","model"],{
		model_workspace => $input->{phenotypeSet_workspace},
		formulation => undef,
		notes => "",
		phenotypeSimultationSet => $input->{phenotypeSet}.".simulation",
		phenotypeSimultationSet_workspace => $input->{phenotypeSet_workspace},
		overwrite => 0
	});
	#Retrieving phenotypes
	my $pheno = $self->_get_msobject("PhenotypeSet",$input->{phenotypeSet_workspace},$input->{phenotypeSet});
	#Retrieving model
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	#Creating FBAFormulation Object
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{model_workspace},$input->{model}.".fba");
	#Translating phenotypes to fbaformulation
	my $bio = $model->biochemistry();
	for (my $i=0; $i < @{$pheno->{phenotypes}};$i++) {
		my $media = $pheno->{phenotypes}->[$i]->[2]."/".$pheno->{phenotypes}->[$i]->[1]; 
		if ($pheno->{phenotypes}->[$i]->[2] eq "kbasecdm") {
			my $mediaobj = $bio->queryObject("media",{id => $pheno->{phenotypes}->[$i]->[1]});
			$media = $mediaobj->uuid();
		} else {
			my $mediaobj = $self->_get_msobject("Media",$pheno->{phenotypes}->[$i]->[2],$pheno->{phenotypes}->[$i]->[1]);
			$bio->add("media",$mediaobj);
		}
		my $genekos = [];
		foreach my $gene (@{$pheno->{phenotypes}->[$i]->[0]}) {
			my $geneObj = $model->annotation()->queryObject("features",{id => $gene});
			push(@{$genekos},$geneObj->uuid());
		}
		my $addnlcpds = [];
		foreach my $addnlcpd (@{$pheno->{phenotypes}->[$i]->[3]}) {
			my $cpdObj = $model->biochemistry()->searchForCompound($addnlcpd);
			push(@{$addnlcpds},$cpdObj->uuid());
		}
		my $newpheno = {
			label => $i,
			media_uuid => $media,
			geneKO_uuids => $genekos,
			reactionKO_uuids => [],
			additionalCpd_uuids => $addnlcpds,
			pH => 7,
			temperature => 303,
			observedGrowthFraction => $pheno->{phenotypes}->[$i]->[4]
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
    	model_workspace => $input->{model_workspace},
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
		workspace => $input->{phenotypeSimultationSet_workspace},
		command => "simulate_phenotypes",
		auth => $self->_authentication(),
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_phenotypeSimulationSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_phenotypeSimulationSet');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN export_phenotypeSimulationSet
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["phenotypeSimulationSet","workspace","format"],{});
	my $obj = $self->_get_msobject("PhenotypeSimulationSet",$input->{workspace},$input->{phenotypeSimulationSet});
	my $output;
	if ($input->{format} eq "readable") {
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
	} elsif ($input->{format} eq "html") {
		$output = $self->_phenotypeSimulationSet_to_html($obj);
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
	fba_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
	fba_workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
	add_to_model has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
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
		fba => undef,
		donot_submit_job => 0
	});
	if (!defined($input->{fba})) {
		$input->{fba} = $self->_get_new_id($input->{model}.".fba.");
	}
	#Creating FBAFormulation Object
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{fba_workspace},$input->{fba});
	#Saving FBAFormulation to database
	my $fbameta = $self->_save_msobject($fba,"FBA",$input->{fba_workspace},$input->{fba},"queue_runfba");
	my $mediaids = [];
	my $mediaws = [];
	my $mediainst = [];
	my $mediauuids = $fba->mediaUUIDs();
	foreach my $media (@{$mediauuids}) {
		my $mediaObj = $fba->model()->biochemistry()->getObject("media",$media);
		if (defined($mediaObj->{_kbaseWSMeta})) {
			push(@{$mediaids},$mediaObj->{_kbaseWSMeta}->{wsid});
			push(@{$mediaws},$mediaObj->{_kbaseWSMeta}->{ws});
			push(@{$mediainst},$mediaObj->{_kbaseWSMeta}->{wsinst});
		}
	}
	my $job = $self->_create_job({
		clusterjobs => [{
			mediaids => $mediaids,
			mediawss => $mediaws,
			mediainsts => $mediainst,
			bioid => "kbase",
			biows => "default",
			bioinst => 0,
			mapid => "kbase",
			mapws => "default",
			mapinst => 0,
			annoid => $model->annotation()->{_kbaseWSMeta}->{wsid},
			annows => $model->annotation()->{_kbaseWSMeta}->{ws},
			annoinst => $model->annotation()->{_kbaseWSMeta}->{wsinst},
			modelid => $model->{_kbaseWSMeta}->{wsid},
			modelws => $model->{_kbaseWSMeta}->{ws},
			modelinst => $model->{_kbaseWSMeta}->{wsinst},
			fbaid => $fba->{_kbaseWSMeta}->{wsid},
			fbaws => $fba->{_kbaseWSMeta}->{ws},
			fbainst => $fba->{_kbaseWSMeta}->{wsinst},
		}],
		postprocess_command => undef,
		postprocess_args => undef,
		queuing_command => "queue_runfba",
		workspace => $input->{fba_workspace}
	});
	if ($input->{donot_submit_job} == 0) {
		$job = $self->_submit_job($job);
	}
	$output = $self->_save_msobject($job,"FBAJob",$job->{workspace},$job->{id},"queue_runfba");
	$self->_clearContext();
    #END queue_runfba
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
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
$output is an object_metadata
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
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
	probabilisticAnnotation has a value which is a probabilisticAnnotation_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
probabilisticAnnotation_id is a string
phenotypeSet_id is a string
gapfill_id is a string
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
	out_workspace has a value which is a workspace_id
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
	probabilisticAnnotation has a value which is a probabilisticAnnotation_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
probabilisticAnnotation_id is a string
phenotypeSet_id is a string
gapfill_id is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN queue_gapfill_model
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","model_workspace"],{
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{model_workspace},
		integrate_solution => 0,
		out_model => $input->{model},
		out_workspace => $input->{model_workspace},
		gapFill => undef,
		gapFill_workspace => $input->{model_workspace},
		overwrite => 0,
		donot_submit_job => 0
	});
	#Checking is this is a postprocessing or initialization call
	if (!defined($input->{gapFill})) {
		$input->{gapFill} = $self->_get_new_id($input->{model}.".gapfill.");
		$input->{formulation} = $self->_setDefaultGapfillFormulation($input->{formulation});
		my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
		my $gapfill = $self->_buildGapfillObject($input->{formulation},$model,$input->{gapFill_workspace},$input->{gapFill});
		my $fbameta = $self->_save_msobject($gapfill->fbaFormulation(),"FBA",$gapfill->fbaFormulation()->{_kbaseWSMeta}->{ws},$gapfill->fbaFormulation()->{_kbaseWSMeta}->{wsid},"queue_gapfill_model");
		my $gapfillmeta = $self->_save_msobject($gapfill,"GapFill",$input->{gapFill_workspace},$input->{gapFill},"queue_gapfill_model");
		push(@{$model->unintegratedGapfilling_uuids()},$gapfill->uuid());
		my $modelmeta = $self->_save_msobject($model,"Model",$input->{out_workspace},$input->{out_model},"queue_gapfill_model");
		my $fba = $gapfill->fbaFormulation();
		my $mediaids = [];
		my $mediaws = [];
		my $mediainst = [];
		my $mediauuids = $fba->mediaUUIDs();
		foreach my $media (@{$mediauuids}) {
			my $mediaObj = $fba->model()->biochemistry()->getObject("media",$media);
			if (defined($mediaObj->{_kbaseWSMeta})) {
				push(@{$mediaids},$mediaObj->{_kbaseWSMeta}->{wsid});
				push(@{$mediaws},$mediaObj->{_kbaseWSMeta}->{ws});
				push(@{$mediainst},$mediaObj->{_kbaseWSMeta}->{wsinst});
			}
		}
		my $job = $self->_create_job({
			clusterjobs => [{
				mediaids => $mediaids,
				mediawss => $mediaws,
				mediainsts => $mediainst,
				bioid => "kbase",
				biows => "default",
				bioinst => 0,
				mapid => "kbase",
				mapws => "default",
				mapinst => 0,
				annoid => $model->annotation()->{_kbaseWSMeta}->{wsid},
				annows => $model->annotation()->{_kbaseWSMeta}->{ws},
				annoinst => $model->annotation()->{_kbaseWSMeta}->{wsinst},
				modelid => $model->{_kbaseWSMeta}->{wsid},
				modelws => $model->{_kbaseWSMeta}->{ws},
				modelinst => $model->{_kbaseWSMeta}->{wsinst},
				fbaid => $fba->{_kbaseWSMeta}->{wsid},
				fbaws => $fba->{_kbaseWSMeta}->{ws},
				fbainst => $fba->{_kbaseWSMeta}->{wsinst},
			}],
			postprocess_command => "queue_gapfill_model",
			postprocess_args => [$input],
			queuing_command => "queue_gapfill_model",
			workspace => $input->{out_workspace}
		});
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
		}
		$output = $self->_save_msobject($job,"FBAJob",$job->{workspace},$job->{id},"queue_gapfill_model");
	} else {
		my $gapfill = $self->_get_msobject("GapFill",$input->{gapFill_workspace},$input->{gapFill});
		if (!defined($gapfill->fbaFormulation()->fbaResults()->[0])) {
			my $msg = "Gapfilling failed!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_gapfill_model');
		}
		$gapfill->parseGapfillingResults($gapfill->fbaFormulation()->fbaResults()->[0]);
		if (!defined($gapfill->gapfillingSolutions()->[0])) {
			my $msg = "Gapfilling completed, but no valid solutions found!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_gapfill_model');
		}
		if ($input->{integrate_solution} == 1) {
			$gapfill->model()->integrateGapfillSolution({
				gapfillingFormulation => $gapfill,
				solutionNum => 0
			});
		}
		my $modelmeta = $self->_save_msobject($gapfill->model(),"Model",$input->{out_workspace},$input->{out_model},"queue_gapfill_model");
		$output = $self->_save_msobject($gapfill,"GapFill",$input->{gapFill_workspace},$input->{gapFill},"queue_gapfill_model");
	}
	$self->_clearContext();
    #END queue_gapfill_model
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
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
$output is an object_metadata
gapgen_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
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
	out_workspace has a value which is a workspace_id
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN queue_gapgen_model
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","model_workspace"],{
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{model_workspace},
		integrate_solution => 0,
		out_model => $input->{model},
		out_workspace => $input->{model_workspace},
		gapGen => undef,
		gapGen_workspace => $input->{model_workspace},
		overwrite => 0,
		donot_submit_job => 0
	});
	#Checking is this is a postprocessing or initialization call
	if (!defined($input->{gapGen})) {
		$input->{gapGen} = $self->_get_new_id($input->{model}.".gapGen.");
		$input->{formulation} = $self->_setDefaultGapGenFormulation($input->{formulation});
		my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
		my $gapgen = $self->_buildGapGenObject($input->{formulation},$model,$input->{gapGen_workspace},$input->{gapGen});
		my $fbameta = $self->_save_msobject($gapgen->fbaFormulation(),"FBA",$gapgen->fbaFormulation()->{_kbaseWSMeta}->{ws},$gapgen->fbaFormulation()->{_kbaseWSMeta}->{wsid},"queue_gapgen_model");
		my $gapgenmeta = $self->_save_msobject($gapgen,"GapGen",$input->{gapGen_workspace},$input->{gapGen},"queue_gapgen_model");
		push(@{$model->unintegratedGapgen_uuids()},$gapgen->uuid());
		my $modelmeta = $self->_save_msobject($model,"Model",$input->{out_workspace},$input->{out_model},"queue_gapgen_model");
		my $fba = $gapgen->fbaFormulation();
		my $mediaids = [];
		my $mediaws = [];
		my $mediainst = [];
		my $mediauuids = $fba->mediaUUIDs();
		foreach my $media (@{$mediauuids}) {
			my $mediaObj = $fba->model()->biochemistry()->getObject("media",$media);
			if (defined($mediaObj->{_kbaseWSMeta})) {
				push(@{$mediaids},$mediaObj->{_kbaseWSMeta}->{wsid});
				push(@{$mediaws},$mediaObj->{_kbaseWSMeta}->{ws});
				push(@{$mediainst},$mediaObj->{_kbaseWSMeta}->{wsinst});
			}
		}
		my $job = $self->_create_job({
			clusterjobs => [{
				mediaids => $mediaids,
				mediawss => $mediaws,
				mediainsts => $mediainst,
				bioid => "kbase",
				biows => "default",
				bioinst => 0,
				mapid => "kbase",
				mapws => "default",
				mapinst => 0,
				annoid => $model->annotation()->{_kbaseWSMeta}->{wsid},
				annows => $model->annotation()->{_kbaseWSMeta}->{ws},
				annoinst => $model->annotation()->{_kbaseWSMeta}->{wsinst},
				modelid => $model->{_kbaseWSMeta}->{wsid},
				modelws => $model->{_kbaseWSMeta}->{ws},
				modelinst => $model->{_kbaseWSMeta}->{wsinst},
				fbaid => $fba->{_kbaseWSMeta}->{wsid},
				fbaws => $fba->{_kbaseWSMeta}->{ws},
				fbainst => $fba->{_kbaseWSMeta}->{wsinst},
			}],
			postprocess_command => "queue_gapgen_model",
			postprocess_args => [$input],
			queuing_command => "queue_gapgen_model",
			workspace => $input->{out_workspace}
		});
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
		}
		$output = $self->_save_msobject($job,"FBAJob",$job->{workspace},$job->{id},"queue_gapgen_model");
	} else {
		my $gapgen = $self->_get_msobject("GapGen",$input->{gapGen_workspace},$input->{gapGen});
		if (!defined($gapgen->fbaFormulation()->fbaResults())) {
			my $msg = "Gap generation failed!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_gapgen_model');
		}
		$gapgen->parseGapgenResults($gapgen->fbaFormulation()->fbaResults()->[0]);
		if ($input->{integrate_solution} == 1 && defined($gapgen->gapgenSolutions()->[0])) {
			$gapgen->model()->integrateGapgenSolution({
				gapgenFormulation => $gapgen,
				solutionNum => 0
			});
		}
		my $modelmeta = $self->_save_msobject($gapgen->model(),"Model",$input->{out_workspace},$input->{out_model},"queue_gapgen_model");
		$output = $self->_save_msobject($gapgen,"GapGen",$input->{gapGen_workspace},$input->{gapGen},"queue_gapgen_model");
	}
	$self->_clearContext();
    #END queue_gapgen_model
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
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
$output is an object_metadata
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
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
	probabilisticAnnotation has a value which is a probabilisticAnnotation_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
probabilisticAnnotation_id is a string
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

$input is a wildtype_phenotype_reconciliation_params
$output is an object_metadata
wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	formulation has a value which is a GapfillingFormulation
	formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
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
	probabilisticAnnotation has a value which is a probabilisticAnnotation_id
	probabilisticAnnotation_workspace has a value which is a workspace_id
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
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
probabilisticAnnotation_id is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN queue_wildtype_phenotype_reconciliation
    #END queue_wildtype_phenotype_reconciliation
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
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
$output is an object_metadata
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	num_solutions has a value which is an int
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	fba has a value which is a fba_id
	gapFill_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
gapfill_id is a string
gapgen_id is a string
phenotypeSet_id is a string
fba_id is a string
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

$input is a combine_wildtype_phenotype_reconciliation_params
$output is an object_metadata
combine_wildtype_phenotype_reconciliation_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	model_workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
	num_solutions has a value which is an int
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	out_workspace has a value which is a workspace_id
	fba has a value which is a fba_id
	gapFill_workspace has a value which is a workspace_id
	integrate_solution has a value which is a bool
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
fbamodel_id is a string
workspace_id is a string
gapfill_id is a string
gapgen_id is a string
phenotypeSet_id is a string
fba_id is a string
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

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN queue_combine_wildtype_phenotype_reconciliation_params
    #END queue_combine_wildtype_phenotype_reconciliation_params
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_combine_wildtype_phenotype_reconciliation_params:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_combine_wildtype_phenotype_reconciliation_params');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to jobs_done:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'jobs_done');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN jobs_done
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["jobid","workspace"],{});
    my $job = $self->_get_msobject("FBAJob",$input->{workspace},$input->{jobid});
    $job->{complete} = 1;
    $job->{completetime} = Data::UUID->new()->create_str();
    if (defined($job->{postprocess_command})) {
    	my $function = $job->{postprocess_command};
    	$self->$function(@{$job->{postprocess_args}});
    }
    $self->_save_msobject($job,"FBAJob",$input->{workspace},$input->{jobid},"run_job",1);
    $output = $job;
    $self->_clearContext();
    #END jobs_done
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to jobs_done:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'jobs_done');
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to check_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'check_job');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN check_job
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["jobid","workspace"],{});
    $output = $self->_get_msobject("FBAJob",$input->{workspace},$input->{jobid});
    $self->_clearContext();
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to run_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'run_job');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN run_job
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["jobid","workspace"],{
    	"index" => 0,
    });
    my $job = $self->_get_msobject("FBAJob",$input->{workspace},$input->{jobid});
    my $clusterjob = $job->{clusterjobs}->[$input->{"index"}];
    my $fba = $self->_get_msobject("FBA",$clusterjob->{fbaws},$clusterjob->{fbaid});
    my $fbaResult = $fba->runFBA();
    if (!defined($fbaResult)) {
    	my $msg = "FBA failed with no solution returned!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'runfba');
    }
    print $job->{queuing_command}."\t".$fba->jobDirectory()."\n";
    $self->_save_msobject($fba,"FBA",$clusterjob->{fbaws},$clusterjob->{fbaid},"run_job");
	$output = $job;
    $self->jobs_done($input);
    $self->_clearContext();
    #END run_job
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to run_job:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'run_job');
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



=head2 modelcompartment_id

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



=head2 probabilisticAnnotation_id

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



=head2 compartment_id

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



=head2 phenotypeSet_id

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



=item Description

********************************************************************************
    Object type definition
   	********************************************************************************


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
probabilisticAnnotation has a value which is a probabilisticAnnotation_id
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
probabilisticAnnotation has a value which is a probabilisticAnnotation_id
probabilisticAnnotation_workspace has a value which is a workspace_id


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



=head2 GapFillSolution

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
objective has a value which is a float
biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
mediaAdditions has a value which is a reference to a list where each element is a compound_id
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
objective has a value which is a float
biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
mediaAdditions has a value which is a reference to a list where each element is a compound_id
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



=head2 GapgenSolution

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
objective has a value which is a float
biomassAdditions has a value which is a reference to a list where each element is a compound_id
mediaRemovals has a value which is a reference to a list where each element is a compound_id
reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
objective has a value which is a float
biomassAdditions has a value which is a reference to a list where each element is a compound_id
mediaRemovals has a value which is a reference to a list where each element is a compound_id
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
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
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
fba_workspace has a value which is a workspace_id
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
fba_workspace has a value which is a workspace_id
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
phenotypeSet_workspace has a value which is a workspace_id
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
phenotypeSet_workspace has a value which is a workspace_id
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
phenotypeSimultationSet_workspace has a value which is a workspace_id
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
phenotypeSimultationSet_workspace has a value which is a workspace_id
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
fba_workspace has a value which is a workspace_id
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
fba_workspace has a value which is a workspace_id
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
out_workspace has a value which is a workspace_id
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
out_workspace has a value which is a workspace_id
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
out_workspace has a value which is a workspace_id
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
out_workspace has a value which is a workspace_id
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
formulation has a value which is a GapfillingFormulation
formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
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
formulation has a value which is a GapgenFormulation
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
gapFill_workspace has a value which is a workspace_id
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
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
num_solutions has a value which is an int
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
fba has a value which is a fba_id
gapFill_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
model_workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
num_solutions has a value which is an int
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
out_workspace has a value which is a workspace_id
fba has a value which is a fba_id
gapFill_workspace has a value which is a workspace_id
integrate_solution has a value which is a bool
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

1;
