package Bio::KBase::fbaModelServices::Impl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

fbaModelServices

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

#BEGIN_HEADER
use URI;
use Bio::KBase::IDServer::Client;
use Bio::KBase::CDMI::CDMIClient;
use Bio::KBase::AuthToken;
use Bio::KBase::ClusterService;
use Bio::KBase::workspaceService::Client;
use ModelSEED::KBaseStore;
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
use ModelSEED::MS::PROMModel;;
use ModelSEED::MS::Metadata::Definitions;
use ModelSEED::Client::MSSeedSupport;
use ModelSEED::utilities qw( args verbose set_verbose translateArrayOptions);
use Try::Tiny;
use Data::Dumper;
use Config::Simple;
use POSIX;

sub _authentication {
	my($self) = @_;
	if (defined($self->_getContext->{_override}->{_authentication})) {
		return $self->_getContext->{_override}->{_authentication};
	}
	return undef;
}

sub _getUsername {
	my ($self) = @_;
	if (!defined($self->_getContext->{_override}->{_currentUser})) {
		if (defined($self->{_testuser})) {
			$self->_getContext->{_override}->{_currentUser} = $self->{_testuser};
		} else {
			$self->_getContext->{_override}->{_currentUser} = "public";
		}
		
	}
	return $self->_getContext->{_override}->{_currentUser};
}

sub _cachedBiochemistry {
	my ($self,$biochemistry) = @_;
	if (defined($biochemistry)) {
		$self->{_cachedbiochemistry} = $biochemistry;
		$self->{_initialBiochemistryCounts}->{Media} = @{$biochemistry->media()};
		$self->{_initialBiochemistryCounts}->{Compounds} = @{$biochemistry->compounds()};
		$self->{_initialBiochemistryCounts}->{Reactions} = @{$biochemistry->reactions()};
	}
	return $self->{_cachedbiochemistry};
}

sub _resetCachedBiochemistry {
	my ($self) = @_;
	if (defined($self->_cachedBiochemistry())) {
		if (@{$self->_cachedBiochemistry()->media()} >= $self->_cachedBiochemistry()) {
			for (my $i=@{$self->_cachedBiochemistry()->media()}; $i >= $self->{_initialBiochemistryCounts}->{Media}; $i--) {
				$self->_cachedBiochemistry()->remove("media",$self->_cachedBiochemistry()->media()->[$i]);
			}
		}
		if (@{$self->_cachedBiochemistry()->compounds()} >= $self->_cachedBiochemistry()) {
			for (my $i=@{$self->_cachedBiochemistry()->compounds()}; $i >= $self->{_initialBiochemistryCounts}->{Compounds}; $i--) {
				$self->_cachedBiochemistry()->remove("compounds",$self->_cachedBiochemistry()->compounds()->[$i]);
			}
		}
		if (@{$self->_cachedBiochemistry()->reactions()} >= $self->_cachedBiochemistry()) {
			for (my $i=@{$self->_cachedBiochemistry()->reactions()}; $i >= $self->{_initialBiochemistryCounts}->{Reactions}; $i--) {
				$self->_cachedBiochemistry()->remove("reactions",$self->_cachedBiochemistry()->reactions()->[$i]);
			}
		}
	}
}

sub _resetKBaseStore {
	my ($self) = @_;
	delete $self->{_kbasestore};
	if (defined($self->_authentication())) {
		$self->{_kbasestore} = ModelSEED::KBaseStore->new({
			auth => $self->_authentication(),
			workspace => $self->_workspaceServices()
		});
	} else {
		$self->{_kbasestore} = ModelSEED::KBaseStore->new({
			auth => "",
			workspace => $self->_workspaceServices()
		});
	}
	if (defined($self->_cachedBiochemistry())) {
		$self->_resetCachedBiochemistry();
		$self->{_kbasestore}->cache()->{Biochemistry}->{"kbase/default"} = $self->_cachedBiochemistry();
	}
}

sub _KBaseStore {
	my ($self) = @_;
	return $self->{_kbasestore};
}

sub _setContext {
	my ($self,$context,$params) = @_;
	#Clearing the existing kbasestore and initializing a new one
	if (defined($params->{wsurl})) {
		$self->_getContext()->{_override}->{_wsurl} = $params->{wsurl};
	}	
	$self->_resetKBaseStore();
	if ( defined $params->{auth} ) {
		if (!defined($self->_getContext()->{_override}) || $self->_getContext()->{_override}->{_authentication} ne $params->{auth}) {
			if ($params->{auth} eq m/^IRIS-/ ) {
				$self->_getContext()->{_override}->{_authentication} = $params->{auth};
				$self->_getContext()->{_override}->{_currentUser} = $params->{auth};
			} else {
				my $token = Bio::KBase::AuthToken->new(
					token => $params->{auth},
				);
				if ($token->validate()) {
					$self->_getContext()->{_override}->{_authentication} = $params->{auth};
					$self->_getContext()->{_override}->{_currentUser} = $token->user_id;
					$self->_KBaseStore()->auth($params->{auth});
				} else {
					Bio::KBase::Exceptions::KBaseException->throw(error => "Invalid authorization token!",
					method_name => '_setContext');
				}
			}
		}
    }
}

sub _getContext {
	my ($self) = @_;
	if (!defined($Bio::KBase::fbaModelServices::Server::CallContext)) {
		$Bio::KBase::fbaModelServices::Server::CallContext = {};
	}
	return $Bio::KBase::fbaModelServices::Server::CallContext;
}

sub _clearContext {
	my ($self) = @_;
}

sub _modify_annotation_from_probanno {
	my ($self,$input) = @_;
    $input = $self->_validateargs($input,["probanno","annotation"],{
		threshold => 0,
		probannoonly => 0,
	});
    my $probanno = $input->{probanno};
    my $annotation = $input->{annotation};
    my $mapping = $annotation->mapping();
    if (defined($probanno->{featureAlternativeFunctions})) {
		if ($input->{probannoonly} == 1) {
			my $ftrs = $annotation->features();
			for (my $i=0; $i < @{$ftrs}; $i++) {
				my $ftr = $ftrs->[$i];
				my $roles = $ftr->featureroles();
				for (my $j=0; $j < @{$roles}; $j++) {
					$ftr->remove($roles->[$j]);
				}
			}	
		}
		for (my $i=0; $i < @{$probanno->{featureAlternativeFunctions}}; $i++) {
			my $feature = $probanno->{featureAlternativeFunctions}->[$i];
			my $ftrObj = $annotation->query_object("features",{id => $feature->{id}});
			if (defined($ftrObj) && defined($feature->{alternative_functions})) {
				for (my $j=0; $j < @{$feature->{alternative_functions}}; $j++) {
					my $anno = $feature->{alternative_functions}->[$j];
					if ($anno->[1] >= $input->{threshold}) {
						my $role = $mapping->queryObject( "roles",{
							name => $anno->[0]
						});
						if ( !defined($role) ) {
							$role = $mapping->add( "roles",{
								name => $anno->[0]
							});
						}
						my $roles = $feature->featureroles();
						my $found = 0;
						for (my $k=0; $k < @{$roles}; $k++) {
							if ($roles->[$k]->role()->uuid() eq $role->uuid()) {
								$found = 1;
							}
						}
						if ($found == 0) {
							$ftrObj->add("featureroles",{
								 role_uuid   => $role->uuid(),
								 compartment => "u",
								 delimiter   => ";",
								 comment     => "Added from probabilistic annotation with probability ".$anno->[1]
							});
						}
					} 
				}
			}
		}
	}
    return ($annotation,$mapping);
}

