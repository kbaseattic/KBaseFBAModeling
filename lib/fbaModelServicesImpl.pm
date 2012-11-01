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

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 get_genomeobject

  $genome = $obj->get_genomeobject($id, $options)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is a genome_id
$options is a Get_GenomeObject_Opts
$genome is a GenomeObject
genome_id is a string
Get_GenomeObject_Opts is a reference to a hash where the following keys are defined:
	as_new_genome has a value which is a bool
bool is an int
GenomeObject is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	source has a value which is a string
	source_id has a value which is a string
	contigs has a value which is a reference to a list where each element is a contig
	features has a value which is a reference to a list where each element is a feature
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
	1: an int
	2: a string
	3: an int
feature_type is a string
alt_func is a reference to a list containing 3 items:
	0: a string
	1: a float
	2: a reference to a list where each element is a gene_hit
gene_hit is a reference to a list containing 2 items:
	0: a feature_id
	1: a float
annotation is a reference to a list containing 3 items:
	0: a string
	1: a string
	2: an int

</pre>

=end html

=begin text

$id is a genome_id
$options is a Get_GenomeObject_Opts
$genome is a GenomeObject
genome_id is a string
Get_GenomeObject_Opts is a reference to a hash where the following keys are defined:
	as_new_genome has a value which is a bool
bool is an int
GenomeObject is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	source has a value which is a string
	source_id has a value which is a string
	contigs has a value which is a reference to a list where each element is a contig
	features has a value which is a reference to a list where each element is a feature
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
	1: an int
	2: a string
	3: an int
feature_type is a string
alt_func is a reference to a list containing 3 items:
	0: a string
	1: a float
	2: a reference to a list where each element is a gene_hit
gene_hit is a reference to a list containing 2 items:
	0: a feature_id
	1: a float
annotation is a reference to a list containing 3 items:
	0: a string
	1: a string
	2: an int


=end text



=item Description



=back

=cut

sub get_genomeobject
{
    my $self = shift;
    my($id, $options) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"options\" (value was \"$options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_genomeobject:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_genomeobject');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($genome);
    #BEGIN get_genomeobject
    my $loadObject = $objAPI->
    
    
    
    my $data = $cdmi->genomes_to_genome_data([$id]);
    if (!defined($data->{$genome})) {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Genome ".$genome." not found!",
							       method_name => 'get_genomeobject');
    }
    $data = $data->{$genome};
    my $genome = {
		id => $genome,
		scientific_name => $data->{scientific_name},
		genetic_code => $data->{genetic_code},
		domain => undef,
		source => undef,
		source_id => undef,
		contigs => [],
		features => []
    };
    $data = $obj->get_relationship_IsComposedOf([$genome],["domain","source_id"], [], ["id"]);
    if (defined($data->[0])) {
    	if (defined($data->[0]->[0]->{domain})) {
    		$genome->{domain} = $data->[0]->[0]->{domain};
    	}
    	if (defined($data->[0]->[0]->{source_id})) {
    		$genome->{source_id} = $data->[0]->[0]->{source_id};
    	}
    }
   	for (my $i=0; $i < @{$data}; $i++) {
    	if (defined($data->[$i]->[2]->{id})) {
	    	my $contig = {
	    		id => $data->[$i]->[2]->{id},
	    		dna => undef
	    	};
	    	my $seqData = $cdmapi->contigs_to_sequences([$data->[$i]->[2]->{id}]);
	    	if (defined($seqData->{$data->[$i]->[2]->{id}})) {
	    		$contig->{dna} = $seqData->{$data->[$i]->[2]->{id}};
	    	}
	    	push(@{$genome->{contigs}},$contig);
    	}
   	}
   	$data = $obj->get_relationship_WasSubmittedBy([$genome],[], ["id"], ["id"]);
    if (defined($data->[0])) {
    	if (defined($data->[0]->[2]->{id})) {
    		$genome->{source} = $data->[0]->[2]->{id};
    	}
    }
  	my $genomeFtrs = $obj->genomes_to_fids([$genome],[]);
	my $features = $genomeFtrs->{$genome};
  	my $fidAnnotationHash = $obj->fids_to_annotations($features);
  	my $fidProteinSequences = $obj->fids_to_protein_sequences($features);
  	my $fidDataHash = $obj->fids_to_feature_data($features);
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
  		
  		push(@{$genome->{features}},$feature);
  	}
  	
    #END get_genomeobject
    my @_bad_returns;
    (ref($genome) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"genome\" (value was \"$genome\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_genomeobject:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_genomeobject');
    }
    return($genome);
}




