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


sub _init_instance {
    my ($self) = @_;

    # if we want to use FileDB, put it in configuration
    # simple configuration file can look like this:
    #
    # fbaModelServices.mongodb-host  mongodb.kbase.us
    #
    # make sure you export KB_DEPLOYMENT_CONFIG to point to config file

    my $host;
    if (my $e = $ENV{KB_DEPLOYMENT_CONFIG}) {
	my $service = $ENV{KB_SERVICE_NAME};
	my $c = new Config::Simple($e);
	$host = $c->param("$service.mongodb-host");
    }

    if (!$host) {
	$host = "birch.mcs.anl.gov";
	warn "No deployment configuration found; falling back to $host";
    }

    $self->{_db} = ModelSEED::Database::MongoDBSimple->new({
	db_name => "modelObjectStore",
	host => $host
    });

    $self->{_auth} = ModelSEED::Auth::Basic->new({
	username => "kbase",
	password => "kbase"
    });

    $self->{_store} = ModelSEED::Store->new({
	auth => $self->{_auth},
	database => $self->{_db}
    });
}

=head1 METHODS



=head2 genome_to_fbamodel

  $out_model = $obj->genome_to_fbamodel($in_genome)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_genome is a GenomeTO
$out_model is an FBAModel
GenomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	source has a value which is a string
	source_id has a value which is a string
	contigs has a value which is a reference to a list where each element is a Contig
	features has a value which is a reference to a list where each element is a Feature
genome_id is a string
Contig is a reference to a hash where the following keys are defined:
	id has a value which is a contig_id
	dna has a value which is a string
contig_id is a string
Feature is a reference to a hash where the following keys are defined:
	id has a value which is a feature_id
	location has a value which is a location
	type has a value which is a feature_type
	function has a value which is a string
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
annotation is a reference to a list containing 3 items:
	0: a string
	1: a string
	2: an int
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float

</pre>

=end html

=begin text

$in_genome is a GenomeTO
$out_model is an FBAModel
GenomeTO is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	scientific_name has a value which is a string
	domain has a value which is a string
	genetic_code has a value which is an int
	source has a value which is a string
	source_id has a value which is a string
	contigs has a value which is a reference to a list where each element is a Contig
	features has a value which is a reference to a list where each element is a Feature
genome_id is a string
Contig is a reference to a hash where the following keys are defined:
	id has a value which is a contig_id
	dna has a value which is a string
contig_id is a string
Feature is a reference to a hash where the following keys are defined:
	id has a value which is a feature_id
	location has a value which is a location
	type has a value which is a feature_type
	function has a value which is a string
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
annotation is a reference to a list containing 3 items:
	0: a string
	1: a string
	2: an int
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float


=end text



=item Description

This function creates a metabolic model object from the annotated genome object.

=back

=cut

sub genome_to_fbamodel
{
    my $self = shift;
    my($in_genome) = @_;

    my @_bad_arguments;
    (ref($in_genome) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_genome\" (value was \"$in_genome\")");
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
    (ref($out_model) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"out_model\" (value was \"$out_model\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_fbamodel');
    }
    return($out_model);
}




=head2 fbamodel_to_sbml

  $out_model = $obj->fbamodel_to_sbml($in_model)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is an FBAModel
$out_model is an SBML
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
SBML is a string

</pre>

=end html

=begin text

$in_model is an FBAModel
$out_model is an SBML
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
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
    (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fbamodel_to_sbml:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fbamodel_to_sbml');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_model);
    #BEGIN fbamodel_to_sbml
    my $model = $self->loadObject($in_model);
    $out_model = join("\n",@{$model->printSBML()});
    #END fbamodel_to_sbml
    my @_bad_returns;
    (!ref($out_model)) or push(@_bad_returns, "Invalid type for return variable \"out_model\" (value was \"$out_model\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fbamodel_to_sbml:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fbamodel_to_sbml');
    }
    return($out_model);
}




=head2 gapfill_fbamodel

  $out_model = $obj->gapfill_fbamodel($in_model, $in_formulation, $overwrite, $save)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is an FBAModel
$in_formulation is a GapfillingFormulation
$overwrite is a bool
$save is a string
$out_model is an FBAModel
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
GapfillingFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a string
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

</pre>

=end html

=begin text

$in_model is an FBAModel
$in_formulation is a GapfillingFormulation
$overwrite is a bool
$save is a string
$out_model is an FBAModel
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
GapfillingFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a string
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