sub _translate_genome_to_annotation {
    my($self,$genome,$mapping) = @_;
   	if (!defined($genome->{gc}) || !defined($genome->{size})) {
   		$genome->{gc} = 0.5;
   		$genome->{size} = 0;
   		my $contigs = [];
   		if (defined($genome->{contigs})) {
   			$contigs = $genome->{contigs};
   		} elsif (defined($genome->{contigs_uuid})) {
   			my $obj = $self->_get_msobject("GenomeContigs","NO_WORKSPACE",$genome->{contigs_uuid});
   			$contigs = $obj->{contigs};
   		}
   		for ( my $i = 0 ; $i < @{ $contigs } ; $i++ ) {
			my $dna = $contigs->[$i]->{dna};
			$genome->{size} += length($dna);
			for ( my $j = 0 ; $j < length($dna) ; $j++ ) {
				if ( substr( $dna, $j, 1 ) =~ m/[gcGC]/ ) {
					$genome->{gc}++;
				}
			}
		}
   	}
    #Creating the annotation from the input genome object
	my $annotation = ModelSEED::MS::Annotation->new({
	  name         => $genome->{scientific_name},
	  mapping_uuid => $mapping->uuid(),
	  mapping      => $mapping,
	  genomes      => [{
		 name => $genome->{scientific_name},
		 source   => "KBase",
		 id       => $genome->{id},
		 cksum    => "unknown",
		 class    => "unknown",
		 taxonomy => $genome->{domain},
		 etcType  => "unknown",
		 size     => $genome->{size},
		 gc       => $genome->{gc}
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
	if (!defined($self->{_workspaceServices}->{$self->_workspaceURL()})) {
		$self->{_workspaceServices}->{$self->_workspaceURL()} = Bio::KBase::workspaceService::Client->new($self->_workspaceURL());
	}
    return $self->{_workspaceServices}->{$self->_workspaceURL()};
}

sub _workspaceURL {
	my $self = shift;
	if (defined($self->_getContext()->{_override}->{_wsurl})) {
		return $self->_getContext()->{_override}->{_wsurl};
	}
	return $self->{"_workspace-url"};
}

sub _myURL {
	my $self = shift;
	return "http://bio-data-1.mcs.anl.gov/services/fba";
}

sub _save_msobject {
	my($self,$obj,$type,$ws,$id,$command,$overwrite,$reference) = @_;
	my $data;
	if (defined($obj->{_kbaseWSMeta})) {
		delete $obj->{_kbaseWSMeta};
	}
	if (ref($obj) =~ m/ModelSEED::MS::/) {
		$data = $obj->serializeToDB();
	} else {
		$data = $obj;
	}
	my $objmeta;
	if ($ws eq "NO_WORKSPACE") {
		$objmeta = $self->_workspaceServices()->save_object_by_ref({
			reference => $reference,
			id => $id,
			type => $type,
			data => $data,
			command => $command,
			auth => $self->_authentication(),
			replace => $overwrite
		});
	} else {
		$objmeta = $self->_workspaceServices()->save_object({
			id => $id,
			type => $type,
			data => $data,
			workspace => $ws,
			command => $command,
			auth => $self->_authentication(),
			overwrite => $overwrite
		});
	}
	if (!defined($objmeta)) {
		my $msg = "Unable to save object:".$type."/".$ws."/".$id;
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_msobject');
	}
	$obj->{_kbaseWSMeta}->{wsid} = $id;
	$obj->{_kbaseWSMeta}->{ws} = $ws;
	$obj->{_kbaseWSMeta}->{wsinst} = $objmeta->[3];	
	if ($type eq "Model" || $type eq "Mapping" || $type eq "Annotation" || $type eq "Biochemistry") {
		$obj->uuid($objmeta->[8]);
	}
	return $objmeta;
}

sub _get_msobject {
	my($self,$type,$ws,$id,$cache) = @_;
	my $ref = $ws."/".$id;
	if ($ws eq "NO_WORKSPACE") {
		$ref = $id;
	}
	my $obj = $self->_KBaseStore()->get_object($type,$ref);
	if (!defined($self->_cachedBiochemistry()) && $type eq "Biochemistry" && $id eq "default" && $ws eq "kbase") {
		$self->_cachedBiochemistry($obj);
	}
	#Processing genomes to automatically have an annotation object
	if ($type eq "Genome") {
		if (!defined($obj->{annotation_uuid})) {
			my $mapping = $self->_get_msobject("Mapping","kbase","default");
			($obj,my $annotation,$mapping,my $contigs) = $self->_processGenomeObject($obj,$mapping,"get_genome_object");
			my $meta = $self->_save_msobject($obj,"Genome",$ws,$id,"get_genome_object");
		}
	}
	return $obj;
}


sub _set_uuid_by_idws {
	my($self,$id,$ws) = @_;
	if ($ws eq "NO_WORKSPACE") {
		return $id;
	}
	return $ws."/".$id;
}

sub _get_object_by_uuid {
	my($self,$type,$uuid,$cache) = @_;
	if ($uuid =~ m/(.+)\/([^\/]+)$/) {
		return $self->_get_msobject($type,$1,$2,$cache);
	}
	return $self->_get_msobject($type,"NO_WORKSPACE",$uuid,$cache);
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
  	my $size = 0;
	my $gc   = 0;
	for ( my $i = 0 ; $i < @{ $genomeObj->{contigs} } ; $i++ ) {
		my $dna = $genomeObj->{contigs}->[$i]->{dna};
		$size += length($dna);
		for ( my $j = 0 ; $j < length($dna) ; $j++ ) {
			if ( substr( $dna, $j, 1 ) =~ m/[gcGC]/ ) {
				$gc++;
			}
		}
	}
	$genomeObj->{gc} = $gc;
	$genomeObj->{size} = $size;
	return $genomeObj;
}

sub _get_genomeObj_from_SEED {
	my($self,$id) = @_;
	my $sapsvr = ModelSEED::Client::SAP->new();;
	my $data = $sapsvr->genome_data({
		-ids => [$id],
		-data => [qw(gc-content dna-size name taxonomy domain genetic-code)]
	});
	if (!defined($data->{$id})) {
    	my $msg = "Could not load data for PubSEED genome!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_get_genomeObj_from_SEED');
	}
	my $genomeObj = {
		id => $id,
		scientific_name => $data->{$id}->[2],
		genetic_code => $data->{$id}->[5],
		domain => $data->{$id}->[4],
		size => $data->{$id}->[1],
		gc => $data->{$id}->[0],
		taxonomy => $data->{$id}->[3],
		source => "PubSEED",
		source_id => $id,
		contigs => [],
		features => []
    };
	my $featureHash = $sapsvr->all_features({-ids => $id});
	if (!defined($featureHash->{$id})) {
		die "Could not load features for pubseed genome: $id";
	}
	my $genomeHash = $sapsvr->genome_contigs({
		-ids => [$id]
	});
	my $featureList = $featureHash->{$id};
	my $contigList = $genomeHash->{$id};
	my $functions = $sapsvr->ids_to_functions({-ids => $featureList});
	my $locations = $sapsvr->fid_locations({-ids => $featureList});
	my $sequences = $sapsvr->fids_to_proteins({-ids => $featureList,-sequence => 1});
	my $contigHash = $sapsvr->contig_sequences({
		-ids => $contigList
	});
	foreach my $key (keys(%{$contigHash})) {
		push(@{$genomeObj->{contigs}},{
			id => $key,
	    	dna => $contigHash->{$key}
		});
	}
	for (my $i=0; $i < @{$featureList}; $i++) {
		my $feature = {
  			id => $featureList->[$i],
  			location => undef,
  			function => undef,
  			aliases => [],
  			annotations => []
  		};
  		if (defined($locations->{$featureList->[$i]}->[0])) {
			for (my $j=0; $j < @{$locations->{$featureList->[$i]}}; $j++) {
				my $loc = $locations->{$featureList->[$i]}->[$j];
				if ($loc =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
					my $array = [split(/:/,$1)];
					if ($3 eq "-" || $3 eq "+") {
						$feature->{location}->[$j] = [$array->[1],$2,$3,$4];
					} elsif ($2 > $4) {
						$feature->{location}->[$j] = [$array->[1],$2,"-",($2-$4)];
					} else {
						$feature->{location}->[$j] = [$array->[1],$2,"+",($4-$2)];
					}
				}
			}
			
		}
		if (defined($functions->{$featureList->[$i]})) {
			$feature->{function} = $functions->{$featureList->[$i]};
		}
		if (defined($sequences->{$featureList->[$i]})) {
			$feature->{protein_translation} = $sequences->{$featureList->[$i]};
		}
  		push(@{$genomeObj->{features}},$feature);	
	}
	return $genomeObj;
}

sub _get_genomeObj_from_RAST {
	my($self,$id,$username,$password) = @_;
	my $mssvr = ModelSEED::Client::MSSeedSupport->new();
	my $data = $mssvr->genomeData({
		ids      => [ $id ],
		username => $username,
		password => $password,
		withSequences => 1
	});
    $data = $data->{$id};
    if (!defined($data->{features})) {
    	my $msg = "Could not load data for rast genome!";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => '_buildFBAObject');
	}
	my $genomeObj = {
		id => $id,
		scientific_name => $data->{name},
		genetic_code => "11",#TODO
		domain => $data->{taxonomy},#TODO
		size => $data->{size},
		gc => 0,
		source => "RAST",
		source_id => $id,
		contigs => [],
		features => []
    };
    if (defined($data->{sequence})) {
    	for (my $i=0; $i < @{$data->{sequence}}; $i++) {
    		push(@{$genomeObj->{contigs}},{
    			id => $id.".contig.".$i,
	    		dna => $data->{sequence}->[$i]
    		});
    	}
    	my $size = 0;
    	for ( my $i = 0 ; $i < @{ $genomeObj->{contigs} } ; $i++ ) {
			my $dna = $genomeObj->{contigs}->[$i]->{dna};
			$size += length($dna);
			for ( my $j = 0 ; $j < length($dna) ; $j++ ) {
				if ( substr( $dna, $j, 1 ) =~ m/[gcGC]/ ) {
					$genomeObj->{gc}++;
				}
			}
		}
		if ($size > 0) {
			$genomeObj->{gc} = $genomeObj->{gc}/$size;
		} else {
			$genomeObj->{gc} = 0.5;
		}
    }
	for (my $i=0; $i < @{$data->{features}}; $i++) {
		my $ftr = $data->{features}->[$i];
		my $feature = {
  			id => $ftr->{ID},
  			location => "",
  			function => "",
  			aliases => [],
  			annotations => []
  		};
  		if (defined($ftr->{LOCATION}) && $ftr->{LOCATION} =~ m/^(.+)_(\d+)([\+\-_])(\d+)$/) {
			my $contigData = $1;
			if ($3 eq "-" || $3 eq "+") {
				$feature->{location} = [[$contigData,$2,$3,$4]];
			} elsif ($2 > $4) {
				$feature->{location} = [[$contigData,$2,"-",($2-$4)]];
			} else {
				$feature->{location} = [[$contigData,$2,"+",($4-$2)]];
			}
		}
  		if (defined($ftr->{SEQUENCE})) {
			$feature->{protein_translation} = $ftr->{SEQUENCE}->[0];
		}
		if (defined($ftr->{FUNCTION})) {
			$feature->{function} = $ftr->{FUNCTION};
		}
  		push(@{$genomeObj->{features}},$feature);
	}
	return $genomeObj;
}

sub _processGenomeObject {
	my($self,$genome,$mapping,$command) = @_;
	my $anno = $self->_translate_genome_to_annotation($genome,$mapping);
	my $meta = $self->_save_msobject($mapping,"Mapping","NO_WORKSPACE",$genome->{id}.".anno.mapping",$command);
	$anno->mapping_uuid($meta->[8]);
	$meta = $self->_save_msobject($anno,"Annotation","NO_WORKSPACE",$genome->{id}.".anno",$command);
	$genome->{annotation_uuid} = $meta->[8];
	my $contigObj = {contigs => $genome->{contigs}};
	$meta = $self->_save_msobject($contigObj,"GenomeContigs","NO_WORKSPACE",$genome->{id}.".contigs",$command);
	$genome->{contigs_uuid} = $meta->[8];
	delete $genome->{contigs};
	return ($genome,$anno,$mapping,$contigObj);
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
		media_workspace => "NO_WORKSPACE",
		objfraction => 0.1,
		allreversible => 0,
		maximizeObjective => 1,
		objectiveTerms => [
			[1,"biomassflux","bio1"]
		],
		additionalcpds => [],
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
		minthermoerror => 0,
		prommodel => undef,
		prommodel_workspace => undef
	});
	return $fbaFormulation;
}

sub _buildFBAObject {
	my ($self,$fbaFormulation,$model,$workspace,$id) = @_;
	#Parsing media
	my $media;
	if ($fbaFormulation->{media_workspace} ne "NO_WORKSPACE") {
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
	my $fbaid = $workspace."/".$id;
	if ($workspace eq "NO_WORKSPACE") {
		$fbaid = $id;
	}
	#Building FBAFormulation object
	my $form = ModelSEED::MS::FBAFormulation->new({
		uuid => $fbaid,
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
	$form->parent($self->_KBaseStore());
	if (defined($fbaFormulation->{prommodel}) && defined($fbaFormulation->{prommodel_workspace})) {
		my $promobj = $self->_get_msobject("PROMModel",$fbaFormulation->{prommodel_workspace},$fbaFormulation->{prommodel});
		if (defined($promobj)) {
			$form->promModel_uuid($promobj->uuid());
			$form->promModel($promobj);
		}
	}
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
	foreach my $reaction (@{$fbaFormulation->{rxnko}}) {
		my $rxnObj = $model->biochemistry()->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$form->addLinkArrayItem("reactionKOs",$rxnObj);
		}
	}
	#Parsing additional Cpds
	foreach my $compound (@{$fbaFormulation->{additionalcpds}}) {
		my $cpdObj = $model->biochemistry()->searchForCompound($compound);
		if (defined($cpdObj)) {
			$form->addLinkArrayItem("additionalCpds",$cpdObj);
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
		timePerSolution => 3600,
		totalTimeLimit => 18000,
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
	my ($self,$formulation,$model) = @_;
	my $fbaid = Data::UUID->new()->create_str();
	my $gapform = ModelSEED::MS::GapfillingFormulation->new({
		uuid => Data::UUID->new()->create_str(),
		model_uuid => $model->uuid(),
		model => $model,
		fbaFormulation_uuid => $fbaid,
		fbaFormulation => $self->_buildFBAObject($formulation->{formulation},$model,"NO_WORKSPACE",$fbaid),
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
		timePerSolution => $formulation->{timePerSolution},
		totalTimeLimit => $formulation->{totalTimeLimit},
	});
	$gapform->parent($self->_KBaseStore());
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
	$gapform->{_kbaseWSMeta}->{wsid} = $gapform->uuid();
	$gapform->{_kbaseWSMeta}->{ws} = "NO_WORKSPACE";
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
		refmedia_workspace => "KBaseMedia",
		timePerSolution => 3600,
		totalTimeLimit => 18000,
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
	my ($self,$formulation,$model) = @_;
	#Parsing media
	my $media;
	my $mediaobj;
	if ($formulation->{refmedia_workspace} ne "NO_WORKSPACE") {
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
	my $fbaid = Data::UUID->new()->create_str();
	my $gapform = ModelSEED::MS::GapgenFormulation->new({
		uuid => Data::UUID->new()->create_str(),
		model_uuid => $model->uuid(),
		model => $model,
		fbaFormulation_uuid => $fbaid,
		fbaFormulation => $self->_buildFBAObject($formulation->{formulation},$model,"NO_WORKSPACE",$fbaid),
		mediaHypothesis => $self->_invert_boolean($formulation->{nomediahyp}),
		biomassHypothesis => $self->_invert_boolean($formulation->{nobiomasshyp}),
		gprHypothesis => $self->_invert_boolean($formulation->{nogprhyp}),
		reactionAdditionHypothesis => $self->_invert_boolean($formulation->{nopathwayhyp}),
		referenceMedia_uuid => $media,
		referenceMedia => $mediaobj,
		timePerSolution => $formulation->{timePerSolution},
		totalTimeLimit => $formulation->{totalTimeLimit},
	});
	$gapform->parent($self->_KBaseStore());
	$gapform->{_kbaseWSMeta}->{wsid} = $gapform->uuid();
	$gapform->{_kbaseWSMeta}->{ws} = "NO_WORKSPACE";
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
		clustermem => 1200,
		clustertime => 19800,
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
		workspaceURL => $self->_workspaceURL(),
		fbaURL => $self->_myURL()
	};
}

sub _submit_job {
	my ($self,$job) = @_;

	my $cs=Bio::KBase::ClusterService::new({ token => $job->{token}});
        
	my $clusterJob = $cs->Submit({
		mem => $job->{clustermem},
		"time" => $job->{clustertime},
		jobid => $job->{id},
		auth => $self->_authentication(),
		application => "fba",
		target => "jesup",
		jobs => $job->{clusterjobs},
		workspace_url => $job->{workspaceURL}
	});
	#$job->{csjob} = $clusterJob;
	$job->{clustertoken} = $clusterJob->{ID};
	return $job;
};

sub _cancel_job {
	my ($self,$job) = @_;
	return 0; # TBD: $job->{csjob}->Cancel();
};

sub _check_job {
	my ($self,$job) = @_;
	return 0; # TBD: $job->{csjob}->Done();
};

sub _get_new_id {
	my ($self,$prefix) = @_;
	my $id;
	eval {
		$id = $self->_idServer()->allocate_id_range( $prefix, 1 );
	};
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
		$mediaws = "NO_WORKSPACE";
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
		$mediaws = "NO_WORKSPACE";
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
	my $media_workspace = "NO_WORKSPACE";
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
				$var->variableType(),
				$var->modelcompound()->name()
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
				$var->variableType(),
				$var->modelreaction()->definition()
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
				$var->modelCompound()->id(),
				$var->modelCompound()->name()
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
		probabilisticAnnotation => undef
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
	my $solutions = $obj->fbaFormulation()->gapfillingSolutions();
    if (defined($solutions->[0])) {
		$data->{isComplete} = 1;
		for (my $i=0; $i < @{$solutions}; $i++) {
			my $solution = $solutions->[$i];
			my $solData = {
				id => $array->[1].".solution.".$i,
				objective => $solution->{solutionCost},
				biomassRemovals => [],
				mediaAdditions => [],
				reactionAdditions => []
			};
			for (my $j=0; $j < @{$solutions->biomassRemovals()}; $j++) {
				push(@{$solData->{biomassRemovals}},[
					$solutions->biomassRemovals()->[$j]->id(),
					$solutions->biomassRemovals()->[$j]->name()
				]);
			}
			for (my $j=0; $j < @{$solutions->mediaSupplements()}; $j++) {
				push(@{$solData->{mediaAdditions}},[
					$solutions->mediaSupplements()->[$j]->id(),
					$solutions->mediaSupplements()->[$j]->name()
				]);
			}
			for (my $j=0; $j < @{$solutions->gapfillingSolutionReactions()}; $j++) {
				push(@{$solData->{reactionAdditions}},[
					$solutions->gapfillingSolutionReactions()->[$j]->reaction()->id(),
					$solutions->gapfillingSolutionReactions()->[$j]->reaction()->direction(),
					"c",
					$solutions->gapfillingSolutionReactions()->[$j]->reaction()->equation(),
					$solutions->gapfillingSolutionReactions()->[$j]->reaction()->definition()
				]);
			}
			$data->{solutions}->[$i] = $solData;
		}
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
    my $solutions = $obj->fbaFormulation()->gapfillingSolutions();
    if (defined($solutions->[0])) {
		$data->{isComplete} = 1;
		for (my $i=0; $i < @{$solutions}; $i++) {
			my $solution = $solutions->[$i];
			my $solData = {
				id => $array->[1].".solution.".$i,
				objective => $solution->{solutionCost},
				biomassAdditions => [],
				mediaRemovals => [],
				reactionRemovals => []
			};
			for (my $j=0; $j < @{$solutions->biomassSupplements()}; $j++) {
				push(@{$solData->{biomassAdditions}},[
					$solutions->biomassSupplements()->[$j]->id(),
					$solutions->biomassSupplements()->[$j]->name()
				]);
			}
			for (my $j=0; $j < @{$solutions->mediaRemovals()}; $j++) {
				push(@{$solData->{mediaRemovals}},[
					$solutions->mediaRemovals()->[$j]->id(),
					$solutions->mediaRemovals()->[$j]->name()
				]);
			}
			for (my $j=0; $j < @{$solutions->gapgenSolutionReactions()}; $j++) {
				push(@{$solData->{reactionRemovals}},[
					$solutions->gapgenSolutionReactions()->[$j]->modelreaction()->reaction()->id(),
					$solutions->gapgenSolutionReactions()->[$j]->modelreaction()->reaction()->direction(),
					"c",
					$solutions->gapgenSolutionReactions()->[$j]->modelreaction()->reaction()->equation(),
					$solutions->gapgenSolutionReactions()->[$j]->modelreaction()->reaction()->definition()
				]);
			}
			$data->{solutions}->[$i] = $solData;
		}
	}
    return $data;
}

=head3 parseGPR

Definition:
	{}:Logic hash = ModelSEED::MS::Factories::SBMLFactory->parseGPR();
Description:
	Parses GPR string into a hash where each key is a node ID,
	and each node ID points to a logical expression of genes or other
	node IDs. 
	
	Logical expressions only have one form of logic, either "or" or "and".

	Every hash returned has a root node called "root", and this is
	where the gene protein reaction boolean rule starts.
Example:
	GPR string "(A and B) or (C and D)" is translated into:
	{
		root => "node1|node2",
		node1 => "A+B",
		node2 => "C+D"
	}
	
=cut

sub _parseGPR {
	my $self = shift;
	my $gpr = shift;
	$gpr =~ s/\s+and\s+/;/g;
	$gpr =~ s/\s+or\s+/:/g;
	$gpr =~ s/\s+\)/)/g;
	$gpr =~ s/\)\s+/)/g;
	$gpr =~ s/\s+\(/(/g;
	$gpr =~ s/\(\s+/(/g;
	my $index = 1;
	my $gprHash = {_baseGPR => $gpr};
	while ($gpr =~ m/\(([^\)^\(]+)\)/) {
		my $node = $1;
		my $text = "\\(".$node."\\)";
		if ($node !~ m/;/ && $node !~ m/:/) {
			$gpr =~ s/$text/$node/g;
		} else {
			my $nodeid = "node".$index;
			$index++;
			$gpr =~ s/$text/$nodeid/g;
			$gprHash->{$nodeid} = $node;
		}
	}
	$gprHash->{root} = $gpr;
	$index = 0;
	my $nodelist = ["root"];
	while (defined($nodelist->[$index])) {
		my $currentNode = $nodelist->[$index];
		my $data = $gprHash->{$currentNode};
		my $delim = "";
		if ($data =~ m/;/) {
			$delim = ";";
		} elsif ($data =~ m/:/) {
			$delim = ":";
		}
		if (length($delim) > 0) {
			my $split = [split(/$delim/,$data)];
			foreach my $item (@{$split}) {
				if (defined($gprHash->{$item})) {
					my $newdata = $gprHash->{$item};
					if ($newdata =~ m/$delim/) {
						$gprHash->{$currentNode} =~ s/$item/$newdata/g;
						delete $gprHash->{$item};
						$index--;
					} else {
						push(@{$nodelist},$item);
					}
				}
			}
		} elsif (defined($gprHash->{$data})) {
			push(@{$nodelist},$data);
		}
		$index++;
	}
	foreach my $item (keys(%{$gprHash})) {
		$gprHash->{$item} =~ s/;/+/g;
		$gprHash->{$item} =~ s/:/|/g;
	}
	return $gprHash;
}

=head3 _translateGPRHash

Definition:
	[[[]]]:Protein subunit gene array = ModelSEED::MS::Factories::SBMLFactory->translateGPRHash({}:GPR hash);
Description:
	Translates the GPR hash generated by "parseGPR" into a three level array ref.
	The three level array ref represents the three levels of GPR rules in the ModelSEED.
	The outermost array represents proteins (with 'or' logic).
	The next level array represents subunits (with 'and' logic).
	The innermost array represents gene homologs (with 'or' logic).
	In order to be parsed into this form, the input GPR hash must include logic
	of the forms: "or(and(or))" or "or(and)" or "and" or "or"
	
Example:
	GPR hash:
	{
		root => "node1|node2",
		node1 => "A+B",
		node2 => "C+D"
	}
	Is translated into the array:
	[
		[
			["A"],
			["B"]
		],
		[
			["C"],
			["D"]
		]
	]

=cut

sub _translateGPRHash {
	my $self = shift;
	my $gprHash = shift;
	my $root = $gprHash->{root};
	my $proteins = [];
	if ($root =~ m/\|/) {
		my $proteinItems = [split(/\|/,$root)];
		my $found = 0;
		foreach my $item (@{$proteinItems}) {
			if (defined($gprHash->{$item})) {
				$found = 1;
				last;
			}
		}
		if ($found == 0) {
			$proteins->[0]->[0] = $proteinItems
		} else {
			foreach my $item (@{$proteinItems}) {
				push(@{$proteins},$self->_parseSingleProtein($item,$gprHash));
			}
		}
	} elsif ($root =~ m/\+/) {
		$proteins->[0] = $self->_parseSingleProtein($root,$gprHash);
	} elsif (defined($gprHash->{$root})) {
		$gprHash->{root} = $gprHash->{$root};
		return $self->_translateGPRHash($gprHash);
	} else {
		$proteins->[0]->[0]->[0] = $root;
	}
	return $proteins;
}

=head3 _parseSingleProtein

Definition:
	[[]]:Subunit gene array = ModelSEED::MS::Factories::SBMLFactory->parseSingleProtein({}:GPR hash);
Description:
	Translates the GPR hash generated by "parseGPR" into a two level array ref.
	The two level array ref represents the two levels of GPR rules in the ModelSEED.
	The outermost array represents subunits (with 'and' logic).
	The innermost array represents gene homologs (with 'or' logic).
	In order to be parsed into this form, the input GPR hash must include logic
	of the forms: "and(or)" or "and" or "or"
	
Example:
	GPR hash:
	{
		root => "A+B",
	}
	Is translated into the array:
	[
		["A"],
		["B"]
	]

=cut

sub _parseSingleProtein {
	my $self = shift;
	my $node = shift;
	my $gprHash = shift;
	my $subunits = [];
	if ($node =~ m/\+/) {
		my $items = [split(/\+/,$node)];
		my $index = 0;
		foreach my $item (@{$items}) {
			if (defined($gprHash->{$item})) {
				my $subunitNode = $gprHash->{$item};
				if ($subunitNode =~ m/\|/) {
					my $suitems = [split(/\|/,$subunitNode)];
					my $found = 0;
					foreach my $suitem (@{$suitems}) {
						if (defined($gprHash->{$item})) {
							$found = 1;
						}
					}
					if ($found == 0) {
						$subunits->[$index] = $suitems;
						$index++;
					} else {
						print "Incompatible GPR:".$gprHash->{_baseGPR}."\n";
					}
				} elsif ($subunitNode =~ m/\+/) {
					print "Incompatible GPR:".$gprHash->{_baseGPR}."\n";
				} else {
					$subunits->[$index]->[0] = $subunitNode;
					$index++;
				}
			} else {
				$subunits->[$index]->[0] = $item;
				$index++;
			}
		}
	} elsif (defined($gprHash->{$node})) {
		return $self->_parseSingleProtein($gprHash->{$node},$gprHash)
	} else {
		$subunits->[0]->[0] = $node;
	}
	return $subunits;
}

=head3 _prepPhenotypeSimultationFBA

Definition:
	 = $self->_prepPhenotypeSimultationFBA(ModelSEED::MS::Model,PhenotypeSet);
Description:
	Translate an input Model and PhenotypeSet into a loaded FBA problem object.
	
=cut

sub _prepPhenotypeSimultationFBA {
	my($self,$model,$pheno,$fba) = @_;
	my $ftrs = $model->features();
	my $ftrhash = {};
	for (my $i=0; $i < @{$ftrs}; $i++) {
		$ftrhash->{$ftrs->[$i]} = 1;
	}
	#Translating phenotypes to fbaformulation
	my $bio = $model->biochemistry();
	my $mediaChecked = {};
	my $existingPhenos = {};
	my $phenokeys = [];
	for (my $i=0; $i < @{$pheno->{phenotypes}};$i++) {
		my $media = $pheno->{phenotypes}->[$i]->[2]."/".$pheno->{phenotypes}->[$i]->[1]; 
		if (!defined($mediaChecked->{$media})) {
			$mediaChecked->{$media} = 1;
			if ($pheno->{phenotypes}->[$i]->[2] eq "NO_WORKSPACE") {
				my $mediaobj = $bio->queryObject("media",{id => $pheno->{phenotypes}->[$i]->[1]});
				$media = $mediaobj->uuid();
			} else {
				my $mediaobj = $self->_get_msobject("Media",$pheno->{phenotypes}->[$i]->[2],$pheno->{phenotypes}->[$i]->[1]);
				$bio->add("media",$mediaobj);
			}
		}
		my $genekos = [];
		foreach my $gene (@{$pheno->{phenotypes}->[$i]->[0]}) {
			my $geneObj = $model->annotation()->queryObject("features",{id => $gene});
			if (defined($ftrhash->{$geneObj->uuid()})) {
				push(@{$genekos},$geneObj->uuid());
			}
		}
		my $addnlcpds = [];
		foreach my $addnlcpd (@{$pheno->{phenotypes}->[$i]->[3]}) {
			my $cpdObj = $model->biochemistry()->searchForCompound($addnlcpd);
			push(@{$addnlcpds},$cpdObj->uuid());
		}
		my $phenokey = $media."|".join(";",sort(@{$genekos}))."|".join(";",sort(@{$addnlcpds}));
		if (!defined($existingPhenos->{$phenokey})) {
			push(@{$phenokeys},$phenokey);
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
			$existingPhenos->{$phenokey} = [$i];
		} else {
			push(@{$existingPhenos->{$phenokey}},$i);
		}
		if ($i/1000 eq floor($i/1000)) {
			#print $i."\n";
		}
	}
	#print "Unique phenos:".keys(%{$existingPhenos})."\n";
	return ($fba,$existingPhenos,$phenokeys);
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
	$ENV{KB_NO_FILE_ENVIRONMENT} = 1;
    my %params;
    if ((my $e = $ENV{KB_DEPLOYMENT_CONFIG}) && -e $ENV{KB_DEPLOYMENT_CONFIG})
    {
	my $service = $ENV{KB_SERVICE_NAME};
	my $c = Config::Simple->new();
	$c->read($e);
	my @params = qw(workspace-url);
	for my $p (@params)
	{
	  	my $v = $c->param("$service.$p");

	    if ($v)
	    {
		$params{$p} = $v;
	    }
	}
    }

    if (defined $params{"workspace-url"}) {
		$self->{"_workspace-url"} = $params{"workspace-url"};
    } else {
		print STDERR "workspace-url configuration not found, using 'localhost'\n";
		$self->{"_workspace-url"} = "http://localhost:7058";
    }
	if (defined($options->{workspace})) {
    	$self->{_workspaceServices}->{$self->{"_workspace-url"}} = $options->{workspace};
    }
    if (defined($options->{verbose})) {
    	set_verbose(1);
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
	modelSubsystems has a value which is a reference to a list where each element is a Subsystem
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
Subsystem is a reference to a hash where the following keys are defined:
	name has a value which is a string
	feature has a value which is a reference to a list where each element is a feature_id

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
	modelSubsystems has a value which is a reference to a list where each element is a Subsystem
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
Subsystem is a reference to a hash where the following keys are defined:
	name has a value which is a string
	feature has a value which is a reference to a list where each element is a feature_id


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
		id_type => "ModelSEED",
		biochemistry => "default",
		mapping => "mapping"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry})
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
    		"map" => $input->{mapping},
    		map_workspace => "kbase",
    		biochemistry => $input->{biochemistry},
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
    			name => $bio->name(),
    			definition => $bio->definition()
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
    			equation => $rxn->equation(),
    			definition => $rxn->definition()
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
		id_type => "ModelSEED",
		biochemistry => "default",
		mapping => "default"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry})
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
		id_type => "ModelSEED",
		biochemistry => "default",
		mapping => "default"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry})
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
		id_type => "ModelSEED",
		biochemistry => "default",
		mapping => "default"
	});
	#Creating cache with the biochemistry, to ensure only one is created for all models
	my $cache = {
		Biochemistry => {
			kbase => {
				"default" => $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry})
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
    	id_type => "ModelSEED",
    	biochemistry => "default",
		mapping => "default"
    });
	my $biochem = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
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
                definition => $obj->definition()
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
    	id_type => "ModelSEED",
    	biochemistry => "default",
		mapping => "default"
    });
	my $biochem = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
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
    $input = $self->_validateargs($input,["medias","workspaces"],{
    	biochemistry => "default",
		mapping => "default"
    });
	my $biochem = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
	$out_media = [];
	for (my $i=0; $i < @{$input->{medias}}; $i++) {
		my $media = $input->{medias}->[$i];
		my $workspace = $input->{workspaces}->[$i];
		my $obj;
		if (!defined($workspace) || $workspace eq "NO_WORKSPACE") {
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
    my $biochem = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
    
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
	$aliases = $aliasset->aliasesByuuid();
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




=head2 get_ETCDiagram

  $output = $obj->get_ETCDiagram($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_ETCDiagram_params
$output is an ETCDiagramSpecs
get_ETCDiagram_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	media has a value which is a media_id
	mediaws has a value which is a workspace_id
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
media_id is a string
ETCDiagramSpecs is a reference to a hash where the following keys are defined:
	nodes has a value which is a reference to a list where each element is an ETCNodes
	media has a value which is a string
	growth has a value which is a string
	organism has a value which is a string
ETCNodes is a reference to a hash where the following keys are defined:
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

$input is a get_ETCDiagram_params
$output is an ETCDiagramSpecs
get_ETCDiagram_params is a reference to a hash where the following keys are defined:
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	media has a value which is a media_id
	mediaws has a value which is a workspace_id
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
media_id is a string
ETCDiagramSpecs is a reference to a hash where the following keys are defined:
	nodes has a value which is a reference to a list where each element is an ETCNodes
	media has a value which is a string
	growth has a value which is a string
	organism has a value which is a string
ETCNodes is a reference to a hash where the following keys are defined:
	resp has a value which is a string
	y has a value which is an int
	x has a value which is an int
	width has a value which is an int
	height has a value which is an int
	shape has a value which is a string
	label has a value which is a string


=end text



=item Description

This function retrieves an ETC diagram for the input model operating in the input media condition
    The model must grow on the specified media in order to return a working ETC diagram

=back

=cut

sub get_ETCDiagram
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_ETCDiagram:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_ETCDiagram');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN get_ETCDiagram
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace","media"],{
		mediaws => $input->{workspace}
	});
    #
    my $model = $self->_get_msobject("Model",$input->{workspace},$input->{model});
    if (!defined($model)) {
    	my $msg = "Failed to retrieve model ".$input->{workspace}."/".$input->{model};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'get_ETCDiagram');
    }
    my $formulation = $self->_setDefaultFBAFormulation({
    	media => $input->{media},
    	mediaws => $input->{mediaws}
    });
	my $fba = $self->_buildFBAObject($input->{formulation},$model,"NO_WORKSPACE","none");
	my $fbaResult = $fba->runFBA();
    my $etcDiagram;
    $output = $etcDiagram;
	$self->_clearContext();
    #END get_ETCDiagram
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_ETCDiagram:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_ETCDiagram');
    }
    return($output);
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
	0: a feature_id
	1: a string
	2: a float
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	0: a feature_id
	1: a string
	2: a float
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_probanno:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_probanno');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($probannoMeta);
    #BEGIN import_probanno
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["workspace","annotationProbabilities","genome"],{
		probanno => undef,
		genome_workspace => $input->{workspace},
		ignore_errors => 0
	});
    if (!defined($input->{probanno})) {
    	$input->{probanno} = $self->_get_new_id($input->{genome}.".probanno.");
    }
    #Retrieving specified genome
    my $genomeObj = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    if (!defined($genomeObj)) {
    	my $msg = "Failed to retrieve genome ".$input->{genome_workspace}."/".$input->{genome};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
    }
    #Retrieving the annotation object
    my $annotation = $self->_get_msobject("Annotation","NO_WORKSPACE",$genomeObj->{annotation_uuid});
    if (!defined($annotation)) {
    	my $msg = "Failed to retrieve annotation ".$input->{genome_workspace}."/".$input->{genome};
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
    }
    #Retrieving the mapping object
    my $map = $annotation->mapping();
    #Building a hash for all gene aliases mapped to gene IDs
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
    #Instantiating probabilistic annotation object
    my $object = {
    	id => $input->{probanno},
    	genome => $input->{genome},
    	genome_uuid => $genomeObj->{_kbaseWSMeta}->{wsref},
    	featureAlternativeFunctions => [],
    };
    #Validating roles and genes
    my $missingGenes = [];
    my $missingRoles = [];
    my $featureHash;
    my $allfound = 1;
    my $found = 0;
    my $missing = 0;
    for (my $i=0; $i < @{$input->{annotationProbabilities}}; $i++) {
    	my $annoprob = $input->{annotationProbabilities}->[$i];
    	if (!defined($genehash->{$annoprob->[0]})) {
    		push(@{$missingGenes},$annoprob->[0]);
    		$allfound = 0;
    	} else {
    		$annoprob->[0] = $genehash->{$annoprob->[0]};
    		
    		my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($annoprob->[1]);
			my $roleObj = $map->queryObject("roles",{searchname => $searchName});
    		if (defined($roleObj)) {
    			$found++;
    			if (defined($featureHash->{$annoprob->[0]})) {
		    		push(@{$featureHash->{$annoprob->[0]}->{alternative_functions}},[
		    			$annoprob->[1],
		    			$annoprob->[2]
		    		]);
		    	} else {
		    		$featureHash->{$annoprob->[0]} = {
		    			id => $annoprob->[0],
		    			alternative_functions => [
		    				[
		    					$annoprob->[1],
		    					$annoprob->[2]
		    				]
		    			]
		    		};
		    	}
    		} else {
    			$missing++;
    			push(@{$missingRoles},$annoprob->[1]);
    			$allfound = 0;
    		}
    	} 
    }
    #Adding fuction annotation array to structure
    foreach my $key (keys(%{$featureHash})) {
    	push(@{$object->{featureAlternativeFunctions}},$featureHash->{$key});
    }
    #Printing error if any entities could not be validated
    my $msg = "";
    if (@{$missingGenes} > 0) {
    	$msg = "Could not find genes:".join(";",@{$missingGenes})."\n";
    }
    if (@{$missingRoles} > 0) {
    	$msg = "Could not find role:".join(";",@{$missingRoles})."\n";
    }
    my $meta = {};
	if (length($msg) > 0 && $input->{ignore_errors} == 0) {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
	} elsif (length($msg) > 0) {
		$object->{importErrors} = $msg;
	}
    #Saving object to database
    $probannoMeta = $self->_workspaceServices()->save_object({
		id => $input->{probanno},
		type => "ProbAnno",
		data => $object,
		workspace => $input->{workspace},
		command => "import_probanno",
		auth => $self->_authentication()
	});
	$self->_clearContext();
    #END import_probanno
    my @_bad_returns;
    (ref($probannoMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"probannoMeta\" (value was \"$probannoMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_probanno:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_probanno');
    }
    return($probannoMeta);
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
	genomeobj has a value which is a GenomeObject
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
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
	1: an int
	2: a string
	3: an int
feature_type is a string
alt_func is a reference to a list containing 2 items:
	0: a string
	1: a float
gene_hit is a reference to a list containing 2 items:
	0: a feature_id
	1: a float
annotation is a reference to a list containing 3 items:
	0: a string
	1: a string
	2: an int
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	genomeobj has a value which is a GenomeObject
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
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
	1: an int
	2: a string
	3: an int
feature_type is a string
alt_func is a reference to a list containing 2 items:
	0: a string
	1: a float
gene_hit is a reference to a list containing 2 items:
	0: a feature_id
	1: a float
annotation is a reference to a list containing 3 items:
	0: a string
	1: a string
	2: an int
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    	mapping_workspace => "kbase",
    	mapping => "default",
    	overwrite => 0
    });
    #Processing genome object
    my $mapping = $self->_get_msobject("Mapping",$input->{mapping_workspace},$input->{mapping});
    ($input->{genomeobj},my $anno,$mapping,my $contigObj) = $self->_processGenomeObject($input->{genomeobj},$mapping,"genome_object_to_workspace");
    $genomeMeta = $self->_save_msobject($input->{genomeobj},"Genome",$input->{workspace},$input->{genomeobj}->{id},"genome_object_to_workspace",$input->{overwrite});
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
	sourceLogin has a value which is a string
	sourcePassword has a value which is a string
	source has a value which is a string
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    	overwrite => 0,
    	mapping_workspace => "kbase",
    	mapping => "default",
    	sourceLogin => undef,
    	sourcePassword => undef,
    	source => "kbase",
    });
    my $mapping = $self->_get_msobject("Mapping",$input->{mapping_workspace},$input->{mapping});
    my $genomeObj;
    if ($input->{source} eq "kbase") {
    	$genomeObj = $self->_get_genomeObj_from_CDM($input->{genome});
    } elsif ($input->{source} eq "seed") {
    	$genomeObj = $self->_get_genomeObj_from_SEED($input->{genome});
    } elsif ($input->{source} eq "rast") {
    	$genomeObj = $self->_get_genomeObj_from_RAST($input->{genome},$input->{sourceLogin},$input->{sourcePassword});
    }
    ($genomeObj,my $anno,$mapping,my $contigObj) = $self->_processGenomeObject($genomeObj,$mapping,"genome_to_workspace");
    $genomeMeta = $self->_save_msobject($genomeObj,"Genome",$input->{workspace},$genomeObj->{id},"genome_to_workspace",$input->{overwrite});
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to add_feature_translation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_feature_translation');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($genomeMeta);
    #BEGIN add_feature_translation
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","workspace","translations","id_type"],{
    	overwrite => 0
    });
    my $genome = $self->_get_msobject("Genome",$input->{workspace},$input->{genome});
    my $aliases;
    for (my $i=0; $i < @{$input->{translations}}; $i++) {
    	my $trans = $input->{translations}->[$i];
    	$aliases->{$trans->[1]}->{$trans->[0]} = 1;
    }
    for (my $i=0; $i < @{$genome->{features}}; $i++) {
    	my $ftr = $genome->{features}->[$i];
    	my $existingAliases = {};
    	foreach my $alias (@{$ftr->{aliases}}) {
    		$existingAliases->{$alias} = 1;
    	}
    	if (defined($aliases->{$ftr->{id}})) {
    		foreach my $alias (keys(%{$aliases->{$ftr->{id}}})) {
    			if (!defined($existingAliases->{$alias})) {
    				push(@{$ftr->{aliases}},$alias);
    			}
    		}
    	}
    }
    $genomeMeta = $self->_save_msobject($genome,"Genome",$input->{workspace},$input->{genome},"add_feature_translation",$input->{overwrite});
    $self->_clearContext();
    #END add_feature_translation
    my @_bad_returns;
    (ref($genomeMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"genomeMeta\" (value was \"$genomeMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to add_feature_translation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_feature_translation');
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
	probanno has a value which is a probanno_id
	probanno_workspace has a value which is a workspace_id
	probannoThreshold has a value which is a float
	probannoOnly has a value which is a bool
	model has a value which is a fbamodel_id
	coremodel has a value which is a bool
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
probanno_id is a string
bool is an int
fbamodel_id is a string
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	probannoOnly has a value which is a bool
	model has a value which is a fbamodel_id
	coremodel has a value which is a bool
	workspace has a value which is a workspace_id
	auth has a value which is a string
	overwrite has a value which is a bool
genome_id is a string
workspace_id is a string
probanno_id is a string
bool is an int
fbamodel_id is a string
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    $input = $self->_validateargs($input,["genome","workspace"],{
    	probannoThreshold => 0.5,
    	probannoOnly => 0,
    	probanno => undef,
    	probanno_workspace => $input->{workspace},
    	genome_workspace => $input->{workspace},
    	model => undef,
    	overwrite => 0
    });
    #Determining model ID
    if (!defined($input->{model})) {
    	$input->{model} = $self->_get_new_id($input->{genome}.".fbamdl.");
    }
    #Retreiving genome object from workspace
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    #Retrieving annotation and mapping
    my $annotation = $self->_get_msobject("Annotation","NO_WORKSPACE",$genome->{annotation_uuid});
    #Retreiving probabilistic annotation
    if (defined($input->{probanno})) {
    	my $probanno = $self->_get_msobject("ProbAnno",$input->{probanno_workspace},$input->{probanno});
    	($annotation,my $mapping) = $self->_modify_annotation_from_probanno({
    		probanno => $probanno,
    		annotation => $annotation,
    		threshold => $input->{probannoThreshold},
    		probannoonly => $input->{probannoOnly}
    	});
    	my $meta = $self->_save_msobject($mapping,"Mapping","NO_WORKSPACE",$input->{probanno}.".anno.map","genome_to_fbamodel",1);
    	$annotation->mapping_uuid($meta->[8]);
    	#TODO: annotation should probably link to the probanno
    	$meta = $self->_save_msobject($annotation,"Annotation","NO_WORKSPACE",$input->{probanno}.".anno","genome_to_fbamodel",1);
    }
    #Building the FBA model
    my $mdl = $annotation->createStandardFBAModel( { prefix => "Kbase", } );
	$mdl->defaultNameSpace("KBase");
	#Model uuid and model id will be set to WS values during save
	$modelMeta = $self->_save_msobject($mdl,"Model",$input->{workspace},$input->{model},"genome_to_fbamodel",$input->{overwrite});
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
	0: a string
	1: a string
	2: a string
	3: a string

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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	0: a string
	1: a string
	2: a string
	3: a string

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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_fbamodel');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN import_fbamodel
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","workspace","reactions","biomass"],{
    	genome_workspace => $input->{workspace},
    	model => undef,
    	overwrite => 0,
    	ignore_errors => 0
    });
    #Determining model ID
    if (!defined($input->{model})) {
    	$input->{model} = $self->_get_new_id($input->{genome}.".fbamdl.");
    }
    #Retreiving genome object from workspace
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    my $geneAliases = {};
    foreach my $ftr (@{$genome->{features}}) {
    	$geneAliases->{$ftr->{id}} = $ftr->{id};
    	foreach my $alias (@{$ftr->{aliases}}) {
    		$geneAliases->{$alias} = $ftr->{id};
    	}
    }
    #Retrieving annotation and mapping
    my $annotation = $self->_get_msobject("Annotation","NO_WORKSPACE",$genome->{annotation_uuid});
    #Retreiving biochemistry
    my $bio = $annotation->mapping()->biochemistry();
    #Creating empty model
    my $model = ModelSEED::MS::Model->new({
		id => $input->{model},
		name => $input->{model},
		version => 1,
		type => "Imported",
		status => "Model imported",
		growth => 0,
		current => 1,
		mapping_uuid => $annotation->mapping()->uuid(),
		mapping => $annotation->mapping(),
		biochemistry_uuid => $bio->uuid(),
		biochemistry => $bio,
		annotation_uuid => $annotation->uuid(),
		annotation => $annotation
	});
    #Loading reactions to model
	my $reactionsNotFound = [];
	my $missingGenes = {};
	for (my  $i=0; $i < @{$input->{reactions}}; $i++) {
		my $rxnrow = $input->{reactions}->[$i];
		my $rxn = $bio->searchForReaction($rxnrow->[0]);
		if (!defined($rxn)) {
			push(@{$reactionsNotFound},$rxnrow->[0]);
		} else {
			my $direction = "=";
			if ($rxnrow->[1] eq "=>") {
				$direction = ">";
			} elsif ($rxnrow->[1] eq "<=") {
				$direction = "<";
			}
			my $mdlrxn = $model->addReactionToModel({
				reaction => $rxn,
				direction => $direction
			});
			my $gpr = $self->_translateGPRHash($self->_parseGPR($rxnrow->[3]));
			for (my $m=0; $m < @{$gpr}; $m++) {
				my $protObj = $mdlrxn->add("modelReactionProteins",{
					complex_uuid => "00000000-0000-0000-0000-000000000000",
					note => "Imported GPR"
				});
				for (my $j=0; $j < @{$gpr->[$m]}; $j++) {
					my $subObj = $protObj->add("modelReactionProteinSubunits",{
						role_uuid => "00000000-0000-0000-0000-000000000000",
						note => "Imported GPR"
					});
					for (my $k=0; $k < @{$gpr->[$m]->[$j]}; $k++) {
						my $ftrID = $gpr->[$m]->[$j]->[$k];
						if (defined($geneAliases->{$ftrID})) {
							$ftrID = $geneAliases->{$ftrID};
							my $ftrObj = $annotation->queryObject("features",{id => $ftrID});
							if (!defined($ftrObj)) {
								$missingGenes->{$ftrID} = 1;
							} else {
								my $ftr = $subObj->add("modelReactionProteinSubunitGenes",{
									feature_uuid => $ftrObj->uuid()
								});
							}
						} else {
							$missingGenes->{$ftrID} = 1;
						}
					}
				}
			}
		}
	}
	#Adding biomass reaction
	my $bioobj = $model->add("biomasses",{id => "bio1",name => "bio1"});
	my $missingCpd = $bioobj->loadFromEquation({equation => $input->{biomass},addMissingCompounds=>0});
	my $msg = "";
	if (@{$reactionsNotFound} > 0) {
		$msg .= "Missing reactions:".join(";",@{$reactionsNotFound})."\n";
	}
	if (@{$missingCpd} > 0) {
		$msg .= "Missing biomass compounds:".join(";",@{$missingCpd})."\n";
	}
	if (keys(%{$missingGenes}) > 0) {
		$msg .= "Missing genes:".join(";",keys(%{$missingGenes}))."\n";
	}
	if (length($msg) > 0 && $input->{ignore_errors} == 0) {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_fbamodel');
	}
	#Saving imported model
	$modelMeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{model},"import_fbamodel",$input->{overwrite});
    $self->_clearContext();
    #END import_fbamodel
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_fbamodel');
    }
    return($modelMeta);
}