=head2 genome_to_fbamodel

  $out_model = $obj->genome_to_fbamodel($in_genome)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_genome is a genome_id
$out_model is a fbamodel_id
genome_id is a string
fbamodel_id is a string

</pre>

=end html

=begin text

$in_genome is a genome_id
$out_model is a fbamodel_id
genome_id is a string
fbamodel_id is a string


=end text



=item Description

This function creates a new metabolic model given an input genome id

=back

=cut

sub genome_to_fbamodel
{
    my $self = shift;
    my($in_genome) = @_;

    my @_bad_arguments;
    (!ref($in_genome)) or push(@_bad_arguments, "Invalid type for argument \"in_genome\" (value was \"$in_genome\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_fbamodel');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_model);
    #BEGIN genome_to_fbamodel
    my $biochem = $self->{_store}->get_object("biochemistry/kbase/default");
	my $mapping = $self->{_store}->get_object("mapping/kbase/default");
	$mapping->biochemistry($biochem);
	
	#Issuing the mapping a new uuid because it will be altered during this function
	$mapping->uuid( Data::UUID->new()->create_str() );
	
	#Creating the annotation from the input genome object
	my $size = 0;
	my $gc   = 0;
	for ( my $i = 0 ; $i < @{ $in_genome->{contigs} } ; $i++ ) {
		my $dna = $in_genome->{contigs}->[$i]->{dna};
		$size += length($dna);
		for ( my $j = 0 ; $j < length($dna) ; $j++ ) {
			if ( substr( $dna, $j, 1 ) =~ m/[gcGC]/ ) {
				$gc++;
			}
		}
	}
	$gc = $gc / $size;
	my $annotation = ModelSEED::MS::Annotation->new(
									{
									  name         => $in_genome->{scientific_name},
									  mapping_uuid => $mapping->uuid(),
									  mapping      => $mapping,
									  genomes      => [
										   {
											 name => $in_genome->{scientific_name},
											 source   => "KBase",
											 id       => $in_genome->{id},
											 cksum    => "unknown",
											 class    => "unknown",
											 taxonomy => $in_genome->{domain},
											 etcType  => "unknown",
											 size     => $size,
											 gc       => $gc
										   }
									  ]
									}
	);
	for ( my $i = 0 ; $i < @{ $in_genome->{features} } ; $i++ ) {
		my $ftr = $in_genome->{features}->[$i];
		my $newftr = $annotation->add(
				   "features",
				   {
					 id          => $ftr->{id},
					 type        => $ftr->{type},
					 sequence    => $ftr->{protein_translation},
					 genome_uuid => $annotation->genomes()->[0]->uuid(),
					 start       => $ftr->{location}->[0]->[1],
					 stop        =>
					   ( $ftr->{location}->[0]->[1] + $ftr->{location}->[0]->[3] ),
					 contig    => $ftr->{location}->[0]->[0],
					 direction => $ftr->{location}->[0]->[2],
				   }
		);
		my $output =
		  ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles(
																 $ftr->{function} );
		if ( defined( $output->{roles} ) ) {
			for ( my $j = 0 ; $j < @{ $output->{roles} } ; $j++ ) {
				my $role =
				  $mapping->queryObject( "roles",
										{ name => $output->{roles}->[$j] } );
				if ( !defined($role) ) {
					$role =
					  $mapping->add( "roles",
										{ name => $output->{roles}->[$j] } );
				}
				$newftr->add(
							  "featureroles",
							  {
								 role_uuid   => $role->uuid(),
								 compartment => $output->{compartments}->[0],
								 delimiter   => $output->{delimiter},
								 comment     => $output->{comment}
							  }
				);
			}
		}
	}
	#Running the reconstruction algorithm
	my $mdl = $annotation->createStandardFBAModel( { prefix => "Kbase", } );
	#Getting KBase ID
	my $id_server = Bio::KBase::IDServer::Client->new('http://bio-data-1.mcs.anl.gov/services/idserver');
	my $kbid = $id_server->allocate_id_range( "fbamod", 1 ) + 0;
	$kbid = "kb|fm.".$kbid;
	$mdl->id($kbid);
	$mdl->defaultNameSpace("KBase");
	#Saving the model to the mongodb document store
	my $store = $self->{_store};
	$store->save_object("model/kbase/".$mdl->id(),$mdl);
	$out_model = $self->objectToOutput($mdl);
	#Saving the annotation to the mongodb document store
	$store->save_object("annotation/kbase/".$in_genome->{id},$annotation);
	#Saving the mapping to the mongodb document store
	$store->save_object("mapping/kbase/".$in_genome->{id},$annotation);
    #END genome_to_fbamodel
    my @_bad_returns;
    (!ref($out_model)) or push(@_bad_returns, "Invalid type for return variable \"out_model\" (value was \"$out_model\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_fbamodel');
    }
    return($out_model);
}




=head2 fbamodel_to_sbml

  $sbml_string = $obj->fbamodel_to_sbml($in_model)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is a fbamodel_id
$sbml_string is an SBML
fbamodel_id is a string
SBML is a string

</pre>

=end html

=begin text

$in_model is a fbamodel_id
$sbml_string is an SBML
fbamodel_id is a string
SBML is a string


=end text



=item Description



=back

=cut

sub fbamodel_to_sbml
{
    my $self = shift;
    my($in_model) = @_;

    my @_bad_arguments;
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fbamodel_to_sbml:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fbamodel_to_sbml');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($sbml_string);
    #BEGIN fbamodel_to_sbml
    my $model = $self->loadObject($in_model);
    $out_model = join("\n",@{$model->printSBML()});
    #END fbamodel_to_sbml
    my @_bad_returns;
    (!ref($sbml_string)) or push(@_bad_returns, "Invalid type for return variable \"sbml_string\" (value was \"$sbml_string\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fbamodel_to_sbml:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fbamodel_to_sbml');
    }
    return($sbml_string);
}




=head2 fbamodel_to_html

  $html_string = $obj->fbamodel_to_html($in_model)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is a fbamodel_id
$html_string is an HTML
fbamodel_id is a string
HTML is a string

</pre>

=end html

=begin text

$in_model is a fbamodel_id
$html_string is an HTML
fbamodel_id is a string
HTML is a string


=end text



=item Description



=back

=cut

sub fbamodel_to_html
{
    my $self = shift;
    my($in_model) = @_;

    my @_bad_arguments;
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fbamodel_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fbamodel_to_html');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($html_string);
    #BEGIN fbamodel_to_html
    #END fbamodel_to_html
    my @_bad_returns;
    (!ref($html_string)) or push(@_bad_returns, "Invalid type for return variable \"html_string\" (value was \"$html_string\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fbamodel_to_html:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fbamodel_to_html');
    }
    return($html_string);
}




=head2 runfba

  $out_fba = $obj->runfba($in_model, $formulation)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is a fbamodel_id
$formulation is an FBAFormulation
$out_fba is a fba_id
fbamodel_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	model has a value which is a fbamodel_id
	regmodel has a value which is a regmodel_id
	expressionData has a value which is an expression_id
	objective has a value which is a string
	objective has a value which is a float
	description has a value which is a string
	type has a value which is a string
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
regmodel_id is a string
expression_id is a string
bool is an int
feature_id is a string
modelreaction_id is a string
fba_id is a string

</pre>

=end html

=begin text

$in_model is a fbamodel_id
$formulation is an FBAFormulation
$out_fba is a fba_id
fbamodel_id is a string
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	model has a value which is a fbamodel_id
	regmodel has a value which is a regmodel_id
	expressionData has a value which is an expression_id
	objective has a value which is a string
	objective has a value which is a float
	description has a value which is a string
	type has a value which is a string
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
regmodel_id is a string
expression_id is a string
bool is an int
feature_id is a string
modelreaction_id is a string
fba_id is a string


=end text



=item Description

This function runs flux balance analysis on the input FBAModel and produces HTML as output

=back

=cut

sub runfba
{
    my $self = shift;
    my($in_model, $formulation) = @_;

    my @_bad_arguments;
    (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    (ref($formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"formulation\" (value was \"$formulation\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_fba);
    #BEGIN runfba
    #Retreiving the model
    my $model = $self->loadObject($in_model);
	#Creating FBA formulation
	my $input = {model => $model};
	my $overrideList = {
		media => "media",notes => "notes",fva => "fva",simulateko => "comboDeletions",
		minimizeflux => "fluxMinimization",findminmedia => "findMinimalMedia",objfraction => "objectiveConstraintFraction",
		allreversible => "allReversible",objective => "objectiveString",rxnko => "geneKO",geneko => "reactionKO",uptakelim => "uptakeLimits",
		defaultmaxflux => "defaultMaxFlux",defaultminuptake => "defaultMinDrainFlux",defaultmaxuptake => "defaultMaxDrainFlux",
		simplethermoconst => "simpleThermoConstraints",thermoconst => "thermodynamicConstraints",nothermoerror => "noErrorThermodynamicConstraints",
		minthermoerror => "minimizeErrorThermodynamicConstraints",fbaPhenotypeSimulations => "fbaPhenotypeSimulations",
	};
	foreach my $argument (keys(%{$overrideList})) {
		if (defined($in_formulation->{$argument})) {
			$input->{overrides}->{$overrideList->{$argument}} = $in_formulation->{$argument};
		}
	}
	my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
	my $fbaform = $exchange_factory->buildFBAFormulation($input);
    #Running FBA
    my $fbaResult = $fbaform->runFBA();
    if (!defined($fbaResult)) {
    	my $msg = "FBA failed with no solution returned!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'runfba');
    }
    my $store = $self->{_store};
    if ($overwrite == 1) {
    	$model->add("fbaFormulations",$fbaform);
	    $store->save_object("model/kbase/".$model->id(),$model);
    } elsif (length($save) > 0) {
    	$model->add("fbaFormulations",$fbaform);
    	$model->id($save);
		$store->save_object("model/kbase/".$save,$model);
    }
    if (@{$fbaform->fbaResults()->[0]->fbaPhenotypeSimultationResults()} > 0) {
    	$out_solution = $self->objectToOutput($fbaform);
    } else {
    	$out_solution = $fbaform->createHTML();
    }
    #END runfba
    my @_bad_returns;
    (!ref($out_fba)) or push(@_bad_returns, "Invalid type for return variable \"out_fba\" (value was \"$out_fba\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }
    return($out_fba);
}




=head2 fba_check_results

  $is_done = $obj->fba_check_results($in_fba)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_fba is a fba_id
$is_done is a bool
fba_id is a string
bool is an int

</pre>

=end html

=begin text

$in_fba is a fba_id
$is_done is a bool
fba_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub fba_check_results
{
    my $self = shift;
    my($in_fba) = @_;

    my @_bad_arguments;
    (!ref($in_fba)) or push(@_bad_arguments, "Invalid type for argument \"in_fba\" (value was \"$in_fba\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fba_check_results:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fba_check_results');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($is_done);
    #BEGIN fba_check_results
    #END fba_check_results
    my @_bad_returns;
    (!ref($is_done)) or push(@_bad_returns, "Invalid type for return variable \"is_done\" (value was \"$is_done\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fba_check_results:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fba_check_results');
    }
    return($is_done);
}




=head2 fba_results_to_html

  $html_string = $obj->fba_results_to_html($in_fba)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_fba is a fba_id
$html_string is an HTML
fba_id is a string
HTML is a string

</pre>

=end html

=begin text

$in_fba is a fba_id
$html_string is an HTML
fba_id is a string
HTML is a string


=end text



=item Description



=back

=cut

sub fba_results_to_html
{
    my $self = shift;
    my($in_fba) = @_;

    my @_bad_arguments;
    (!ref($in_fba)) or push(@_bad_arguments, "Invalid type for argument \"in_fba\" (value was \"$in_fba\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fba_results_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fba_results_to_html');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($html_string);
    #BEGIN fba_results_to_html
    #END fba_results_to_html
    my @_bad_returns;
    (!ref($html_string)) or push(@_bad_returns, "Invalid type for return variable \"html_string\" (value was \"$html_string\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fba_results_to_html:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fba_results_to_html');
    }
    return($html_string);
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

These functions run gapfilling on the input FBAModel and produce gapfill objects as output

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




=head2 get_models

  $out_models = $obj->get_models($in_model_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model_ids is a reference to a list where each element is a fbamodel_id
$out_models is a reference to a list where each element is an FBAModel
fbamodel_id is a string
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
	coefficient has a value which is a float
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

$in_model_ids is a reference to a list where each element is a fbamodel_id
$out_models is a reference to a list where each element is an FBAModel
fbamodel_id is a string
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
	coefficient has a value which is a float
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

This function returns model data for input ids

=back

=cut

sub get_models
{
    my $self = shift;
    my($in_model_ids) = @_;

    my @_bad_arguments;
    (ref($in_model_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_model_ids\" (value was \"$in_model_ids\")");
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

  $out_fbas = $obj->get_fbas($in_fba_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_fba_ids is a reference to a list where each element is a fba_id
$out_fbas is a reference to a list where each element is an FBA
fba_id is a string
FBA is a reference to a hash where the following keys are defined:
	id has a value which is a fba_id
	formulation has a value which is an FBAFormulation
	minimalMediaPrediction has a value which is a reference to a list where each element is a MinimalMediaPrediction
	metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
	reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
	compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
	geneAssertions has a value which is a reference to a list where each element is a GeneAssertion
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	model has a value which is a fbamodel_id
	regmodel has a value which is a regmodel_id
	expressionData has a value which is an expression_id
	objective has a value which is a string
	objective has a value which is a float
	description has a value which is a string
	type has a value which is a string
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
bool is an int
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

$in_fba_ids is a reference to a list where each element is a fba_id
$out_fbas is a reference to a list where each element is an FBA
fba_id is a string
FBA is a reference to a hash where the following keys are defined:
	id has a value which is a fba_id
	formulation has a value which is an FBAFormulation
	minimalMediaPrediction has a value which is a reference to a list where each element is a MinimalMediaPrediction
	metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
	reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
	compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
	geneAssertions has a value which is a reference to a list where each element is a GeneAssertion
FBAFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a media_id
	model has a value which is a fbamodel_id
	regmodel has a value which is a regmodel_id
	expressionData has a value which is an expression_id
	objective has a value which is a string
	objective has a value which is a float
	description has a value which is a string
	type has a value which is a string
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
bool is an int
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

This function returns fba data for input ids

=back

=cut

sub get_fbas
{
    my $self = shift;
    my($in_fba_ids) = @_;

    my @_bad_arguments;
    (ref($in_fba_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_fba_ids\" (value was \"$in_fba_ids\")");
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

  $out_gapfills = $obj->get_gapfills($in_gapfill_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapfill_ids is a reference to a list where each element is a gapfill_id
$out_gapfills is a reference to a list where each element is a GapFill
gapfill_id is a string
GapFill is a reference to a hash where the following keys are defined:
	id has a value which is a gapfill_id
	formulation has a value which is a GapfillingFormulation
	biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
	mediaAdditions has a value which is a reference to a list where each element is a compound_id
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
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
modelcompound_id is a string
compound_id is a string
reactionAddition is a reference to a list containing 2 items:
	0: a reaction_id
	1: a string
reaction_id is a string

</pre>

=end html

=begin text

$in_gapfill_ids is a reference to a list where each element is a gapfill_id
$out_gapfills is a reference to a list where each element is a GapFill
gapfill_id is a string
GapFill is a reference to a hash where the following keys are defined:
	id has a value which is a gapfill_id
	formulation has a value which is a GapfillingFormulation
	biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
	mediaAdditions has a value which is a reference to a list where each element is a compound_id
	reactionAdditions has a value which is a reference to a list where each element is a reactionAddition
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
modelcompound_id is a string
compound_id is a string
reactionAddition is a reference to a list containing 2 items:
	0: a reaction_id
	1: a string
reaction_id is a string


=end text



=item Description

This function returns gapfill data for input ids

=back

=cut

sub get_gapfills
{
    my $self = shift;
    my($in_gapfill_ids) = @_;

    my @_bad_arguments;
    (ref($in_gapfill_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_gapfill_ids\" (value was \"$in_gapfill_ids\")");
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

  $out_gapgens = $obj->get_gapgens($in_gapgen_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_gapgen_ids is a reference to a list where each element is a gapgen_id
$out_gapgens is a reference to a list where each element is a GapGen
gapgen_id is a string
GapGen is a reference to a hash where the following keys are defined:
	id has a value which is a gapgen_id
	formulation has a value which is a GapgenFormulation
	biomassAdditions has a value which is a reference to a list where each element is a compound_id
	mediaRemovals has a value which is a reference to a list where each element is a compound_id
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
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
compound_id is a string
reactionRemoval is a reference to a list containing 2 items:
	0: a modelreaction_id
	1: a string
modelreaction_id is a string

</pre>

=end html

=begin text

$in_gapgen_ids is a reference to a list where each element is a gapgen_id
$out_gapgens is a reference to a list where each element is a GapGen
gapgen_id is a string
GapGen is a reference to a hash where the following keys are defined:
	id has a value which is a gapgen_id
	formulation has a value which is a GapgenFormulation
	biomassAdditions has a value which is a reference to a list where each element is a compound_id
	mediaRemovals has a value which is a reference to a list where each element is a compound_id
	reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval
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
compound_id is a string
reactionRemoval is a reference to a list containing 2 items:
	0: a modelreaction_id
	1: a string
modelreaction_id is a string


=end text



=item Description

This function returns gapgen data for input ids

=back

=cut

sub get_gapgens
{
    my $self = shift;
    my($in_gapgen_ids) = @_;

    my @_bad_arguments;
    (ref($in_gapgen_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_gapgen_ids\" (value was \"$in_gapgen_ids\")");
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

  $out_reactions = $obj->get_reactions($in_reaction_ids, $biochemistry)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_reaction_ids is a reference to a list where each element is a reaction_id
$biochemistry is a biochemistry_id
$out_reactions is a reference to a list where each element is a Reaction
reaction_id is a string
biochemistry_id is a string
Reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	reversibility has a value which is a string
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	equation has a value which is a string

</pre>

=end html

=begin text

$in_reaction_ids is a reference to a list where each element is a reaction_id
$biochemistry is a biochemistry_id
$out_reactions is a reference to a list where each element is a Reaction
reaction_id is a string
biochemistry_id is a string
Reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	reversibility has a value which is a string
	deltaG has a value which is a float
	deltaGErr has a value which is a float
	equation has a value which is a string


=end text



=item Description

This function returns reaction data for input ids

=back

=cut

sub get_reactions
{
    my $self = shift;
    my($in_reaction_ids, $biochemistry) = @_;

    my @_bad_arguments;
    (ref($in_reaction_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_reaction_ids\" (value was \"$in_reaction_ids\")");
    (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument \"biochemistry\" (value was \"$biochemistry\")");
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

  $out_compounds = $obj->get_compounds($in_compound_ids, $biochemistry)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_compound_ids is a reference to a list where each element is a compound_id
$biochemistry is a biochemistry_id
$out_compounds is a reference to a list where each element is a Compound
compound_id is a string
biochemistry_id is a string
Compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	charge has a value which is a float
	formula has a value which is a string

</pre>

=end html

=begin text

$in_compound_ids is a reference to a list where each element is a compound_id
$biochemistry is a biochemistry_id
$out_compounds is a reference to a list where each element is a Compound
compound_id is a string
biochemistry_id is a string
Compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	name has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	charge has a value which is a float
	formula has a value which is a string


=end text



=item Description

This function returns compound data for input ids

=back

=cut

sub get_compounds
{
    my $self = shift;
    my($in_compound_ids, $biochemistry) = @_;

    my @_bad_arguments;
    (ref($in_compound_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_compound_ids\" (value was \"$in_compound_ids\")");
    (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument \"biochemistry\" (value was \"$biochemistry\")");
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

  $out_media = $obj->get_media($in_media_ids, $biochemistry)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_media_ids is a reference to a list where each element is a media_id
$biochemistry is a biochemistry_id
$out_media is a reference to a list where each element is a Media
media_id is a string
biochemistry_id is a string
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

$in_media_ids is a reference to a list where each element is a media_id
$biochemistry is a biochemistry_id
$out_media is a reference to a list where each element is a Media
media_id is a string
biochemistry_id is a string
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

This function returns media data for input ids

=back

=cut

sub get_media
{
    my $self = shift;
    my($in_media_ids, $biochemistry) = @_;

    my @_bad_arguments;
    (ref($in_media_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"in_media_ids\" (value was \"$in_media_ids\")");
    (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument \"biochemistry\" (value was \"$biochemistry\")");
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

  $out_biochemistry = $obj->get_biochemistry($biochemistry)

=over 4

=item Parameter and return types

=begin html

<pre>
$biochemistry is a biochemistry_id
$out_biochemistry is a Biochemistry
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

$biochemistry is a biochemistry_id
$out_biochemistry is a Biochemistry
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

This function returns biochemistry object

=back

=cut

sub get_biochemistry
{
    my $self = shift;
    my($biochemistry) = @_;

    my @_bad_arguments;
    (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument \"biochemistry\" (value was \"$biochemistry\")");
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
coefficient has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelcompound_id
compound has a value which is a compound_id
name has a value which is a string
compartment has a value which is a modelcompartment_id
coefficient has a value which is a float


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
formulation has a value which is a GapfillingFormulation
biomassRemovals has a value which is a reference to a list where each element is a modelcompound_id
mediaAdditions has a value which is a reference to a list where each element is a compound_id
reactionAdditions has a value which is a reference to a list where each element is a reactionAddition

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapfill_id
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
formulation has a value which is a GapgenFormulation
biomassAdditions has a value which is a reference to a list where each element is a compound_id
mediaRemovals has a value which is a reference to a list where each element is a compound_id
reactionRemovals has a value which is a reference to a list where each element is a reactionRemoval

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gapgen_id
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
objective has a value which is a string
objective has a value which is a float
description has a value which is a string
type has a value which is a string
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
objective has a value which is a string
objective has a value which is a float
description has a value which is a string
type has a value which is a string
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
formulation has a value which is an FBAFormulation
minimalMediaPrediction has a value which is a reference to a list where each element is a MinimalMediaPrediction
metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
geneAssertions has a value which is a reference to a list where each element is a GeneAssertion

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a fba_id
formulation has a value which is an FBAFormulation
minimalMediaPrediction has a value which is a reference to a list where each element is a MinimalMediaPrediction
metaboliteProductions has a value which is a reference to a list where each element is a MetaboliteProduction
reactionFluxes has a value which is a reference to a list where each element is a ReactionFlux
compoundFluxes has a value which is a reference to a list where each element is a CompoundFlux
geneAssertions has a value which is a reference to a list where each element is a GeneAssertion


=end text

=back



=head2 Get_GenomeObject_Opts

=over 4



=item Description

This command accepts a KBase genome ID and returns the requested genome typed object


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
as_new_genome has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
as_new_genome has a value which is a bool


=end text

=back



=head2 SBML

=over 4



=item Description

This function converts a metabolic model into an SBML file.


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



=head2 HTML

=over 4



=item Description

This function converts an input object into HTML format.


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