=end text



=item Description



=back

=cut

sub gapfill_fbamodel
{
    my $self = shift;
    my($in_model, $in_formulation, $overwrite, $save) = @_;

    my @_bad_arguments;
    (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    (ref($in_formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_formulation\" (value was \"$in_formulation\")");
    (!ref($overwrite)) or push(@_bad_arguments, "Invalid type for argument \"overwrite\" (value was \"$overwrite\")");
    (!ref($save)) or push(@_bad_arguments, "Invalid type for argument \"save\" (value was \"$save\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_fbamodel');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_model);
    #BEGIN gapfill_fbamodel
    #Retreiving the model
    my $model = $self->loadObject($in_model);
	#Creating gapfilling formulation
	my $input = {model => $model};
	my $fbaoverrides = {
		media => "media",notes => "notes",objfraction => "objectiveConstraintFraction",
		objective => "objectiveString",rxnko => "geneKO",geneko => "reactionKO",uptakelim => "uptakeLimits",
		defaultmaxflux => "defaultMaxFlux",defaultmaxuptake => "defaultMaxDrainFlux",defaultminuptake => "defaultMinDrainFlux"
	};
	my $overrideList = {
		activitybonus => "reactionActivationBonus",drainpen => "drainFluxMultiplier",directionpen => "directionalityMultiplier",
		unfavorablepen => "deltaGMultiplier",nodeltagpen => "noDeltaGMultiplier",biomasstranspen => "biomassTransporterMultiplier",
		singletranspen => "singleTransporterMultiplier",nostructpen => "noStructureMultiplier",transpen => "transporterMultiplier",
		blacklistedrxns => "blacklistedReactions",gauranteedrxns => "guaranteedReactions",allowedcmps => "allowableCompartments",
	};
	foreach my $argument (keys(%{$overrideList})) {
		if (defined($in_formulation->{$argument}) && $argument eq "allowunbalanced") {
			$input->{overrides}->{balancedReactionsOnly} = 0;
		} elsif (defined($in_formulation->{$argument})) {
			$input->{overrides}->{$overrideList->{$argument}} = $in_formulation->{$argument};
		}
	}
	foreach my $argument (keys(%{$fbaoverrides})) {
		if (defined($in_formulation->{$argument})) {
			$input->{overrides}->{fbaFormulation}->{overrides}->{$fbaoverrides->{$argument}} = $in_formulation->{$argument};
		}
	}
	my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
	my $gapfillingFormulation = $exchange_factory->buildGapfillingFormulation($input);
    #Running gapfilling
    my $result = $model->gapfillModel({
        gapfillingFormulation => $gapfillingFormulation,
    });
    my $store = $self->{_store};
    if (!defined($result)) {
    	my $msg = "Reactions passing user criteria were insufficient to enable objective.";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'gapfill_fbamodel');
    } else {
		if ($overwrite == 1) {
		    $store->save_object("model/kbase/".$model->id(),$model);
	    } elsif (length($save) > 0) {
			$model->id($save);
			$store->save_object("model/kbase/".$save,$model);
	    }
    }
	$out_model = $self->objectToOutput($model);
    #END gapfill_fbamodel
    my @_bad_returns;
    (ref($out_model) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"out_model\" (value was \"$out_model\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapfill_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_fbamodel');
    }
    return($out_model);
}




=head2 runfba

  $out_solution = $obj->runfba($in_model, $in_formulation, $overwrite, $save)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is an FBAModel
$in_formulation is an FBAFormulation
$overwrite is a bool
$save is a string
$out_solution is an HTMLFile
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
FBAFormulation is a reference to a hash where the following keys are defined:
	model has a value which is a string
	regulatoryModel has a value which is a string
	expressionData has a value which is a string
	media has a value which is a string
	rxnKO has a value which is a reference to a list where each element is a string
	geneKO has a value which is a reference to a list where each element is a string
	objective has a value which is a string
	constraints has a value which is a reference to a list where each element is a string
	bounds has a value which is a reference to a list where each element is a string
	phenotypes has a value which is a reference to a list where each element is a string
	uptakelimits has a value which is a string
	fbaResults has a value which is a reference to a list where each element is an FBAResult
	notes has a value which is a string
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
FBAResult is a reference to a hash where the following keys are defined:
	notes has a value which is a string
	objectiveValue has a value which is a float
	variables has a value which is a reference to a list where each element is an FBAVariable
	fbaPhenotypeSimultationResults has a value which is a reference to a list where each element is an FBAPhenotypeSimulationResult
	fbaDeletionResults has a value which is a reference to a list where each element is an FBADeletionResult
	minimalMediaResults has a value which is a reference to a list where each element is an FBAMinimalMediaResult
	fbaMetaboliteProductionResults has a value which is a reference to a list where each element is an FBAMetaboliteProductionResult
FBAVariable is a reference to a hash where the following keys are defined:
	entityID has a value which is a string
	variableType has a value which is a string
	lowerBound has a value which is a float
	upperBound has a value which is a float
	min has a value which is a float
	max has a value which is a float
	value has a value which is a float
FBAPhenotypeSimulationResult is a reference to a hash where the following keys are defined:
	simultatedPhenotype has a value which is a string
	simulatedGrowthFraction has a value which is a float
	simulatedGrowth has a value which is a float
	class has a value which is a string
	noGrowthCompounds has a value which is a reference to a list where each element is a string
	dependantReactions has a value which is a reference to a list where each element is a string
	dependantGenes has a value which is a reference to a list where each element is a string
	fluxes has a value which is a reference to a list where each element is a string
FBADeletionResult is a reference to a hash where the following keys are defined:
	geneKO has a value which is a reference to a list where each element is a string
	simulatedGrowth has a value which is a float
	simulatedGrowthFraction has a value which is a float
FBAMinimalMediaResult is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a string
	essentialNutrients has a value which is a reference to a list where each element is a string
FBAMetaboliteProductionResult is a reference to a hash where the following keys are defined:
	maximumProduction has a value which is a float
	compound has a value which is a string
HTMLFile is a string

</pre>

=end html

=begin text

$in_model is an FBAModel
$in_formulation is an FBAFormulation
$overwrite is a bool
$save is a string
$out_solution is an HTMLFile
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
FBAFormulation is a reference to a hash where the following keys are defined:
	model has a value which is a string
	regulatoryModel has a value which is a string
	expressionData has a value which is a string
	media has a value which is a string
	rxnKO has a value which is a reference to a list where each element is a string
	geneKO has a value which is a reference to a list where each element is a string
	objective has a value which is a string
	constraints has a value which is a reference to a list where each element is a string
	bounds has a value which is a reference to a list where each element is a string
	phenotypes has a value which is a reference to a list where each element is a string
	uptakelimits has a value which is a string
	fbaResults has a value which is a reference to a list where each element is an FBAResult
	notes has a value which is a string
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
FBAResult is a reference to a hash where the following keys are defined:
	notes has a value which is a string
	objectiveValue has a value which is a float
	variables has a value which is a reference to a list where each element is an FBAVariable
	fbaPhenotypeSimultationResults has a value which is a reference to a list where each element is an FBAPhenotypeSimulationResult
	fbaDeletionResults has a value which is a reference to a list where each element is an FBADeletionResult
	minimalMediaResults has a value which is a reference to a list where each element is an FBAMinimalMediaResult
	fbaMetaboliteProductionResults has a value which is a reference to a list where each element is an FBAMetaboliteProductionResult
FBAVariable is a reference to a hash where the following keys are defined:
	entityID has a value which is a string
	variableType has a value which is a string
	lowerBound has a value which is a float
	upperBound has a value which is a float
	min has a value which is a float
	max has a value which is a float
	value has a value which is a float
FBAPhenotypeSimulationResult is a reference to a hash where the following keys are defined:
	simultatedPhenotype has a value which is a string
	simulatedGrowthFraction has a value which is a float
	simulatedGrowth has a value which is a float
	class has a value which is a string
	noGrowthCompounds has a value which is a reference to a list where each element is a string
	dependantReactions has a value which is a reference to a list where each element is a string
	dependantGenes has a value which is a reference to a list where each element is a string
	fluxes has a value which is a reference to a list where each element is a string
FBADeletionResult is a reference to a hash where the following keys are defined:
	geneKO has a value which is a reference to a list where each element is a string
	simulatedGrowth has a value which is a float
	simulatedGrowthFraction has a value which is a float
FBAMinimalMediaResult is a reference to a hash where the following keys are defined:
	optionalNutrients has a value which is a reference to a list where each element is a string
	essentialNutrients has a value which is a reference to a list where each element is a string
FBAMetaboliteProductionResult is a reference to a hash where the following keys are defined:
	maximumProduction has a value which is a float
	compound has a value which is a string
HTMLFile is a string


=end text



=item Description



=back

=cut

sub runfba
{
    my $self = shift;
    my($in_model, $in_formulation, $overwrite, $save) = @_;

    my @_bad_arguments;
    (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    (ref($in_formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_formulation\" (value was \"$in_formulation\")");
    (!ref($overwrite)) or push(@_bad_arguments, "Invalid type for argument \"overwrite\" (value was \"$overwrite\")");
    (!ref($save)) or push(@_bad_arguments, "Invalid type for argument \"save\" (value was \"$save\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_solution);
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
    (!ref($out_solution)) or push(@_bad_returns, "Invalid type for return variable \"out_solution\" (value was \"$out_solution\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runfba');
    }
    return($out_solution);
}




=head2 object_to_html

  $outHTML = $obj->object_to_html($inObject)

=over 4

=item Parameter and return types

=begin html

<pre>
$inObject is an ObjectSpec
$outHTML is an HTMLFile
ObjectSpec is a reference to a hash where the following keys are defined:
	objectType has a value which is a string
	parentUUID has a value which is a string
	uuid has a value which is a string
HTMLFile is a string

</pre>

=end html

=begin text

$inObject is an ObjectSpec
$outHTML is an HTMLFile
ObjectSpec is a reference to a hash where the following keys are defined:
	objectType has a value which is a string
	parentUUID has a value which is a string
	uuid has a value which is a string
HTMLFile is a string


=end text



=item Description



=back

=cut

sub object_to_html
{
    my $self = shift;
    my($inObject) = @_;

    my @_bad_arguments;
    (ref($inObject) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"inObject\" (value was \"$inObject\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to object_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'object_to_html');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($outHTML);
    #BEGIN object_to_html
    my $object = $self->loadObject($inObject);
    $outHTML = $object->createHTML();
    #END object_to_html
    my @_bad_returns;
    (!ref($outHTML)) or push(@_bad_returns, "Invalid type for return variable \"outHTML\" (value was \"$outHTML\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to object_to_html:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'object_to_html');
    }
    return($outHTML);
}




=head2 gapgen_fbamodel

  $out_model = $obj->gapgen_fbamodel($in_model, $in_formulation, $overwrite, $save)

=over 4

=item Parameter and return types

=begin html

<pre>
$in_model is an FBAModel
$in_formulation is a GapgenFormulation
$overwrite is a bool
$save is a string
$out_model is an FBAModel
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
GapgenFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a string
	refmedia has a value which is a string
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

$in_model is an FBAModel
$in_formulation is a GapgenFormulation
$overwrite is a bool
$save is a string
$out_model is an FBAModel
FBAModel is a reference to a hash where the following keys are defined:
	ancestor has a value which is a model_id
	id has a value which is a model_id
	name has a value which is a string
	version has a value which is an int
	type has a value which is a string
	status has a value which is a string
	current has a value which is an int
	growth has a value which is a float
	genome has a value which is a genome_id
	map has a value which is a mapping_id
	biochemistry has a value which is a biochemistry_id
	biomasses has a value which is a reference to a list where each element is a BiomassTO
	modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
	modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
	modelreactions has a value which is a reference to a list where each element is a ModelReactionTO
model_id is a string
genome_id is a string
mapping_id is a string
biochemistry_id is a string
BiomassTO is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	name has a value which is a string
	biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO
biomass_id is a string
BiomassCompoundTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
modelcompound_id is a string
ModelCompartmentTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompartment_id
	compartment_id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
	index has a value which is an int
modelcompartment_id is a string
compartment_id is a string
ModelCompoundTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelcompound_id
	name has a value which is a string
	compound_id has a value which is a compound_id
	modelcompartment_id has a value which is a modelcompartment_id
	charge has a value which is a float
	formula has a value which is a string
compound_id is a string
ModelReactionTO is a reference to a hash where the following keys are defined:
	id has a value which is a modelreaction_id
	reaction_id has a value which is a reaction_id
	modelcompartment_id has a value which is a modelcompartment_id
	direction has a value which is a string
	protons has a value which is a string
	equation has a value which is a string
	gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
	modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO
modelreaction_id is a string
reaction_id is a string
ModelReactionRawGPRTO is a reference to a hash where the following keys are defined:
	isCustomGPR has a value which is a bool
	rawGPR has a value which is a string
bool is an int
ModelReactionReagentTO is a reference to a hash where the following keys are defined:
	modelcompound_id has a value which is a modelcompound_id
	coefficient has a value which is a float
GapgenFormulation is a reference to a hash where the following keys are defined:
	media has a value which is a string
	refmedia has a value which is a string
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



=item Description



=back

=cut

sub gapgen_fbamodel
{
    my $self = shift;
    my($in_model, $in_formulation, $overwrite, $save) = @_;

    my @_bad_arguments;
    (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_model\" (value was \"$in_model\")");
    (ref($in_formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"in_formulation\" (value was \"$in_formulation\")");
    (!ref($overwrite)) or push(@_bad_arguments, "Invalid type for argument \"overwrite\" (value was \"$overwrite\")");
    (!ref($save)) or push(@_bad_arguments, "Invalid type for argument \"save\" (value was \"$save\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapgen_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_fbamodel');
    }

    my $ctx = $fbaModelServicesServer::CallContext;
    my($out_model);
    #BEGIN gapgen_fbamodel
    #Retreiving the model
    my $model = $self->loadObject($in_model);
	#Creating gapgen formulation
	my $input = {model => $model};
	my $fbaoverrides = {
		media => "media",notes => "notes",objfraction => "objectiveConstraintFraction",
		objective => "objectiveString",rxnko => "geneKO",geneko => "reactionKO",uptakelim => "uptakeLimits",
		defaultmaxflux => "defaultMaxFlux",defaultmaxuptake => "defaultMaxDrainFlux",defaultminuptake => "defaultMinDrainFlux"
	};
	my $overrideList = {
		refmedia => "referenceMedia",nomediahyp => "!mediaHypothesis",nobiomasshyp => "!biomassHypothesis",
		nogprhyp => "!gprHypothesis",nopathwayhyp => "!reactionRemovalHypothesis"
	};
	foreach my $argument (keys(%{$overrideList})) {
		if ($overrideList->{$argument} =~ m/^\!(.+)$/) {
			$argument = $1;
			if (defined($in_formulation->{$argument})) {
				$input->{overrides}->{$overrideList->{$argument}} = 0;
			} else {
				$input->{overrides}->{$overrideList->{$argument}} = 1;
			}
		} else {
			$input->{overrides}->{$overrideList->{$argument}} = $in_formulation->{$argument};
		}
	}
	foreach my $argument (keys(%{$fbaoverrides})) {
		if (defined($in_formulation->{$argument})) {
			$input->{overrides}->{fbaFormulation}->{overrides}->{$fbaoverrides->{$argument}} = $in_formulation->{$argument};
		}
	}
	my $exchange_factory = ModelSEED::MS::Factories::ExchangeFormatFactory->new();
	my $gapgenFormulation = $exchange_factory->buildGapgenFormulation($input);
    #Running gapgeneration
    my $result = $model->gapgenModel({
        gapgenFormulation => $gapgenFormulation,
    }); 
    my $store = $self->{_store};
    if (!defined($result)) {
    	my $msg = "Could not find knockouts to meet gapgen specifications!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'gapgen_fbamodel');
    } else {
		if ($overwrite == 1) {
		    $store->save_object("model/kbase/".$model->id(),$model);
	    } elsif (length($save) > 0) {
			$model->id($save);
			$store->save_object("model/kbase/".$save,$model);
	    }
    }
	$out_model = $self->objectToOutput($model);
    #END gapgen_fbamodel
    my @_bad_returns;
    (ref($out_model) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"out_model\" (value was \"$out_model\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapgen_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_fbamodel');
    }
    return($out_model);
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



=head2 Feature

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a feature_id
location has a value which is a location
type has a value which is a feature_type
function has a value which is a string
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
protein_translation has a value which is a string
aliases has a value which is a reference to a list where each element is a string
annotations has a value which is a reference to a list where each element is an annotation


=end text

=back



=head2 Contig

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



=head2 GenomeTO

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
contigs has a value which is a reference to a list where each element is a Contig
features has a value which is a reference to a list where each element is a Feature

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
contigs has a value which is a reference to a list where each element is a Contig
features has a value which is a reference to a list where each element is a Feature


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



=head2 ModelCompoundTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a modelcompound_id
name has a value which is a string
compound_id has a value which is a compound_id
modelcompartment_id has a value which is a modelcompartment_id
charge has a value which is a float
formula has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelcompound_id
name has a value which is a string
compound_id has a value which is a compound_id
modelcompartment_id has a value which is a modelcompartment_id
charge has a value which is a float
formula has a value which is a string


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



=head2 ModelReactionRawGPRTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
isCustomGPR has a value which is a bool
rawGPR has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
isCustomGPR has a value which is a bool
rawGPR has a value which is a string


=end text

=back



=head2 ModelReactionReagentTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
modelcompound_id has a value which is a modelcompound_id
coefficient has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
modelcompound_id has a value which is a modelcompound_id
coefficient has a value which is a float


=end text

=back



=head2 ModelReactionTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a modelreaction_id
reaction_id has a value which is a reaction_id
modelcompartment_id has a value which is a modelcompartment_id
direction has a value which is a string
protons has a value which is a string
equation has a value which is a string
gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelreaction_id
reaction_id has a value which is a reaction_id
modelcompartment_id has a value which is a modelcompartment_id
direction has a value which is a string
protons has a value which is a string
equation has a value which is a string
gpr has a value which is a reference to a list where each element is a ModelReactionRawGPRTO
modelReactionReagents has a value which is a reference to a list where each element is a ModelReactionReagentTO


=end text

=back



=head2 BiomassCompoundTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
modelcompound_id has a value which is a modelcompound_id
coefficient has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
modelcompound_id has a value which is a modelcompound_id
coefficient has a value which is a float


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



=head2 BiomassTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
name has a value which is a string
biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
name has a value which is a string
biomassCompounds has a value which is a reference to a list where each element is a BiomassCompoundTO


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



=head2 ModelCompartmentTO

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a modelcompartment_id
compartment_id has a value which is a compartment_id
name has a value which is a string
pH has a value which is a float
potential has a value which is a float
index has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a modelcompartment_id
compartment_id has a value which is a compartment_id
name has a value which is a string
pH has a value which is a float
potential has a value which is a float
index has a value which is an int


=end text

=back



=head2 model_id

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



=head2 reactionset_id

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



=head2 FBAModelEX

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



=head2 SBML

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



=head2 HTMLFile

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



=head2 fbaformulation_id

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



=head2 FBAVariable

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
entityID has a value which is a string
variableType has a value which is a string
lowerBound has a value which is a float
upperBound has a value which is a float
min has a value which is a float
max has a value which is a float
value has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
entityID has a value which is a string
variableType has a value which is a string
lowerBound has a value which is a float
upperBound has a value which is a float
min has a value which is a float
max has a value which is a float
value has a value which is a float


=end text

=back



=head2 FBAPhenotypeSimulationResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
simultatedPhenotype has a value which is a string
simulatedGrowthFraction has a value which is a float
simulatedGrowth has a value which is a float
class has a value which is a string
noGrowthCompounds has a value which is a reference to a list where each element is a string
dependantReactions has a value which is a reference to a list where each element is a string
dependantGenes has a value which is a reference to a list where each element is a string
fluxes has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
simultatedPhenotype has a value which is a string
simulatedGrowthFraction has a value which is a float
simulatedGrowth has a value which is a float
class has a value which is a string
noGrowthCompounds has a value which is a reference to a list where each element is a string
dependantReactions has a value which is a reference to a list where each element is a string
dependantGenes has a value which is a reference to a list where each element is a string
fluxes has a value which is a reference to a list where each element is a string


=end text

=back



=head2 FBADeletionResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
geneKO has a value which is a reference to a list where each element is a string
simulatedGrowth has a value which is a float
simulatedGrowthFraction has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
geneKO has a value which is a reference to a list where each element is a string
simulatedGrowth has a value which is a float
simulatedGrowthFraction has a value which is a float


=end text

=back



=head2 FBAMinimalMediaResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
optionalNutrients has a value which is a reference to a list where each element is a string
essentialNutrients has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
optionalNutrients has a value which is a reference to a list where each element is a string
essentialNutrients has a value which is a reference to a list where each element is a string


=end text

=back



=head2 FBAMetaboliteProductionResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
maximumProduction has a value which is a float
compound has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
maximumProduction has a value which is a float
compound has a value which is a string


=end text

=back



=head2 FBAResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
notes has a value which is a string
objectiveValue has a value which is a float
variables has a value which is a reference to a list where each element is an FBAVariable
fbaPhenotypeSimultationResults has a value which is a reference to a list where each element is an FBAPhenotypeSimulationResult
fbaDeletionResults has a value which is a reference to a list where each element is an FBADeletionResult
minimalMediaResults has a value which is a reference to a list where each element is an FBAMinimalMediaResult
fbaMetaboliteProductionResults has a value which is a reference to a list where each element is an FBAMetaboliteProductionResult

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
notes has a value which is a string
objectiveValue has a value which is a float
variables has a value which is a reference to a list where each element is an FBAVariable
fbaPhenotypeSimultationResults has a value which is a reference to a list where each element is an FBAPhenotypeSimulationResult
fbaDeletionResults has a value which is a reference to a list where each element is an FBADeletionResult
minimalMediaResults has a value which is a reference to a list where each element is an FBAMinimalMediaResult
fbaMetaboliteProductionResults has a value which is a reference to a list where each element is an FBAMetaboliteProductionResult


=end text

=back



=head2 FBAFormulation

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a string
regulatoryModel has a value which is a string
expressionData has a value which is a string
media has a value which is a string
rxnKO has a value which is a reference to a list where each element is a string
geneKO has a value which is a reference to a list where each element is a string
objective has a value which is a string
constraints has a value which is a reference to a list where each element is a string
bounds has a value which is a reference to a list where each element is a string
phenotypes has a value which is a reference to a list where each element is a string
uptakelimits has a value which is a string
fbaResults has a value which is a reference to a list where each element is an FBAResult
notes has a value which is a string
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

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a string
regulatoryModel has a value which is a string
expressionData has a value which is a string
media has a value which is a string
rxnKO has a value which is a reference to a list where each element is a string
geneKO has a value which is a reference to a list where each element is a string
objective has a value which is a string
constraints has a value which is a reference to a list where each element is a string
bounds has a value which is a reference to a list where each element is a string
phenotypes has a value which is a reference to a list where each element is a string
uptakelimits has a value which is a string
fbaResults has a value which is a reference to a list where each element is an FBAResult
notes has a value which is a string
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


=end text

=back



=head2 ReactionSetMultiplier

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reactionset has a value which is a reactionset_id
reactionsetType has a value which is a string
multiplierType has a value which is a string
description has a value which is a string
multiplier has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reactionset has a value which is a reactionset_id
reactionsetType has a value which is a string
multiplierType has a value which is a string
description has a value which is a string
multiplier has a value which is a float


=end text

=back



=head2 GeneCandidate

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
role has a value which is a string
orthologGenome has a value which is a genome_id
ortholog has a value which is a feature_id
feature has a value which is a feature_id
similarityScore has a value which is a float
distanceScore has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
role has a value which is a string
orthologGenome has a value which is a genome_id
ortholog has a value which is a feature_id
feature has a value which is a feature_id
similarityScore has a value which is a float
distanceScore has a value which is a float


=end text

=back



=head2 GapfillingFormulation

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a string
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

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a string
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


=end text

=back



=head2 GapgenFormulation

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a string
refmedia has a value which is a string
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
media has a value which is a string
refmedia has a value which is a string
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



=head2 FBAModel

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ancestor has a value which is a model_id
id has a value which is a model_id
name has a value which is a string
version has a value which is an int
type has a value which is a string
status has a value which is a string
current has a value which is an int
growth has a value which is a float
genome has a value which is a genome_id
map has a value which is a mapping_id
biochemistry has a value which is a biochemistry_id
biomasses has a value which is a reference to a list where each element is a BiomassTO
modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
modelreactions has a value which is a reference to a list where each element is a ModelReactionTO

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ancestor has a value which is a model_id
id has a value which is a model_id
name has a value which is a string
version has a value which is an int
type has a value which is a string
status has a value which is a string
current has a value which is an int
growth has a value which is a float
genome has a value which is a genome_id
map has a value which is a mapping_id
biochemistry has a value which is a biochemistry_id
biomasses has a value which is a reference to a list where each element is a BiomassTO
modelcompartments has a value which is a reference to a list where each element is a ModelCompartmentTO
modelcompounds has a value which is a reference to a list where each element is a ModelCompoundTO
modelreactions has a value which is a reference to a list where each element is a ModelReactionTO


=end text

=back



=head2 ObjectSpec

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
objectType has a value which is a string
parentUUID has a value which is a string
uuid has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
objectType has a value which is a string
parentUUID has a value which is a string
uuid has a value which is a string


=end text

=back



=cut

1;