=head2 genome_to_probfbamodel

  $modelMeta = $obj->genome_to_probfbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a genome_to_probfbamodel_params
$modelMeta is an object_metadata
genome_to_probfbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	probanno has a value which is a probanno_id
	probanno_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
genome_id is a string
workspace_id is a string
probanno_id is a string
fbamodel_id is a string
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$input is a genome_to_probfbamodel_params
$modelMeta is an object_metadata
genome_to_probfbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a genome_id
	genome_workspace has a value which is a workspace_id
	probanno has a value which is a probanno_id
	probanno_workspace has a value which is a workspace_id
	model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	auth has a value which is a string
genome_id is a string
workspace_id is a string
probanno_id is a string
fbamodel_id is a string
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text



=item Description

Build a probabilistic genome-scale metabolic model based on annotations in an input genome and probabilistic annotation

=back

=cut

sub genome_to_probfbamodel
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to genome_to_probfbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_probfbamodel');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN genome_to_probfbamodel
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","workspace","probanno"],{
    	probanno_workspace => $input->{workspace},
    	genome_workspace => $input->{workspace},
    	model => undef,
    	overwrite => 0
    });
    #Determining model ID
    if (!defined($input->{model})) {
    	$input->{model} = $self->_get_new_id($input->{genome}.".fbamdl.");
    }
    #Retreiving genome object from workspace
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    #Retrieving annotation and mapping
    my $annotation = $self->_get_msobject("Annotation","NO_WORKSPACE",$genome->{annotation_uuid});
    #Retreiving probabilistic annotation
    my $probanno = $self->_get_msobject("ProbAnno",$input->{probanno_workspace},$input->{probanno});
    #Building the FBA model
    my $mdl = ModelSEED::MS::Model->new({
		id => $genome->{id},
		version => 0,
		type => "ProbModel",
		name => $genome->{name},
		growth => 0,
		status => "Reconstruction complete",
		current => 1,
		mapping_uuid => $annotation->mapping_uuid(),
		mapping => $annotation->mapping(),
		biochemistry_uuid => $annotation->mapping()->biochemistry_uuid(),
		biochemistry => $annotation->mapping()->biochemistry(),
		annotation_uuid => $annotation->uuid(),
		annotation => $annotation
	});
	#Adding all mass balanced unblacklisted reactions in biochemistry to model
	my $gfform = $self->_setDefaultGapfillFormulation({});
	my $blhash;
	foreach my $rxn (@{$gfform->{blacklistedrxns}}) {
		$blhash->{$rxn} = 1;
	}
	my $grhash;
	foreach my $rxn (@{$gfform->{gauranteedrxns}}) {
		$grhash->{$rxn} = 1;
	}
	my $rxns = $annotation->mapping()->biochemistry()->reactions();
	foreach my $rxn (@{$rxns}) {
		my $id = $rxn->id();
		my $add = 0;
		if (defined($grhash->{$id})) {
			$add = 1;
		} elsif (!defined($blhash->{$id})) {
			if ($rxn->status() eq "OK") {
				my $mdlrxn = $self->addReactionToModel({
					reaction => $rxns,
					direction => $rxns->thermoReversibility()
				});
				$mdlrxn->probability(0);
			}
		}
	}
	#Adding biomass reaction
	my $bio = $self->createStandardFBABiomass({
		annotation => $annotation,
		mapping => $annotation->mapping(),
	});
	$mdl->defaultNameSpace("KBase");
	#Model uuid and model id will be set to WS values during save
	$modelMeta = $self->_save_msobject($mdl,"Model",$input->{workspace},$input->{model},"genome_to_probfbamodel",$input->{overwrite});
    $self->_clearContext();
    #END genome_to_probfbamodel
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to genome_to_probfbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'genome_to_probfbamodel');
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
workspace_ref is a string


=end text



=item Description

This function prints the object pointed to by the input reference in the specified format

=back

=cut

sub export_object
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_object');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN export_object
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["reference","type"],{
    	format => "html"
    });
    my $obj = $self->_KBaseStore()->get_object($input->{type},$input->{reference});
	my $msobject = {
		Mapping => 1,
		Model => 1,
		Media => 1,
		Annotation => 1,
		Biochemistry => 1,
		FBA => 1,
		PromConstraints => 1
	};
	if ($input->{type} eq "Genome") {
		$obj = $self->_KBaseStore()->get_object("Annotation",$obj->{annotation_uuid});
		$output = $obj->export({format => $input->{format}});
	} elsif (defined($msobject->{$input->{type}})) {
		$output = $obj->export({format => $input->{format}});
	} elsif (ref($obj) eq "HASH") {
		my $JSON = JSON::XS->new->utf8(1);
    	$output = $JSON->encode($obj);
	} else {
		$output = $obj;
	}
    $self->_clearContext();
    #END export_object
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to export_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_object');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to export_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_genome');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN export_genome
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["genome","workspace","format"],{});
    my $genome = $self->_get_msobject("Genome",$input->{workspace},$input->{genome});
    my $annotation = $self->_get_msobject("Annotation","NO_WORKSPACE",$genome->{annotation_uuid});
    $output = $annotation->export({format => $input->{format}});
    $self->_clearContext();
    #END export_genome
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to export_genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'export_genome');
    }
    return($output);
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
	reaction has a value which is a reaction_id
	direction has a value which is a string
	compartment has a value which is a compartment_id
	compartmentIndex has a value which is an int
	gpr has a value which is a reference to a list where each element is a reference to a list where each element is a reference to a list where each element is a feature_id
	removeReaction has a value which is a bool
	addReaction has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
reaction_id is a string
compartment_id is a string
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	reaction has a value which is a reaction_id
	direction has a value which is a string
	compartment has a value which is a compartment_id
	compartmentIndex has a value which is an int
	gpr has a value which is a reference to a list where each element is a reference to a list where each element is a reference to a list where each element is a feature_id
	removeReaction has a value which is a bool
	addReaction has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
reaction_id is a string
compartment_id is a string
feature_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_model_reaction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_model_reaction');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN adjust_model_reaction
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["reaction","model","workspace"],{
    	direction => undef,
    	compartment => "c",
    	compartmentIndex => 0,
    	gpr => undef,
    	removeReaction => 0,
    	addReaction => 0,
    	overwrite => 0
    });
    my $model = $self->_get_msobject("Model",$input->{workspace},$input->{model});
    $model->manualReactionAdjustment({
    	reaction => $input->{reaction},
    	direction => $input->{direction},
    	compartment => $input->{compartment},
    	compartmentIndex => $input->{compartmentIndex},
    	gpr => $input->{gpr},
    	removeReaction => $input->{removeReaction},
    	addReaction => $input->{addReaction}
    });
	$modelMeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{model},"adjust_model_reaction",$input->{overwrite});
    $self->_clearContext();
    #END adjust_model_reaction
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_model_reaction:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_model_reaction');
    }
    return($modelMeta);
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
	coefficient has a value which is a float
	compound has a value which is a compound_id
	compartment has a value which is a compartment_id
	compartmentIndex has a value which is an int
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
biomass_id is a string
compound_id is a string
compartment_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	coefficient has a value which is a float
	compound has a value which is a compound_id
	compartment has a value which is a compartment_id
	compartmentIndex has a value which is an int
	overwrite has a value which is a bool
	auth has a value which is a string
fbamodel_id is a string
workspace_id is a string
biomass_id is a string
compound_id is a string
compartment_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_biomass_reaction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_biomass_reaction');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN adjust_biomass_reaction
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["compound","model","workspace"],{
    	biomass => "bio1",
    	coefficient => 1,
    	compartment => "c",
    	"index" => 0,
    	overwrite => 0
    });
	my $model = $self->_get_msobject("Model",$input->{workspace},$input->{model});
	$model->adjustBiomassReaction({
		compound => $input->{compound},
		coefficient => $input->{coefficient},
    	biomass => $input->{biomass},
    	compartment => $input->{compartment},
    	"index" => $input->{"index"}
    });
	$modelMeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{model},"adjust_biomass_reaction",$input->{overwrite});
    $self->_clearContext();
    #END adjust_biomass_reaction
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_biomass_reaction:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_biomass_reaction');
    }
    return($modelMeta);
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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    	overwrite => 0,
    	biochemistry => "default"
    });
    #Creating the media object from the specifications
    my $bio = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
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
	$input = $self->_validateargs($input,["media","workspace","format"],{
		biochemistry => "default",
		mapping => "default"
	});
    my $med;
    my $bio = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
    if ($input->{workspace} eq "NO_WORKSPACE") {
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    $input = $self->_validateargs($input,["model","workspace"],{
		formulation => undef,
		fva => 0,
		simulateko => 0,
		minimizeflux => 0,
		findminmedia => 0,
		notes => "",
		model_workspace => $input->{workspace},
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
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{workspace},$input->{fba});
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
    $fba->model_uuid($model->uuid());
	$fbaMeta = $self->_save_msobject($fba,"FBA",$input->{workspace},$input->{fba},"runfba",$input->{overwrite});
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	$input = $self->_validateargs($input,["workspace","genome","phenotypes"],{
		phenotypeSet => undef,
		genome_workspace => $input->{workspace},
		ignore_errors => 0,
		biochemistry => "default"
	});
    if (!defined($input->{phenotypeSet})) {
    	$input->{phenotypeSet} = $self->_get_new_id($input->{genome}.".phenos.");
    }
    
    #Retrieving biochemistry
    my $bio = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
    #Retrieving specified genome
    my $genomeObj;
    if ($input->{genome_workspace} eq "NO_WORKSPACE") {
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
    my $mediaChecked = {};
    my $cpdChecked = {};
    my $geneChecked = {};
    for (my $i=0; $i < @{$input->{phenotypes}}; $i++) {
    	my $phenotype = $input->{phenotypes}->[$i];
    	#Validating gene IDs
    	my $allfound = 1;
    	for (my $j=0;$j < @{$phenotype->[0]};$j++) {
    		if (!defined($geneChecked->{$phenotype->[0]->[$j]})) {
	    		$geneChecked->{$phenotype->[0]->[$j]} = 1;
	    		if (!defined($genehash->{$phenotype->[0]->[$j]})) {
	    			push(@{$missingGenes},$phenotype->[0]->[$j]);
	    			$allfound = 0;
	    		} else {
	    			$phenotype->[0]->[$j] = $genehash->{$phenotype->[0]->[$j]};
	    		}
    		}
    	}
    	if ($allfound == 0) {
    		next;
    	}
    	#Validating media
    	if (!defined($mediaChecked->{$phenotype->[2]}->{$phenotype->[1]})) {
	    	$mediaChecked->{$phenotype->[2]}->{$phenotype->[1]} = 1;
	    	if ($phenotype->[2] eq "NO_WORKSPACE") {
	    		my $media = $bio->queryObject("media",{id => $phenotype->[1]});
	    		if (!defined($media)) {
	    			push(@{$missingMedia},$phenotype->[1]);
	    			$allfound = 0;
	    		}
	    	} else {
	    		try {
	    			my $media = $self->_get_msobject("Media",$phenotype->[2],$phenotype->[1]);
		    	} catch {
		    		push(@{$missingMedia},$phenotype->[1]);
		    		$allfound = 0;
		    	};
	    	}
    	}
    	if ($allfound == 0) {
    		next;
    	}
    	#Validating compounds
    	$allfound = 1;
    	for (my $j=0;$j < @{$phenotype->[3]};$j++) {
    		if (!defined($cpdChecked->{$phenotype->[3]->[$j]})) {
	    		$cpdChecked->{$phenotype->[3]->[$j]} = 1;
	    		my $cpd = $bio->searchForCompound($phenotype->[3]->[$j]);
	    		if (!defined($cpd)) {
	    			push(@{$missingCompounds},$phenotype->[3]->[$j]);
	    			$allfound = 0;
	    		} else {
	    			$phenotype->[3]->[$j] = $cpd->id();
	    		}
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
    	$msg .= "Could not find compounds:".join(";",@{$missingCompounds})."\n";
    }
    if (@{$missingGenes} > 0) {
    	$msg .= "Could not find genes:".join(";",@{$missingGenes})."\n";
    }
    if (@{$missingMedia} > 0) {
    	$msg .= "Could not find media:".join(";",@{$missingMedia})."\n";
    }
    my $meta = {};
	if (length($msg) > 0 && $input->{ignore_errors} == 0) {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'import_phenotypes');
	} elsif (length($msg) > 0) {
		$object->{importErrors} = $msg;
	}
    #Saving object to database
    my $objmeta = $self->_workspaceServices()->save_object({
		id => $input->{phenotypeSet},
		type => "PhenotypeSet",
		data => $object,
		workspace => $input->{workspace},
		command => "import_phenotypes",
		auth => $self->_authentication()
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	$input = $self->_validateargs($input,["phenotypeSet","workspace","model"],{
		phenotypeSet_workspace => $input->{workspace},
		model_workspace => $input->{workspace},
		formulation => undef,
		notes => "",
		phenotypeSimultationSet => $input->{phenotypeSet}.".simulation",
		overwrite => 0
	});
	#Retrieving phenotypes
	my $pheno = $self->_get_msobject("PhenotypeSet",$input->{phenotypeSet_workspace},$input->{phenotypeSet});
	#Retrieving model
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	#Creating FBAFormulation Object
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $fba = $self->_buildFBAObject($input->{formulation},$model,"NO_WORKSPACE",Data::UUID->new()->create_str());
	#Constructing FBA simulation object from 
	($fba,my $existingPhenos,my $phenokeys) = $self->_prepPhenotypeSimultationFBA($model,$pheno,$fba);
	#Running FBA
	my $fbaResult = $fba->runFBA();
	if (!defined($fbaResult) || @{$fbaResult->fbaPhenotypeSimultationResults()} == 0) {
    	my $msg = "Simulation of phenotypes failed to return results from FBA!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'simulate_phenotypes');
    }
	#Converting FBA results into simulated phenotype
    my $object = {
    	id => $input->{phenotypeSimultationSet},
    	phenotypeSet_workspace => $input->{phenotypeSet_workspace},
    	phenotypeSet => $input->{phenotypeSet},
    	model => $input->{model},
    	model_workspace => $input->{model_workspace},
    	phenotypeSimulations => []
    };
    my $phenoresults = $fbaResult->fbaPhenotypeSimultationResults();
    for (my $i=0; $i < @{$phenoresults};$i++) {
    	my $phenoResult = $phenoresults->[$i];
    	my $phenosim = [
    		$pheno->{phenotypes}->[$existingPhenos->{$phenokeys->[$i]}->[0]],
    		$phenoResult->simulatedGrowth(),
    		$phenoResult->simulatedGrowthFraction(),
    		$phenoResult->class(),
    		$existingPhenos->{$phenokeys->[$i]}
    	];
    	push(@{$object->{phenotypeSimulations}},$phenosim);
    }
    #Saving object to database
    my $objmeta = $self->_workspaceServices()->save_object({
		id => $input->{phenotypeSimultationSet},
		type => "PhenotypeSimulationSet",
		data => $object,
		workspace => $input->{workspace},
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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to integrate_reconciliation_solutions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'integrate_reconciliation_solutions');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN integrate_reconciliation_solutions
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["model","workspace","gapfillSolutions","gapgenSolutions"],{
		model_workspace => $input->{workspace},
		out_model => $input->{model},
    	overwrite => 0
    });
    my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
    foreach my $id (@{$input->{gapfillSolutions}}) {
    	if ($id =~ m/(.+)\.solution\.(.+)/) {
    		my $gfid = $1;
    		my $solid = $2;
    		my $gfs = $model->unintegratedGapfillings();
    		foreach my $gf (@{$gfs}) {
    			if ($gf->uuid() eq $gfid) {
	    			$model->integrateGapfillSolution({
						gapfillingFormulation => $gf,
						solutionNum => $solid
					});
					$self->_save_msobject($gf,"GapFill","NO_WORKSPACE",$gf->uuid(),"integrate_reconciliation_solutions",1,$gf->uuid());
					last;
    			}
    		}
    	}
    }
    foreach my $id (@{$input->{gapgenSolutions}}) {
    	if ($id =~ m/(.+)\.solution\.(.+)/) {
    		my $ggid = $1;
    		my $solid = $2;
    		my $ggs = $model->unintegratedGapgens();
    		foreach my $gg (@{$ggs}) {
    			if ($gg->uuid() eq $ggid) {
	    			$model->integrateGapgenSolution({
						gapgenFormulation => $gg,
						solutionNum => $solid
					});
					$self->_save_msobject($gg,"GapGen","NO_WORKSPACE",$gg->uuid(),"integrate_reconciliation_solutions",1,$gg->uuid());
    				last;
    			}
    		}
    	}
    }
    $modelMeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{out_model},"integrate_reconciliation_solutions",$input->{overwrite});
    $self->_clearContext();
    #END integrate_reconciliation_solutions
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to integrate_reconciliation_solutions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'integrate_reconciliation_solutions');
    }
    return($modelMeta);
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	$input = $self->_validateargs($input,["model","workspace"],{
		formulation => undef,
		fva => 0,
		simulateko => 0,
		minimizeflux => 0,
		findminmedia => 0,
		notes => "",
		model_workspace => $input->{workspace},
		fba => undef,
		donot_submit_job => 0,
	});
	if (!defined($input->{fba})) {
		$input->{fba} = $self->_get_new_id($input->{model}.".fba.");
	}
	#Creating FBAFormulation Object
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{workspace},$input->{fba});
	#Saving FBAFormulation to database
	my $fbameta = $self->_save_msobject($fba,"FBA",$input->{workspace},$input->{fba},"queue_runfba");
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
			bioref => $model->biochemistry_uuid(),
			mapref => $model->mapping_uuid(),
			annoref => $model->annotation_uuid(),
			modelref => $model->uuid(),
			fbaref => $fbameta->[8],
			fbaid => $input->{fba}
		}],
		postprocess_command => undef,
		postprocess_args => undef,
		queuing_command => "queue_runfba",
		workspace => $input->{workspace}
	});
	$job->{token} = $input->{auth};
	my $state = "queued";
	if ($input->{donot_submit_job} == 0) {
		$job = $self->_submit_job($job);
		$state = "nersc";
	}
	$output = $self->_save_msobject($job,"FBAJob","NO_WORKSPACE",$job->{id},"queue_runfba",0,$job->{id});
	$self->_workspaceServices()->queue_job({
    	jobid => $job->{id},
    	auth => $self->_authentication(),
    	"state" => $state
    });
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
	workspace has a value which is a workspace_id
	gapFill has a value which is a gapfill_id
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	$input = $self->_validateargs($input,["model","workspace"],{
		model_workspace => $input->{workspace},
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{workspace},
		integrate_solution => 0,
		out_model => $input->{model},
		gapFill => undef,
		gapFill_workspace => $input->{workspace},
		overwrite => 0,
		donot_submit_job => 0,
		timePerSolution => 3600,
		totalTimeLimit => 18000
	});
	$input->{formulation}->{timePerSolution} = $input->{timePerSolution};
	$input->{formulation}->{totalTimeLimit} = $input->{totalTimeLimit};
	#Checking is this is a postprocessing or initialization call
	if (!defined($input->{gapFill})) {
		$self->_get_new_id($input->{model}.".gapfill.");
		$input->{formulation} = $self->_setDefaultGapfillFormulation($input->{formulation});
		#TODO: This block should be in a "safe save" block to prevent race conditions
		my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
		my $gapfill = $self->_buildGapfillObject($input->{formulation},$model);
		$input->{gapFill} = $gapfill->uuid();
		push(@{$model->unintegratedGapfilling_uuids()},$gapfill->uuid());
		my $modelmeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{out_model},"queue_gapfill_model");
		#End "safe save" block
		$gapfill->fbaFormulation()->model_uuid($model->uuid());
		my $fbameta = $self->_save_msobject($gapfill->fbaFormulation(),"FBA","NO_WORKSPACE",$gapfill->fbaFormulation()->uuid(),"queue_gapfill_model",0,$gapfill->fbaFormulation()->uuid());
		$gapfill->model_uuid($model->uuid());
		my $gapfillmeta = $self->_save_msobject($gapfill,"GapFill","NO_WORKSPACE",$gapfill->uuid(),"queue_gapfill_model",0,$gapfill->uuid());
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
				bioref => $model->biochemistry_uuid(),
				mapref => $model->mapping_uuid(),
				annoref => $model->annotation_uuid(),
				modelref => $model->uuid(),
				fbaref => $gapfill->fbaFormulation()->uuid(),
				fbaid => $gapfill->fbaFormulation()->uuid()
			}],
			postprocess_command => "queue_gapfill_model",
			postprocess_args => [$input],
			queuing_command => "queue_gapfill_model",
			workspace => $input->{workspace}
		});
		$job->{token} = $input->{auth};
		my $state = "queued";
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
			$state = "nersc";
		}
		$output = $self->_save_msobject($job,"FBAJob","NO_WORKSPACE",$job->{id},"queue_gapfill_model",0,$job->{id});
		$self->_workspaceServices()->queue_job({
	    	jobid => $job->{id},
	    	auth => $self->_authentication(),
	    	"state" => $state
	    });
	} else {
		my $gapfill = $self->_get_msobject("GapFill","NO_WORKSPACE",$input->{gapFill});
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
			#TODO: This block should be in a "safe save" block to prevent race conditions
			my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
			$model->integrateGapfillSolution({
				gapfillingFormulation => $gapfill,
				solutionNum => 0
			});
			my $modelmeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{out_model},"queue_gapfill_model");
			#End "safe save" block
		}
		$output = $self->_save_msobject($gapfill,"GapFill","NO_WORKSPACE",$gapfill->uuid(),"queue_gapfill_model",1,$gapfill->uuid());
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
	workspace has a value which is a workspace_id
	gapGen has a value which is a gapgen_id
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	$input = $self->_validateargs($input,["model","workspace"],{
		model_workspace => $input->{workspace},
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{workspace},
		integrate_solution => 0,
		out_model => $input->{model},
		gapGen => undef,
		overwrite => 0,
		donot_submit_job => 0,
	});
	$input->{formulation}->{timePerSolution} = $input->{timePerSolution};
	$input->{formulation}->{totalTimeLimit} = $input->{totalTimeLimit};
	#Checking is this is a postprocessing or initialization call
	if (!defined($input->{gapGen})) {
		$input->{formulation} = $self->_setDefaultGapGenFormulation($input->{formulation});
		#TODO: This block should be in a "safe save" block to prevent race conditions
		my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
		my $gapgen = $self->_buildGapGenObject($input->{formulation},$model);	
		$input->{gapgen} = $gapgen->uuid();
		push(@{$model->unintegratedGapgen_uuids()},$gapgen->uuid());
		my $modelmeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{out_model},"queue_gapgen_model");
		#End "safe save" block
		$gapgen->fbaFormulation()->model_uuid($model->uuid());
		my $fbameta = $self->_save_msobject($gapgen->fbaFormulation(),"FBA","NO_WORKSPACE",$gapgen->fbaFormulation()->uuid(),"queue_gapgen_model",0,$gapgen->fbaFormulation()->uuid());
		$gapgen->model_uuid($model->uuid());
		my $gapgenmeta = $self->_save_msobject($gapgen,"GapGen","NO_WORKSPACE",$gapgen->uuid(),"queue_gapgen_model",0,$gapgen->uuid());
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
				bioref => $model->biochemistry_uuid(),
				mapref => $model->mapping_uuid(),
				annoref => $model->annotation_uuid(),
				modelref => $model->uuid(),
				fbaref => $gapgen->fbaFormulation()->uuid(),
				fbaid => $gapgen->fbaFormulation()->uuid()
			}],
			postprocess_command => "queue_gapgen_model",
			postprocess_args => [$input],
			queuing_command => "queue_gapgen_model",
			workspace => $input->{workspace}
		});
		$job->{token} = $input->{auth};
		my $state = "queued";
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
			$state = "nersc";
		}
		$output = $self->_save_msobject($job,"FBAJob","NO_WORKSPACE",$job->{id},"queue_gapgen_model",0,$job->{id});
		$self->_workspaceServices()->queue_job({
	    	jobid => $job->{id},
	    	auth => $self->_authentication(),
	    	"state" => $state
	    });
	} else {
		my $gapgen = $self->_get_msobject("GapGen","NO_WORKSPACE",$input->{gapGen});
		if (!defined($gapgen->fbaFormulation()->fbaResults())) {
			my $msg = "Gap generation failed!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_gapgen_model');
		}
		$gapgen->parseGapgenResults($gapgen->fbaFormulation()->fbaResults()->[0]);
		if ($input->{integrate_solution} == 1 && defined($gapgen->gapgenSolutions()->[0])) {
			#TODO: This block should be in a "safe save" block to prevent race conditions
			my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
			$model->integrateGapgenSolution({
				gapgenFormulation => $gapgen,
				solutionNum => 0
			});
			my $modelmeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{out_model},"queue_gapgen_model");			
			#End "safe save" block
		}
		$output = $self->_save_msobject($gapgen,"GapGen","NO_WORKSPACE",$gapgen->uuid(),"queue_gapgen_model",1,$gapgen->uuid());
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
	fba_formulation has a value which is an FBAFormulation
	gapfill_formulation has a value which is a GapfillingFormulation
	gapgen_formulation has a value which is a GapgenFormulation
	phenotypeSet has a value which is a phenotypeSet_id
	phenotypeSet_workspace has a value which is a workspace_id
	out_model has a value which is a fbamodel_id
	workspace has a value which is a workspace_id
	gapFills has a value which is a reference to a list where each element is a gapfill_id
	gapGens has a value which is a reference to a list where each element is a gapgen_id
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace","phenotypeSet"],{
		out_model => $input->{model},
		phenotypeSet => undef,
		gapFills => undef,
		gapGens => undef,
		model_workspace => $input->{workspace},
		phenotypeSet_workspace => $input->{workspace},
		gapGen_workspace => $input->{workspace},
		gapFill_workspace => $input->{workspace},
		fba_formulation => undef,
		gapfill_formulation => undef,
		gapgen_formulation => undef,
		overwrite => 0,
		donot_submit_job => 0,
		queueSensitivityAnalysis => 0,
		queueReconciliationCombination => 0
	});
	#Code to set up job
	if (!defined($input->{gapFills}) && !defined($input->{gapGens})) {
		#Creating formulations
		$input->{fba_formulation} = $self->_setDefaultFBAFormulation($input->{fba_formulation});
		$input->{gapfill_formulation} = $self->_setDefaultGapfillFormulation($input->{gapfill_formulation});
		$input->{gapgen_formulation} = $self->_setDefaultGapGenFormulation($input->{gapgen_formulation});
		$input->{gapfill_formulation}->{formulation} = $input->{fba_formulation};
		$input->{gapgen_formulation}->{formulation} = $input->{fba_formulation};	
		#Creating job object
		my $job = $self->_create_job({
			clusterjobs => [],
			postprocess_command => "queue_wildtype_phenotype_reconciliation",
			postprocess_args => [$input],
			queuing_command => "queue_wildtype_phenotype_reconciliation",
			workspace => $input->{workspace}
		});
		#Getting the simulated phenotype set to be reconciled
		my $simPheno = $self->_get_msobject("PhenotypeSimulationSet",$input->{phenotypeSet_workspace},$input->{phenotypeSet});
		if (!defined($simPheno->{phenotypeSimulations})) {
			my $msg = "No phenotypes simulated!";
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_wildtype_phenotype_reconciliation');
		}
		#Queing up gapfill and gapgen jobs
		#TODO: This block should be in a "safe save" block to prevent race conditions
		my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
		my $input = {
			model => $input->{model},
			model_workspace => $input->{model_workspace},
			phenotypeSet => $input->{phenotypeSet},
			phenotypeSet_workspace => $input->{phenotypeSet_workspace},
			formulation => $input->{fba_formulation},
			overwrite => $input->{overwrite},
			gapFills => [],
			gapGens => []
		};
		#Creating gapfill and gapgen jobs
		my $gapgenObjs = [];
		my $gapfillObjs = [];
		for (my $i=0; $i < @{$simPheno->{phenotypeSimulations}};$i++) {
			my $phenosim = $simPheno->{phenotypeSimulations}->[$i];
			if (@{$phenosim->[0]->[0]} == 0) {
				if ($phenosim->[3] eq "FN") {
					my $id = $self->_get_new_id($input->{model}.".gapfill.");
					push(@{$input->{gapFills}},$id);
					my $gapfill = $self->_buildGapfillObject($input->{gapfill_formulation},$model,$input->{gapFill_workspace},$id);
					push(@{$gapfillObjs},$gapfill);
					push(@{$model->unintegratedGapfilling_uuids()},$gapfill->uuid());
				} elsif ($phenosim->[3] eq "FP") {
					my $id = $self->_get_new_id($input->{model}.".gapgen.");
					push(@{$input->{gapGens}},$id);
					my $gapgen = $self->_buildGapGenObject($input->{gapgen_formulation},$model,$input->{gapGen_workspace},$id);
					push(@{$gapgenObjs},$gapgen);
					push(@{$model->unintegratedGapgen_uuids()},$gapgen->uuid());
				}
			}
		}
		my $modelmeta = $self->_save_msobject($model,"Model",$input->{workspace},$input->{out_model},"queue_wildtype_phenotype_reconciliation");
		#End "safe save" block
		foreach my $gapgenObj (@{$gapgenObjs}) {
			$gapgenObj->fbaFormulation()->model_uuid($model->uuid());
			my $fbameta = $self->_save_msobject($gapgenObj->fbaFormulation(),"FBA",$gapgenObj->fbaFormulation()->{_kbaseWSMeta}->{ws},$gapgenObj->fbaFormulation()->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			$gapgenObj->model_uuid($model->uuid());
			my $gapgenmeta = $self->_save_msobject($gapgenObj,"GapGen",$input->{gapGen_workspace},$gapgenObj->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			push(@{$job->{clusterjobs}},{
				mediaids => [],
				mediawss => [],
				mediainsts => [],
				bioref => $model->biochemistry_uuid(),
				mapref => $model->mapping_uuid(),
				annoref => $model->annotation_uuid(),
				modelref => $model->uuid(),
				fbaref => $fbameta->[8],
				fbaid => $gapgenObj->fbaFormulation()->{_kbaseWSMeta}->{wsid}
			});
		}
		foreach my $gapfillObj (@{$gapfillObjs}) {
			$gapfillObj->fbaFormulation()->model_uuid($model->uuid());
			my $fbameta = $self->_save_msobject($gapfillObj->fbaFormulation(),"FBA",$gapfillObj->fbaFormulation()->{_kbaseWSMeta}->{ws},$gapfillObj->fbaFormulation()->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			$gapfillObj->model_uuid($model->uuid());
			my $gapfillmeta = $self->_save_msobject($gapfillObj,"GapFill",$input->{gapFill_workspace},$gapfillObj->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			push(@{$job->{clusterjobs}},{
				mediaids => [],
				mediawss => [],
				mediainsts => [],
				bioref => $model->biochemistry_uuid(),
				mapref => $model->mapping_uuid(),
				annoref => $model->annotation_uuid(),
				modelref => $model->uuid(),
				fbaref => $fbameta->[8],
				fbaid => $gapfillObj->fbaFormulation()->{_kbaseWSMeta}->{wsid}
			});
		}
		$output = $self->_save_msobject($job,"FBAJob",$job->{workspace},$job->{id},"queue_gapfill_model");
		$job->{token} = $input->{auth};
		my $state = "queued";
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
			$state = "nersc";
		}
		$self->_workspaceServices()->queue_job({
	    	jobid => $job->{id},
	    	auth => $self->_authentication(),
	    	"state" => $state
	    });
	} elsif ($input->{queueSensitivityAnalysis} == 1) {
		#Code to post process job
		if (defined($input->{gapFills})) {
			foreach my $gf (@{$input->{gapFills}}) {
				my $gapfill = $self->_get_msobject("GapFill",$input->{gapFill_workspace},$gf);
				if (!defined($gapfill->fbaFormulation()->fbaResults())) {
					my $msg = "Gap filling failed!";
					Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_gapgen_model');
				}
				$gapfill->parseGapfillResults($gapfill->fbaFormulation()->fbaResults()->[0]);
				$output = $self->_save_msobject($gapfill,"GapFill",$input->{gapFill_workspace},$gf,"queue_gapgen_model");
			}
		}
		if (defined($input->{gapGens})) {
			foreach my $gg (@{$input->{gapGens}}) {
				my $gapgen = $self->_get_msobject("GapGen",$input->{gapGen_workspace},$gg);
				if (!defined($gapgen->fbaFormulation()->fbaResults())) {
					my $msg = "Gap generation failed!";
					Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'queue_gapgen_model');
				}
				$gapgen->parseGapgenResults($gapgen->fbaFormulation()->fbaResults()->[0]);
				$output = $self->_save_msobject($gapgen,"GapGen",$input->{gapGen_workspace},$gg,"queue_gapgen_model");
			}
		}
		#Queing up sensitivity analysis, the next step in the pipeline
		if ($input->{queueSensitivityAnalysis} == 1) {
			my $input = {
				model => $input->{out_model},
				workspace => $input->{workspace},
				phenotypeSet => $input->{phenotypeSet},
				phenotypeSet_workspace => $input->{phenotypeSet_workspace},
				gapFills => $input->{gapFills},
				gapGens => $input->{gapGens},
				overwrite => $input->{overwrite},
				donot_submit_job => $input->{donot_submit_job},
				queueReconciliationCombination => $input->{queueReconciliationCombination}
			};
			return $self->queue_reconciliation_sensitivity_analysis($input);
		}
	}	
    $self->_clearContext();
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_reconciliation_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_reconciliation_sensitivity_analysis');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN queue_reconciliation_sensitivity_analysis
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace","phenotypeSet"],{
		fba_formulation => undef,
		phenotypeSet_workspace => $input->{workspace},
		model_workspace => $input->{workspace},
		gapFills => undef,
		gapGens => undef,
		queueReconciliationCombination => 0,
		donot_submit_job => 1,
		overwrite => 0,
		simPhenoID => undef
	});
	#Retreiving model
	my $model = $self->_get_msobject("Model",$input->{model_workspace},$input->{model});
	if (!defined($input->{simPhenoID})) {
		#Retrieving phenotypes
		my $pheno = $self->_get_msobject("PhenotypeSet",$input->{phenotypeSet_workspace},$input->{phenotypeSet});
		#Creating FBAFormulation Object
		$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
		my $fba = $self->_buildFBAObject($input->{formulation},$model,"NO_WORKSPACE",Data::UUID->new()->create_str());
		#Constructing FBA simulation object from 
		($fba,my $existingPhenos,my $phenokeys) = $self->_prepPhenotypeSimultationFBA($model,$pheno,$fba);
		$fba->uuid(Data::UUID->new()->create_str());
		$fba->model($model);
		$fba->model_uuid($model->uuid());
		$fba->notes("WT");
		$output = $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_reconciliation_sensitivity_analysis",1,$fba->uuid());
		#Creating PhenotypeSensitivityAnalysis object
		my $phenoSenseAnalysis = {
			id => $self->_get_new_id($input->{model}.".phenosens."),
			phenotypeSet => $input->{phenotypeSet},
			phenotypeSet_workspace => $input->{phenotypeSet_workspace},
			model => $input->{model},
			model_workspace => $input->{model_workspace},
			phenotypes => [],
			wildtypePhenotypeSimulations => [],
			reconciliationSolutionSimulations => [],
			fbaids => [$fba->uuid()]
		};
		#Creating job object
		my $job = $self->_create_job({
			clusterjobs => [{
			mediaids => [],
			mediawss => [],
			mediainsts => [],
			bioref => $model->biochemistry_uuid(),
			mapref => $model->mapping_uuid(),
			annoref => $model->annotation_uuid(),
			modelref => $model->uuid(),
			fbaref => $fba->uuid(),
			fbaid => $fba->uuid()
		}],
			postprocess_command => "queue_reconciliation_sensitivity_analysis",
			postprocess_args => [{
				model => $input->{model},
				workspace => $input->{workspace},
				phenotypeSet => $input->{phenotypeSet},
				model_workspace => $input->{model_workspace},
				phenotypeSet_workspace => $input->{phenotypeSet_workspace},
				gapFills => $input->{gapFills},
				gapGens => $input->{gapGens},
				simPhenoID => $phenoSenseAnalysis->{id}
			}],
			queuing_command => "queue_reconciliation_sensitivity_analysis",
			workspace => $input->{workspace}
		});
		#Identifying gapfills and gapgens to assess
		if (!defined($input->{gapFills})) {
			$input->{gapFills} = [];
			for (my $i=0; $i < @{$model->unintegratedGapfillings()}; $i++) {
				push(@{$input->{gapFills}},$model->unintegratedGapfillings()->[$i]->uuid());
			}
		}
		if (!defined($input->{gapGens})) {
			$input->{gapGens} = [];
			for (my $i=0; $i < @{$model->unintegratedGapgens()}; $i++) {
				push(@{$input->{gapGens}},$model->unintegratedGapgens()->[$i]->uuid());
			}
		}
		#Queuing up sensitivity analysis of gapfilling solutions
		my $solIndex = 0;
		for (my $i=0;$i<@{$input->{gapFills}};$i++) {
			#print $input->{gapFills}->[$i]."\n";
			my $gf;
			for (my $j=0;$j<@{$model->unintegratedGapfillings()};$j++) {
				if ($model->unintegratedGapfillings()->[$j]->uuid() eq $input->{gapFills}->[$i]) {
					$gf = $model->unintegratedGapfillings()->[$j];
					last;
				}
			}
			if (defined($gf)) {
				#for (my $j=0;$j<2;$j++) {
				for (my $j=0;$j<@{$gf->gapfillingSolutions()};$j++) {
					#print "Integrating ".$input->{gapFills}->[$i].".".$j."\n";
					my $newmod = $model->cloneObject();
					$newmod->parent($self->_KBaseStore());
					$newmod->integrateGapfillSolution({
						solutionNum => $j,
						gapfillingFormulation => $gf
					});
					$newmod->uuid(Data::UUID->new()->create_str());
					$fba->uuid(Data::UUID->new()->create_str());
					$fba->model($newmod);
					$fba->model_uuid($newmod->uuid());
					$fba->notes($solIndex);
					$output = $self->_save_msobject($newmod,"Model","NO_WORKSPACE",$newmod->uuid(),"queue_reconciliation_sensitivity_analysis",1,$newmod->uuid());
					$output = $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_reconciliation_sensitivity_analysis",1,$fba->uuid());
					push(@{$phenoSenseAnalysis->{fbaids}},$fba->uuid());
					push(@{$phenoSenseAnalysis->{reconciliationSolutionSimulations}},["GF",$gf->uuid(),$j,$gf->gapfillingSolutions()->[$j]->solrxn(),$gf->gapfillingSolutions()->[$j]->biocpd(),[]]);
					push(@{$job->{clusterjobs}},{
						mediaids => [],
						mediawss => [],
						mediainsts => [],
						bioref => $newmod->biochemistry_uuid(),
						mapref => $newmod->mapping_uuid(),
						annoref => $newmod->annotation_uuid(),
						modelref => $newmod->uuid(),
						fbaref => $fba->uuid(),
						fbaid => $fba->uuid(),
					});
				}
			}
			$solIndex++;
		}		
		#Queuing up sensitivity analysis of gapgen solutions
		for (my $i=0;$i<@{$input->{gapGens}};$i++) {
			my $gg;
			for (my $j=0;$j<@{$model->unintegratedGapgens()};$j++) {
				if ($model->unintegratedGapgens()->[$j]->uuid() eq $input->{gapGens}->[$i]) {
					$gg = $model->unintegratedGapgens()->[$j];
					last;
				}
			}
			if (defined($gg)) {
				for (my $j=0;$j<@{$gg->gapgenSolutions()};$j++) {
					my $newmod = $model->cloneObject();
					$newmod->parent($self->_KBaseStore());
					$newmod->integrateGapgenSolution({
						solutionNum => $j,
						gapgenFormulation => $gg
					});
					$newmod->uuid(Data::UUID->new()->create_str());
					$fba->uuid(Data::UUID->new()->create_str());
					$fba->model($newmod);
					$fba->model_uuid($newmod->uuid());
					$fba->notes($solIndex);
					$output = $self->_save_msobject($newmod,"Model","NO_WORKSPACE",$newmod->uuid(),"queue_reconciliation_sensitivity_analysis",1,$newmod->uuid());
					$output = $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_reconciliation_sensitivity_analysis",1,$fba->uuid());
					push(@{$phenoSenseAnalysis->{fbaids}},$fba->uuid());
					push(@{$phenoSenseAnalysis->{reconciliationSolutionSimulations}},["GG",$gg->uuid(),$j,$gg->gapgenSolutions()->[$j]->solrxn(),$gg->gapgenSolutions()->[$j]->biocpd(),[]]);
					push(@{$job->{clusterjobs}},{
						mediaids => [],
						mediawss => [],
						mediainsts => [],
						bioref => $newmod->biochemistry_uuid(),
						mapref => $newmod->mapping_uuid(),
						annoref => $newmod->annotation_uuid(),
						modelref => $newmod->uuid(),
						fbaref => $fba->uuid(),
						fbaid => $fba->uuid()
					});
				}
			}
			$solIndex++;
		}    
		#Saving job object
		#print "Saving!\n";
		#print join("\n",@{$phenoSenseAnalysis->{fbaids}})."\n";
		$output = $self->_save_msobject($phenoSenseAnalysis,"PhenoSenseAnalysis",$input->{workspace},$phenoSenseAnalysis->{id},"queue_reconciliation_sensitivity_analysis");
		$output = $self->_save_msobject($job,"FBAJob","NO_WORKSPACE",$job->{id},"queue_reconciliation_sensitivity_analysis",0,$job->{id});
		#Queuing job
		$job->{token} = $input->{auth};
		my $state = "test";
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
			$state = "nersc";
		}
		$self->_workspaceServices()->queue_job({
	    	jobid => $job->{id},
	    	auth => $self->_authentication(),
	    	"state" => $state
	    });
	} else {
		my $phenoSense = $self->_get_msobject("PhenoSenseAnalysis",$input->{workspace},$input->{simPhenoID});
		my $allJobsComplete = 1;
		foreach my $fbaid (@{$phenoSense->{fbaids}}) {
			my $fba = $self->_get_msobject("FBA","NO_WORKSPACE",$fbaid);
			if (!defined($fba->fbaResults()->[0])) {
				$allJobsComplete = 0;
			}
		}
		if ($allJobsComplete == 1) {
			#print "All complete!\n";
			foreach my $fbaid (@{$phenoSense->{fbaids}}) {
				my $fba = $self->_get_msobject("FBA","NO_WORKSPACE",$fbaid);
				my $result = $fba->fbaResults()->[0];
				if ($fba->notes() eq "WT") {
					$phenoSense->{wildtypePhenotypeSimulations} = [];
					for (my $i=0; $i < @{$result->fbaPhenotypeSimultationResults()};$i++) {
						my $simResult = $result->fbaPhenotypeSimultationResults()->[$i];
						push(@{$phenoSense->{wildtypePhenotypeSimulations}},[$simResult->simulatedGrowth(),$simResult->simulatedGrowthFraction(),$simResult->class()]);
					}
				} else {
					my $index = $fba->notes();
					$phenoSense->{reconciliationSolutionSimulations}->[$index]->[5] = [];
					for (my $i=0; $i < @{$result->fbaPhenotypeSimultationResults()};$i++) {
						my $simResult = $result->fbaPhenotypeSimultationResults()->[$i];
						push(@{$phenoSense->{reconciliationSolutionSimulations}->[$index]->[5]},[$simResult->simulatedGrowth(),$simResult->simulatedGrowthFraction(),$simResult->class()]);
					}
#					$self->_workspaceServices()->delete_object_permanently({
#						type => "Model",
#						id => $fba->model_uuid(),
#						workspace => "NO_WORKSPACE"
#					});
#					$self->_workspaceServices()->delete_object_permanently({
#						type => "FBA",
#						id => $fba->uuid(),
#						workspace => "NO_WORKSPACE"
#					});
				}
			}
			#delete $phenoSense->{fbaids};
			$output = $self->_save_msobject($phenoSense,"PhenoSenseAnalysis",$input->{workspace},$input->{simPhenoID},"queue_reconciliation_sensitivity_analysis");
		} else {
			$output = $phenoSense->{_kbaseWSMeta}->{wsmeta};
		}
	}
    #END queue_reconciliation_sensitivity_analysis
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_reconciliation_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_reconciliation_sensitivity_analysis');
    }
    return($output);
}




=head2 queue_combine_wildtype_phenotype_reconciliation

  $output = $obj->queue_combine_wildtype_phenotype_reconciliation($input)

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
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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
	auth has a value which is a string
	overwrite has a value which is a bool
	donot_submit_job has a value which is a bool
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
object_metadata is a reference to a list containing 11 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a string
	5: a username
	6: a username
	7: a workspace_id
	8: a workspace_ref
	9: a string
	10: a reference to a hash where the key is a string and the value is a string
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

sub queue_combine_wildtype_phenotype_reconciliation
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_combine_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_combine_wildtype_phenotype_reconciliation');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN queue_combine_wildtype_phenotype_reconciliation
    #CombinedReconciliation
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["PhenoSensitivityAnalysis","workspace"],{
		out_model => undef,
		numsolutions => 1,
		intsolution => 1,
		timePerSolution => 3600,
		totalTimeLimit => 18000,
		donot_submit_job => 0,
		overwrite => 0,
		fbaid =>undef
	});
	my $classTrans = {
		"CP" => 0,
		"CN" => 1,
		"FP" => 2,
		"FN" => 3
	};
	my $phenoSense = $self->_get_msobject("PhenoSenseAnalysis",$input->{workspace},$input->{PhenoSensitivityAnalysis});
	my $model = $self->_get_msobject("Model",$phenoSense->{model_workspace},$phenoSense->{model});
	if (!defined($input->{out_model})) {
		$input->{out_model} = $phenoSense->{model};
	}
	if (!defined($input->{fbaid})) {
		my $origerrors = [];
		my $errorCount = 0;
		for (my $i=0; $i < @{$phenoSense->{wildtypePhenotypeSimulations}};$i++) {
			$origerrors->[$i] = $classTrans->{$phenoSense->{wildtypePhenotypeSimulations}->[$i]->[2]};
			if ($classTrans->{$phenoSense->{wildtypePhenotypeSimulations}->[$i]->[2]} eq "FP" || $classTrans->{$phenoSense->{wildtypePhenotypeSimulations}->[$i]->[2]} eq "FN") {
				$errorCount++;
			}		
		}
		my $formulation = $self->_setDefaultFBAFormulation({});
		my $fba = $self->_buildFBAObject($formulation,$model,"NO_WORKSPACE",Data::UUID->new()->create_str());
		$fba->inputfiles()->{"OPEM.txt"} = [join(";",@{$origerrors})];
		my $ggem = [];
		my $gfem = [];
		for (my $i=0; $i < @{$phenoSense->{reconciliationSolutionSimulations}}; $i++) {
			my $rxns = "";
			for (my $j=0; $j < @{$phenoSense->{reconciliationSolutionSimulations}->[$i]->[3]}; $j++) {
				if (length($rxns) > 0) {
					$rxns .= ",";
				}
				if ($phenoSense->{reconciliationSolutionSimulations}->[$i]->[3]->[$j]->[0] eq "<") {
					$rxns .= "-";
				} elsif ($phenoSense->{reconciliationSolutionSimulations}->[$i]->[3]->[$j]->[0] eq ">") {
					$rxns .= "+";
				}
				$rxns .= $phenoSense->{reconciliationSolutionSimulations}->[$i]->[3]->[$j]->[1];
			}
			my $solutionArray = [$phenoSense->{reconciliationSolutionSimulations}->[$i]->[1],$phenoSense->{reconciliationSolutionSimulations}->[$i]->[2],"",$rxns,""];
			$errorCount = 0;
			for (my $j=0; $j < @{$phenoSense->{reconciliationSolutionSimulations}->[$i]->[5]}; $j++) {
				push(@{$solutionArray},$classTrans->{$phenoSense->{reconciliationSolutionSimulations}->[$i]->[5]->[$j]});
				if ($classTrans->{$phenoSense->{reconciliationSolutionSimulations}->[$i]->[5]->[$j]} eq "FP" || $classTrans->{$phenoSense->{reconciliationSolutionSimulations}->[$i]->[5]->[$j]} eq "FN") {
					$errorCount++;
				}
			}
			$solutionArray->[4] = $errorCount."/".@{$phenoSense->{reconciliationSolutionSimulations}->[$i]->[5]};
			if ($phenoSense->{reconciliationSolutionSimulations}->[$i]->[0] eq "GG") {
				push(@{$ggem},join(";",@{$solutionArray}));
			} else {
				push(@{$gfem},join(";",@{$solutionArray}));
			}
		}
		$fba->inputfiles()->{"GGEM.txt"} = [join("\n",@{$ggem})];
		$fba->inputfiles()->{"GFEM.txt"} = [join("\n",@{$gfem})];
		$fba->parameters()->{"Perform solution reconciliation"} = 1;
		$fba->outputfiles()->[0] = "ReconciliationSolutions.txt";
		$self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_combine_wildtype_phenotype_reconciliation",1,$fba->uuid());
		my $job = $self->_create_job({
			clusterjobs => [{
				mediaids => [],
				mediawss => [],
				mediainsts => [],
				bioref => $model->biochemistry_uuid(),
				mapref => $model->mapping_uuid(),
				annoref => $model->annotation_uuid(),
				modelref => $model->uuid(),
				fbaref => $fba->uuid(),
				fbaid => $fba->uuid()
			}],
			postprocess_command => "queue_combine_wildtype_phenotype_reconciliation",
			postprocess_args => [{
				fbaid => $fba->uuid(),
				PhenoSensitivityAnalysis => $input->{PhenoSensitivityAnalysis},
				out_model => $input->{out_model},
				workspace => $input->{workspace},
			}],
			queuing_command => "queue_combine_wildtype_phenotype_reconciliation",
			workspace => $input->{workspace}
		});
		$job->{token} = $input->{auth};
		my $state = "test";
		if ($input->{donot_submit_job} == 0) {
			$job = $self->_submit_job($job);
			$state = "nersc";
		}
		$output = $self->_save_msobject($job,"FBAJob","NO_WORKSPACE",$job->{id},"queue_runfba",0,$job->{id});
		$self->_workspaceServices()->queue_job({
	    	jobid => $job->{id},
	    	auth => $self->_authentication(),
	    	"state" => $state
	    });
	} else {
		my $fba = $self->_get_msobject("FBA","NO_WORKSPACE",$input->{fbaid});
		my $data;
		#$output = $self->_save_msobject($data,"CombinedReconciliation",$input->{workspace},$data->{id},"queue_combine_wildtype_phenotype_reconciliation");
	}
	$self->_clearContext();
    #END queue_combine_wildtype_phenotype_reconciliation
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_combine_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_combine_wildtype_phenotype_reconciliation');
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
	auth has a value which is a string
job_id is a string
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
workspace_id is a string
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
	auth has a value which is a string
job_id is a string
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
workspace_id is a string
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
    $input = $self->_validateargs($input,["jobid"],{
    	"index" => 0
    });
    my $job = $self->_get_msobject("FBAJob","NO_WORKSPACE",$input->{jobid});
    my $clusterjob = $job->{clusterjobs}->[$input->{"index"}];
    $job->{complete} = 1;
    $job->{completetime} = DateTime->now()->datetime();
    if (defined($job->{postprocess_command})) {
    	my $function = $job->{postprocess_command};
    	my $args;
    	if (defined($clusterjob->{postprocess_args})) {
    		$args = $clusterjob->{postprocess_args};
    	} else {
    		$args = $job->{postprocess_args};
    	}
    	#$args->[0]->{auth} = $self->_authentication();
    	$self->$function(@{$args});
    }
    my $jobCount = @{$job->{clusterjobs}};
    $jobCount--;
    if ($input->{"index"} == $jobCount) {
	    $self->_workspaceServices()->set_job_status({
	    	jobid => $input->{jobid},
	    	status => "done",
	    	auth => $self->_authentication(),
	    	currentStatus => "running"
	    });
    }
    $self->_save_msobject($job,"FBAJob","NO_WORKSPACE",$input->{jobid},"jobs_done",1,$input->{jobid});
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
	auth has a value which is a string
job_id is a string
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
workspace_id is a string
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
	auth has a value which is a string
job_id is a string
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
workspace_id is a string
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
    $input = $self->_validateargs($input,["jobid"],{});
    $output = $self->_get_msobject("FBAJob","NO_WORKSPACE",$input->{jobid});
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
	index has a value which is an int
	auth has a value which is a string
job_id is a string
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
workspace_id is a string
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
	index has a value which is an int
	auth has a value which is a string
job_id is a string
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
workspace_id is a string
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
    $input = $self->_validateargs($input,["jobid"],{
    	"index" => 0,
    });
    my $job = $self->_get_msobject("FBAJob","NO_WORKSPACE",$input->{jobid});
    if ($input->{"index"} == 0) {
	    my $currentState = "queued";
	    if (defined($job->{clustertoken})) {
	    	$currentState = "nersc";
	    }
	    $self->_workspaceServices()->set_job_status({
	    	jobid => $input->{jobid},
	    	status => "running",
	    	auth => $self->_authentication(),
	    	currentStatus => $currentState
	    });
    }
    my $clusterjob = $job->{clusterjobs}->[$input->{"index"}];
    my $fba = $self->_get_msobject("FBA","NO_WORKSPACE",$clusterjob->{fbaref});
    my $fbaResult = $fba->runFBA();
    if (!defined($fbaResult)) {
    	my $msg = "FBA failed with no solution returned!";
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => 'runfba');
    }
    #Saving the FBA by reference, overwriting the same object in the workspace
    $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->{_kbaseWSMeta}->{wsid},"run_job",1,$clusterjob->{fbaref});
	$output = $job;
	delete $input->{auth};
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
a reference to a list containing 11 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a string
5: a username
6: a username
7: a workspace_id
8: a workspace_ref
9: a string
10: a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a list containing 11 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a string
5: a username
6: a username
7: a workspace_id
8: a workspace_ref
9: a string
10: a reference to a hash where the key is a string and the value is a string


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
0: a feature_id
1: a string
2: a float

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: a feature_id
1: a string
2: a float


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
0: a string
1: a float

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: a string
1: a float


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



=item Description

Data structures for media formulation

media_id id - ID of media formulation
string name - name of media formulaiton
list<compound_id> compounds - list of compounds in media formulation
list<float> concentrations - list of compound concentrations
float pH - pH of media condition
float temperature - temperature of media condition


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



=item Description

Data structures for a reaction in a model

modelcompound_id modelcompound - ID of model compound in biomass reaction
float coefficient - coefficient of compound in biomass reaction
string name - name of compound in biomass reaction


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



=head2 Subsystem

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
name has a value which is a string
feature has a value which is a reference to a list where each element is a feature_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
name has a value which is a string
feature has a value which is a reference to a list where each element is a feature_id


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
modelSubsystems has a value which is a reference to a list where each element is a Subsystem

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
modelSubsystems has a value which is a reference to a list where each element is a Subsystem


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



=item Description

Maximum production of compound in FBA simulation

float maximumProduction - maximum production of compound
modelcompound_id modelcompound - ID of compound with production maximized
string name - name of compound with simulated production


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



=item Description

Term of constraint or objective in FBA simulation

float coefficient - coefficient of term in objective or constraint
string varType - type of variable for term in objective or constraint
string variable - variable ID for term in objective or constraint


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



=item Description

Biomass component removed in gapfill solution

compound_id compound - ID of biomass component removed
string name - name of biomass component removed


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



=item Description

Media component added in gapfill solution

compound_id compound - ID of media component added
string name - name of media component added


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



=item Description

Compounds added to biomass in gapgen solution

compound_id compound - ID of biomass compound added
string name - name of biomass compound added


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



=item Description

Media components removed in gapgen solution

compound_id compound - ID of media component removed
string name - name of media component removed


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



=item Description

Data structures for set of growth phenotype observations

phenotypeSet_id id - ID of the phenotype set
genome_id genome - ID of the genome for the strain used with the growth phenotypes
workspace_id genome_workspace - workspace containing the genome object
list<Phenotype> phenotypes - list of phenotypes included in the phenotype set
string importErrors - list of errors encountered during the import of the phenotype set


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
string class - class of the phenotype simulation (i.e. 'CP' - correct positive, 'CN' - correct negative, 'FP' - false positive, 'FN' - false negative)


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



=item Description

Data structures for phenotype simulations of a set of phenotype data

phenotypeSimulationSet_id id - ID for the phenotype simulation set object
fbamodel_id model - ID of the model used to simulate all phenotypes
workspace_id model_workspace - workspace containing the model used for the simulation
phenotypeSet_id phenotypeSet - set of observed phenotypes that were simulated
list<PhenotypeSimulation> phenotypeSimulations - list of simulated phenotypes


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

Data structures for an FBA job object

job_id id - ID of the job object
workspace_id workspace - workspace containing job object
list<clusterjob> clusterjobs - list of data related to cluster jobs
string postprocess_command - command to be run after the job is complete
list<CommandArguments> postprocess_args - arguments to be submitted to the postprocess job
string queuing_command - command used to queue job
float clustermem - maximum memmory expected to be consumed by the job
int clustertime - maximum time to spent running the job
string clustertoken - token for submitted cluster job
string queuetime - time when the job was queued
string completetime - time when the job was completed
bool complete - flag indicating if job is complete
string owner - username of the user that queued the job


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



=head2 get_ETCDiagram_params

=over 4



=item Description

Input parameters for the "genome_to_fbamodel" function.

        model_id model - ID of the model to retrieve ETC for
        workspace_id workspace - ID of the workspace containing the model 
        media_id media - ID of the media to retrieve ETC for
        workspace_id mediaws - workpace containing the specified media
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
media has a value which is a media_id
mediaws has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
media has a value which is a media_id
mediaws has a value which is a workspace_id
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



=head2 genome_object_to_workspace_params

=over 4



=item Description

Input parameters for the "genome_object_to_workspace" function.

        GenomeObject genomeobj - full genome typed object to be loaded into the workspace (a required argument)
        workspace_id workspace - ID of the workspace into which the genome typed object is to be loaded (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genomeobj has a value which is a GenomeObject
workspace has a value which is a workspace_id
auth has a value which is a string
overwrite has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
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
        probanno_id probanno - ID of the probabilistic annotation to be used in building the model (an optional argument; default is 'undef')
        workspace_id probanno_workspace - ID of the workspace containing the probabilistic annotation (an optional argument; default is the workspace argument)
        float probannoThreshold - a threshold of the probability required for a probabilistic annotation to be accepted (an optional argument; default is '1')
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
probanno has a value which is a probanno_id
probanno_workspace has a value which is a workspace_id
probannoThreshold has a value which is a float
probannoOnly has a value which is a bool
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
probanno has a value which is a probanno_id
probanno_workspace has a value which is a workspace_id
probannoThreshold has a value which is a float
probannoOnly has a value which is a bool
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

Input parameters for the "genome_to_fbamodel" function.

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
0: a string
1: a string
2: a string
3: a string

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
0: a string
1: a string
2: a string
3: a string

model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
ignore_errors has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool


=end text

=back



=head2 genome_to_probfbamodel_params

=over 4



=item Description

Input parameters for the "genome_to_fbamodel" function.

        genome_id genome - ID of the genome for which a model is to be built (a required argument)
        workspace_id genome_workspace - ID of the workspace containing the target genome (an optional argument; default is the workspace argument)
        probanno_id probanno - ID of the probabilistic annotation to be used in building the model (an optional argument; default is 'undef')
        workspace_id probanno_workspace - ID of the workspace containing the probabilistic annotation (an optional argument; default is the workspace argument)
        fbamodel_id model - ID that should be used for the newly constructed model (an optional argument; default is 'undef')
        workspace_id workspace - ID of the workspace where the newly developed model will be stored; also the default assumed workspace for input objects (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
probanno has a value which is a probanno_id
probanno_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a genome_id
genome_workspace has a value which is a workspace_id
probanno has a value which is a probanno_id
probanno_workspace has a value which is a workspace_id
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
auth has a value which is a string


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


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
type has a value which is a string
format has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
type has a value which is a string
format has a value which is a string


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
        reaction_id reaction - ID of reaction to be added, removed, or adjusted
        string direction - direction to set for reaction being added or adjusted
        compartment_id compartment - ID of compartment containing reaction being added or adjusted
        int compartmentIndex - index of compartment containing reaction being altered or adjusted
        list<list<list<feature_id>>> gpr - array specifying gene-protein-reaction associations
        bool removeReaction - boolean indicating reaction should be removed
        bool addReaction - boolean indicating reaction should be added
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
reaction has a value which is a reaction_id
direction has a value which is a string
compartment has a value which is a compartment_id
compartmentIndex has a value which is an int
gpr has a value which is a reference to a list where each element is a reference to a list where each element is a reference to a list where each element is a feature_id
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
reaction has a value which is a reaction_id
direction has a value which is a string
compartment has a value which is a compartment_id
compartmentIndex has a value which is an int
gpr has a value which is a reference to a list where each element is a reference to a list where each element is a reference to a list where each element is a feature_id
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
        float coefficient - coefficient of biomass compound
        compound_id compound - ID of biomass compound to adjust in biomass
        compartment_id compartment - ID of compartment containing compound to adjust in biomass
        int compartmentIndex - index of compartment containing compound to adjust in biomass
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
biomass has a value which is a biomass_id
coefficient has a value which is a float
compound has a value which is a compound_id
compartment has a value which is a compartment_id
compartmentIndex has a value which is an int
overwrite has a value which is a bool
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
biomass has a value which is a biomass_id
coefficient has a value which is a float
compound has a value which is a compound_id
compartment has a value which is a compartment_id
compartmentIndex has a value which is an int
overwrite has a value which is a bool
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



=item Description

Input parameters for the "simulate_phenotypes" function.

        fbamodel_id model - ID of the model to be used for the simulation (a required argument)
        workspace_id model_workspace - workspace containing the model for the simulation (an optional argument: default is value of workspace argument)
        phenotypeSet_id phenotypeSet - ID of the phenotypes set to be simulated (a required argument)
        workspace_id phenotypeSet_workspace - workspace containing the phenotype set to be simulated (an optional argument: default is value of workspace argument)
        FBAFormulation formulation - parameters for the simulation flux balance analysis (an optional argument: default is 'undef')
        string notes - string of notes to associate with the phenotype simulation (an optional argument: default is '')
        phenotypeSimulationSet_id phenotypeSimultationSet - ID of the phenotype simulation set to be generated (an optional argument: default is 'undef')
        workspace_id workspace - workspace where the phenotype simulation set should be saved (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


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



=item Description

Input parameters for the "queue_gapfill_model" function.

        fbamodel_id model - ID of the model that gapfill should be run on (a required argument)
        workspace_id model_workspace - workspace where model for gapfill should be run (an optional argument; default is the value of the workspace argument)
        GapfillingFormulation formulation - a hash specifying the parameters for the gapfill study (an optional argument)
        phenotypeSet_id phenotypeSet - ID of a phenotype set against which gapfilled model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        bool integrate_solution - a flag indicating if the first solution should be integrated in the model (an optional argument: default is '0')
        fbamodel_id out_model - ID where the gapfilled model will be saved (an optional argument: default is 'undef')
        gapfill_id gapFill - ID to which gapfill solution will be saved (an optional argument: default is 'undef')
        workspace_id workspace - workspace where gapfill results will be saved (a required argument)
        bool donot_submit_job - a flag indicating if the job should be submitted to the cluster (an optional argument: default is '0')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


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
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 gapgen_model_params

=over 4



=item Description

Input parameters for the "queue_gapfill_model" function.

        fbamodel_id model - ID of the model that gapgen should be run on (a required argument)
        workspace_id model_workspace - workspace where model for gapgen should be run (an optional argument; default is the value of the workspace argument)
        GapgenFormulation formulation - a hash specifying the parameters for the gapgen study (an optional argument)
        phenotypeSet_id phenotypeSet - ID of a phenotype set against which gapgened model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        bool integrate_solution - a flag indicating if the first solution should be integrated in the model (an optional argument: default is '0')
        fbamodel_id out_model - ID where the gapgened model will be saved (an optional argument: default is 'undef')
        gapgen_id gapGen - ID to which gapgen solution will be saved (an optional argument: default is 'undef')
        workspace_id workspace - workspace where gapgen results will be saved (a required argument)
        bool donot_submit_job - a flag indicating if the job should be submitted to the cluster (an optional argument: default is '0')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


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
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


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
        phenotypeSet_id phenotypeSet - ID of a phenotype set against which reconciled model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        fbamodel_id out_model - ID where the reconciled model will be saved (an optional argument: default is 'undef')
        list<gapgen_id> gapGens - IDs of gapgen solutions (an optional argument: default is 'undef')
        list<gapfill_id> gapFills - IDs of gapfill solutions (an optional argument: default is 'undef')
        bool queueSensitivityAnalysis - flag indicating if sensitivity analysis should be queued to run on solutions (an optional argument: default is '0')
        bool queueReconciliationCombination - flag indicating if reconcilication combination should be queued to run on solutions (an optional argument: default is '0')
        workspace_id workspace - workspace where reconciliation results will be saved (a required argument)
        bool donot_submit_job - a flag indicating if the job should be submitted to the cluster (an optional argument: default is '0')
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
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
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
queueSensitivityAnalysis has a value which is a bool
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


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
        phenotypeSet_id phenotypeSet - ID of a phenotype set against which sensitivity analysis model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        fbamodel_id out_model - ID where the sensitivity analysis model will be saved (an optional argument: default is 'undef')
        list<gapgen_id> gapGens - IDs of gapgen solutions (an optional argument: default is 'undef')
        list<gapfill_id> gapFills - IDs of gapfill solutions (an optional argument: default is 'undef')
        bool queueReconciliationCombination - flag indicating if sensitivity analysis combination should be queued to run on solutions (an optional argument: default is '0')
        workspace_id workspace - workspace where sensitivity analysis results will be saved (a required argument)
        bool donot_submit_job - a flag indicating if the job should be submitted to the cluster (an optional argument: default is '0')
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
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
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
queueReconciliationCombination has a value which is a bool
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


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
        phenotypeSet_id phenotypeSet - ID of a phenotype set against which solution combination model should be simulated (an optional argument: default is 'undef')
        workspace_id phenotypeSet_workspace - workspace containing phenotype set to be simulated (an optional argument; default is the value of the workspace argument)
        fbamodel_id out_model - ID where the solution combination model will be saved (an optional argument: default is 'undef')
        list<gapgen_id> gapGens - IDs of gapgen solutions (an optional argument: default is 'undef')
        list<gapfill_id> gapFills - IDs of gapfill solutions (an optional argument: default is 'undef')
        workspace_id workspace - workspace where solution combination results will be saved (a required argument)
        bool donot_submit_job - a flag indicating if the job should be submitted to the cluster (an optional argument: default is '0')
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
phenotypeSet has a value which is a phenotypeSet_id
phenotypeSet_workspace has a value which is a workspace_id
out_model has a value which is a fbamodel_id
workspace has a value which is a workspace_id
gapFills has a value which is a reference to a list where each element is a gapfill_id
gapGens has a value which is a reference to a list where each element is a gapgen_id
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
auth has a value which is a string
overwrite has a value which is a bool
donot_submit_job has a value which is a bool


=end text

=back



=head2 jobs_done_params

=over 4



=item Description

Input parameters for the "jobs_done" function.

        job_id jobid - ID of the job object (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
auth has a value which is a string


=end text

=back



=head2 check_job_params

=over 4



=item Description

Input parameters for the "check_job" function.

        job_id jobid - ID of the job object (a required argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
auth has a value which is a string


=end text

=back



=head2 run_job_params

=over 4



=item Description

Input parameters for the "run_job" function.

        job_id jobid - ID of the job object (a required argument)
        int index - index of subobject to be run (an optional argument; default is '0')
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace (an optional argument; user is "public" if auth is not provided)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
index has a value which is an int
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a job_id
index has a value which is an int
auth has a value which is a string


=end text

=back



=cut

1;
