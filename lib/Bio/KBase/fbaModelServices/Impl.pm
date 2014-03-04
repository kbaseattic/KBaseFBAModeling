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
use ModelSEED::Client::SAP;
use Bio::KBase::IDServer::Client;
use Bio::KBase::workspaceService::Client;
use Bio::KBase::CDMI::CDMIClient;
use Bio::KBase::AuthToken;
use Bio::KBase::probabilistic_annotation::Client;
use Bio::KBase::GenomeAnnotation::Client;
use Bio::KBase::ObjectAPI::KBaseStore;
use Data::UUID;
use Bio::KBase::ObjectAPI::ProbabilisticAnnotation::ProbAnno;
use Bio::KBase::ObjectAPI::ProbabilisticAnnotation::RxnProbs;
use Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry;
use Bio::KBase::ObjectAPI::KBaseBiochem::Media;
use Bio::KBase::ObjectAPI::KBaseOntology::Mapping;
use Bio::KBase::ObjectAPI::KBaseGenomes::Genome;
use Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet;
use Bio::KBase::ObjectAPI::KBaseGenomes::ProteinSet;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAModel;
#use Bio::KBase::ObjectAPI::GlobalFunctions;
use Bio::KBase::ObjectAPI::KBaseFBA::Gapfilling;
use Bio::KBase::ObjectAPI::KBaseFBA::Gapgeneration;
use Bio::KBase::ObjectAPI::KBaseFBA::FBA;
use Bio::KBase::ObjectAPI::KBaseFBA::ModelTemplate;
use Bio::KBase::workspace::Client;
use Bio::KBase::ObjectAPI::KBaseGenomes::MetagenomeAnnotation;
use Bio::KBase::ObjectAPI::utilities qw( args verbose set_verbose translateArrayOptions);
use Try::Tiny;
use Data::Dumper;
use Config::Simple;
use Digest::MD5;
use LWP::Simple "getstore";

sub _authentication {
	my($self) = @_;
	if (defined($self->_getContext->{_override}->{_authentication})) {
		return $self->_getContext->{_override}->{_authentication};
	} elsif (defined($self->_getContext()->{token})) {
		return $self->_getContext()->{token};
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
		$self->{_initialBiochemistryCounts}->{Compounds} = @{$biochemistry->compounds()};
		$self->{_initialBiochemistryCounts}->{Reactions} = @{$biochemistry->reactions()};
	}
	return $self->{_cachedbiochemistry};
}

sub _resetCachedBiochemistry {
	my ($self) = @_;
	if (defined($self->_cachedBiochemistry())) {
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
	my ($self,$params) = @_;
	delete $self->{_kbasestore};
	my @calldata = caller(2);
	my $temp = [split(/:/,$calldata[3])];
	$temp = pop(@{$temp});
	my $newparams = {};
	foreach my $param (keys(%{$params})) {
		if ($param ne "fasta" && $param ne "annotations") {
			$newparams->{$param} = $params->{$param};
		}
	}
	if (defined($self->_authentication())) {	
		$self->{_kbasestore} = Bio::KBase::ObjectAPI::KBaseStore->new({
			provenance => [{
				"time" => DateTime->now()->datetime()."+0000",
				service_ver => $VERSION,
				service => "KBaseFBAModeling",
				method => $temp,
				method_params => [$newparams],
				input_ws_objects => [],
				resolved_ws_objects => [],
				intermediate_incoming => [],
				intermediate_outgoing => []
			}],
			workspace => $self->_workspaceServices()
		});
	} else {
		$self->{_kbasestore} = Bio::KBase::ObjectAPI::KBaseStore->new({
			provenance => [{
				"time" => DateTime->now()->datetime()."+0000",
				service_ver => $VERSION,
				service => "KBaseFBAModeling",
				method => $temp,
				method_params => [$newparams],
				input_ws_objects => [],
				resolved_ws_objects => [],
				intermediate_incoming => [],
				intermediate_outgoing => []
			}],
			workspace => $self->_workspaceServices()
		});
	}
	if (defined($self->_cachedBiochemistry())) {
		$self->_resetCachedBiochemistry();
		$self->{_kbasestore}->cache()->{"kbase/default"} = $self->_cachedBiochemistry();
	}
}

sub _KBaseStore {
	my ($self) = @_;
	return $self->{_kbasestore};
}

sub _accountType {
	my ($self) = @_;
	if (!defined($self->{_accounttype})) {
		$self->{_accounttype} = "kbase";
	}
	return $self->{_accounttype};	
}

sub _authenticate {
	my ($self,$auth) = @_;
	if ($self->{_accounttype} eq "kbase") {
		if ($auth =~ m/^IRIS-/) {
			return {
				authentication => $auth,
				user => $auth
			};
		} else {
			my $token = Bio::KBase::AuthToken->new(
				token => $auth,
			);
			if ($token->validate()) {
				return {
					authentication => $auth,
					user => $token->user_id
				};
			} else {
				$self->_error("Invalid authorization token:".$auth,'_setContext');
			}
		}
	} elsif ($self->{_accounttype} eq "seed") {
		$auth =~ s/\s/\t/;
		my $split = [split(/\t/,$auth)];
		my $svr = $self->_mssServer();
		my $token = $svr->authenticate({
			username => $split->[0],
			password => $split->[1]
		});
		if (!defined($token) || $token =~ m/ERROR:/) {
			$self->_error($token,'_setContext');
		}
		$token =~ s/\s/\t/;
		$split = [split(/\t/,$token)];
		return {
			authentication => $token,
			user => $split->[0]
		};
	} elsif ($self->{_accounttype} eq "modelseed") {
		require "ModelSEED/utilities.pm";
		my $config = ModelSEED::utilities::config();
		my $username = $config->authenticate({
			token => $auth
		});
		return {
			authentication => $auth,
			user => $username
		};
	} elsif ($self->{_accounttype} eq "simple") {
		if ($auth !~ m/^[a-zA-Z0-9_]*$/) {
			$self->_error("Simple accounts must be alphanumeric!",'_setContext');
		}
		return {
			authentication => $auth,
			user => $auth
		};
	}
}

sub _setContext {
	my ($self,$context,$params) = @_;
	if (defined($params->{wsurl})) {
		$self->_getContext()->{_override}->{_wsurl} = $params->{wsurl};
	}
	if (defined($params->{probanno_url})) {
		$self->_getContext()->{_override}->{_probanno_url} = $params->{probanno_url};
	}
    if (defined($params->{auth}) && length($params->{auth}) > 0) {
		if (!defined($self->_getContext()->{_override}) || $self->_getContext()->{_override}->{_authentication} ne $params->{auth}) {
			my $output = $self->_authenticate($params->{auth});
			$self->_getContext()->{_override}->{_authentication} = $output->{authentication};
			$self->_getContext()->{_override}->{_currentUser} = $output->{user};
		}
    }
    delete $self->{_workspaceServices};
	$self->_resetKBaseStore($params);		
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

sub _cdmi {
	my $self = shift;
	if (!defined($self->{_cdmi})) {
		$self->{_cdmi} = Bio::KBase::CDMI::CDMIClient->new_for_script();
	}
    return $self->{_cdmi};
}

sub _mssServer {
	my $self = shift;
	if (!defined($self->{_mssServer})) {
		require "Bio/ModelSEED/MSSeedSupportServer/Client.pm";
		$self->{_mssServer} = Bio::ModelSEED::MSSeedSupportServer::Client->new($self->{'_mssserver-url'});
	}
    return $self->{_mssServer};
}

sub _idServer {
	my $self = shift;
    return Bio::KBase::ObjectAPI::utilities::idServer();
}

sub _gaserv {
	my $self = shift;
    return $self->{_gaserver};
}

sub _jobserv {
	my $self = shift;
    return $self->{_jobserver};
}

sub _workspaceServices {
	my $self = shift;
	if (defined($self->{_workspaceServiceOveride})) {
		return $self->{_workspaceServiceOveride};
	}
	if (!defined($self->{_workspaceServices}->{$self->_workspaceURL()})) {
		my $url = $self->_workspaceURL();
		$url =~ s/https/http/;
		$self->{_workspaceServices}->{$self->_workspaceURL()} = Bio::KBase::workspace::Client->new($url);
		$self->{_workspaceServices}->{$self->_workspaceURL()}->{token} = $self->_authentication();
		$self->{_workspaceServices}->{$self->_workspaceURL()}->{client}->{token} = $self->_authentication();
	}
    return $self->{_workspaceServices}->{$self->_workspaceURL()};
}

sub _workspace_list {
	my $self = shift;
	if (!defined($self->_getContext()->{_workspace_list})) {
		$self->_getContext()->{_workspace_list} = $self->_workspaceServices()->list_workspace_info({});
	}
	return $self->_getContext()->{_workspace_list};
}

sub _workspaceURL {
	my $self = shift;
	if (defined($self->_getContext()->{_override}->{_wsurl})) {
		return $self->_getContext()->{_override}->{_wsurl};
	}
	return $self->{"_workspace-url"};
}

sub _probanno {
	my $self = shift;
	my $url = $self->{"_probanno-url"};
	if (defined($self->_getContext()->{_override}->{_probanno_url})) {
		$url = $self->_getContext()->{_override}->{_probanno_url};
	}
	if (!defined($self->{_probannoServices}->{$url})) {
		$self->{_probannoServices}->{$url} = Bio::KBase::probabilistic_annotation::Client->new($url);
	}
	return $self->{_probannoServices}->{$url};
}

sub _myURL {
	my $self = shift;
	return $self->{"_fba-url"};
}

sub _save_msobject {
	my($self,$obj,$type,$ws,$id,$params) = @_;
	my $data;
	if (ref($obj) =~ m/Bio::KBase::ObjectAPI::/) {
		return $self->_KBaseStore()->save_object($obj,$ws."/".$id,$params);
	} else {
		$data = $obj;
		my $input = {
			objects => [{
				data => $data,
				type => "Unspecified",
				provenance => $self->_KBaseStore()->provenance()
			}],
		};
		if ($ws  =~ m/^\d+$/) {
    		$input->{id} = $ws;
    	} else {
    		$input->{workspace} = $ws;
    	}
		if ($id =~ m/^\d+$/) {
			$input->{objects}->[0]->{objid} = $id;
		} else {
			$input->{objects}->[0]->{name} = $id;
		}
		my $listout = $self->_KBaseStore()->workspace()->save_objects($input);
    	return $listout->[0];
	}
}

sub _get_msobject {
	my($self,$type,$ws,$id,$options) = @_;
	my $ref = $ws."/".$id;
	if ($ws eq "kbase" && $id eq "default" && $type eq "Mapping") {
		$id = "default-mapping";
	}
	my $obj = $self->_KBaseStore()->get_object($ref,$options);
	if (!defined($self->_cachedBiochemistry()) && $type eq "Biochemistry" && $id eq "default" && $ws eq "kbase") {
		$self->_cachedBiochemistry($obj);
	}
	return $obj;
}

sub _get_genomeObj_from_CDM {
	my($self,$id,$asNew) = @_;
	my $cdmi = $self->_cdmi();
    my $data = $cdmi->genomes_to_genome_data([$id]);
    if (!defined($data->{$id})) {
    	$self->_error("Genome ".$id." not found!",'get_genomeobject');
    }
    my $genomeObj = {
		id => $id,
		scientific_name => $data->{$id}->{scientific_name},
		domain => "Bacteria",
		genetic_code => $data->{$id}->{genetic_code},
		dna_size => $data->{$id}->{dna_size},
		num_contigs => $data->{$id}->{contigs},
		contig_lengths => [],
		contig_ids => [],
		source => "KBase",
		source_id => $id,
		md5 => $data->{$id}->{genome_md5},
		taxonomy => $data->{$id}->{taxonomy},
		gc_content => $data->{$id}->{gc_content},
		complete => $data->{$id}->{complete},
		publications => [],
		features => [],
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
    $data = $cdmi->genomes_to_contigs([$id]);
    my $contigset = {
    	id => $self->_register_kb_id("kb|contigset",$genomeObj->{md5},"md5hash"),
		name => $genomeObj->{scientific_name},
		md5 => $genomeObj->{md5},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
    };
    for (my $i=0; $i < @{$data->{$id}}; $i++) {
    	my $seqData = $cdmi->contigs_to_sequences([$data->{$id}->[$i]]);
    	push(@{$contigset->{contigs}},{
    		id => $data->{$id}->[$i],
			"length" => length($seqData->{$data->{$id}->[$i]}),
			md5 => Digest::MD5::md5_hex($seqData->{$data->{$id}->[$i]}),
			sequence => $seqData->{$data->{$id}->[$i]},
			name => $data->{$id}->[$i]
    	});
   	}
    my $ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
    my $genomeFtrs = $cdmi->genomes_to_fids([$id],[]);
	my $features = $genomeFtrs->{$id};
  	my $fidAnnotationHash = $cdmi->fids_to_annotations($features);
  	my $fidProteinSequences = $cdmi->fids_to_protein_sequences($features);
  	my $fidDataHash = $cdmi->fids_to_feature_data($features);
  	for (my $i=0; $i < @{$features};$i++) {
  		my $ftr = $features->[$i];
  		my $ftrdata = $fidDataHash->{$ftr};
  		my $feature = {
  			id => $ftr,
			location => $ftrdata->{feature_location},
			function => $ftrdata->{feature_function},
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => []
  		};
  		for (my $j=0; $j < @{$ftrdata->{feature_location}}; $j++) {
  			$feature->{location}->[$j]->[1] = $feature->{location}->[$j]->[1]+0;
			$feature->{location}->[$j]->[3] = $feature->{location}->[$j]->[3]+0;
  		}
  		if (defined($fidAnnotationHash->{$ftr})) {
  			$feature->{annotations} = $fidAnnotationHash->{$ftr};
  			for (my $j=0; $j < @{$feature->{annotations}}; $j++) {
  				$feature->{annotations}->[$j]->[2] = $feature->{annotations}->[$j]->[2]+0;
  			}
  		}	
  		if (defined($fidProteinSequences->{$ftr})) {
  			$feature->{protein_translation} = $fidProteinSequences->{$ftr};
  			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
  		}	
  		if ($ftr =~ m/(\w+)\.\d+$/) {
			$feature->{type} = $1;
		}	
  		push(@{$genomeObj->{features}},$feature);
  	}
  	if (!defined($genomeObj->{md5})) {
    	$genomeObj->{md5} = "";
    }
    $genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	return [$genomeObj,$ContigObj];
}

sub _get_genomeObj_from_SEED {
	my($self,$id) = @_;
	my $sapsvr = ModelSEED::Client::SAP->new();;
	my $data = $sapsvr->genome_data({
		-ids => [$id],
		-data => [qw(gc-content dna-size name taxonomy domain genetic-code)]
	});
	if (!defined($data->{$id})) {
    	$self->_error("PubSEED genome ".$id." not found!",'get_genomeobject');
    }
    my $genomeObj = {
		id => $self->_register_kb_id("kb|g",$id,"SEED"),
		scientific_name => $data->{$id}->[2],
		domain => $data->{$id}->[4],
		genetic_code => $data->{$id}->[5],
		dna_size => $data->{$id}->[1],
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "PubSEED",
		source_id => $id,
		taxonomy => $data->{$id}->[3],
		gc_content => $data->{$id}->[0]/100,
		complete => 1,
		publications => [],
		features => [],
    };
    my $contigset = {
		name => $genomeObj->{scientific_name},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
    };
	my $featureHash = $sapsvr->all_features({-ids => $id});
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
		$genomeObj->{num_contigs}++;
		push(@{$genomeObj->{contig_ids}},$key);
		push(@{$genomeObj->{contig_lengths}},length($contigHash->{$key}));
		push(@{$contigset->{contigs}},{
			id => $key,
			"length" => length($contigHash->{$key}),
			md5 => Digest::MD5::md5_hex($contigHash->{$key}),
			sequence => $contigHash->{$key},
			name => $key
		});
	}
	my $sortedcontigs = [sort { $a->{sequence} cmp $b->{sequence} } @{$contigset->{contigs}}];
	my $str = "";
	for (my $i=0; $i < @{$sortedcontigs}; $i++) {
		if (length($str) > 0) {
			$str .= ";";
		}
		$str .= $sortedcontigs->[$i]->{sequence};	
	}
	$genomeObj->{md5} = Digest::MD5::md5_hex($str);
	$contigset->{md5} = $genomeObj->{md5};
	$contigset->{id} = $self->_register_kb_id("kb|contigset",$contigset->{md5},"md5hash");
	for (my $i=0; $i < @{$featureList}; $i++) {
		my $feature = {
  			id => $featureList->[$i],
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => []
  		};
  		if ($featureList->[$i] =~ m/\.([^\.]+)\.\d+$/) {
  			$feature->{type} = $1;
  		}
		if (defined($functions->{$featureList->[$i]})) {
			$feature->{function} = $functions->{$featureList->[$i]};
		}
		if (defined($sequences->{$featureList->[$i]})) {
			$feature->{protein_translation} = $sequences->{$featureList->[$i]};
			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
		}
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
					$feature->{location}->[$j]->[1] = $feature->{location}->[$j]->[1]+0;
					$feature->{location}->[$j]->[3] = $feature->{location}->[$j]->[3]+0;
				}
			}
			
		}
  		push(@{$genomeObj->{features}},$feature);	
	}
	my $ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	return [$genomeObj,$ContigObj];
}

sub _get_genomeObj_from_RAST {
	my($self,$id,$username,$password) = @_;
	my $mssvr = $self->_mssServer();
	my $data = $mssvr->getRastGenomeData({
		genome => $id,
		username => $username,
		password => $password,
		getSequences => 1,
		getDNASequence => 1
	});
    if (!defined($data->{owner})) {
    	$self->_error("RAST genome ".$id." not found!",'get_genomeobject');
    }
	my $genomeObj = {
		id => $self->_register_kb_id("kb|g",$id,"RAST"),
		scientific_name => $data->{name},
		domain => $data->{taxonomy},
		genetic_code => 11,
		dna_size => $data->{size},
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "RAST",
		source_id => $id,
		taxonomy => $data->{taxonomy},
		gc_content => 0.5,
		complete => 1,
		publications => [],
		features => [],
    };
    my $contigset = {
		name => $genomeObj->{scientific_name},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
    };
    my $contighash = {};
	for (my $i=0; $i < @{$data->{features}}; $i++) {
		my $ftr = $data->{features}->[$i];
		my $feature = {
  			id => $ftr->{ID}->[0],
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => [],
			protein_translation_length => 0,
			protein_translation => "",
			dna_sequence_length => 0,
			md5 => ""
  		};
  		if ($ftr->{ID}->[0] =~ m/\.([^\.]+)\.\d+$/) {
  			$feature->{type} = $1;
  		}
  		if (defined($ftr->{SEQUENCE})) {
			$feature->{protein_translation} = $ftr->{SEQUENCE}->[0];
			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
		}
		if (defined($ftr->{ROLES})) {
			$feature->{function} = join(" / ",@{$ftr->{ROLES}});
		}
  		if (defined($ftr->{LOCATION}->[0]) && $ftr->{LOCATION}->[0] =~ m/^(.+)_(\d+)([\+\-_])(\d+)$/) {
			my $contigData = $1;
			if (!defined($contighash->{$contigData})) {
				$contighash->{$contigData} = $2;
			} elsif ($2 > $contighash->{$contigData}) {
				$contighash->{$contigData} = $2;
			}
			if ($3 eq "-" || $3 eq "+") {
				$feature->{location} = [[$contigData,$2,$3,$4]];
			} elsif ($2 > $4) {
				$feature->{location} = [[$contigData,$2,"-",($2-$4)]];
			} else {
				$feature->{location} = [[$contigData,$2,"+",($4-$2)]];
			}
			$feature->{location}->[0]->[1] = $feature->{location}->[0]->[1]+0;
			$feature->{location}->[0]->[3] = $feature->{location}->[0]->[3]+0;
		}
  		push(@{$genomeObj->{features}},$feature);
	}
	my $ContigObj;
	if (defined($data->{DNAsequence}->[0])) {
    	my $gccount = 0;
    	my $size = 0;
    	for (my $i=0; $i < @{$data->{DNAsequence}}; $i++) {
    		my $closest;
    		foreach my $key (keys(%{$contighash})) {
    			my $dist = abs(length($data->{DNAsequence}->[$i]) - $contighash->{$key});
    			my $closestdist = abs(length($data->{DNAsequence}->[$i]) - $contighash->{$closest});
    			if (!defined($closest) || $dist < $closestdist) {
    				$closest = $key;
    			}
    		}
    		push(@{$contigset->{contigs}},{
    			id => $closest,
				"length" => length($data->{DNAsequence}->[$i]),
				md5 => Digest::MD5::md5_hex($data->{DNAsequence}->[$i]),
				sequence => $data->{DNAsequence}->[$i],
				name => $closest
    		});
    		push(@{$genomeObj->{contig_lengths}},length($data->{DNAsequence}->[$i]));
    		$size += length($data->{DNAsequence}->[$i]);
    		push(@{$genomeObj->{contig_ids}},$closest);
			for ( my $j = 0 ; $j < length($data->{DNAsequence}->[$i]) ; $j++ ) {
				if ( substr( $data->{DNAsequence}->[$i], $j, 1 ) =~ m/[gcGC]/ ) {
					$gccount++;
				}
			}
    	}
    	if ($size > 0) {
			$genomeObj->{gc_content} = $$gccount/$size;
		}
		my $sortedcontigs = [sort { $a->{sequence} cmp $b->{sequence} } @{$contigset->{contigs}}];
		my $str = "";
		for (my $i=0; $i < @{$sortedcontigs}; $i++) {
			if (length($str) > 0) {
				$str .= ";";
			}
			$str .= $sortedcontigs->[$i]->{sequence};	
		}
		$genomeObj->{md5} = Digest::MD5::md5_hex($str);
		$contigset->{md5} = $genomeObj->{md5};
		$contigset->{id} = $self->_register_kb_id("kb|contigset",$contigset->{md5},"md5hash");
    	$ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
	}
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	return [$genomeObj,$ContigObj];
}

sub _validateargs {
	my ($self,$args,$mandatoryArguments,$optionalArguments,$substitutions) = @_;
	if (!defined($args)) {
	    $args = {};
	}
	if (ref($args) ne "HASH") {
		$self->_error("Arguments not hash",'_validateargs');
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
		$self->_error("Mandatory arguments ".join("; ",@{$args->{_error}})." missing.",'_validateargs');
	}
	if (defined($optionalArguments)) {
		foreach my $argument (keys(%{$optionalArguments})) {
			if (!defined($args->{$argument})) {
				$args->{$argument} = $optionalArguments->{$argument};
				
			}
		}
	}
	my $wshash = {};
	foreach my $argument (keys(%{$args})) {
		if (defined($args->{$argument}) && length($args->{$argument}) > 0) {
			if ($argument =~ m/_ws$/ || $argument =~ m/workspace$/) {
				$wshash->{$args->{$argument}} = 0;
			} elsif ($argument =~ m/workspaces/) {
				foreach my $ws (@{$args->{$argument}}) {
					$wshash->{$ws} = 0;
				}
			}
		}
	}
	if (keys(%{$wshash}) > 0) {
		my $output = $self->_workspace_list();
		foreach my $item (@{$output}) {
			if (defined($wshash->{$item->[0]})) {
				$wshash->{$item->[0]} = 1;
			} elsif (defined($wshash->{$item->[1]})) {
				$wshash->{$item->[1]} = 1;
			}
		}
		foreach my $ws (keys(%{$wshash})) {
			if ($wshash->{$ws} == 0) {
				$self->_error("Job specifies a workspace that does not exist or that user has no access to:".$ws);
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
		media_workspace => "KBaseMedia",
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
		prommodel_workspace => undef,
		regmodel => undef,
		regmodel_workspace => undef
	});
	return $fbaFormulation;
}

sub _buildFBAObject {
	my ($self,$fbaFormulation,$model) = @_;
	#Parsing media
	my $mediaobj = $self->_get_msobject("Media",$fbaFormulation->{media_workspace},$fbaFormulation->{media});
	#Building FBAFormulation object
	my $fbaobj = Bio::KBase::ObjectAPI::KBaseFBA::FBA->new({
		id => $self->_get_new_id($model->id().".fba."),
		fva => 0,
		fluxMinimization => 0,
		findMinimalMedia => 0,
		allReversible => $fbaFormulation->{allreversible},
		simpleThermoConstraints => $fbaFormulation->{simplethermoconst},
		thermodynamicConstraints => $fbaFormulation->{thermoconst},
		noErrorThermodynamicConstraints => $fbaFormulation->{nothermoerror},
		minimizeErrorThermodynamicConstraints => $fbaFormulation->{minthermoerror},
		maximizeObjective => $fbaFormulation->{maximizeObjective},
		compoundflux_objterms => {},
    	reactionflux_objterms => {},
		biomassflux_objterms => {},
		comboDeletions => 0,
		numberOfSolutions => 1,
		objectiveConstraintFraction => $fbaFormulation->{objfraction},
		defaultMaxFlux => $fbaFormulation->{defaultmaxflux},
		defaultMaxDrainFlux => $fbaFormulation->{defaultmaxuptake},
		defaultMinDrainFlux => $fbaFormulation->{defaultminuptake},
		decomposeReversibleFlux => 0,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 0,
		drainfluxUseVariables => 0,
		fbamodel_ref => $model->_reference(),
		media_ref => $mediaobj->_reference(),
		geneKO_refs => [],
		reactionKO_refs => [],
		additionalCpd_refs => [],
		uptakeLimits => {},
		parameters => {},
		inputfiles => {},
		FBAConstraints => [],
		FBAReactionBounds => [],
		FBACompoundBounds => [],
		outputfiles => {},
		FBACompoundVariables => [],
		FBAReactionVariables => [],
		FBABiomassVariables => [],
		FBAPromResults => [],
		FBADeletionResults => [],
		FBAMinimalMediaResults => [],
		FBAMetaboliteProductionResults => [],
	});
	$fbaobj->parent($self->_KBaseStore());
	if (defined($fbaFormulation->{prommodel}) && defined($fbaFormulation->{prommodel_workspace})) {
		my $promobj = $self->_get_msobject("PROMModel",$fbaFormulation->{prommodel_workspace},$fbaFormulation->{prommodel});
		if (defined($promobj)) {
			$fbaobj->prommodel_ref($promobj->_reference)
		}
	}
	if (defined($fbaFormulation->{regmodel}) && defined($fbaFormulation->{regmodel_workspace})) {
		my $regmodel = $self->_get_msobject("RegulatoryModel",$fbaFormulation->{regmodel_workspace},$fbaFormulation->{regmodel});
		if (defined($regmodel)) {
			$fbaobj->regmodel_ref($regmodel->_reference)
		}
	}
	#Parse objective equation
	foreach my $term (@{$fbaFormulation->{objectiveTerms}}) {
		if ($term->[1] eq "flux" || $term->[1] eq "reactionflux") {
			$term->[1] = "flux";
			my $obj = $model->searchForReaction($term->[2]);
			if (!defined($obj)) {
				$self->_error("Reaction ".$term->[2]." not found!");
			}
			$fbaobj->reactionflux_objterms()->{$obj->id()} = $term->[0]+1;
		} elsif ($term->[1] eq "compoundflux" || $term->[1] eq "drainflux") {
			$term->[1] = "drainflux";
			my $obj = $model->searchForCompound($term->[2]);
			if (!defined($obj)) {
				$self->_error("Compound ".$term->[2]." not found!");
			}
			$fbaobj->compoundflux_objterms()->{$obj->id()} = $term->[0]+1;
		} elsif ($term->[1] eq "biomassflux") {
			my $obj = $model->searchForBiomass($term->[2]);
			if (!defined($obj)) {
				$self->_error("Biomass ".$term->[2]." not found!");
			}
			$fbaobj->biomassflux_objterms()->{$obj->id()} = $term->[0]+1;
		} else {
			$self->_error("Objective variable type ".$term->[1]." not recognized!");
		}
	}
	#Parse constraints
	foreach my $constraint (@{$fbaFormulation->{constraints}}) {
		my $const = $fbaobj->add("FBAConstraints",{
			name => $constraint->[3],
			rhs => $constraint->[0],
			sign => $constraint->[1],
			compound_terms => {},
			reaction_terms => {},
			biomass_terms => {}
		});
		foreach my $term (@{$const->[2]}) {
			if ($term->[1] eq "flux" || $term->[1] eq "reactionflux") {
				$term->[1] = "flux";
				my $obj = $model->searchForReaction($term->[2]);
				if (!defined($obj)) {
					$self->_error("Reaction ".$term->[2]." not found!");
				}
				$const->reaction_terms()->{$obj->id()} = $term->[0];
			} elsif ($term->[1] eq "compoundflux" || $term->[1] eq "drainflux") {
				$term->[1] = "drainflux";
				my $obj = $model->searchForCompound($term->[2]);
				if (!defined($obj)) {
					$self->_error("Compound ".$term->[2]." not found!");
				}
				$const->compound_terms()->{$obj->id()} = $term->[0];
			} elsif ($term->[1] eq "biomassflux") {
				my $obj = $model->searchForBiomass($term->[2]);
				if (!defined($obj)) {
					$self->_error("Biomass ".$term->[2]." not found!");
				}
				$const->biomass_terms()->{$obj->id()} = $term->[0];
			} else {
				$self->_error("Constraint variable type ".$term->[1]." not recognized!");
			}
		}
	}
	#Parse bounds
	foreach my $term (@{$fbaFormulation->{bounds}}) {
		if ($term->[2] eq "flux" || $term->[2] eq "reactionflux") {
			$term->[2] = "flux";
			my $obj = $model->searchForReaction($term->[3]);
			if (!defined($obj)) {
				$self->_error("Reaction ".$term->[3]." not found!");
			}
			$fbaobj->add("fbaReactionBounds",{modelreaction_ref => $obj->_reference(),variableType=> $term->[2],upperBound => $term->[1],lowerBound => $term->[0]});
		} elsif ($term->[2] eq "compoundflux" || $term->[2] eq "drainflux") {
			$term->[2] = "flux";
			my $obj = $model->searchForCompound($term->[3]);
			if (!defined($obj)) {
				$self->_error("Compound ".$term->[3]." not found!");
			}
			$fbaobj->add("fbaCompoundBounds",{modelcompound_ref => $obj->_reference(),variableType=> $term->[2],upperBound => $term->[1],lowerBound => $term->[0]});
		} else {
			$self->_error("Objective variable type ".$term->[1]." not recognized!");
		}
	}
	#Parsing gene KO
	if (defined($model->genome_ref())) {
		my $genome = $model->genome();
		foreach my $gene (@{$fbaFormulation->{geneko}}) {
			my $geneObj = $genome->searchForFeature($gene);
			if (defined($geneObj)) {
				$fbaobj->addLinkArrayItem("geneKOs",$geneObj->_reference());
			}
		}
	}
	#Parsing reaction KO and blacklisted reactions
	foreach my $reaction (@{$fbaFormulation->{rxnko}}) {
		my $rxnObj = $model->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$fbaobj->addLinkArrayItem("reactionKOs",$rxnObj->_reference());
		}
	}
	#Parsing additional Cpds
	foreach my $compound (@{$fbaFormulation->{additionalcpds}}) {
		my $cpdObj = $model->searchForCompound($compound);
		if (defined($cpdObj)) {
			$fbaobj->addLinkArrayItem("additionalCpds",$cpdObj->_reference());
		}
	}
	return $fbaobj;
}

sub _setDefaultGapfillFormulation {
	my ($self,$formulation) = @_;
	if (!defined($formulation)) {
		$formulation = {};
	}
	$formulation = $self->_validateargs($formulation,[],{
		target_reactions => [],
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
			rxn01267 
		)],
		gauranteedrxns => [qw(
			rxn1 rxn2 rxn3 rxn4 rxn5 rxn6 rxn7 rxn8 rxn11572
			rxn07298 rxn24256 rxn04219 rxn17241 rxn19302 rxn25468 rxn23165
			rxn25469 rxn23171 rxn23067 rxn30830 rxn30910 rxn31440 rxn01659
			rxn13782 rxn13783 rxn13784 rxn05294 rxn05295 rxn05296 rxn10002
			rxn10088 rxn11921 rxn11922 rxn10200 rxn11923 rxn05029
		)],
		allowedcmps => []
	});
	$formulation->{formulation} = $self->_setDefaultFBAFormulation($formulation->{formulation});
	return $formulation;
}

sub _buildGapfillObject {
	my ($self,$formulation,$model,$gfid) = @_;
	if (!defined($gfid)) {
		$gfid = $self->_get_new_id($model->id().".gf.");
	}
	my $fba = $self->_buildFBAObject($formulation->{formulation},$model);
	my $gapform = Bio::KBase::ObjectAPI::KBaseFBA::Gapfilling->new({
		id => $gfid,
    	fba_ref => "",
    	media_ref => $fba->media()->_reference(),
    	fbamodel_ref => $model->_reference(),
    	guaranteedReaction_refs => [],
		blacklistedReaction_refs => [],
		allowableCompartment_refs => [],    
		mediaHypothesis => $self->_invert_boolean($formulation->{nomediahyp}),
		balancedReactionsOnly => $self->_invert_boolean($formulation->{allowunbalanced}),
		reactionAdditionHypothesis => $self->_invert_boolean($formulation->{nopathwayhyp}),
		gprHypothesis => $self->_invert_boolean($formulation->{nogprhyp}),
		#biomassHypothesis => $self->_invert_boolean($formulation->{nobiomasshyp}),
		biomassHypothesis => 0,
		completeGapfill => $formulation->{completeGapfill},
		reactionActivationBonus => $formulation->{activitybonus},
		drainFluxMultiplier => $formulation->{drainpen},
		directionalityMultiplier => $formulation->{directionpen},
		deltaGMultiplier => $formulation->{unfavorablepen},
		noStructureMultiplier => $formulation->{nostructpen},
		noDeltaGMultiplier => $formulation->{nodeltagpen},
		biomassTransporterMultiplier => $formulation->{biomasstranspen},
		singleTransporterMultiplier => $formulation->{singletranspen},
		transporterMultiplier => $formulation->{transpen},
		timePerSolution => $formulation->{timePerSolution},
		totalTimeLimit => $formulation->{totalTimeLimit},
		reactionMultipliers => {},
		gapfillingSolutions => []
	});
	$gapform->fba($fba);
	$gapform->parent($self->_KBaseStore());
	foreach my $reaction (@{$formulation->{targeted_reactions}}) {
		my $rxnObj = $model->template()->biochemistry()->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$gapform->addLinkArrayItem("targetedreactions",$rxnObj);
		}
	}
	foreach my $reaction (@{$formulation->{gauranteedrxns}}) {
		my $rxnObj = $model->template()->biochemistry()->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$gapform->addLinkArrayItem("guaranteedReactions",$rxnObj);
		}
	}
	foreach my $reaction (@{$formulation->{blacklistedrxns}}) {
		my $rxnObj = $model->template()->biochemistry()->searchForReaction($reaction);
		if (defined($rxnObj)) {
		    # This one is no longer necessary for gapfill itself but I don't know if it's used elsewhere or not.
			$gapform->addLinkArrayItem("blacklistedReactions",$rxnObj);
			$gapform->fba()->addLinkArrayItem("reactionKOs",$rxnObj);
		}
	}
	my $mdlcmps = $model->modelcompartments();
	foreach my $mdlcmp (@{$mdlcmps}) {
		$gapform->addLinkArrayItem("allowableCompartments",$mdlcmp->compartment());
	}
	$gapform->prepareFBAFormulation();
	$gapform->fba()->numberOfSolutions($formulation->{num_solutions});
	#Handling the probabilistic annotation
	my $probRXNWS = $formulation->{probabilisticAnnotation_workspace};
	if (defined($formulation->{probabilisticAnnotation})) {
		my $probanno = $self->_get_msobject("ProbAnno",$formulation->{probabilisticAnnotation_workspace},$formulation->{probabilisticAnnotation});
		if (!defined($probanno)) {
			$self->_error("Invalid probabilistic annotation object!","_buildGapfillObject");
		}
		# Calculate the reaction probabilities from the probabilistic annotation.
		# The output RxnProbs object is saved by reference via the "NO_WORKSPACE" workspace.
		# TODO Do we need to specify a model template here?
		my $rpmeta = $self->_probanno()->calculate( { 
			probanno => $formulation->{probabilisticAnnotation},
			probanno_workspace => $formulation->{probabilisticAnnotation_workspace},
			rxnprobs => $formulation->{probabilisticAnnotation},
			rxnprobs_workspace => $formulation->{probabilisticAnnotation_workspace},
			auth => $self->_authentication()
		});
		$formulation->{probabilisticReactions} = $rpmeta->[8];
		$probRXNWS = $formulation->{probabilisticAnnotation_workspace};
		
	}
	$formulation->{probabilisticReaction_workspace} = $probRXNWS;
	if (defined($formulation->{probabilisticReactions})) {
		# Get the RxnProbs object from the workspace.
		my $rxnprobs = $self->_get_msobject("RxnProbs",$probRXNWS,$formulation->{probabilisticReactions});
		#Get coefficients of probmodel
		$gapform->fba()->parameters()->{"Objective coefficient file"} = "ProbModelReactionCoefficients.txt";
		$gapform->fba()->inputfiles()->{"ProbModelReactionCoefficients.txt"} = [];
		my $rxns = $rxnprobs->reaction_probabilities();
		for (my $i=0; $i < @{$rxns}; $i++) {
			my $rxn = $rxns->[$i];
			my $cost = (1-$rxn->[1]);
			push(@{$gapform->fba()->inputfiles()->{"ProbModelReactionCoefficients.txt"}},"forward\t".$rxn->[0]."\t".$cost);
			push(@{$gapform->fba()->inputfiles()->{"ProbModelReactionCoefficients.txt"}},"reverse\t".$rxn->[0]."\t".$cost);
		}	
	}
	return ($gapform,$fba);
}

# Build the three-level GPR array for all reactions in a RxnProbs object.

sub _buildRxnProbsGPRArray {
    my ($self, $rxnprobs) = @_;
    my($rxnprobsGPRArray);
    for(my $i=0; $i < @{$rxnprobs->reaction_probabilities()}; $i++) {
	my $rxnarray = $rxnprobs->reaction_probabilities()->[$i];
	my $rxnid = $rxnarray->[0];
	my $gpr = $rxnarray->[4];
	if ( $gpr ne "" ) {
#	    $rxnprobsGPRArray->{$rxnid} = Bio::KBase::ObjectAPI::utilities::translateGPRHash(Bio::KBase::ObjectAPI::utilities::parseGPR($gpr));
	    $rxnprobsGPRArray->{$rxnid} = $gpr;
	}
    }
    return $rxnprobsGPRArray;
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
			$self->_error("Media object ".$formulation->{refmedia}." not found in biochemistry!",'_buildFBAObject');
		}
		$media = $mediaobj->uuid();
	}
	my $fbaid = Data::UUID->new()->create_str();
	my $gapform = Bio::KBase::ObjectAPI::KBaseFBA::Gapgeneration->new({
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
	$id =~ s/(kb\|[a-zA-Z]+)(\d+)$/$1.$2/;
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
		if (defined($gene) && ref($gene) eq "Bio::KBase::ObjectAPI::KBaseGenomes::Feature") {
			push(@{$kos},$gene->id());
		}
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

=head3 _was_reaction_gapfilled

Definition:
    Bool = _was_reaction_gapfilled(ModelSEED::MS::ModelReaction)

Description:
    Returns 1 if the ModelReaction was a gapfilled reaction.
    Returns 0 for any reaction originally in the model (even if the reversibility was changed by gapfill)

=cut

sub _was_reaction_gapfilled {
    my ($self, $modelrxn) = @_;
    my $proteins = $modelrxn->modelReactionProteins();
    my $gapfilled = 0;
    if (@{$proteins} == 0) {
	$gapfilled = 1;
    } elsif ( @{$proteins} >= 1 ) {
	my $ok = 1;
	foreach ( my $j=0; $j<@{$proteins}; $j++ ) {
	    if ( $proteins->[$j]->complex_ref() ne "00000000-0000-0000-0000-000000000000" || $proteins->[$j]->note() eq "spontaneous" || $proteins->[$j]->note() eq "universal" ) {
		$ok = 0;
		last;
	    }
	}
	if ( $ok == 1 ) {
	    $gapfilled = 1;
	}
    }   
}

# Get an array if (rxnid, direction) pairs from the third element of a line in ProblemReport.txt
sub _parse_problem_report_solution {
    my ($self, $str) = @_;
    my $matches = [];
    @$matches = ( $str =~ /([+-]rxn\d+)/g );
    my $outarr = [];
    for( my $i=0; $i<@{$matches}; $i++ ) {
	my $subarr = [];
	if ( $matches->[$i] =~ /\+/ ) {
	    ( $subarr->[0] = $matches->[$i] ) =~ s/\+//;
	    $subarr->[1] = ">";
	} else {
	    ( $subarr->[0] = $matches->[$i] ) =~ s/-//;
	    $subarr->[1] = "<";
	}
	push(@$outarr, $subarr);
    }
    return $outarr;
}

# Parse a gapfill solution ID into (gapfill UUID, solution number)
sub _parse_gapfillsolution_id {
    my ($self, $solution_id) = @_;
    my($gfid, $solid);
    # Handle gapfill solution. Get all the reactions modified by the specified gapfill solution.
    if ($solution_id =~ m/(.+)\.gfsol\.(.+)/) {
	$gfid = $1;
	$solid = $2;
    } else { 
	$self->_error("Specified gapfill solution ID did not have expected format GAPFILLID.gfsol.NUMBER", "_get_gapfill_solution");
    }
    my $result = [];
    $result->[0] = $gfid;
    $result->[1] = $solid;
    return $result;
}

# Get a MS::GapfillSolution object given its ID
sub _get_gapfill_solution{
    my ($self, $solution_id, $gapfill_ws) = @_;
    my $parsedsolution = $self->_parse_gapfillsolution_id($solution_id);
    my $gfid = $parsedsolution->[0];
    my $solid = $parsedsolution->[1];
    my $gapfill = $self->_get_msobject("Gapfilling", $gapfill_ws, $gfid);
    my $gapfillSolutions = $gapfill->gapfillingSolutions();
    if ( ! defined($gapfillSolutions) ) { 
	$self->_error("Unable to find gapfill solution $solution_id", "_get_gapfill_solution");  
    }
    if ( @{$gapfillSolutions} <= $solid ) { 
	$self->_error("Solution number $solid specified but there are fewer than that in the specified gapfill object (note that the solution numbers start at 0)", "_get_gapfill_solution"); 
    }
    my $desiredSolution = $gapfillSolutions->[$solid];
    return $desiredSolution;
}

=head3 get_gapfill_solution_reactions

Definition:
    Array_ref = _get_gapfill_solution_reactions(Gapfill_solution_id, Gapfill_workspace, ModelSEED::MS::Model)

Description:
    Get a GapFill object associated with a solution ID.
    Returns an array ref contianing the ModelSEED IDs for each reaction.
    Ignores reations that are not in the model and only adds each reaction once...
    Also ignored reactions that were added as reversibility changes.

Example:

    Array_ref = _get_gapfill_solution_reactions(GAPFILL_REF.gfsol.0)

=cut

sub _get_gapfill_solution_reactions {
    my ( $self, $solution_id, $gapfill_ws, $model ) = @_;
    my($gfid, $solid);

    # Get a hash of the reactions in the model (was the reaction deleted after gapfill?)
    # Also get a hash of all reactions ADDED by the combination of integrated gapfill solutions.
    # This potentially is wrong if there are multiple integrated gapfill solutions that weren't done sequentially.
    # We could use a more robust way of storing whether or not a reaction was a reversibility change due to gapfill.
    my $model_rxnids = {};
    my $gapfilled_rxnids = {};
    my $modelrxns = $model->modelreactions();
    for ( my $i=0; $i < @{$modelrxns}; $i++ ) {
	my $dir = $modelrxns->[$i]->direction;
	if ( $dir eq "=" ) {
	    $model_rxnids->{ "+".$modelrxns->[$i]->reaction()->id } = 1;
	    $model_rxnids->{ "-".$modelrxns->[$i]->reaction()->id } = 1;
	} elsif ( $dir eq ">" ) {
	    $model_rxnids->{ "+".$modelrxns->[$i]->reaction()->id } = 1;
	} elsif ( $dir eq "<" ) {
	    $model_rxnids->{ "-".$modelrxns->[$i]->reaction()->id } = 1;
	}
    }

    my $desiredSolution = $self->_get_gapfill_solution($solution_id, $gapfill_ws);
    my $solutionReactions = $desiredSolution->gapfillingSolutionReactions();

    # Get the desired list of reactions.
    my $rxnids = [];
    my $directions = [];
    my $seenrxns = {};
    for ( my $i=0; $i < @{$solutionReactions}; $i++ ) {
	my $id = $solutionReactions->[$i]->reaction()->id;
	my $modelDirection = $solutionReactions->[$i]->direction;
	my ($dirstring);
	if ( $modelDirection eq ">" ) {
	    $dirstring = "+";
	} elsif ( $modelDirection eq "<" ) {
	    $dirstring = "-";
	} else {
	    self->_error("ERROR: Direction for gapfill solution reaction was not < or > (this should never happen)", "_get_gapfill_solution_reactions");
	}
	$id = $dirstring.$id;

	# Is this reaction in the original model?
	if ( ! defined($model_rxnids->{$id} ) ) {
	    next;
	}
	# Duplicates happen in the iterative gapfill solutions. We don't want them, and if it appeared both earlier and later then it is useful for a high-priority gapfill
	# so we want to test it later.
	if ( defined($seenrxns->{$id}) ) {
	    next;
	}
	$seenrxns->{$id} = 1;
	push(@{$rxnids}, $id);
    }
    # Reverse order - lower-priority gapfill solutions are tested for removal first.
    @{$rxnids} = reverse(@{$rxnids});

    return $rxnids;
    
}

=head3 _sort_gapfill_solution_reactions

Definition:
    Array_ref = _sort_gapfill_solution_reactions(Array_ref, RxnProbs_id, RxnProbs_ws)

Description:
    (Stably) sort the reaction list by probability.
    Returns the sorted list of reactions

=cut

sub _sort_gapfill_solution_reactions {
    my ($self, $rxnlist, $rxnprobs_id, $rxnprobs_workspace) = @_;
    my $rxnprobdict = {};
    # Build up the rxnprobs dictionary...
    my $RxnProbs = $self->_get_msobject("RxnProbs", $rxnprobs_workspace, $rxnprobs_id);
    for(my $i=0; $i<@{$RxnProbs->reaction_probabilities()}; $i++) {
		my $rxnarray = $RxnProbs->reaction_probabilities()->[$i];
        my $rxnid = $rxnarray->[0];
		my $likelihood = $rxnarray->[1];
		$rxnprobdict->{"+".$rxnid} = $likelihood;
		$rxnprobdict->{"-".$rxnid} = $likelihood;
    }

    # Build an array of (reaction, likelihood) sets
    my $unsorted = [];
    for(my $i=0; $i<@{$rxnlist}; $i++) {
	my $singlearray = [];
	if ( defined($rxnprobdict->{$rxnlist->[$i]}) ) {
	    $singlearray = [ $rxnlist->[$i], $rxnprobdict->{$rxnlist->[$i]} ];
	} else {
	    $singlearray = [ $rxnlist->[$i], 0 ];
	}
	push(@$unsorted, [ @$singlearray ]);
    }

    my $sorted = [];
    @$sorted = map { $_->[0] } sort { $a->[1] cmp $b->[1] } @$unsorted;

    return $sorted;
}


sub _generate_gapmeta {
	my ($self,$obj) = @_;
	my $idarray = [split(/\//,$obj->uuid())];
	my $done = 0;
	if ($obj->_type() eq "Gapfilling" && defined($obj->gapfillingSolutions())) {
		$done = 1;
	} elsif ($obj->_type() eq "Gapgeneration" && defined($obj->gapgenSolutions())) {
		$done = 1;
	}
	my $kos = [];
	foreach my $gene ($obj->fba()->geneKOs()) {
		if (defined($gene) && ref($gene) eq "Bio::KBase::ObjectAPI::KBaseGenomes::Feature") {
			push(@{$kos},$gene->id());
		}
	}
	return [
		$obj->id(),
		$obj->_reference(),
		$obj->fba()->media()->name(),
		$obj->fba()->media_ref(),
		$done,
		$kos
	];
}

sub _FBA_to_FBAFormulation {
	my ($self,$obj) = @_;
	my $media;
	my $media_workspace;
	if ($obj->media_ref() =~ m/^(.+)\/(.+)/) {
		$media_workspace = $1;
		$media = $2;
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
	foreach my $const (@{$obj->FBAConstraints()}) {
		my $terms = [];
		foreach my $term (@{$const->FBAConstraintVariables()}) {
			push(@{$terms},[$term->coefficient(),$term->variableType(),$term->entity()->id()]);
		}
		push(@{$form->{constraints}},[$const->rhs(),$const->sign(),$terms,$const->name()]);
	}
	foreach my $bound (@{$obj->FBAReactionBounds()}) {
		push(@{$form->{bounds}},[$bound->lowerBound(),$bound->upperBound(),$bound->variableType(),$bound->modelreaction()->id()]);
	}
	foreach my $bound (@{$obj->FBACompoundBounds()}) {
		push(@{$form->{bounds}},[$bound->lowerBound(),$bound->upperBound(),$bound->variableType(),$bound->modelcompound()->id()]);
	}
	foreach my $term (keys(%{$obj->compoundflux_objterms()})) {
		push(@{$form->{objectiveTerms}},[$obj->compoundflux_objterms()->{$term},"drainflux",$term]);
	}
	foreach my $term (keys(%{$obj->reactionflux_objterms()})) {
		push(@{$form->{objectiveTerms}},[$obj->reactionflux_objterms()->{$term},"flux",$term]);
	}
	foreach my $term (keys(%{$obj->biomassflux_objterms()})) {
		push(@{$form->{objectiveTerms}},[$obj->biomassflux_objterms()->{$term},"flux",$term]);
	}
	return $form;
}

sub _FBA_to_FBAdata {
	my ($self,$obj) = @_;
	my $array = [split(/\//,$obj->uuid())];
	my $mdlarray = [split(/\//,$obj->fbamodel()->uuid())];
	my $fbadata = {
    	id => $obj->id(),
    	fbaref => $obj->_reference(),
    	modelref => $obj->fbamodel_ref(),
    	isComplete => 0,
    	objective => undef,
    	formulation => $self->_FBA_to_FBAFormulation($obj),
    	minimalMediaPredictions => [],
		metaboliteProductions => [],
		reactionFluxes => [],
		compoundFluxes => [],
		geneAssertions => []
	};
    if (defined($obj->objectiveValue())) {
		$fbadata->{isComplete} = 1;
		$fbadata->{objective} = $obj->objectiveValue();
		foreach my $var (@{$obj->FBACompoundVariables()}) {
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
		foreach my $var (@{$obj->FBAReactionVariables()}) {
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
		foreach my $var (@{$obj->FBABiomassVariables()}) {
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
		foreach my $var (@{$obj->FBADeletionResults()}) {
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
		foreach my $var (@{$obj->FBAMetaboliteProductionResults()}) {
			push(@{$fbadata->{metaboliteProductions}},[
				$var->maximumProduction(),
				$var->modelcompound()->id(),
				$var->modelcompound()->name()
			]);
		}
		foreach my $minmedia (@{$obj->FBAMinimalMediaResults()}) {
			my $data = {
				optionalNutrients => [],
				essentialNutrients => []
			};
			foreach my $cpd (@{$minmedia->essentialNutrients()}) {
				push(@{$data->{essentialNutrients}},$cpd->id())
			}
			foreach my $cpd (@{$minmedia->optionalNutrients()}) {
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
		formulation => $self->_FBA_to_FBAFormulation($obj->fba()),
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
		probabilisticAnnotation => undef,
		probabilisticReactions => undef
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
	my $array = [split(/\//,$obj->_reference())];
	my $mdlarray = [split(/\//,$obj->fbamodel()->_reference())];
	my $data = {
    	id => $obj->_wsname(),
    	workspace => $obj->_wsworkspace(),
    	model => $obj->fbamodel()->_wsname(),
    	model_workspace => $obj->fbamodel()->_wsworkspace(),
    	isComplete => 0,
    	formulation => $self->_GapFill_to_GapFillFormulation($obj),
    	solutions => []
	};
	my $solutions = $obj->gapfillingSolutions();
    if (defined($solutions->[0])) {
		$data->{isComplete} = 1;
		for (my $i=0; $i < @{$solutions}; $i++) {
			my $solution = $solutions->[$i];
			my $solData = {
				id => $array->[1].".solution.".$i,
				objective => $solution->{solutionCost},
				biomassRemovals => [],
				mediaAdditions => [],
				reactionAdditions => [],
			};
			for (my $j=0; $j < @{$solution->biomassRemovals()}; $j++) {
				push(@{$solData->{biomassRemovals}},[
					$solution->biomassRemovals()->[$j]->id(),
					$solution->biomassRemovals()->[$j]->name()
				]);
			}
			for (my $j=0; $j < @{$solution->mediaSupplements()}; $j++) {
				push(@{$solData->{mediaAdditions}},[
					$solution->mediaSupplements()->[$j]->id(),
					$solution->mediaSupplements()->[$j]->name()
				]);
			}
			for (my $j=0; $j < @{$solution->gapfillingSolutionReactions()}; $j++) {
				push(@{$solData->{reactionAdditions}},[
					$solution->gapfillingSolutionReactions()->[$j]->reaction()->id(),
					$solution->gapfillingSolutionReactions()->[$j]->reaction()->direction(),
					"c",
					$solution->gapfillingSolutionReactions()->[$j]->reaction()->equation(),
					$solution->gapfillingSolutionReactions()->[$j]->reaction()->definition()
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
    my $solutions = $obj->gapgenSolutions();
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



=head3 _queueJob

Definition:
	{} JobObject = $self->_queueJob({
	 	type => string,
	 	jobdata => {},
	 	queuecommand => string,
	 	state => state
	 });
Description:
	Queues job in workspace
		
=cut

sub _queueJob {
	my($self,$args) = @_;
	my $input = {
		type => $args->{type},
		jobdata => $args->{jobdata},
		queuecommand => $args->{queuecommand},
		"state" => $args->{"state"},
		auth => $self->_authentication(),
	};
	if (!defined($args->{jobdata}->{wsurl})) {
		$args->{jobdata}->{wsurl} = $self->_workspaceURL();
	}
	return $self->_jobserv()->queue_job($input);
}

=head3 _defaultJobState

Definition:
	 = $self->_defaultJobState();
Description:
	Returns the default job state for this service
		
=cut

sub _defaultJobState {
	my($self) = @_;
	return $self->{_defaultJobState};
}

=head3 _getJob

Definition:
	{} JobObject = $self->_getJob(string id);
Description:
	Returns the specified job object
		
=cut

sub _getJob {
	my($self,$id) = @_;
	my $jobs = $self->_jobserv()->get_jobs({
		jobids => [$id],
		auth => $self->_authentication()
	});
	return $jobs->[0];
}

=head3 _error

Definition:
	$self->_error(string message,string method);
Description:
	Throws an exception
		
=cut

sub _error {
	my($self,$msg) = @_;
	$msg = "_ERROR_".$msg."_ERROR_";
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => $self->_KBaseStore()->provenance()->[0]->{method});
}

=head3 _build_sequence_object

Definition:
	{} object meta = $self->_build_sequence_object(string type,{} params);
Description:
	Builds a sequence type object and loads it into the workspace
		
=cut
sub _build_sequence_object {
	my($self,$type,$params) = @_;
	my $subprefix = "prot";
	my $prefix = "kb|protset";
	my $fieldname = "proteins";
	if ($type eq "ContigSet") {
		$subprefix = "contig";
		$fieldname = "contigs";
		$prefix = "kb|contigset";
	}
	my $object = {
		id => undef,
		name => $params->{name},
		source_id => $params->{sourceid},
		source => $params->{source},
		type => $params->{type},
		$fieldname => []
	};
	$params->{fasta} =~ s/\>(.+)\n/>$1\|\|\|/g;
	$params->{fasta} =~ s/\n//g;
	my $array = [split(/\>/,$params->{fasta})];
	for (my $i=0; $i < @{$array}; $i++) {
		if (length($array->[$i]) > 0) {
			my $subarray = [split(/\|\|\|/,$array->[$i])];
			if (@{$subarray} == 2) {
			    # This isn't strictly a standard but it gets it right when you download from RAST or the SEED at least (and probably genbank too)).
			    my $description = "unknown";
			    if( $subarray->[0] =~ /.*?\s(.+)/ ) {
					$description = $1;
			    }
			    my $contigobject = {
					id => $subarray->[0],
					name => $subarray->[0],
					"length" => length($subarray->[1]),
					md5 => Digest::MD5::md5_hex($subarray->[1]),
					sequence => $subarray->[1],
					description => $description
				};
				if ($fieldname eq "proteins") {
					$contigobject->{protein_families} = [];
					$contigobject->{aliases} = [];
					$contigobject->{annotations} = [];
					$contigobject->{function} = $description;
				} else {
					$contigobject->{name} = $subarray->[0];
					$contigobject->{description} = $description;
				}
				push(@{$object->{$fieldname}},$contigobject);
 			}
		}
	}
	$object->{$fieldname} = [sort { $a->{sequence} <=> $b->{sequence} } @{$object->{$fieldname}}];
	my $str = "";
	for (my $i=0; $i < @{$object->{$fieldname}}; $i++) {
		if (length($str) > 0) {
			$str .= ";";
		}
		$str .= $object->{$fieldname}->[$i]->{sequence};
	}
	$object->{md5} = Digest::MD5::md5_hex($str);
	$object->{id} = $self->_register_kb_id($prefix,$object->{md5},"md5hash");
	if (!defined($object->{source_id})) {
		$object->{source_id} = $object->{id};
		$object->{source} = "KBase";
	}
	if (!defined($params->{uid})) {
		$params->{uid} = $object->{id};
	}
	if (!defined($object->{name})) {
		$object->{name} = $object->{id};
	}
	my $class = "Bio::KBase::ObjectAPI::KBaseGenomes::".$type;
	$object = $class->new($object);
	$object->parent($self->_KBaseStore());
	return $self->_save_msobject($object,$type,$params->{workspace},$params->{uid});	
}

=head3 _register_kb_id

Definition:
	string kbid = $self->_register_kb_id(string prefix,string extid,string extidtype);
Description:
	Registers and returns a kbase ID
		
=cut
sub _register_kb_id {
	my($self,$prefix,$extid,$extidtype) = @_;
	my $output = $self->_idServer()->register_ids($prefix,$extidtype,[$extid]);
	return $output->{$extid};
}

=head3 _assess_confidence

Definition:
	0/1 = $self->_assess_confidence(string type,float threshold,float confidence);
Description:
	Returns 1 if the confidence is sufficient, 0 otherwise
		
=cut
sub _assess_confidence {
	my($self,$type,$thresh,$conf) = @_;
	if ($thresh == 0) {
		return 1;	
	}
	if ($type eq "blast" || $type eq "blat") {
		if ($conf < $thresh) {
			return 1;
		}
		return 0;
	}
	if ($conf > $thresh) {
		return 1;
	}
	return 0;
}

=head3 _buildGenomeFromFunctions

Definition:
	Bio::KBase::ObjectAPI::KBaseGenomes::Genome = $self->_buildGenomeFromFunctions();
Description:
	Returns 1 if the confidence is sufficient, 0 otherwise
		
=cut
sub _buildGenomeFromFunctions {
	my($self,$id,$functions,$name) = @_;
	my $genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new({
		id => $id,
		scientific_name => $name,
		domain => "Bacteria",
		genetic_code => 11,
		dna_size => 0,
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "KBase",
		source_id => $id,
		md5 => "",
		taxonomy => "Bacteria",
		gc_content => 0,
		complete => 0,
		publications => [],
		features => [],
    });
    my $count = 0;
    foreach my $function (keys(%{$functions})) {
    	$count++;
    	$genomeObj->add("features",{
    		id => $id.".peg.".$count,
			function => $function,
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => [],
			location => []
  		});
    }
	return $genomeObj;
}

=head3 _genome_to_model

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel = $self->_genome_to_model(Bio::KBase::ObjectAPI::KBaseGenomes::Genome);
Description:
	Builds model from genome
		
=cut
sub _genome_to_model {
	my($self,$genome,$mdlid,$params) = @_;
    #Retrieving template model
    my $template;
    if (defined($params->{templatemodel})) {
    	$template = $self->_get_msobject("ModelTemplate",$params->{templatemodel_workspace},$params->{templatemodel});
    } elsif ($params->{coremodel} == 1) {
    	$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","CoreModelTemplate");
    } elsif ($genome->domain() eq "Plant") {
    	$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","PlantModelTemplate");
	} else {
		my $class = $self->_classify_genome($genome);
		if ($class eq "Gram positive") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramPosModelTemplate");
    	} elsif ($class eq "Gram negative") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramNegModelTemplate");
    	} elsif ($class eq "Plant") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","PlantModelTemplate");
    	}
    }
    if (!defined($template)) {
    	$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramPosModelTemplate");
    }
    #Building the model
    my $mdl = $template->buildModel({
	    genome => $genome,
	    modelid => $mdlid
	});
	return $mdl;
}

=head3 _annotate_genome

Definition:
	Genome = $self->_annotate_genome(Genome genome,AnnotationParameters parameters);
Description:
	Returns genome with annotated genes
		
=cut
sub _annotate_genome {
	my($self,$genome,$parameters) = @_;
	$parameters = $self->_validateargs($parameters,[],{
		call_genes => 0,
		annotate_genes => 1,
	});
	my $gaserv = $self->_gaserv();
	my $genomeTO = $genome->genome_typed_object();
	if ($parameters->{call_genes} == 1 && @{$genomeTO->{contigs}} > 0) {
		$genomeTO = $gaserv->annotate_genome($genomeTO);
	} elsif ($parameters->{annotate_genes} == 1) {
		$genomeTO = $gaserv->annotate_proteins($genomeTO);
	}
	foreach my $gene (@{$genomeTO->{features}}) {
		my $feature = $genome->getObject("features",$gene->{id});
		if (!defined($feature)) {
			$genome->add("features",{
				id => $gene->{id},
				function => $gene->{function},
				type => $gene->{type},
				protein_translation => $gene->{protein_translation},
				protein_translation_length => length($gene->{protein_translation}),
  				dna_sequence_length => 3*$gene->{protein_translation_length},
  				md5 => Digest::MD5::md5_hex($gene->{protein_translation}),
				location => $gene->{location},
				publications => [],
				subsystems => [],
				protein_families => [],
				aliases => [],
				annotations => [],
				subsystem_data => [],
				regulon_data => [],
				atomic_regulons => [],
				coexpressed_fids => [],
				co_occurring_fids => [],
			});
		} else {
			$feature->id($gene->{id});
			$feature->function($gene->{function});
			$feature->type($gene->{type});
			$feature->protein_translation($gene->{protein_translation}),
			$feature->protein_translation_length(length($gene->{protein_translation}));
  			$feature->dna_sequence_length = 3*$gene->{protein_translation_length};
  			$feature->md5(Digest::MD5::md5_hex($gene->{protein_translation}));
			$feature->location($gene->{location});
		}
	}
	return $genome;
}

=head3 _classify_genome

Definition:
	Genome = $self->_classify_genome(Genome genome);
Description:
	Returns the cell wall classification for genome
		
=cut
sub _classify_genome {
	my($self,$genome) = @_;
	if (!defined($self->{_classifierdata})) {
	    my ($fh1, $classifierFile) = File::Temp::tempfile();
	    close($fh1);
	    my $status = LWP::Simple::getstore("http://bioseed.mcs.anl.gov/~chenry/ModelSEED/classifier.txt", $classifierFile);
	    $self->_error("Unable to fetch cell wall classifier data!") unless($status == 200);
		my $data = Bio::KBase::ObjectAPI::utilities::LOADFILE($classifierFile);
		my $headings = [split(/\t/,$data->[0])];
		my $popprob = [split(/\t/,$data->[1])];
		for (my $i=1; $i < @{$headings}; $i++) {
			$self->{_classifierdata}->{classifierClassifications}->{$headings->[$i]} = {
				name => $headings->[$i],
				populationProbability => $popprob->[$i]
			};
		}
		my $cfRoleHash = {};
		for (my $i=2;$i < @{$data}; $i++) {
			my $row = [split(/\t/,$data->[$i])];
			my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($row->[0]);
			$self->{_classifierdata}->{classifierRoles}->{$searchrole} = {
				classificationProbabilities => {},
				role => $row->[0]
			};
			for (my $j=1; $j < @{$headings}; $j++) {
				$self->{_classifierdata}->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$headings->[$j]} = $row->[$j];
			}
		}
	}
	my $scores = {};
	my $sum = 0;
	foreach my $class (keys(%{$self->{_classifierdata}->{classifierClassifications}})) {
		$scores->{$class} = 0;
		$sum += $self->{_classifierdata}->{classifierClassifications}->{$class}->{populationProbability};
	}
	my $features = $genome->features();
	for (my $i=0; $i < @{$features}; $i++) {
		my $feature = $features->[$i];
		my $roles = $feature->roles();
		foreach my $role (@{$roles}) {
			my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($role);
			if (defined($self->{_classifierdata}->{classifierRoles}->{$searchrole})) {
				foreach my $class (keys(%{$self->{_classifierdata}->{classifierClassifications}})) {
					$scores->{$class} += $self->{_classifierdata}->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$class};
				}
			}
		}
	}
	my $largest;
	my $largestClass;
	foreach my $class (keys(%{$self->{_classifierdata}->{classifierClassifications}})) {
		$scores->{$class} += log($self->{_classifierdata}->{classifierClassifications}->{$class}->{populationProbability}/$sum);
		if (!defined($largest)) {
			$largest = $scores->{$class};
			$largestClass = $class;
		} elsif ($largest > $scores->{$class}) {
			$largest = $scores->{$class};
			$largestClass = $class;
		}
	}
	return $largestClass;
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
	
    my $params;
    $self->{_defaultJobState} = "queued";
    $self->{_accounttype} = "kbase";
    $self->{'_fba-url'} = "";
    Bio::KBase::ObjectAPI::utilities::ID_SERVER_URL("http://kbase.us/services/idserver");
    $self->{'_jobserver-url'} = "http://kbase.us/services/workspace";
    $self->{'_gaserver-url'} = "http://kbase.us/services/genome_annotation";
    $self->{'_mssserver-url'} = "http://bio-data-1.mcs.anl.gov/services/ms_fba";
    $self->{"_probanno-url"} = "http://localhost:7073";
    $self->{"_workspace-url"} = "http://kbase.us/services/ws";
    my $paramlist = [qw(fbajobcache gaserver-url jobserver-url fbajobdir mfatoolkitbin fba-url probanno-url mssserver-url accounttype workspace-url defaultJobState idserver-url)];

    # so it looks like params is created by looping over the config object
    # if deployment.cfg exists

    # the keys in the params hash are the same as in the config obuject 
    # except the block name from the config file is ommitted.

    # the block name is picked up from KB_SERVICE_NAME. this has to be set
    # in the start_service script as an environment variable.

    # looping over a set of predefined set of parameter keys, see if there
    # is a value for that key in the config object
    if ((my $e = $ENV{KB_DEPLOYMENT_CONFIG}) && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
		my $service = $ENV{KB_SERVICE_NAME};
		if (!defined($service)) {
			$service = "fbaModelService";
		}
		if (defined($service)) {
			my $c = Config::Simple->new();
			$c->read($e);
			for my $p (@{$paramlist}) {
			  	my $v = $c->param("$service.$p");
			    if ($v) {
					$params->{$p} = $v;
			    }
			}
		}
    }

    # now, we have the options hash. THis is passed into the constructor as a
    # parameter to new(). If a key from the predefined set of parameter keys
    # is found in the incoming hash, let the associated value override what
    # was previously assigned to the params hash from the config object.

	print STDERR "\nServer config values:\n";
    for my $p (@{$paramlist}) {
  		if (defined($options->{$p})) {
			$params->{$p} = $options->{$p};
        }
        print STDERR $p."\t".$params->{$p}."\n";
    }

    # now, if params has one of the predefined set of parameter keys,
    # use that value to override object instance variable values. The
    # default object instance variable values were set above.
	if (defined($params->{mfatoolkitbin})) {
		Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_BINARY($params->{mfatoolkitbin});
	}
	if (defined($params->{fbajobdir})) {
		Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY($params->{fbajobdir});
	}
	if (defined($params->{fbajobcache})) {
		Bio::KBase::ObjectAPI::utilities::FinalJobCache($params->{fbajobcache});
	}
    if (defined $params->{accounttype}) {
		$self->{_accounttype} = $params->{accounttype};
    }
    if (defined $params->{defaultJobState}) {
		$self->{_defaultJobState} = $params->{defaultJobState};
    }
    if (defined $params->{'gaserver-url'}) {
    		$self->{'_gaserver-url'} = $params->{'gaserver-url'};
    }
    if (defined $params->{'fba-url'}) {
    		$self->{'_fba-url'} = $params->{'fba-url'};
    }
    if (defined $params->{'idserver-url'}) {
    	Bio::KBase::ObjectAPI::utilities::ID_SERVER_URL($params->{'idserver-url'});
    }
    if (defined $params->{'jobserver-url'}) {
    		$self->{'_jobserver-url'} = $params->{'jobserver-url'};
    }
    if (defined $params->{'mssserver-url'}) {
    		$self->{'_mssserver-url'} = $params->{'mssserver-url'};
    }
    if (defined $params->{'workspace-url'}) {
    		$self->{'_workspace-url'} = $params->{'workspace-url'};
    }
    if (defined $params->{'probanno-url'}) {
    		$self->{'_probanno-url'} = $params->{'probanno-url'};
    }
    #This final condition allows one to specify a fully implemented workspace IMPL or CLIENT for use

    if (defined($options->{workspace})) {
    	$self->{_workspaceServiceOveride} = $options->{workspace};
    }
    if (defined($options->{verbose})) {
    	set_verbose(1);
    }
    
	if ($self->{'_gaserver-url'} eq "impl") {
		require "Bio/KBase/GenomeAnnotation/GenomeAnnotationImpl.pm";
		$self->{_gaserver} = Bio::KBase::GenomeAnnotation::GenomeAnnotationImpl->new();
	} else {
		$self->{_gaserver} = Bio::KBase::GenomeAnnotation::Client->new($self->{'_gaserver-url'});
	}
	$self->{_jobserver} = Bio::KBase::workspaceService::Client->new($self->{'_jobserver-url'});
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
    $input = $self->_validateargs($input,["models","workspaces"],{});
    for (my $i=0; $i < @{$input->{models}}; $i++) {
    	my $id = $input->{models}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $model = $self->_get_msobject("FBAModel",$input->{workspaces}->[$i],$input->{models}->[$i]);
    	my $mdldata = {
    		id => $input->{models}->[$i],
    		genome_ref => $model->genome_ref(),
    		biochemistry_ref => $model->template()->biochemistry_ref(),
    		name => $model->name(),
    		type => $model->type(),
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
    			id => $comp->id(),
    			name => $comp->id(),
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
    			compartment => $cpd->modelcompartment()->id()
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
    			compartment => $rxn->modelcompartment()->id(),
    			equation => $rxn->equation(),
    			definition => $rxn->definition(),
    			gapfilled => 0
    		};
			$rxndata->{gapfilled} = $self->_was_reaction_gapfilled($rxn);
    		push(@{$mdldata->{reactions}},$rxndata);
    	}
    	#Creating fbas, gapfills, and gapgens
    	foreach my $obj (@{$model->gapfillings()}) {
    		if ($obj->integrated() == 1) {
    			push(@{$mdldata->{integrated_gapfillings}},$self->_generate_gapmeta($obj->gapfill()));
    		} else {
    			push(@{$mdldata->{unintegrated_gapfillings}},$self->_generate_gapmeta($obj->gapfill()));
    		}
    	}
    	foreach my $obj (@{$model->gapgens()}) {
    		if ($obj->integrated() == 1) {
    			push(@{$mdldata->{integrated_gapfillings}},$self->_generate_gapmeta($obj->gapgen()));
    		} else {
    			push(@{$mdldata->{unintegrated_gapfillings}},$self->_generate_gapmeta($obj->gapgen()));
    		}
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
		biochemistry_workspace => "kbase"
	});
    for (my $i=0; $i < @{$input->{fbas}}; $i++) {
    	my $id = $input->{fbas}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $fba = $self->_get_msobject("FBA",$ws,$id);
    	my $fbadata = $self->_FBA_to_FBAdata($fba);
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
    for (my $i=0; $i < @{$input->{gapfills}}; $i++) {
    	my $id = $input->{gapfills}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $obj = $self->_get_msobject("Gapfilling",$ws,$id);
    	my $data = $self->_GapFill_to_GapFillData($obj);
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
    for (my $i=0; $i < @{$input->{gapgens}}; $i++) {
    	my $id = $input->{gapgens}->[$i];
    	my $ws = $input->{workspaces}->[$i];
    	my $obj = $self->_get_msobject("GapGen",$ws,$id);
    	my $data = $self->_GapGen_to_GapGenData($obj);
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
    	biochemistry => "default",
    	biochemistry_workspace => "kbase"
    });
	my $biochem = $self->_get_msobject("Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
	$out_reactions = [];
	for (my $i=0; $i < @{$input->{reactions}}; $i++) {
		my $rxn = $input->{reactions}->[$i];
		my $obj;
		if ($rxn =~ m/(rxn\d+)$/) {
			$obj = $biochem->getObject("reactions",$1);
		} else {
			$obj = $biochem->searchForReaction($rxn);
		}
		my $new;
		if (defined($obj)) {
			$new = {
                id => $obj->id(),
                abbrev => $obj->abbreviation(),
                name => $obj->name(),
                enzymes => $obj->getAliases("Enzyme Class"),
				aliases => $obj->allAliases(),
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
    	id_type => "all",
    	biochemistry => "default",
		biochemistry_workspace => "kbase"
    });
	my $biochem = $self->_get_msobject("Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
	$out_compounds = [];
	for (my $i=0; $i < @{$input->{compounds}}; $i++) {
		my $cpd = $input->{compounds}->[$i];
		my $obj;
		if ($cpd =~ m/(cpd\d+)$/) {
			$obj = $biochem->getObject("compounds",$1);
		} else {
			$obj = $biochem->searchForCompound($cpd);
		}
		my $new;
		if (defined($obj)) {
			$new = {
                id => $obj->id(),
                name => $obj->name(),
                abbrev => $obj->abbreviation(),
                aliases => $obj->allAliases(),
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_alias:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alias');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN get_alias
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["input_ids", "input_id_type", "output_id_type", "object_type"],{
        biochemistry => "default",
        biochemistry_workspace => "kbase"
    });
    my $biochem = $self->_get_msobject("Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
    $output = [];
    for (my $i=0; $i < @{$input->{input_ids}}; $i++) {
		my $id = $input->{input_ids}->[$i];
		my $obj;
		my $oneoutput = {};
		if (lc($input->{"object_type"}) eq "compound") {
		    $obj = $biochem->getObjectByAlias("compounds",$id,$input->{input_id_type});
		} elsif (lc($input->{"object_type"}) eq "reaction") {
		    $obj = $biochem->getObjectByAlias("reactions", $id, $input->{input_id_type});
		} else { 
		    die "Object type $input->{object_type} does not support alias sets";
		}
		if (defined($obj)) {
		    $oneoutput->{original_id} = $id;
		    $oneoutput->{aliases} = [];
		    my $alias = $obj->getAliases($input->{output_id_type});
		    push(@{$oneoutput->{aliases}},$alias);
		    push(@{$output}, $oneoutput);
		}
    }
    #END get_alias
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_alias:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alias');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_aliassets:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_aliassets');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($aliassets);
    #BEGIN get_aliassets
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["object_type"],{biochemistry => "default"});
    my $biochem = $self->_get_msobject("Biochemistry","kbase",$input->{biochemistry});
    $aliassets = [];
    my $aliashash = {};
    if (lc($input->{object_type}) eq "compound") {
    	$aliashash = $biochem->compoundsByAlias();
    } elsif (lc($input->{object_type}) eq "reaction") {
    	$aliashash = $biochem->reactionsByAlias();
    }
    $aliassets = [keys(%{$aliashash})];

    #END get_aliassets
    my @_bad_returns;
    (ref($aliassets) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"aliassets\" (value was \"$aliassets\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_aliassets:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_aliassets');
    }
    return($aliassets);
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
	$out_media = [];
	for (my $i=0; $i < @{$input->{medias}}; $i++) {
		my $media = $input->{medias}->[$i];
		my $workspace = $input->{workspaces}->[$i];
		my $obj = $self->_get_msobject("Media",$workspace,$media);
		my $new;
		if (defined($obj)) {
			$new = {
                id => $obj->id(),
                name => $obj->name(),
                pH => 7,#TODO:Fix this
                temperature => 298,#TODO:Fix this
                media_compounds => [],
            };
            foreach my $mediaCompound (@{$obj->mediacompounds}) {
                push(@{$new->{media_compounds}},{
                	compound => $mediaCompound->compound()->id(),
                	name => $mediaCompound->compound()->name(),
                	concentration => $mediaCompound->concentration(),
                	max_flux => $mediaCompound->maxFlux(),
                	min_flux => $mediaCompound->minFlux()
                });
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
	});
    my $biochem = $self->_get_msobject("Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
    my $compounds = [];
    my $reactions = [];
    $out_biochemistry = {
        id => $biochem->id(),
        name => $biochem->name,
        compounds => $compounds,
        reactions => $reactions,
    };
	my $cpds = $biochem->compounds();
    for (my $i=0; $i < @{$cpds}; $i++) {
    	push(@{$compounds},$cpds->[$i]->id());
    }
    my $rxns = $biochem->reactions();
    for (my $i=0; $i < @{$rxns}; $i++) {
    	push(@{$reactions},$rxns->[$i]->id());
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
    	$self->_error($msg,'import_phenotypes');
    }
    #Retrieving the annotation object
    my $annotation = $self->_get_msobject("Annotation","NO_WORKSPACE",$genomeObj->{annotation_uuid});
    if (!defined($annotation)) {
    	my $msg = "Failed to retrieve annotation ".$input->{genome_workspace}."/".$input->{genome};
    	$self->_error($msg,'import_phenotypes');
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
		$self->_error($msg,'import_phenotypes');
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
    	uid => $input->{genomeobj}->{id}
    });
    #Processing genome object
	my $genome = $input->{genomeobj};
	if (!defined($genome->{scientific_name})) {
		$genome->{scientific_name} = $genome->{id};
	}
	if (defined($genome->{gc})) {
		$genome->{gc_content} = $genome->{gc};
	}
	if (defined($genome->{contigs})) {
		my $label = "dna";
		if (defined($genome->{contigs}->[0]->{seq})) {
			$label = "seq";
		}
		$genome->{num_contigs} = @{$genome->{contigs}};
		my $sortedcontigs = [sort { $a->{$label} cmp $b->{$label} } @{$genome->{contigs}}];
		my $str = "";
		for (my $i=0; $i < @{$sortedcontigs}; $i++) {
			if (length($str) > 0) {
				$str .= ";";
			}
			$str .= $sortedcontigs->[$i]->{$label};
			
		}
		$genome->{dna_size} = length($str);
		$genome->{md5} = Digest::MD5::md5_hex($str);
		my $contigset = {
			id => $self->_register_kb_id("kb|contigset",$genome->{md5},"md5hash"),
			name => $genome->{scientific_name},
			md5 => $genome->{md5},
			source_id => $genome->{source_id},
			source => $genome->{source},
			type => "Organism",
			contigs => []
		};
		for (my $i=0; $i < @{$genome->{contigs}}; $i++) {
			push(@{$genome->{contig_ids}},$genome->{contigs}->[$i]->{id});
			push(@{$genome->{contig_lengths}},length($genome->{contigs}->[$i]->{$label}));
			my $md5 = Digest::MD5::md5_hex($genome->{contigs}->[$i]->{$label});
			push(@{$contigset->{contigs}},{
				id => $genome->{contigs}->[$i]->{id},
				"length" => length($genome->{contigs}->[$i]->{$label}),
				md5 => $md5,
				sequence => $genome->{contigs}->[$i]->{$label},
				name => $genome->{contigs}->[$i]->{id}
			});
		}
		my $ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
		$self->_save_msobject($ContigObj,"ContigSet",$input->{workspace},$input->{uid}.".contigset",{hidden => 1});
		$genome->{contigset_ref} = $ContigObj->_reference();
	}
	if (defined($genome->{features})) {
		for (my $i=0; $i < @{$genome->{features}}; $i++) {
			my $ftr = $genome->{features}->[$i];
			if (!defined($ftr->{type}) && $ftr->{id} =~ m/(\w+)\.\d+$/) {
				$ftr->{type} = $1;
			}
			if (defined($ftr->{protein_translation})) {
				$ftr->{protein_translation_length} = length($ftr->{protein_translation});
				$ftr->{md5} = Digest::MD5::md5_hex($ftr->{protein_translation});
			}
			if (defined($ftr->{dna_sequence})) {
				$ftr->{dna_sequence_length} = length($ftr->{dna_sequence});
			}
		}
	}
	my $GenomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genome);
	$genomeMeta = $self->_save_msobject($GenomeObj,"Genome",$input->{workspace},$input->{uid});
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
    	sourceLogin => undef,
    	sourcePassword => undef,
    	source => "kbase",
    });
    my $objects;
    if ($input->{source} eq "kbase") {
    	$objects = $self->_get_genomeObj_from_CDM($input->{genome});
    } elsif ($input->{source} eq "seed") {
    	$objects = $self->_get_genomeObj_from_SEED($input->{genome});
    } elsif ($input->{source} eq "rast") {
    	$objects = $self->_get_genomeObj_from_RAST($input->{genome},$input->{sourceLogin},$input->{sourcePassword});
    }
    if (defined($objects->[1])) {
    	my $contigmeta = $self->_save_msobject($objects->[1],"ContigSet",$input->{workspace},$objects->[1]->{id});
		$objects->[0]->contigset_ref($objects->[1]->_reference());
    }
	$genomeMeta = $self->_save_msobject($objects->[0],"Genome",$input->{workspace},$input->{genome});
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
    $input = $self->_validateargs($input,["genome","workspace","translations","id_type"],{});
    my $genome = $self->_get_msobject("Genome",$input->{workspace},$input->{genome});
    my $aliases;
    for (my $i=0; $i < @{$input->{translations}}; $i++) {
    	my $trans = $input->{translations}->[$i];
    	$aliases->{$trans->[1]}->{$trans->[0]} = 1;
    }
    my $features = $genome->features();
    for (my $i=0; $i < @{$features}; $i++) {
    	my $ftr = $features->[$i];
    	if (defined($aliases->{$ftr->id()})) {
    		my $existingAliases = {};
	    	foreach my $alias (@{$ftr->aliases()}) {
	    		$existingAliases->{$alias} = 1;
	    	}
    		foreach my $alias (keys(%{$aliases->{$ftr->id()}})) {
    			if (!defined($existingAliases->{$alias})) {
    				push(@{$ftr->aliases()},$alias);
    			}
    		}
    	}
    }
    $genomeMeta = $self->_save_msobject($genome,"Genome",$input->{workspace},$input->{genome});
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
    	templatemodel => undef,
    	templatemodel_workspace => $input->{workspace},
    	coremodel => 0,
    	genome_workspace => $input->{workspace},
    	model => undef
    });
    #Retreiving genome object from workspace
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    #Determining model ID
    my $kbid = $self->_get_new_id($genome->id().".fbamdl");
    if (!defined($input->{model})) {
    	$input->{model} = $input->{genome}.".fbamdl";
    }
    my $mdl = $self->_genome_to_model($genome,$kbid,$input);
	#Model uuid and model id will be set to WS values during save
	$modelMeta = $self->_save_msobject($mdl,"FBAModel",$input->{workspace},$input->{model});
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
    	ignore_errors => 0,
    	source => "Imported",
    	type => "SingleOrganism",
    	template => undef,
    	template_workspace => $input->{workspace},
    	compounds => [],
    });
    my $genome = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
    my $kbid = $self->_get_new_id($genome->id().".fbamdl.");
    if (!defined($input->{model})) {
    	$input->{model} = $kbid;
    }
    my $template;
    if (defined($input->{template})) {
    	$template = $self->_get_msobject("ModelTemplate",$input->{template_workspace},$input->{template});
    } else {
    	my $class = $self->_classify_genome($genome);
		if ($class eq "Gram positive") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramPosModelTemplate");
    	} elsif ($class eq "Gram negative") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramNegModelTemplate");
    	} elsif ($class eq "Plant") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","PlantModelTemplate");
    	}
    }
    my $model = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->new({
		id => $kbid,
		source => $input->{source},
		source_id => $input->{model},
		name => $genome->scientific_name(),
		type => $input->{type},
		genome_ref => $genome->_reference(),
		template_ref => $template->_reference(),
		gapfillings => [],
		gapgens => [],
		biomasses => [],
		modelcompartments => [],
		modelcompounds => [],
		modelreactions => []
	});
	$model->parent($self->_KBaseStore());
    #Loading reactions to model
	my $missingGenes = {};
	my $missingCompounds = {};
	my $missingReactions = {};
	my $compoundhash = {};
	for (my $i=0; $i < @{$input->{compounds}}; $i++) {
		$compoundhash->{$input->{compounds}->[$i]->[0]} = $input->{compounds}->[$i];
	}
	for (my  $i=0; $i < @{$input->{reactions}}; $i++) {
		my $rxnrow = $input->{reactions}->[$i];
		$model->manualReactionAdjustment({
		    reaction => $rxnrow->[0],
		    direction => $rxnrow->[1],
		    compartment => $rxnrow->[2],
		    compartmentIndex => 0,
		    gpr => $rxnrow->[3],
		    removeReaction => 0,
		    addReaction => 1,
		    compounds => $compoundhash
		});
		#if (defined($report->{missing_genes})) {
		#	for (my $i=0; $i < @{$report->{missing_genes}}; $i++) {
		#		$missingGenes->{$report->{missing_genes}->[$i]} = 1;
		#	}
		#}
		#if (defined($report->{missing_compounds})) {
		#	for (my $i=0; $i < @{$report->{missing_compounds}}; $i++) {
		#		$missingCompounds->{$report->{missing_compounds}->[$i]} = 1;
		#	}
		#}
		#if (defined($report->{missing_reactions})) {
		#	for (my $i=0; $i < @{$report->{missing_reactions}}; $i++) {
		#		$missingReactions->{$report->{missing_reactions}->[$i]} = 1;
		#	}
		#}
	}
	my $report = $model->manualReactionAdjustment({
		biomass => 1,
		reaction => "bio1:".$input->{biomass},
		direction => ">",
		compartment => "c",
		compartmentIndex => 0,
		gpr => "",
		removeReaction => 0,
	    addReaction => 0,
	    compounds => $compoundhash
	});
	my $msg = "";
	#if (keys(%{$missingReactions}) > 0) {
	#	$msg .= "Missing reactions:".join(";",keys(%{$missingReactions}))."\n";
	#}
	#if (keys(%{$missingCompounds}) > 0) {
	#	$msg .= "Missing biomass compounds:".join(";",keys(%{$missingCompounds}))."\n";
	#}
	#if (keys(%{$missingGenes}) > 0) {
	#	$msg .= "Missing genes:".join(";",keys(%{$missingGenes}))."\n";
	#}
	if (length($msg) > 0 && $input->{ignore_errors} == 0) {
		$self->_error($msg);
	}

	#Saving imported model
	$modelMeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{model});
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
    my $model = $self->_get_msobject("FBAModel",$input->{workspace},$input->{model});
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
 	my $array = [split(/\//,$input->{reference})];
    my $obj = $self->_get_msobject($input->{type},$array->[0],$array->[1]);
	if (ref($obj) eq "HASH") {
		my $JSON = JSON::XS->new->utf8(1);
    	$output = $JSON->encode($obj);
	} elsif (ref($obj) =~ m/Bio::KBase::ObjectAPI/) {
		$output = $obj->export({format => $input->{format}});;
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
    $output = $genome->export({format => $input->{format}});
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
    	model_workspace => $input->{workspace},
    	direction => [undef],
    	compartment => ["c"],
    	compartmentIndex => [0],
    	gpr => [undef],
    	removeReaction => 0,
    	addReaction => 0,
    	compounds => [],
		outputid => $input->{model},
    });

    # For reverse compatibility, if we are given scalar arguments for the reactions or other multi-component objects
    # we turn them into array refs.
    if ( ref($input->{reaction}) eq 'SCALAR' ) {  $input->{reaction} = [ $input->{reaction} ];   }
    if ( ref($input->{direction}) eq 'SCALAR' ) { $input->{direction} = [ $input->{direction} ]; }
    if ( ref($input->{gpr}) eq 'SCALAR' ) {  $input->{gpr} = [ $input->{gpr} ];  }
    if ( ref($input->{compartment}) eq 'SCALAR') { $input->{compartment} = [ $input->{compartment} ]; }
    if ( ref($input->{compartmentIndex}) eq 'SCALAR') { $input->{compartmentIndex} = [ $input->{compartmentIndex} ]; }

    # If we receive entries for compartments, directions, gprs, etc... they must all either have the same size
    # or be size 1 (in which case we apply the same value to all of the elements)
    my $nreactions = scalar @{ $input->{reaction} };
    my $ncomps = scalar @{ $input->{compartment} };
    my $ncompidx = scalar @{ $input->{compartmentIndex} };
    my $ndir = scalar @{ $input->{direction} };
    my $ngpr = scalar @{ $input->{gpr} };
    if( !($ncomps == $nreactions || $ncomps == 1) ||
	!($ncompidx == $nreactions || $ncompidx == 1) ||
	!($ndir == $nreactions || $ndir == 1) ||
	!($ngpr == $nreactions || $ngpr == 1) ) {
	die "Size mismatch between number of reactions and number of GPR, direction, compartment or compartmentIndexes";
    }

    my $model = $self->_get_msobject("FBAModel",$input->{workspace},$input->{model});
    my $compoundhash = {};
	for (my $i=0; $i < @{$input->{compounds}}; $i++) {
		$compoundhash->{$input->{compounds}->[$i]->[0]} = $input->{compounds}->[$i];
	}
    for (my $i=0; $i < @{$input->{reaction}}; $i++)  {
		my $gpr;
		my $dir;
		my $comp;
		my $compidx;
		if ( scalar @{$input->{gpr}} eq 1) {
		    $gpr = $input->{gpr}->[0];
		} else {
		   	$gpr = $input->{gpr}->[$i];
		}
		if ( scalar @{$input->{direction}} eq 1 ) {
		    $dir = $input->{direction}->[0];
		} else {
		    $dir = $input->{direction}->[$i];
		}
		if ( scalar @{$input->{compartment}} eq 1 ) {  
		    $comp = $input->{compartment}->[0]; 
		} else {  
		    $comp = $input->{compartment}->[$i];
		}
		if ( scalar @{$input->{compartmentIndex}} eq 1 ) {
		    $compidx = $input->{compartmentIndex}->[0];
		} else {
		    $compidx = $input->{compartmentIndex}->[$i];
		}
		$model->manualReactionAdjustment({
		    reaction => $input->{reaction}->[$i],
		    direction => $dir,
		    compartment => $comp,
		    compartmentIndex => $compidx,
		    gpr => $gpr,
		    removeReaction => $input->{removeReaction},
		    addReaction => $input->{addReaction},
		    compounds => $compoundhash
		});
	}
    $modelMeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{outputid});
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
    $input = $self->_validateargs($input,["compounds","model","workspace"],{
    	biomass => "bio1",
    	coefficients => [],
    	compartments => [],
    	compartmentIndecies => [],
    });
	my $model = $self->_get_msobject("FBAModel",$input->{workspace},$input->{model});
	for (my $i=0; $i < @{$input->{compounds}}; $i++) {
		if (!defined($input->{coefficients}->[$i])) {
			$input->{coefficients}->[$i] = 1;
		}
		if (!defined($input->{compartments}->[$i])) {
			$input->{compartments}->[$i] = 1;
		}
		if (!defined($input->{indecies}->[$i])) {
			$input->{indecies}->[$i] = 1;
		}
		$model->adjustBiomassReaction({
			compound => $input->{compound}->[$i],
			coefficient => $input->{coefficient}->[$i],
	    	biomass => $input->{biomass},
	    	compartment => $input->{compartment}->[$i],
	    	compartmentIndecies => $input->{compartmentIndecies}->[$i],
	    });
	}
	$modelMeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{model});
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
    	biochemistry => "default",
    	biochemistry_workspace => "kbase"
    });
    #Creating the media object from the specifications
    my $bio = $self->_get_msobject("Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
    my $media = Bio::KBase::ObjectAPI::KBaseBiochem::Media->new({
    	id => "kb|media.".$self->_idServer()->allocate_id_range("kb|media",1),
    	name => $input->{name},
    	isDefined => $input->{isDefined},
    	isMinimal => $input->{isMinimal},
    	type => $input->{type},
    	source_id => $input->{media}
    });
    my $missing = [];
    my $found = [];
    for (my $i=0; $i < @{$input->{compounds}}; $i++) {
    	my $name = $input->{compounds}->[$i];
    	my $cpdobj = $bio->searchForCompound($name);
    	if (defined($cpdobj)) {
	    	my $data = {
	    		compound_ref => $bio->_reference()."/compounds/id/".$cpdobj->id(),
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
	    	push(@{$found},$cpdobj->id());
    	} else {
    		push(@{$missing},$input->{compounds}->[$i]);
    	}
    }
    #Checking that all compounds specified for media were found
	if (defined($missing->[0])) {
		$self->_error("Compounds specified for media not found: ".join(";",@{$missing}),'addmedia');
	}
    #Saving media in database
    $media->parent($self->_KBaseStore());
    $mediaMeta = $self->_save_msobject($media,"Media",$input->{workspace},$input->{media});
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
    my $med = $self->_get_msobject("Media",$input->{workspace},$input->{media});
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
		biomass => undef
	});
	my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
	if (!defined($input->{fba})) {
		$input->{fba} = $self->_get_new_id($input->{model}.".fba.");
	}
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	#Creating FBAFormulation Object
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{workspace},$input->{fba});
	$fba->fva($input->{fva});
	$fba->comboDeletions($input->{simulateko});
	$fba->fluxMinimization($input->{minimizeflux});
	$fba->findMinimalMedia($input->{findminmedia});
	if (defined($input->{biomass}) && defined($fba->biomassflux_objterms()->{bio1})) {
		my $bio = $model->searchForBiomass($input->{biomass});
		if (defined($bio)) {
			delete $fba->biomassflux_objterms()->{bio1};
			$fba->biomassflux_objterms()->{$bio->id()} = 1;
		}			
	}
    #Running FBA
    my $objective;
    eval {
		local $SIG{ALRM} = sub { die "FBA timed out! Model likely contains numerical instability!" };
		alarm 600;
		$objective = $fba->runFBA();
		alarm 0;
	};
	if ($@) {
		$self->_error($@);
    }
    if (!defined($objective)) {
    	$self->_error("FBA failed with no solution returned!");
    }
	$fbaMeta = $self->_save_msobject($fba,"FBA",$input->{workspace},$input->{fba});
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
		biochemistry => "default",
		biochemistry_workspace => "kbase",
		name => undef,
		source => "unknown",
		type => "unspecified",
	});
	my $genomeObj = $self->_get_msobject("Genome",$input->{genome_workspace},$input->{genome});
	my $kbid = $self->_get_new_id($genomeObj->id().".phe.");
	my $uid = $input->{genome}.".phe.".$input->{type};
	if (!defined($input->{phenotypeSet})) {
		$input->{phenotypeSet} = $uid;
	}
	if (!defined($input->{name})) {
		$input->{name} = $input->{phenotypeSet};
	}
	
	my $phenoset = Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSet->new({
		id => $kbid,
		source_id => $input->{phenotypeSet},
		source => $input->{source},
		name => $input->{name},
		genome_ref => $genomeObj->_reference(),
		phenotypes => [],
		importErrors => "",
		type => $input->{type}
	});
	$phenoset->parent($self->_KBaseStore());
	my $bio = $self->_get_msobject("Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
	$phenoset->import_phenotype_table({
		data => $input->{phenotypes},
		biochem => $bio
	});
	if (length($phenoset->importErrors()) > 0 && $input->{ignore_errors} == 0) {
		$self->_error($phenoset->importErrors());
	}
	$output = $phenoset->save($input->{workspace}."/".$input->{phenotypeSet});
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
		phenotypeSimultationSet => $input->{phenotypeSet}.".simulation",
		all_transporters => 0,
		positive_transporters => 0
	});
	my $pheno = $self->_get_msobject("PhenotypeSet",$input->{phenotypeSet_workspace},$input->{phenotypeSet});
	my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
    if ( $input->{all_transporters} ) {
		$model->addPhenotypeTransporters({phenotypes => $pheno,positiveonly => 0});
	} elsif ( $input->{positive_transporters} ) {
		$model->addPhenotypeTransporters({phenotypes => $pheno,positiveonly => 1});
	}
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	my $fba = $self->_buildFBAObject($input->{formulation},$model);
	$fba->parent($self->_KBaseStore());
	$fba->phenotypeset_ref($pheno->_reference());
	$fba->runFBA();
	if (!defined($fba->phenotypesimulationset())) {
    	$self->_error("Simulation of phenotypes failed to return results from FBA!");
	}
	if (!defined($input->{phenotypeSimulationSet})) {
		$input->{phenotypeSimulationSet} = $fba->phenotypesimulationset()->id();
	}
	$output = $self->_save_msobject($fba->phenotypesimulationset(),"PhenotypeSimulationSet",$input->{workspace},$input->{phenotypeSimultationSet});
	$fba->phenotypesimulationset_ref($fba->phenotypesimulationset()->_reference());
    my $meta = $self->_save_msobject($fba,"FBA",$input->{workspace},$fba->id(),{hidden => 1});
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to add_media_transporters:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_media_transporters');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN add_media_transporters
    # TODO - I could also attempt to use the probanno object to add the "best" transporters. But I didn't
    # get that complicated here.
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["phenotypeSet","model","outmodel", "workspace"],{
		phenotypeSet_workspace => $input->{workspace},
		model_workspace => $input->{workspace},
		all_transporters => 0,
		positive_transporters => 0
	});

    my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
    my $pheno = $self->_get_msobject("PhenotypeSet", $input->{phenotypeSet_workspace}, $input->{phenotypeSet});

    if ( $input->{all_transporters} ) {
		$model->addPhenotypeTransporters({phenotypes => $pheno,positiveonly => 0});
    } elsif ( $input->{positive_transporters} ) {
		$model->addPhenotypeTransporters({phenotypes => $pheno,positiveonly => 1});
    } else {
		die "Must specify either all_transporters or positive_transporters.\n";
    }

    $output = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{outmodel});

    #END add_media_transporters
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to add_media_transporters:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_media_transporters');
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
    my $phenosim = $self->_get_msobject("PhenotypeSimulation",$input->{workspace},$input->{phenotypeSimulationSet});
    $output = $phenosim->export({format => $input->{format}});
    $self->_clearContext();
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
		overwrite => 0,
		rxnprobs => undef,
		rxnprobs_workspace => $input->{workspace}
    });
    my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
    my($rxnprobs);
    my($rxnprobsGPRArray);
    if ( defined($input->{rxnprobs}) ) {
		$rxnprobs = $self->_get_msobject("RxnProbs", $input->{rxnprobs_workspace}, $input->{rxnprobs});
		$rxnprobsGPRArray = $self->_buildRxnProbsGPRArray($rxnprobs);
    }
    foreach my $id (@{$input->{gapfillSolutions}}) {
    	if ($id =~ m/^(.+\.gf\.\d+)\./) {
    		my $gfid = $1;
			$model->integrateGapfillSolution({
				gapfill=> $gfid,
				solution => $id,
				rxnProbGpr => $rxnprobsGPRArray
			});
    	}
    }
    foreach my $id (@{$input->{gapgenSolutions}}) {
    	if ($id =~ m/^(.+\.gg\.\d+)\./) {
	    	my $ggid = $1;
			$model->integrateGapfillSolution({
				gapgen=> $ggid,
				solution => $id,
			});
	    }
    }
    
    $model->modelreactions();#This must be called here to ensure that the reaction objects are instantiated
    $modelMeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{out_model});
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
    my($job);
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
	});
	$job = $self->_queueJob({
		type => "KBaseFBAModeling",
		jobdata => $input,
		queuecommand => "runfba",
		"state" => "queued",
		auth => $self->_authentication(),
	});
	$self->_clearContext();
    #END queue_runfba
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_runfba:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_runfba');
    }
    return($job);
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
    my($job);
    #BEGIN queue_gapfill_model
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace"],{		
		model_workspace => $input->{workspace},
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{workspace},
		integrate_solution => 0,
		out_model => undef,
		gapFill => undef,
		gapFill_workspace => $input->{workspace},
		target_reactions => [],
		overwrite => 0,
		timePerSolution => 3600,
		totalTimeLimit => 18000,
		completeGapfill => 0,
		solver => undef
	});
	$job = $self->_queueJob({
		type => "KBaseFBAModeling",
		jobdata => $input,
		queuecommand => "gapfill_model",
		"state" => "queued",
		auth => $self->_authentication(),
	});
	$self->_clearContext();
    #END queue_gapfill_model
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_gapfill_model');
    }
    return($job);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_model');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN gapfill_model
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace"],{		
		model_workspace => $input->{workspace},
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{workspace},
		integrate_solution => 0,
		out_model => undef,
		gapFill => undef,
		gapFill_workspace => $input->{workspace},
		target_reactions => [],
		timePerSolution => 3600,
		totalTimeLimit => 18000,
		completeGapfill => 0,
		solver => undef
	});
	$input->{formulation}->{target_reactions} = $input->{target_reactions};
	$input->{formulation}->{timePerSolution} = $input->{timePerSolution};
	$input->{formulation}->{totalTimeLimit} = $input->{totalTimeLimit};
	$input->{formulation}->{completeGapfill} = $input->{completeGapfill};
	if (@{$input->{target_reactions}} > 0) {
		$input->{completeGapfill} = 1;
	}
	if ($input->{completeGapfill} == 1) {
		$input->{formulation}->{num_solutions} = 1;
	}
	$input->{formulation} = $self->_setDefaultGapfillFormulation($input->{formulation});
	my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
	if (!defined($input->{out_model})) {
		$input->{out_model} = $input->{model};
	}
	my ($gapfill,$fba) = $self->_buildGapfillObject($input->{formulation},$model,$input->{gfid});
	if (defined($input->{solver})) {
    	$fba->parameters()->{MFASolver} = uc($input->{solver});
    }
	$fba->runFBA();
	#Error checking the FBA and gapfilling solution
	if (!defined($fba->outputfiles()->{"CompleteGapfillingOutput.txt"}->[1] ) ) {
		$self->_error("Gapfilling failed to produce an output file. Check gapfilling infrastructure!");
	}
	my $gfoutput = $fba->outputfiles()->{"CompleteGapfillingOutput.txt"};
	for (my $i=0; $i < @{$gfoutput}; $i++) {
		my $line = $gfoutput->[$i];
		if ($line =~ /FAILED/ && $line =~ /Prelim/ && $line =~ /bio\d+/) {
			my $array = [split(/\t/,$line)];
			my $msg;
			if (defined($array->[6])) {
				$msg = "Gapfilling failed in preliminary feasibility determination. The following biomass compounds appear to be problematic: ".$array->[6]."!";
			} else {
				$msg = "Gapfilling failed in preliminary feasibility determination.";
			}
			$self->_error($msg);
		} elsif ($line =~ /FAILED/ && $line =~ /bio\d+/) {
			$self->_error("Gapfilling failed with no solutions!");
		}
	}
	$gapfill->parseGapfillingResults($fba);
	if (!defined($gapfill->gapfillingSolutions()->[0])) {
		$self->_error("Gapfilling completed, but no valid solutions found!");
	}
	my $meta = $self->_save_msobject($fba,"FBA",$input->{workspace},$fba->id());
	$gapfill->fba_ref($fba->_reference());
	$meta = $self->_save_msobject($gapfill,"Gapfilling",$input->{workspace},$gapfill->id(),{hidden => 1});
	#Since gapfilling can take hours, we retrieve the model again in case it changed since accessed previously
	if ($input->{out_model} eq $input->{model}) {
		$model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model},{refreshcache => 1});
	}
	$model->add("gapfillings",{
		id => $gapfill->id(),
		gapfill_id => $gapfill->id(),
		gapfill_ref => $gapfill->_reference(),
		integrated => 0,
		media_ref => $fba->media()->_reference()
	});
	#If specified, we now integrate the first solution of the gapfilling into the model
	if ($input->{integrate_solution} == 1) {
		my ($rxnprobsGPRArray);
		my ($rxnprobs);
		if ( defined($input->{formulation}->{probabilisticReactions} )) {
		    my $rxnprobsid = $input->{formulation}->{probabilisticReactions};
		    my $rxnprobsws = $input->{formulation}->{probabilisticReaction_workspace};
		    $rxnprobs = $self->_get_msobject("RxnProbs", $rxnprobsws, $rxnprobsid);
		    $rxnprobsGPRArray = $self->_buildRxnProbsGPRArray($rxnprobs);
		}
		my $report = $model->integrateGapfillSolution({
			gapfill => $gapfill->id(),
			rxnProbGpr => $rxnprobsGPRArray
		});
	}
	$modelMeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{out_model});
	$self->_clearContext();
    #END gapfill_model
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_model');
    }
    return($modelMeta);
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
    my($job);
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
		solver => undef
	});
	$job = $self->_queueJob({
		type => "KBaseFBAModeling",
		jobdata => $input,
		queuecommand => "gapgen_model",
		"state" => "queued",
		auth => $self->_authentication(),
	});
	$self->_clearContext();
    #END queue_gapgen_model
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_gapgen_model');
    }
    return($job);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_model');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN gapgen_model
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace"],{
		model_workspace => $input->{workspace},
		formulation => undef,
		phenotypeSet => undef,
		phenotypeSet_workspace => $input->{workspace},
		integrate_solution => 0,
		out_model => $input->{model},
		gapGen => undef,
		solver => undef
	});
	$input->{formulation}->{timePerSolution} = $input->{timePerSolution};
	$input->{formulation}->{totalTimeLimit} = $input->{totalTimeLimit};
	$input->{formulation} = $self->_setDefaultGapGenFormulation($input->{formulation});
	my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
	if (!defined($input->{out_model})) {
		$input->{out_model} = $input->{model};
	}
	my ($gapgen,$fba) = $self->_buildGapGenObject($input->{formulation},$model,$input->{ggid});
	if (defined($input->{solver})) {
    	$fba->parameters()->{MFASolver} = uc($input->{solver});
    }
    $gapgen->fbamodel_ref($model->_reference());
    if (!defined($input->{ggid})) {
		my $fbameta = $self->_save_msobject($fba,"FBA",$input->{workspace},$fba->id());
		$gapgen->fba_ref($fba->_reference());
		my $ggMeta = $self->_save_msobject($gapgen,"Gapgeneration",$input->{workspace},$gapgen->id(),{hidden => 1});
		$model->add("gapgens",{
			id => $gapgen->_reference(),
			gapgen_id => $gapgen->_reference(),
			gapgen_ref => $input->{workspace}."/".$gapgen->id(),
			integrated => 0,
			media_ref => $fba->media()->_reference()
		});
		$modelMeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{out_model});
 		$gapgen->fbamodel_ref($model->_reference());
    }
	$fba->runFBA();
	if (!defined($fba->objectiveValue())) {
		$self->_error("Gapgeneration failed to produce any results. Check gapgeneration infrastructure!");
	}
	$gapgen->parseGapgenResults($gapgen->fba());
	#We must resave the FBA and gapgen as these objects now have populated solutions
	my $fbameta = $self->_save_msobject($fba,"FBA",$input->{workspace},$fba->id());
	$gapgen->fba_ref($fba->_reference());
	my $ggMeta = $self->_save_msobject($gapgen,"Gapgeneration",$input->{workspace},$gapgen->id(),{hidden => 1});
	#Since gapgen can take hours, we retrieve the model again in case it changed since accessed previously
	$model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model},{refreshcache => 1});
	$model->add("gapgens",{
		id => $gapgen->id(),
		gapgen_id => $gapgen->id(),
		gapgen_ref => $gapgen->_reference(),
		integrated => 0,
		media_ref => $fba->media()->_reference()
	});
	#If specified, we now integrate the first solution of the gapgen into the model
	if ($input->{integrate_solution} == 1 && defined($gapgen->gapgenSolutions()->[0])) {
		$model->integrateGapgenSolution({
			gapgen => $gapgen->id(),
		});
	}
	my $modelmeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{out_model});
	$self->_clearContext();
    #END gapgen_model
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapgen_model');
    }
    return($modelMeta);
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
    my($job);
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
		#Getting the simulated phenotype set to be reconciled
		my $simPheno = $self->_get_msobject("PhenotypeSimulationSet",$input->{phenotypeSet_workspace},$input->{phenotypeSet});
		if (!defined($simPheno->{phenotypeSimulations})) {
			my $msg = "No phenotypes simulated!";
			$self->_error($msg,'queue_wildtype_phenotype_reconciliation');
		}
		#Queing up gapfill and gapgen jobs
		#TODO: This block should be in a "safe save" block to prevent race conditions
		my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
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
		my $modelmeta = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{out_model},"queue_wildtype_phenotype_reconciliation");
		#End "safe save" block
		my $joblist = [];
		foreach my $gapgenObj (@{$gapgenObjs}) {
			$gapgenObj->fbaFormulation()->model_uuid($model->uuid());
			my $fbameta = $self->_save_msobject($gapgenObj->fbaFormulation(),"FBA",$gapgenObj->fbaFormulation()->{_kbaseWSMeta}->{ws},$gapgenObj->fbaFormulation()->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			$gapgenObj->model_uuid($model->uuid());
			my $gapgenmeta = $self->_save_msobject($gapgenObj,"GapGen",$input->{gapGen_workspace},$gapgenObj->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			my $subJob = $self->_queueJob({
				type => "FBA",
				jobdata => {
					postprocess_command => "queue_wildtype_phenotype_reconciliation",
					postprocess_args => [$input],
					fbaref => $fbameta->[8]
				},
				queuecommand => "queue_wildtype_phenotype_reconciliation",
				"state" => $self->_defaultJobState()
			});
			push(@{$joblist},$subJob->{id});
		}
		foreach my $gapfillObj (@{$gapfillObjs}) {
			$gapfillObj->fbaFormulation()->model_uuid($model->uuid());
			my $fbameta = $self->_save_msobject($gapfillObj->fbaFormulation(),"FBA",$gapfillObj->fbaFormulation()->{_kbaseWSMeta}->{ws},$gapfillObj->fbaFormulation()->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			$gapfillObj->model_uuid($model->uuid());
			my $gapfillmeta = $self->_save_msobject($gapfillObj,"GapFill",$input->{gapFill_workspace},$gapfillObj->{_kbaseWSMeta}->{wsid},"queue_wildtype_phenotype_reconciliation");
			my $subJob = $self->_queueJob({
				type => "FBA",
				jobdata => {
					postprocess_command => "queue_wildtype_phenotype_reconciliation",
					postprocess_args => [$input],
					fbaref => $fbameta->[8]
				},
				queuecommand => "queue_wildtype_phenotype_reconciliation",
				"state" => $self->_defaultJobState()
			});
			push(@{$joblist},$subJob->{id});
		}
		$job = $self->_queueJob({
			type => "FBAJobSet",
			jobdata => {
				postprocess_command => "queue_wildtype_phenotype_reconciliation",
				postprocess_args => [$input],
				jobs => $joblist
			},
			queuecommand => "queue_wildtype_phenotype_reconciliation",
			"state" => $self->_defaultJobState()
		});
	} elsif ($input->{queueSensitivityAnalysis} == 1) {
		#Code to post process job
		if (defined($input->{gapFills})) {
			foreach my $gf (@{$input->{gapFills}}) {
				my $gapfill = $self->_get_msobject("GapFill",$input->{gapFill_workspace},$gf);
				if (!defined($gapfill->fbaFormulation()->fbaResults())) {
					my $msg = "Gap filling failed!";
					$self->_error($msg,'queue_gapgen_model');
				}
				$gapfill->parseGapfillResults($gapfill->fbaFormulation()->fbaResults()->[0]);
				my $output = $self->_save_msobject($gapfill,"GapFill",$input->{gapFill_workspace},$gf,"queue_gapgen_model");
			}
		}
		if (defined($input->{gapGens})) {
			foreach my $gg (@{$input->{gapGens}}) {
				my $gapgen = $self->_get_msobject("GapGen",$input->{gapGen_workspace},$gg);
				if (!defined($gapgen->fbaFormulation()->fbaResults())) {
					my $msg = "Gap generation failed!";
					$self->_error($msg,'queue_gapgen_model');
				}
				$gapgen->parseGapgenResults($gapgen->fbaFormulation()->fbaResults()->[0]);
				my $output = $self->_save_msobject($gapgen,"GapGen",$input->{gapGen_workspace},$gg,"queue_gapgen_model");
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
		$job = {};
	}	
    $self->_clearContext();
    #END queue_wildtype_phenotype_reconciliation
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_wildtype_phenotype_reconciliation');
    }
    return($job);
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
    my($job);
    #BEGIN queue_reconciliation_sensitivity_analysis
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace","phenotypeSet"],{
		fba_formulation => undef,
		phenotypeSet_workspace => $input->{workspace},
		model_workspace => $input->{workspace},
		gapFills => undef,
		gapGens => undef,
		queueReconciliationCombination => 0,
		overwrite => 0,
		simPhenoID => undef
	});
	#Retreiving model
	my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
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
		my $output = $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_reconciliation_sensitivity_analysis",1,$fba->uuid());
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
		my $joblist = [];
		my $postProcArgs = {
			model => $input->{model},
			workspace => $input->{workspace},
			phenotypeSet => $input->{phenotypeSet},
			model_workspace => $input->{model_workspace},
			phenotypeSet_workspace => $input->{phenotypeSet_workspace},
			gapFills => $input->{gapFills},
			gapGens => $input->{gapGens},
			simPhenoID => $phenoSenseAnalysis->{id}
		};
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
					my $output = $self->_save_msobject($newmod,"FBAModel","NO_WORKSPACE",$newmod->uuid(),"queue_reconciliation_sensitivity_analysis",1,$newmod->uuid());
					$output = $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_reconciliation_sensitivity_analysis",1,$fba->uuid());
					push(@{$phenoSenseAnalysis->{fbaids}},$fba->uuid());
					push(@{$phenoSenseAnalysis->{reconciliationSolutionSimulations}},["GF",$gf->uuid(),$j,$gf->gapfillingSolutions()->[$j]->solrxn(),$gf->gapfillingSolutions()->[$j]->biocpd(),[]]);
					my $subJob = $self->_queueJob({
						type => "FBA",
						jobdata => {
							postprocess_command => undef,
							postprocess_args => undef,
							fbaref => $fba->uuid()
						},
						queuecommand => "queue_reconciliation_sensitivity_analysis",
						"state" => $self->_defaultJobState()
					});
					push(@{$joblist},$subJob->{id});		
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
					$output = $self->_save_msobject($newmod,"FBAModel","NO_WORKSPACE",$newmod->uuid(),"queue_reconciliation_sensitivity_analysis",1,$newmod->uuid());
					$output = $self->_save_msobject($fba,"FBA","NO_WORKSPACE",$fba->uuid(),"queue_reconciliation_sensitivity_analysis",1,$fba->uuid());
					push(@{$phenoSenseAnalysis->{fbaids}},$fba->uuid());
					push(@{$phenoSenseAnalysis->{reconciliationSolutionSimulations}},["GG",$gg->uuid(),$j,$gg->gapgenSolutions()->[$j]->solrxn(),$gg->gapgenSolutions()->[$j]->biocpd(),[]]);
					my $subJob = $self->_queueJob({
						type => "FBA",
						jobdata => {
							postprocess_command => undef,
							postprocess_args => undef,
							fbaref => $fba->uuid()
						},
						queuecommand => "queue_reconciliation_sensitivity_analysis",
						"state" => $self->_defaultJobState()
					});
					push(@{$joblist},$subJob->{id});
				}
			}
			$solIndex++;
		}    
		#Saving job object
		#print "Saving!\n";
		#print join("\n",@{$phenoSenseAnalysis->{fbaids}})."\n";
		$output = $self->_save_msobject($phenoSenseAnalysis,"PhenoSenseAnalysis",$input->{workspace},$phenoSenseAnalysis->{id},"queue_reconciliation_sensitivity_analysis");
		$job = $self->_queueJob({
			type => "FBAJobSet",
			jobdata => {
				postprocess_command => "queue_reconciliation_sensitivity_analysis",
				postprocess_args => [$postProcArgs],
				jobs => $joblist
			},
			queuecommand => "queue_reconciliation_sensitivity_analysis",
			"state" => $self->_defaultJobState()
		});
	} else {
		my $phenoSense = $self->_get_msobject("PhenoSenseAnalysis",$input->{workspace},$input->{simPhenoID});
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
#				$self->_workspaceServices()->delete_object_permanently({
#					type => "Model",
#					id => $fba->model_uuid(),
#					workspace => "NO_WORKSPACE"
#				});
#				$self->_workspaceServices()->delete_object_permanently({
#					type => "FBA",
#					id => $fba->uuid(),
#					workspace => "NO_WORKSPACE"
#				});
			}
		}
		#delete $phenoSense->{fbaids};
		my $output = $self->_save_msobject($phenoSense,"PhenoSenseAnalysis",$input->{workspace},$input->{simPhenoID},"queue_reconciliation_sensitivity_analysis");
		$job = {};
	}
    #END queue_reconciliation_sensitivity_analysis
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_reconciliation_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_reconciliation_sensitivity_analysis');
    }
    return($job);
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
    my($job);
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
	my $model = $self->_get_msobject("FBAModel",$phenoSense->{model_workspace},$phenoSense->{model});
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
		$job = $self->_queueJob({
			type => "FBA",
			jobdata => {
				postprocess_command => "queue_combine_wildtype_phenotype_reconciliation",
				postprocess_args => [{
					fbaid => $fba->uuid(),
					PhenoSensitivityAnalysis => $input->{PhenoSensitivityAnalysis},
					out_model => $input->{out_model},
					workspace => $input->{workspace},
				}],
				fbaref => $fba->uuid()
			},
			queuecommand => "queue_combine_wildtype_phenotype_reconciliation",
			"state" => $self->_defaultJobState()
		});
	} else {
		my $fba = $self->_get_msobject("FBA","NO_WORKSPACE",$input->{fbaid});
		my $data;
		$job = {};
		#$output = $self->_save_msobject($data,"CombinedReconciliation",$input->{workspace},$data->{id},"queue_combine_wildtype_phenotype_reconciliation");
	}
	$self->_clearContext();
    #END queue_combine_wildtype_phenotype_reconciliation
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_combine_wildtype_phenotype_reconciliation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_combine_wildtype_phenotype_reconciliation');
    }
    return($job);
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
    my($job);
    #BEGIN run_job
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["job"],{usecpx => 0});
    $job = $self->_getJob($input->{job});
    Bio::KBase::ObjectAPI::utilities::CurrentJobID($input->{job});
    eval {
	    $self->_jobserv()->set_job_status({
		   	jobid => $job->{id},
		   	status => "running",
		   	auth => $self->_authentication(),
		   	currentStatus => $job->{status},
		   	jobdata => {error => "None"}
	    });
    };
    my $params = $job->{jobdata};
    $params->{auth} = $job->{auth};
    my $command = $job->{queuecommand};
    $self->$command($params);
    eval {
	    $job = $self->_jobserv()->set_job_status({
	    	jobid => $input->{job},
	    	status => "done",
	    	auth => $self->_authentication(),
	    	currentStatus => "running",
	    	jobdata => {error => "None"}
	    });
    };
    $self->_clearContext();
    #END run_job
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to run_job:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'run_job');
    }
    return($job);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to queue_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_job');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($job);
    #BEGIN queue_job
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["method","parameters"],{});
	$job = $self->_queueJob({
		type => "KBaseFBAModeling",
		jobdata => $input->{parameters},
		queuecommand => $input->{method},
		"state" => "queued",
		auth => $self->_authentication(),
	});
	$self->_clearContext();
    #END queue_job
    my @_bad_returns;
    (ref($job) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"job\" (value was \"$job\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to queue_job:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'queue_job');
    }
    return($job);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_cofactors:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_cofactors');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN set_cofactors
    $self->_setContext($ctx,$input);

	# Get the biochemistry from the workspace.
	my $biochem = $self->_get_msobject("Biochemistry", $input->{biochemistry_workspace}, $input->{biochemistry});
	
	# Set the value for the isCofactor flag.
	my $value = 1;
	if ($input->{reset}) {
		$value = 0;
	}
	
	# Find each compound and set the isCofactor flag.
	foreach my $cpdid (@{$input->{cofactors}}) {
		my $cpd = $biochem->searchForCompound($cpdid);
		if (defined($cpd)) {
			$cpd->isCofactor($value);
		} else {
			my $msg = "Compound ".$cpdid." was not found in biochemistry database ".$input->{biochemistry_workspace}."/".$input->{biochemistry};
			$self->_error($msg);
		}
	}
	
	# Save the updated biochemistry to the workspace.
   	$output = $self->_save_msobject($biochem,"Biochemistry",$input->{biochemistry_workspace},$input->{biochemistry});
	
    $self->_clearContext();
    #END set_cofactors
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to set_cofactors:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_cofactors');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to find_reaction_synonyms:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'find_reaction_synonyms');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN find_reaction_synonyms
    $self->_setContext($ctx,$input);

	# Get the biochemistry from the workspace.
	my $biochem = $self->_get_msobject("Biochemistry", $input->{biochemistry_workspace}, $input->{biochemistry});
	
	# Build a hash of compounds that are cofactors.
	my $cofactors = { };
	my $compoundList = $biochem->compounds();
	foreach my $cpd (@{$compoundList}) {
		if ($cpd->isCofactor()) {
			$cofactors->{$cpd->id()} = 1;
		}
	}
	
	# Iterate over the list of reactions and identify the net reaction for each one.
	my $netReactions = { };
	my $excludedReactions = [ ];
	my $reactionList = $biochem->reactions();
	my $moreCofactors = { };
	foreach my $rxn (@{$reactionList}) {
		my $nonCofactorCompounds = [ ];
		my $numReagents = @{$rxn->reagents()};
		foreach my $reagent (@{$rxn->reagents()}) {
			# Skip if compound is a cofactor within reaction.
			next if ($reagent->isCofactor());
	
			# Skip if compound is a cofactor within cofactor list.
			my $cpd = $reagent->compound();
			next if (exists($cofactors->{$cpd->id()}));
	
			# Add the compound to the list of non-cofactor compounds for this reaction.
			push(@$nonCofactorCompounds, $cpd->id());
		}
		
		# Only add to the net reaction hash if there is at least one non-cofactor compound.
		my $numcpds = @$nonCofactorCompounds;
		if ($numcpds > 0) {
			$netReactions->{$rxn->id()} = { compounds => $nonCofactorCompounds, reaction => $rxn };
		} else {
			my $excludedrxn = { id => $rxn->id(), name => $rxn->name, definition => $rxn->createEquation( { format => "formula" } ) };
			push(@$excludedReactions, $excludedrxn);	
		}
	}
	my $numExcluded = @$excludedReactions;
	
	# Iterate over the list of reactions and identify the reaction synonyms.
	# Two reactions are synonyms if the net reaction compound lists are the same.
	my $reactionSynonyms = [ ];
	foreach my $rxn (@{$reactionList}) {
		# Skip if reaction is not in the net reaction hash.
		my $found = $netReactions->{$rxn->id()}->{compounds};
		next if (!defined($found));
		
		# Check each net reaction and see if the compound list matches this reaction.
		# The synonyms will at least include this reaction.  Maybe should exclude the same reaction from the list???
		my $rxnsyn = { primary => $rxn->id(), synonyms => [] };	
		foreach my $key (keys %$netReactions) {
			my $cpds = $netReactions->{$key}->{compounds};
			if (@$cpds ~~ @$found) {
				my $synrxn = $netReactions->{$key}->{reaction};
				my $rxndef = { id => $synrxn->id(), name => $synrxn->name, definition => $synrxn->createEquation( { format => "formula" } ) };
				push(@{$rxnsyn->{synonyms}}, $rxndef);
			}
		}
		push(@$reactionSynonyms, $rxnsyn);
	}
	my $numSynonyms = @$reactionSynonyms;
	
	# Create the reaction synonyms object and save it to the workspace.
	my $object = { 
		version => 1,
		biochemistry => $input->{biochemistry},
		biochemistry_workspace => $input->{biochemistry_workspace},
		synonym_list => $reactionSynonyms,
		excluded_list => $excludedReactions
	};
	my $metadata = {
		number_synonyms => $numSynonyms,
		number_excluded => $numExcluded,
		biochemistry_ref => $biochem->_reference()
	};
	$output = $self->_save_msobject($object,"ReactionSynonyms",$input->{workspace},$input->{reaction_synonyms},{meta => $metadata});
    $self->_clearContext();
    #END find_reaction_synonyms
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to find_reaction_synonyms:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'find_reaction_synonyms');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to role_to_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'role_to_reactions');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN role_to_reactions
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["templateModel","workspace"],{});
	my $template = $self->_get_msobject("ModelTemplate",$params->{workspace},$params->{templateModel});
	$output = $template->roleToReactions();
	$self->_clearContext();
    #END role_to_reactions
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to role_to_reactions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'role_to_reactions');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to reaction_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'reaction_sensitivity_analysis');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN reaction_sensitivity_analysis
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["model","workspace"],{
		model_ws => $input->{workspace},
		rxnsens_uid => undef,
		type => "unknown",
		delete_noncontributing_reactions => 0,
		fba_ref => undef,
		reactions_to_delete => undef,
		gapfill_ws => $input->{workspace},
		gapfill_solution_id => undef,
		rxnprobs_id => undef,
		rxnprobs_ws => $input->{workspace},
	});
    if ( ! ( defined($input->{reactions_to_delete}) || defined($input->{gapfill_solution_id}) ) ) {
		my $msg = "Must specify either reactions_to_delete or a gapfill solution ID (if both are specified the gapfill solution is attemtped first)";
		$self->_error($msg);
    }
    # If the user does not specify a sign we add both directions to the list of things to delete.
    my $processedReactions = [];
    if ( defined($input->{reactions_to_delete}) ) {
	for ( my $i=0; $i<@{$input->{reactions_to_delete}}; $i++) { 
	    my $rxn = $input->{reactions_to_delete}->[$i];
	    if ( $rxn =~ /^[+-]/ ) {
		push(@$processedReactions, $rxn);
	    } else {
		push(@$processedReactions, "+".$rxn);
		push(@$processedReactions, "-".$rxn);
	    }
	}
    }
    $input->{reactions_to_delete} = $processedReactions;
    # If gapfill solution is defined we need to get the reactions associated with it.
    # We only try to get reactions that are acutally in the model.
    my $model = $self->_get_msobject("FBAModel",$input->{model_ws},$input->{model});
    if ( defined($input->{gapfill_solution_id}) ) {
	        # Note - this automatically changes the names to '+-' stuff
		my $rxnlist = $self->_get_gapfill_solution_reactions($input->{gapfill_solution_id}, $input->{gapfill_ws}, $model);
		if ( @{$rxnlist} == 0 ) {
		    my $msg = "No reactions in the specified gapfill solution were found in the model (did you integrate the gapfill solution first?)";
		    $self->_error($msg, "reaction_sensitivity_analysis");
		}
		if ( defined($input->{rxnprobs_id}) ) {
		    $rxnlist = $self->_sort_gapfill_solution_reactions($rxnlist, $input->{rxnprobs_id}, $input->{rxnprobs_ws});
		}
		if ( defined($input->{reactions_to_delete}) ) {
		    push(  @{$input->{reactions_to_delete}}, @{$rxnlist} );
		} else {
		    $input->{reactions_to_delete} = $rxnlist;
		}
    }
	my $formulation = $self->_setDefaultFBAFormulation({});
	#Creating FBAFormulation Object
	my $fba = $self->_buildFBAObject($formulation,$model);
	$fba->fva(1);
	push(@{$fba->outputfiles()},"FBAExperimentOutput.txt");
	$fba->parameters()->{"deletion experiments"} = "";
	for (my $i=0; $i < @{$input->{reactions_to_delete}}; $i++) {
		if (length($fba->parameters()->{"deletion experiments"}) > 0) {
			$fba->parameters()->{"deletion experiments"} .= ";";
		}
		$fba->parameters()->{"deletion experiments"} .= $input->{reactions_to_delete}->[$i].":Complete:".$input->{reactions_to_delete}->[$i];
	}
	if ($input->{delete_noncontributing_reactions} == 1) {
		$fba->parameters()->{"delete noncontributing reactions"} = 1;
	}
	$fba->parameters()->{"optimize metabolite production if objective is zero"} = 1;
	my $objective;
    eval {
		local $SIG{ALRM} = sub { die "FBA timed out! Model likely contains numerical instability!" };
		alarm 600;
		$objective = $fba->runFBA();
		alarm 0;
	};
	if ($@) {
		$self->_error($@);
    }
    if (!defined($objective)) {
    	$self->_error("FBA failed with no solution returned!");
    }
	my $fbameta = $self->_save_msobject($fba,"FBA",$input->{workspace},$fba->id(),{hidden => 1});
	my $kbid = $self->_get_new_id($model->id().".rxnsens.");
	if (!defined($input->{rxnsens_uid})) {
		$input->{rxnsens_uid} = $kbid;
	}
	my $object = Bio::KBase::ObjectAPI::ReactionSensitivity->new({
		id => $kbid,
		fbamodel_ref => $model->_reference(),
		type => $input->{type},
		deleted_noncontributing_reactions => $input->{delete_noncontributing_reactions},
		integrated_deletions_in_model => 0,
		reactions => [],
		corrected_reactions => []
	});
	my $deletehash = {};
	for (my $j=0; $j < @{$input->{reactions_to_delete}}; $j++ ) {
	    $deletehash->{$input->{reactions_to_delete}->[$j]} = 1;
	}

	my $array = $fba->fbaResults()->[0]->outputfiles()->{"FBAExperimentOutput.txt"};
	my $inactiveRxns = {};
	for (my $i=1; $i < @{$array}; $i++) {
		my $row = [split(/\t/,$array->[$i])];
		my ($direction, $rxnid);
		($rxnid = $row->[0]) =~ s/[+-]//;
		if ( $row->[0] =~ /^\+/ ) {
		    $direction = ">";
		} elsif ( $row->[0] =~ /^-/ ) {
		    $direction = "<";
		}
		my $sensrxn = {
			id => $object->id().".rxn.".($i-1),
			modelreaction_ref => $model->_reference()."/modelreactions/id/".$rxnid."_c0",
			growth_fraction => $row->[5],
			"delete" => 0,
			deleted => 0,
			direction => $direction,
			biomass_compounds => [],
			new_inactive_rxns => [],
			new_essentials => [split(/;/,$row->[8])]
		};
		if ($row->[7] eq "DELETED") {
		    $sensrxn->{"delete"} = 1;
		} else {
		    my $growth_fraction = $row->[5];
		    my $inactive_rxns = [split(/;/,$row->[7])];
		    my $ok_rxns = [];
		    for ( my $k=0; $k < @{$inactive_rxns}; $k++ ) {
			# Eliminate reactions that were tested for deletion from the list of inactive reactions
			if ( ! defined( $deletehash->{$inactive_rxns->[$k]} ) ) {
			    $inactiveRxns->{$inactive_rxns->[$k]}->{required}->{$row->[0]} = 1;
			    push(@{$ok_rxns}, $inactive_rxns->[$k]);
			}
		    }
		    # TODO - this cutoff should match the one in the MFA toolkit.
		    if ( @{$ok_rxns} == 0 && $growth_fraction > 0.00001) {
			$sensrxn->{"delete"} = 1;
		    } elsif ( @{$ok_rxns} > 0 ) {
			$sensrxn->{"new_inactive_rxns"} = $ok_rxns;
		    }
		}
		if ($row->[6] ne "NA") {
		    $sensrxn->{"biomass_compounds"} = [split(/;/,$row->[6])];
		}
		$object->add("reactions",$sensrxn);
	}
	foreach my $rxn (keys(%{$inactiveRxns})) {
		$inactiveRxns->{$rxn} = $object->add("corrected_reactions",{
			modelreaction_ref => $model->_reference()."/modelreactions/id/".$rxn."_c0",
			normalized_required_reaction_count => 0,
			required_reactions => [keys(%{$inactiveRxns->{required}})]
		});
	}
	my $rxns = $object->reactions();
	for (my $i=0; $i < @{$rxns}; $i++) {
		my $rxn = $rxns->[$i];
		if ( @{$rxn->new_inactive_rxns()} == 0 ) {
		    next;
		}
		my $value = 1/@{$rxn->new_inactive_rxns()};
		$rxn->normalized_activated_reaction_count(0);
		for (my $j=0; $j < @{$rxn->new_inactive_rxns()}; $j++) {
			my $inactiveRxn = $inactiveRxns->{$rxn->new_inactive_rxns()->[$j]};
			$rxn->normalized_activated_reaction_count($rxn->normalized_activated_reaction_count()+1/@{$inactiveRxn->required_reactions()});
			$inactiveRxn->normalized_required_reaction_count($inactiveRxn->normalized_required_reaction_count()+$value);
		}
	}
	$output = $self->_save_msobject($object,"RxnSensitivity",$input->{workspace},$input->{rxnsens_uid});
	$self->_clearContext();
    #END reaction_sensitivity_analysis
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to reaction_sensitivity_analysis:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'reaction_sensitivity_analysis');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to filter_iterative_solutions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'filter_iterative_solutions');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN filter_iterative_solutions
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["model","workspace", "cutoff", "gapfillsln"],{
		input_model_ws => $input->{workspace},
		outmodel => $input->{model}	
    });

    my $model = $self->_get_msobject("FBAModel",$input->{input_model_ws},$input->{model});
    my $parsedid = $self->_parse_gapfillsolution_id($input->{gapfillsln});
    my $gapfill = $self->_get_msobject("Gapfilling", $input->{input_model_ws}, $parsedid->[0]);
    my $problemReport = $gapfill->fba()->outputfiles()->{"ProblemReport.txt"};
    # Map from reaction ID to the direction to delete in the model...
    my $deleteDirections = {};
    # Parse the ProblemReport.txt to get a list of reactions aded to the model to actiave each inactive reaction.
    # Start at 1 to skip the header
    # Apply the cutoff and flag reactions for deletion if they are part of a too-costly solution.
    for (my $i=1; $i<@{$problemReport}; $i++) {
	my $prString = $problemReport->[$i];
	my $spl = [];
	@$spl = split(/;/, $prString);
	my $obj = $spl->[1];
	my $solution = $spl->[2];
	# This should contain an array of (reactionID, direction) pairs.
	# Direction should be > or <
	my $slnrxnarray = $self->_parse_problem_report_solution($solution);
	my $numrxns = @{$slnrxnarray};
	my $norm = $obj/$numrxns;
	# Remove high-cost pathways.
	if ( $norm > $input->{cutoff} ) {
	    for (my $j=0; $j<@{$slnrxnarray}; $j++) {
		my $rxnid = $slnrxnarray->[$j]->[0];
		my $dir = $slnrxnarray->[$j]->[1];
		if ( defined($deleteDirections->{$rxnid} )) {
		    if ( ( $deleteDirections->{$rxnid} eq  $dir ) ) {
			next;
		    } else {
			$deleteDirections->{$rxnid} = "=";
		    }
		} else {
		    $deleteDirections->{$rxnid} = $dir;
		}
	    }
	}
    }

    foreach my $key ( keys(%{$deleteDirections}) ) {
	my $modelrxn = $model->searchForReaction($key);
	if ( ! defined($modelrxn) ) {
	    # This could happen because of previous filtering (e.g. a normal reaction_sensitivity_analysis)
#	    print STDERR "WARNING: Reaction $key flagged for deletion but not found in model";
	    next;
	}
	if ( $deleteDirections->{$key} eq "=" ) {
	    # Both directions were flagged for deletion, so we just delete the reaction.
	    $model->manualReactionAdjustment( { reaction => $key,
						removeReaction => 1
					      } );
	} else {
	    # What is the direction in the model?
	    my $modelrxndir = $modelrxn->direction();
	    # Is the direction the same as deleteDirections?
	    if ( $modelrxndir eq $deleteDirections->{$key} ) {
		# If YES, delete the reaction.
		$model->manualReactionAdjustment( { reaction => $key,
						    removeReaction => 1 } );
	    } elsif ( $modelrxndir eq "=" ) {
		# If the model reaction is reversible we assume this means
		# that gapfilling changed the reversibility of that reaction.
		my($newdir);
		if ( $deleteDirections->{$key} eq ">" ) { $newdir = "<"; }
		else { $newdir = ">"; }
		$model->manualReactionAdjustment( { reaction => $key,
						    direction => $newdir } );
	    }
	}
    }

    $output = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{outmodel});

    #END filter_iterative_solutions
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to filter_iterative_solutions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'filter_iterative_solutions');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to delete_noncontributing_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_noncontributing_reactions');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN delete_noncontributing_reactions
    $self->_setContext($ctx,$input);
	$input = $self->_validateargs($input,["rxn_sensitivity","workspace"],{
		rxn_sensitivity_ws => $input->{workspace},
		new_model_uid => undef,
		new_rxn_sensitivity_uid => undef
	});
	my $rxnsens = $self->_get_msobject("RxnSensitivity",$input->{rxn_sensitivity_ws},$input->{rxn_sensitivity});
	$rxnsens->{integrated_deletions_in_model} = 1;
	my $model = $rxnsens->fbamodel();
	for (my $i=0; $i < @{$rxnsens->{reactions}}; $i++) {
		if ($rxnsens->{reactions}->[$i]->{"delete"} eq "1") {
			my $rxn = $model->searchForReaction($rxnsens->{reactions}->[$i]->{reaction});
			if (defined($rxn)) {
			    if ( ! defined($rxnsens->{reactions}->[$i]->{direction} ) ) {
				# For reverse compatibility with old RxnSensitivity objects
				$model->remove("modelreactions", $rxn);
			    } elsif ($rxn->direction eq $rxnsens->{reactions}->[$i]->{direction}) {
				$model->remove("modelreactions",$rxn);
			    } else {
				# Change from a reversible reaction to an irreversible one
				# (if model has < and rxnsensitivity had > or vice versa we just ignore it, maybe it was just already deleted somewhere else)
				if ( $rxn->direction eq "=" ) {
				    # This should never happen but just in case
				    if ( $rxnsens->{reactions}->[$i]->{direction} eq "=" ) {
					$model->remove("modelreactions", $rxn);
				    } elsif ( $rxnsens->{reactions}->[$i]->{direction} eq ">" ) {
					$model->manualReactionAdjustment( { reaction => $rxnsens->{reactions}->[$i]->{reaction},
									    direction => "<" } );
				    } elsif ( $rxnsens->{reactions}->[$i]->{direction} eq "<" ) {
					$model->manualReactionAdjustment( { reaction => $rxnsens->{reactions}->[$i]->{reaction},
									    direction => ">" } );
				    }
				}
			    }
			}
			$rxnsens->{reactions}->[$i]->{"deleted"} = 1;
		}
	}
	if (defined($input->{new_model_uid})) {
		$output = $self->_save_msobject($model,"FBAModel",$input->{workspace},$input->{new_model_uid});
	} else {
		$output = $self->_save_msobject($model,"FBAModel",$model->_wsworkspace(),$model->_wsname());
	}
	if (defined($input->{new_rxn_sensitivity_uid})) {
		$self->_save_msobject($rxnsens,"RxnSensitivity",$$model->_wsworkspace(),$model->_wsname());
	} else {
		$self->_save_msobject($rxnsens,"RxnSensitivity",$model->_wsworkspace(),$model->_wsname());
	}
	$self->_clearContext();
    #END delete_noncontributing_reactions
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to delete_noncontributing_reactions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_noncontributing_reactions');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to annotate_workspace_Genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'annotate_workspace_Genome');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN annotate_workspace_Genome
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["Genome_uid","workspace"],{
		Genome_ws => $params->{workspace},
		new_uid => $params->{Genome_uid},
		annotation_parameters => {}
	});
	my $genomeObj = $self->_get_msobject("Genome",$params->{Genome_ws},$params->{Genome_uid});
	$self->_annotate_genome($genomeObj,$params->{annotation_parameters});
  	$output = $self->_save_msobject($genomeObj,"Genome",$params->{workspace},$params->{new_uid});
	$self->_clearContext();
    #END annotate_workspace_Genome
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to annotate_workspace_Genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'annotate_workspace_Genome');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fasta_to_ProteinSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fasta_to_ProteinSet');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN fasta_to_ProteinSet
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["fasta","workspace"],{
		uid => undef,
		name => undef,
		sourceid => undef,
		source => undef,
		type => "Organism"
	});
	$output = $self->_build_sequence_object("ProteinSet",$params);
    $self->_clearContext();
    #END fasta_to_ProteinSet
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fasta_to_ProteinSet:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fasta_to_ProteinSet');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to ProteinSet_to_Genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'ProteinSet_to_Genome');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN ProteinSet_to_Genome
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["ProteinSet_uid","workspace"],{
		ProteinSet_ws => $params->{workspace},
		uid => undef,
		taxonomy => undef,
		scientific_name => "Unknown sample",
		domain => "Bacteria",
		genetic_code => "11",
		source => undef,
		source_id => undef,
		annotation_parameters => {}
	});
	my $kbid = $self->_get_new_id("kb|g");
	if (!defined($params->{source_id})) {
		$params->{source} = "KBase";
		$params->{source_id} = $kbid;
	}
	if (!defined($params->{uid})) {
		$params->{uid} = $kbid;
	}
	my $size = 0;
	my $protObj = $self->_get_msobject("ProteinSet",$params->{ProteinSet_ws},$params->{ProteinSet_uid});
	my $proteins = $protObj->proteins();
	my $sequences = [];
	for (my $i=0; $i < @{$proteins}; $i++) {
		$size += length($proteins->[$i]->sequence());
		push(@{$sequences},$proteins->[$i]->sequence());
	}
	@{$sequences} = sort(@{$sequences});
	$size = 3*$size;
	my $genomeObj = {
		id => $kbid,
		scientific_name => $params->{scientific_name},
		domain => $params->{domain},
		genetic_code => $params->{genetic_code},
		dna_size => $size,
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => $params->{source},
		source_id => $params->{source_id},
		md5 => Digest::MD5::md5_hex(join(";",@{$sequences})),
		taxonomy => $params->{taxonomy},
		gc_content => 0,
		complete => 1,
		publications => [],
		features => [],
    };
	for (my $i=0; $i < @{$proteins}; $i++) {
		push(@{$genomeObj->{features}},{
			id => $proteins->[$i]->id(),
			location => [],
			type => "peg",
			function => $proteins->[$i]->function(),
			md5 => $proteins->[$i]->md5(),
			protein_translation => $proteins->[$i]->sequence(),
			protein_translation_length => $proteins->[$i]->length(),
			dna_sequence_length => 3*$proteins->[$i]->length(),
			publications => [],
			subsystems => [],
			protein_families => $proteins->[$i]->protein_families(),
			aliases => $proteins->[$i]->aliases(),
			annotations => $proteins->[$i]->annotations(),
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => []
		});
	}
	foreach my $param (keys(%{$params->{annotation_parameters}})) {
		if ($param =~ m/^call/) {
			delete $params->{annotation_parameters}->{$param};
		}
	}
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	$genomeObj->parent($self->_KBaseStore());
	$self->_annotate_genome($genomeObj,$params->{annotation_parameters});
  	$output = $self->_save_msobject($genomeObj,"Genome",$params->{workspace},$params->{uid});
	$self->_clearContext();
    #END ProteinSet_to_Genome
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to ProteinSet_to_Genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'ProteinSet_to_Genome');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to fasta_to_ContigSet:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fasta_to_ContigSet');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN fasta_to_ContigSet
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["fasta","workspace"],{
		uid => undef,
		name => undef,
		sourceid => undef,
		source => undef,
		type => "Organism"
	});
	$output = $self->_build_sequence_object("ContigSet",$params);
    $self->_clearContext();
    #END fasta_to_ContigSet
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to fasta_to_ContigSet:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'fasta_to_ContigSet');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to ContigSet_to_Genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'ContigSet_to_Genome');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN ContigSet_to_Genome
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["ContigSet_uid","workspace"],{
		ContigSet_ws => $params->{workspace},
		uid => undef,
		taxonomy => "Bacteria",
		scientific_name => "Unknown sample",
		domain => "Bacteria",
		genetic_code => "11",
		source => undef,
		source_id => undef,
		annotation_parameters => {}
	});
	my $kbid = $self->_get_new_id("kb|g");
	if (!defined($params->{source_id})) {
		$params->{source} = "KBase";
		$params->{source_id} = $kbid;
	}
	if (!defined($params->{uid})) {
		$params->{uid} = $kbid;
	}
	my $size = 0;
	my $gc = 0;
	my $contigObj = $self->_get_msobject("ContigSet",$params->{ContigSet_ws},$params->{ContigSet_uid});
	my $contigs = $contigObj->contigs();
	for (my $i=0; $i < @{$contigs}; $i++) {
		my $seq = $contigs->[$i]->sequence();
		$size += length($seq);
		for ( my $j = 0 ; $j < length($seq) ; $j++ ) {
			if ( substr( $seq, $j, 1 ) =~ m/[gcGC]/ ) {
				$gc++;
			}
		}
	}
	$gc = $gc/$size;
	my $numcontigs = @{$contigs};
	my $genomeObj = {
		id => $kbid,
		scientific_name => $params->{scientific_name},
		domain => $params->{domain},
		genetic_code => $params->{genetic_code},
		dna_size => $size,
		num_contigs => $numcontigs,
		contig_lengths => [],
		contig_ids => [],
		source => $params->{source},
		source_id => $params->{source_id},
		md5 => $contigObj->md5(),
		taxonomy => $params->{taxonomy},
		contigset_ref => $contigObj->_reference(),
		gc_content => $gc,
		complete => 1,
		publications => [],
		features => [],
    };
	for (my $i=0; $i < @{$contigs}; $i++) {
		push(@{$genomeObj->{contig_ids}},$contigs->[$i]->id());
		push(@{$genomeObj->{contig_lengths}},$contigs->[$i]->length());
	}
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	$genomeObj->parent($self->_KBaseStore());
	$self->_annotate_genome($genomeObj,$params->{annotation_parameters});
  	$output = $self->_save_msobject($genomeObj,"Genome",$params->{workspace},$params->{uid});
	$self->_clearContext();
    #END ContigSet_to_Genome
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to ContigSet_to_Genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'ContigSet_to_Genome');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to probanno_to_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'probanno_to_genome');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN probanno_to_genome
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["pa_id","workspace"],{
		g_id => undef,
		pa_ws => $params->{workspace},
		threshold => undef,
	});
	if (!defined($params->{g_id})) {
		$params->{g_id} = $self->_get_new_id("kb|g.");
	}
	my $pa = $self->_get_msobject("ProbabilisticAnnotation",$params->{pa_ws},$params->{pa_id});
	my $gn = $self->_get_msobject("Genome",$pa->{genome_workspace},$pa->{genome});
	if (!defined($pa->roleset_probabilities())) {
		$self->_error("No annotations in probanno!","probanno_to_genome");
	}
	my $ftrs = $gn->features();
	for (my $i=0; $i < @{$ftrs};$i++) {
		my $ftr = $ftrs->[$i];
		if (defined($pa->roleset_probabilities()->{$ftr->id()})) {
			my $function = "";
			for (my $j=0; $j < @{$pa->roleset_probabilities()->{$ftr->id()}};$j++) {
				my $func = $pa->roleset_probabilities()->{$ftr->id()}->[$j];
				if (!defined($params->{threshold}) || $func->[1] > $params->{threshold}) {
					if (length($function) > 0) {
						$function .= " @ ";
					}
					$function .= $func->[0];
				}
			}
			$ftr->function($function);
		} 
	}
	$output = $self->_save_msobject($gn,"Genome",$params->{workspace},$params->{g_id});
	$self->_clearContext();
    #END probanno_to_genome
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to probanno_to_genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'probanno_to_genome');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_mapping:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_mapping');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN get_mapping
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,[],{
		"map" => "default-mapping",
		workspace => "kbase",
	});
    my $map = $self->_get_msobject("Mapping",$input->{workspace},$input->{"map"});
    $output = {
    	id => $input->{workspace}."/".$input->{"map"},
    	name => $map->name(),
    	subsystems => [],
    	roles => [],
    	complexes => []
    };
    my $roles = $map->roles();
    for (my $i=0; $i < @{$roles}; $i++) {
    	my $role = $roles->[$i];
    	push(@{$output->{roles}},{
    		id => $role->id(),
    		name => $role->name(),
    		feature => $role->seedfeature(),
    		aliases => $role->allAliases(),
    		complexes => $role->complexIDs()
    	});
    }
    my $sss = $map->subsystems();
    for (my $i=0; $i < @{$sss}; $i++) {
    	my $ss = $sss->[$i];
    	push(@{$output->{subsystems}},{
    		id => $ss->id(),
    		name => $ss->name(),
    		primclass => $ss->class(),
    		subclass => $ss->subclass(),
    		type => $ss->type(),
    		aliases => $ss->allAliases(),
    		roles => $ss->roleIDs()
    	});
    }
    my $complexes = $map->complexes();
    for (my $i=0; $i < @{$complexes}; $i++) {
    	my $complex = $complexes->[$i];
    	push(@{$output->{complexes}},{
    		id => $complex->id(),
    		name => $complex->name(),
    		aliases => $complex->allAliases(),
    		roles => $complex->roleTuples()
    	});
    }
    #END get_mapping
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_mapping:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_mapping');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_mapping_role:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_mapping_role');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN adjust_mapping_role
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,["map","workspace"],{
		role => undef,
		"new" => undef,
		name => undef,
		feature => undef,
		aliasesToAdd => [],
		aliasesToRemove => [],
		"delete" => undef
	});
    my $map = $self->_get_msobject("Mapping",$input->{workspace},$input->{"map"});
    my $arguments = {};
    if (defined($input->{"new"})) {
    	$arguments->{id} = "new";
    } else {
    	$arguments->{id} = $input->{role};
    }
	if (defined($input->{name})) {
		$arguments->{name} = $input->{name};
	}
	if (defined($input->{feature})) {
		$arguments->{seedfeature} = $input->{feature};
	}
	if (defined($input->{"delete"})) {
		$arguments->{"delete"} = $input->{"delete"};
	}
	if (defined($input->{aliasesToAdd})) {
		$arguments->{aliasToAdd} = $input->{aliasesToAdd};
	}
	if (defined($input->{aliasesToRemove})) {
		$arguments->{aliasToRemove} = $input->{aliasesToRemove};
	}
	my $role = $map->adjustRole($arguments);
	$output = $self->_save_msobject($map,"Mapping",$input->{workspace},$input->{"map"});
    #END adjust_mapping_role
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_mapping_role:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_mapping_role');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_mapping_complex:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_mapping_complex');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN adjust_mapping_complex
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,["map","workspace"],{
		complex => undef,
		"new" => undef,
		name => undef,
		rolesToAdd => [],
		rolesToRemove => [],
		clearRoles => 0,
		"delete" => undef
	});
    my $map = $self->_get_msobject("Mapping",$input->{workspace},$input->{"map"});
    my $arguments = {};
    if (defined($input->{"new"})) {
    	$arguments->{id} = "new";
    } else {
    	$arguments->{id} = $input->{complex};
    }
    my $paramlist = [qw(clearRoles name delete rolesToAdd rolesToRemove)];
    foreach my $param (@{$paramlist}) {
    	if (defined($input->{$param})) {
    		$arguments->{$param} = $input->{$param};
    	}
    }
	my $cpx = $map->adjustComplex($arguments);
	$output = $self->_save_msobject($map,"Mapping",$input->{workspace},$input->{"map"});
    #END adjust_mapping_complex
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_mapping_complex:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_mapping_complex');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_mapping_subsystem:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_mapping_subsystem');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN adjust_mapping_subsystem
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,["map","workspace"],{
		subsystem => undef,
		"new" => undef,
		name => undef,
		type => undef,
		primclass => undef,
		subclass => undef,
		rolesToAdd => [],
		rolesToRemove => [],
		clearRoles => 0,
		"delete" => undef
	});
    my $map = $self->_get_msobject("Mapping",$input->{workspace},$input->{"map"});
    my $arguments = {};
    if (defined($input->{"new"})) {
    	$arguments->{id} = "new";
    } else {
    	$arguments->{id} = $input->{subsystem};
    }
    my $paramlist = [qw(clearRoles name primclass subclass delete type rolesToAdd rolesToRemove)];
    foreach my $param (@{$paramlist}) {
    	if (defined($input->{$param})) {
    		$arguments->{$param} = $input->{$param};
    	}
    }
	my $ss = $map->adjustSubsystem($arguments);
	$output = $self->_save_msobject($map,"Mapping",$input->{workspace},$input->{"map"});
    #END adjust_mapping_subsystem
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_mapping_subsystem:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_mapping_subsystem');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_template_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_template_model');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN get_template_model
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,["templateModel","workspace"],{});
    my $template = $self->_get_msobject("ModelTemplate",$input->{workspace},$input->{templateModel});
    $output = {
    	id => $input->{workspace}."/".$input->{templateModel},
    	name => $template->name(),
    	type => $template->modelType(),
    	domain => $template->domain(),
    	"map" => $template->{_kbaseWSMeta}->{wsid},
    	mappingws => $template->{_kbaseWSMeta}->{ws},
    	reactions => [],
    	biomasses => []
    };
    my $rxns = $template->templateReactions();
    for (my $i=0; $i < @{$rxns}; $i++) {
    	my $rxn = $rxns->[$i];
    	push(@{$output->{reactions}},{
    		id => $rxn->uuid(),
    		compartment => $rxn->compartment()->id(),
    		reaction => $rxn->reaction()->id(),
    		complexes => $rxn->complexIDs(),
    		direction => $rxn->direction(),
    		type => $rxn->type()
    	});
    }
    my $bios = $template->templateBiomasses();
    for (my $i=0; $i < @{$bios}; $i++) {
    	my $bio = $bios->[$i];
    	push(@{$output->{biomasses}},{
    		id => $bio->uuid(),
    		name => $bio->name(),
    		type => $bio->type(),
    		other => $bio->other(),
    		protein => $bio->protein(),
    		dna => $bio->dna(),
    		rna => $bio->rna(),
    		cofactor => $bio->cofactor(),
    		energy => $bio->energy(),
    		cellwall => $bio->cellwall(),
    		lipid => $bio->lipid(),
    		compounds => $bio->compoundTuples()
    	});
    }
    #END get_template_model
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_template_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_template_model');
    }
    return($output);
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
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_template_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_template_fbamodel');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN import_template_fbamodel
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["workspace"],{
    	"map" => "default-mapping",
    	mapping_workspace => "kbase",
    	biochem => "default",
    	biochem_workspace => "kbase",
    	templateReactions => [],
    	templateBiomass => [],
    	name => undef,
    	modelType => "GenomeScale",
    	domain => "Bacteria",
    	uid => undef,
    	ignore_errors => 0
    });
    my $kbid = $self->_get_new_id("kb|template.");
    my $map = $self->_get_msobject("Mapping",$input->{mapping_workspace},$input->{"map"});
	my $bio = $self->_get_msobject("Biochemistry",$input->{biochem_workspace},$input->{biochem});
	if (!defined($input->{uid})) {
    	$input->{uid} = $kbid;
    }
    if (!defined($input->{name})) {
    	$input->{name} = $input->{uid};	
    }
	my $mdlTmp = Bio::KBase::ObjectAPI::KBaseFBA::ModelTemplate->new({
		id => $kbid,
    	name => $input->{name},
		modelType => $input->{modelType},
		domain => $input->{domain},
		mapping_ref => $map->_reference(),
		biochemistry_ref => $bio->_reference(),
    	templateReactions => [],
    	templateBiomasses => []
	});
	$mdlTmp->parent($self->_KBaseStore());
	for (my $i=0; $i < @{$input->{templateReactions}}; $i++) {
		my $row = $input->{templateReactions}->[$i];
		my $rxn = $bio->searchForReaction($row->[0]);
		if (!defined($rxn)) {
			$self->_error("Reaction ".$row->[0]." not found!");
		}
		my $cmp = $bio->searchForCompartment($row->[1]);
		if (!defined($cmp)) {
			$self->_error("Compartment ".$row->[1]." not found!");
		}
		my $cpxs = [];
		for (my $j=0; $j < @{$row->[4]}; $j++) {
			my $cpx = $map->searchForComplex($row->[4]->[$j]);
			if (!defined($cpx)) {
				$self->_error("Complex ".$row->[4]->[$j]." not found!");
			}
			push(@{$cpxs},$cpx->_reference());
		}
		if (!defined($row->[2]) || length($row->[2]) == 0) {
			$row->[2] = $rxn->direction();
		}
		if (!defined($row->[3]) || length($row->[3]) == 0) {
			$row->[3] = "conditional";
		}
		$mdlTmp->add("templateReactions",{
			id => $kbid.".rxn.".$i,
			reaction_ref => $rxn->_reference(),
			compartment_ref => $cmp->_reference(),
			direction => $row->[2],
			type => $row->[3],
			complex_refs => $cpxs
		});
	}
	for (my $i=0; $i < @{$input->{templateBiomass}}; $i++) {
		my $row = $input->{templateBiomass}->[$i];
		my $comps = [];
		my $tmpBio = $mdlTmp->add("templateBiomasses",{
			id => $kbid.".bio.".$i,
			name => $row->[0],
			type => $row->[1],
			dna => $row->[2],
			rna => $row->[3],
			protein => $row->[4],
			lipid => $row->[5],
			cellwall => $row->[6],
			cofactor => $row->[7],
			energy => $row->[8],
			other => $row->[9],
			templateBiomassComponents => []
		});
		for (my $j=0; $j < @{$row->[10]}; $j++) {
			my $comprow = $row->[10]->[$j];
			my $cmp = $bio->searchForCompartment($comprow->[1]);
			if (!defined($cmp)) {
				$self->_error("Compartment ".$comprow->[1]." not found!");
			}
			my $cpd = $bio->searchForCompound($comprow->[0]);
			if (!defined($cpd)) {
				$self->_error("Compound ".$comprow->[0]." not found!");
			}
			my $comp = Bio::KBase::ObjectAPI::KBaseFBA::TemplateBiomassComponent->new({
				id => $tmpBio->id().".cpd.".$j,
				class => $comprow->[2],
				compound_ref => $cpd->_reference(),
				compartment_ref => $cmp->_reference(),
				coefficientType => $comprow->[3],
				coefficient => $comprow->[4]+0,
				linked_compound_refs => [],
				link_coefficients => []
			});
			if (@{$comprow->[6]} > 0) {
				my $linkuuids = [];
				my $linkcoefs = [];
				for (my $k=0; $k < @{$comprow->[6]}; $k++) {
					$cpd = $bio->searchForCompound($comprow->[6]->[$k]->[0]);
					if (!defined($cpd)) {
						$self->_error("Compound ".$comprow->[6]->[$k]->[0]." not found!");
					}
					push(@{$linkuuids},$cpd->uuid());
					push(@{$linkcoefs},$comprow->[6]->[$k]->[1]+0);
				}
				$comp->linked_compound_refs($linkuuids);
				$comp->link_coefficients($linkcoefs);
			}
			$tmpBio->add("templateBiomassComponents",$comp);
		}
	}
    $modelMeta = $self->_save_msobject($mdlTmp,"ModelTemplate",$input->{workspace},$input->{uid});
    $self->_clearContext();
    #END import_template_fbamodel
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_template_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_template_fbamodel');
    }
    return($modelMeta);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_template_reaction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_template_reaction');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN adjust_template_reaction
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,["templateModel","workspace","reaction"],{
		compartment => "c",
		"new" => 0,
		direction => undef,
		type => "conditional",
		complexesToAdd => [],
		complexesToRemove => [],
		clearComplexes => 0,
		"delete" => 0
	});
    my $tempmdl = $self->_get_msobject("ModelTemplate",$input->{workspace},$input->{templateModel});
    my $arguments = {reaction => $input->{reaction}};
    my $paramlist = [qw(compartment new delete clearComplexes direction type complexesToAdd complexesToRemove)];
    foreach my $param (@{$paramlist}) {
    	if (defined($input->{$param})) {
    		$arguments->{$param} = $input->{$param};
    	}
    }
	my $rxn = $tempmdl->adjustReaction($arguments);
	$modelMeta = $self->_save_msobject($tempmdl,"ModelTemplate",$input->{workspace},$input->{templateModel});
    #END adjust_template_reaction
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_template_reaction:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_template_reaction');
    }
    return($modelMeta);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to adjust_template_biomass:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_template_biomass');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($modelMeta);
    #BEGIN adjust_template_biomass
    $self->_setContext($ctx,$params);
    my $input = $self->_validateargs($params,["templateModel","workspace"],{
		biomass => undef,
		"new" => 0,
		"delete" => 0,
		clearBiomassCompounds => 0,
		name => undef,
		type => undef,
		other => undef,
		protein => undef,
		dna => undef,
		rna => undef,
		cofactor => undef,
		energy => undef,
		cellwall => undef,
		lipid => undef,
		compoundsToAdd => [],
		compoundsToRemove => []
	});
    my $tempmdl = $self->_get_msobject("ModelTemplate",$input->{workspace},$input->{templateModel});
    my $arguments = {};
    my $paramlist = [qw(biomass new delete clearBiomassCompounds name type other protein dna rna cofactor energy cellwall lipid compoundsToRemove compoundsToAdd)];
    foreach my $param (@{$paramlist}) {
    	if (defined($input->{$param})) {
    		$arguments->{$param} = $input->{$param};
    	}
    }
	my $bio = $tempmdl->adjustBiomass($arguments);
    $modelMeta = $self->_save_msobject($tempmdl,"ModelTemplate",$input->{workspace},$input->{templateModel});
    #END adjust_template_biomass
    my @_bad_returns;
    (ref($modelMeta) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"modelMeta\" (value was \"$modelMeta\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to adjust_template_biomass:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'adjust_template_biomass');
    }
    return($modelMeta);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to add_stimuli:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_stimuli');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN add_stimuli
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["name","workspace"],{
		biochemid => "default",
		biochem_workspace => "kbase",
		stimuliid => undef,
		abbreviation => $params->{name},
		description => "",
		compounds => [],
		type => undef
	});
	if (!defined($params->{type})) {
		$params->{type} = "environmental";
		if (@{$params->{compounds}} > 0) {
			$params->{type} = "chemical";
		}
	}
	my $allowableTypes = {
		chemical => 1,environmental => 1
	};
	if (!defined($allowableTypes->{$params->{type}})) {
		$self->_error("Input type ".$params->{type}." not recognized!","add_stimuli");
	}
	if (!defined($params->{stimuliid})) {
		$params->{stimuliid} = $self->_get_new_id("stim.");
	}
	my $biochem = $self->_get_msobject("Biochemistry",$params->{biochem_workspace},$params->{biochemid});
	my $obj = {
		description => $params->{stimuliid},
		id => $params->{stimuliid},
		name => $params->{name},
		type => $params->{type},
		abbreviation => $params->{abbreviation},
		description => $params->{description},
		compound_uuids => []
	};
	my $missingCpd;
	if (defined($params->{compounds})) {
		for (my $i=0; $i < @{$params->{compounds}}; $i++) {
			my $cpd = $params->{compounds}->[$i];
			my $cpdobj = $biochem->searchForCompound($cpd);
			if (!defined($cpdobj)) {
				push(@{$missingCpd},$cpd);
			} else {
				push(@{$obj->{compound_uuids}},$cpdobj->uuid());
			}
		}
	}
	if (defined($params->{biochemid})) {
		$biochem->add("stimuli",$obj);
		$output = $self->_save_msobject($biochem,"Biochemistry",$params->{biochem_workspace},$params->{biochemid},"add_stimuli");	
	} else {
		$output = $self->_save_msobject($obj,"Stimuli",$params->{workspace},$params->{stimuliid},"add_stimuli");
	}
	$self->_clearContext();
    #END add_stimuli
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to add_stimuli:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_stimuli');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_regulatory_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_regulatory_model');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN import_regulatory_model
     $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["genome","workspace","regulators"],{
		biochemid => "default",
		biochem_workspace => "kbase",
		regmodel_uid => undef,
		genome_ws => $params->{workspace},
		name => undef,
		type => undef
	});
	if (!defined($params->{type})) {
		$params->{type} = "environmental";
		if (@{$params->{compounds}} > 0) {
			$params->{type} = "chemical";
		}
	}
	my $allowableTypes = {
		chemical => 1,environmental => 1
	};
	if (!defined($allowableTypes->{$params->{type}})) {
		$self->_error("Input type ".$params->{type}." not recognized!","add_stimuli");
	}
	if (!defined($params->{stimuliid})) {
		$params->{stimuliid} = $self->_get_new_id("stim.");
	}
	my $biochem = $self->_get_msobject("Biochemistry",$params->{biochem_workspace},$params->{biochemid});
	my $obj = {
		description => $params->{stimuliid},
		id => $params->{stimuliid},
		name => $params->{name},
		type => $params->{type},
		abbreviation => $params->{abbreviation},
		description => $params->{description},
		compound_uuids => []
	};
	my $missingCpd;
	if (defined($params->{compounds})) {
		for (my $i=0; $i < @{$params->{compounds}}; $i++) {
			my $cpd = $params->{compounds}->[$i];
			my $cpdobj = $biochem->searchForCompound($cpd);
			if (!defined($cpdobj)) {
				push(@{$missingCpd},$cpd);
			} else {
				push(@{$obj->{compound_uuids}},$cpdobj->uuid());
			}
		}
	}
	if (defined($params->{biochemid})) {
		$biochem->add("stimuli",$obj);
		$output = $self->_save_msobject($biochem,"Biochemistry",$params->{biochem_workspace},$params->{biochemid},"add_stimuli");	
	} else {
			}
	
	$output = $self->_save_msobject($obj,"Stimuli",$params->{workspace},$params->{stimuliid},"add_stimuli");
	$self->_clearContext();
    #END import_regulatory_model
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_regulatory_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_regulatory_model');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compare_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_models');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN compare_models
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["models","workspaces"],{});
	$output = {
		model_comparisons => [],
		reaction_comparisons => []
	};
	my $universal = {
		rxn05651 => 1,
		rxn10473 => 1,
		rxn10571 => 1,
		rxn05195 => 1,
		rxn05555 => 1
	};
	my $spontaneous = {
		rxn00062 => 1,
		rxn01208 => 1,
		rxn04132 => 1,
		rxn04133 => 1,
		rxn05319 => 1,
		rxn05467 => 1,
		rxn05468 => 1,
		rxn02374 => 1,
		rxn05116 => 1,
		rxn03012 => 1,
		rxn05064 => 1,
		rxn02666 => 1,
		rxn04457 => 1,
		rxn04456 => 1,
		rxn01664 => 1,
		rxn02916 => 1,
		rxn05667 => 1
	};
	my $modelhash = {};
	my $rxnhash = {};
	my $SubsysRoles = {};
	my $template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramNegModelTemplate");
	my $map = $template->mapping();
	my $rxnroles = {};
	my $rxns = $template->templateReactions();
	for (my $k=0; $k < @{$rxns}; $k++) {
		my $rxn = $rxns->[$k];
		for (my $m=0; $m < @{$rxn->complexs()}; $m++) {
			my $cpx = $rxn->complexs()->[$m];
			my $cpxroles = $cpx->complexroles();
			for (my $j=0; $j < @{$cpxroles}; $j++) {
				my $role = $cpxroles->[$j]->role();
				if (defined($role)) {
					push(@{$rxnroles->{$rxn->reaction()->id()}},$role);
				}
			}
		}
	}
	my $rolesets = $map->subsystems();
	for (my $i=0; $i < @{$rolesets}; $i++) {
		my $roleset = $rolesets->[$i];
		my $roles = $roleset->roles();
		for (my $j=0; $j < @{$roles}; $j++) {
			$SubsysRoles->{$roles->[$j]->name()} = $roleset;
		}
	}
	for (my $i=0; $i < @{$params->{models}}; $i++) {
		my $mdl = $params->{models}->[$i];
		my $ws = $params->{workspaces}->[$i];
		my $model = $self->_get_msobject("FBAModel",$ws,$mdl);
		if (defined($model)) {
			$modelhash->{$ws."/".$mdl} = @{$output->{model_comparisons}};
			my $modelcomp = {
				model => $mdl,
				workspace => $ws,
				model_name => $model->name(),
				genome => "None",
				genome_name => "None",
				gapfilled_reactions => 0,
				core_reactions => 0,
				noncore_reactions => 0
			};
			if (defined($model->genome_ref())) {
				$modelcomp->{genome} = $model->genome()->id();
				$modelcomp->{genome} = $model->genome()->scientific_name();
			}
			my $mdlrxns = $model->modelreactions();
			for (my $j=0; $j < @{$mdlrxns}; $j++) {
				my $mdlrxn = $mdlrxns->[$j];
				if (!defined($rxnhash->{$mdlrxn->reaction()->id()}->{$mdlrxn->modelcompartment()->compartment()->id()})) {
					$rxnhash->{$mdlrxn->reaction()->id()}->{$mdlrxn->modelcompartment()->compartment()->id()} = @{$output->{reaction_comparisons}};
					my $roles = [];
					if (defined($rxnroles->{$mdlrxn->reaction()->id()})) {
						$roles = $rxnroles->{$mdlrxn->reaction()->id()};
					}
					my $rolenames = [];
					my $subsystems = [];
					my $classes = [];
					my $subclasses = [];
					for (my $k=0; $k < @{$roles}; $k++) {
						push(@{$rolenames},$roles->[$k]->name());
						if (defined($SubsysRoles->{$roles->[$k]->name()})) {
							push(@{$subsystems},$SubsysRoles->{$roles->[$k]->name()}->name());
							push(@{$classes},$SubsysRoles->{$roles->[$k]->name()}->class());
							push(@{$subclasses},$SubsysRoles->{$roles->[$k]->name()}->subclass());
						}
						push(@{$subsystems},"None");
						push(@{$classes},"None");
						push(@{$subclasses},"None");						
					}
					push(@{$output->{reaction_comparisons}},{
						reaction => $mdlrxn->reaction()->id(),
						compartment => $mdlrxn->modelcompartment()->compartment()->id(),
						equation => $mdlrxn->definition(),
						core => 1,
						model_features => {},
						role => join(";",@{$rolenames}),
						subsytem => join(";",@{$subsystems}),
						primclass => join(";",@{$classes}),
						subclass => join(";",@{$subclasses}),
						number_models => 0,
						fraction_models => 0
					});
				}
				my $index = $rxnhash->{$mdlrxn->reaction()->id()}->{$mdlrxn->modelcompartment()->compartment()->id()};
				my $ftrs = $mdlrxn->featureIDs();
				if (@{$ftrs} == 0) {
					if (defined($universal->{$mdlrxn->reaction()->id()})) {
						$ftrs = ["Universal"];
					} if (defined($spontaneous->{$mdlrxn->reaction()->id()})) {
						$ftrs = ["Spontaneous"];
					} else {
						$ftrs = ["Gapfilled"];
						$model->{gapfilled_reactions}++;
					}
				}
				push(@{$output->{reaction_comparisons}->[$index]->{model_features}->{$ws."/".$mdl}},@{$ftrs});
			}
			push(@{$output->{model_comparisons}},$modelcomp);
		}
	}
	my $nummodels = @{$output->{model_comparisons}};
	for (my $j=0; $j < @{$output->{reaction_comparisons}}; $j++) {
		my $rxn = $output->{reaction_comparisons}->[$j];
		$rxn->{number_models} = keys(%{$rxn->{model_features}});
		$rxn->{fraction_models} = $rxn->{number_models}/$nummodels;
		if ($nummodels == $rxn->{number_models}) {
			foreach my $key (keys(%{$rxn->{model_features}})) {
				$output->{model_comparisons}->[$modelhash->{$key}]->{core_reactions}++;
			}
		} else {
			foreach my $key (keys(%{$rxn->{model_features}})) {
				$output->{model_comparisons}->[$modelhash->{$key}]->{noncore_reactions}++;
			}
			$rxn->{core} = 0;
		}
	}
	$self->_clearContext();
    #END compare_models
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compare_models:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_models');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compare_genomes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_genomes');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN compare_genomes
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["genomes","workspaces"],{
		mapping => "default-mapping",
		mapping_workspace => "kbase"
	});
	$output = {
		genome_comparisons => [],
		function_comparisons => [],
	};
	my $SubsysRoles = {};
	my $GenomeHash = {};
	my $FunctionHash = {};
	my $map = $self->_get_msobject("Mapping",$params->{mapping_workspace},$params->{mapping});
	my $rolesets = $map->subsystems();
	for (my $i=0; $i < @{$rolesets}; $i++) {
		my $roleset = $rolesets->[$i];
		my $roles = $roleset->roles();
		for (my $j=0; $j < @{$roles}; $j++) {
			$SubsysRoles->{$roles->[$j]->name()} = $roleset;
		}
	}
	for (my $i=0; $i < @{$params->{genomes}}; $i++) {
		my $gen = $params->{genomes}->[$i];
		my $ws = $params->{workspaces}->[$i];
		my $genome = $self->_get_msobject("Genome",$ws,$gen);
		if (defined($genome)) {
			$GenomeHash->{$ws."/".$gen} = @{$output->{genome_comparisons}};
			my $taxonomy = "Unknown";
			if (defined($genome->taxonomy())) {
				$taxonomy = $genome->taxonomy();
			}
			my $numfeature = @{$genome->features()};
			my $genomecomp = {
				genome => $gen,
				workspace => $ws,
				genome_name => $genome->scientific_name(),
				taxonomy => $taxonomy,
				features => $numfeature,
				core_functions => 0,
				noncore_functions => 0
			};
			my $features = $genome->features();
			for (my $j=0; $j < @{$features}; $j++) {
				my $feature = $features->[$j];
				my $roles = $feature->roles();
				for (my $k=0; $k < @{$roles}; $k++) {
					if (!defined($FunctionHash->{$roles->[$k]})) {
						my $ss = "None";
						my $class = "None";
						my $subclass = "None";
						if (defined($SubsysRoles->{$roles->[$k]})) {
							$ss = $SubsysRoles->{$roles->[$k]}->name();
							$class = $SubsysRoles->{$roles->[$k]}->class();
							$subclass = $SubsysRoles->{$roles->[$k]}->subclass();
						}
						$FunctionHash->{$roles->[$k]} = @{$output->{function_comparisons}};
						push(@{$output->{function_comparisons}},{
							core => 1,
							genome_features => {},
							role => $roles->[$k],
							subsytem => $ss,
							primclass => $class,
							subclass => $subclass,
							number_genomes => 0,
							fraction_genomes => 0
						});
					}
					my $index = $FunctionHash->{$roles->[$k]};
					push(@{$output->{function_comparisons}->[$index]->{genome_features}->{$ws."/".$gen}},$feature->{id});	
				}
			}
			push(@{$output->{genome_comparisons}},$genomecomp);
		}
	}
	my $numgenomes = @{$output->{genome_comparisons}};
	for (my $j=0; $j < @{$output->{function_comparisons}}; $j++) {
		my $func = $output->{function_comparisons}->[$j];
		$func->{number_genomes} = keys(%{$func->{genome_features}});
		$func->{fraction_genomes} = $func->{number_genomes}/$numgenomes;
		if ($numgenomes == $func->{number_genomes}) {
			foreach my $key (keys(%{$func->{genome_features}})) {
				$output->{genome_comparisons}->[$GenomeHash->{$key}]->{core_functions}++;
			}
		} else {
			foreach my $key (keys(%{$func->{genome_features}})) {
				$output->{genome_comparisons}->[$GenomeHash->{$key}]->{noncore_functions}++;
			}
			$func->{core} = 0;
		}
	}
	$self->_clearContext();
    #END compare_genomes
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compare_genomes:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_genomes');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_metagenome_annotation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_metagenome_annotation');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN import_metagenome_annotation
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["annotations","workspace"],{
		metaanno_uid => undef,
		source_id => undef,
		source => "KBase",
		type => "unknown",
		name => undef,
		confidence_type => "blast"
	});
	#Obtaining kbase ID
	my $kbid = $self->_get_new_id("kb|mganno");
	if (!defined($params->{source_id}) || $params->{source} eq "KBase") {
		$params->{source_id} = $kbid;
	}
	if (!defined($params->{metaanno_uid})) {
		$params->{metaanno_uid} = $kbid;
	}
	if (!defined($params->{name})) {
		$params->{name} = $params->{metaanno_uid};
	}
	#Creating object
	my $mgobj = Bio::KBase::ObjectAPI::KBaseGenomes::MetagenomeAnnotation->new({
		id => $kbid,
		source_id => $params->{source_id},
		source => $params->{source},
		type => $params->{type},
		name => $params->{name},
		confidence_type => $params->{confidence_type},
		otus => []
	});
	#Organizing annotations by OTU
	my $otus = {};
	my $otuAverages = {};
	for (my $i=0; $i < @{$params->{annotations}}; $i++) {
		if (!defined($otuAverages->{$params->{annotations}->[$i]->[2]})) {
			$otuAverages->{$params->{annotations}->[$i]->[2]}->{coverage} = 0;
			$otuAverages->{$params->{annotations}->[$i]->[2]}->{confidence} = 0;
		}
		$otuAverages->{$params->{annotations}->[$i]->[2]}->{coverage} += $params->{annotations}->[$i]->[3];
		$otuAverages->{$params->{annotations}->[$i]->[2]}->{confidence} += $params->{annotations}->[$i]->[4];
		push(@{$otus->{$params->{annotations}->[$i]->[2]}},{
			reference_genes => [split(/,/,$params->{annotations}->[$i]->[0])],
			functional_role => $params->{annotations}->[$i]->[1],
			abundance => $params->{annotations}->[$i]->[3]+0,
			confidence => $params->{annotations}->[$i]->[4]+0,
		}); 
	}
	my $counter = 0;
	foreach my $otu (keys(%{$otus})) {
		$counter++;
		my $numfunc = @{$otus->{$otu}};
		my $otuobj = {
			ave_confidence => $otuAverages->{$otu}->{confidence}/$numfunc,
			ave_coverage => $otuAverages->{$otu}->{coverage}/$numfunc,
			id => $kbid.".otu.".$counter,
			name => $otu,
			source_id => $otu,
			source => $params->{source},
			functions => [@{$otus->{$otu}}]
		};
		my $fcounter = 0;
		for (my $i=0; $i < @{$otuobj->{functions}}; $i++) {
			$fcounter++;
			$otuobj->{functions}->[$i]->{id} = $kbid.".otu.".$counter.".func.".$fcounter;
		}
		$mgobj->add("otus",$otuobj);
	}
	#Saving object
	$mgobj->parent($self->_KBaseStore());
	$output = $self->_save_msobject($mgobj,"MetagenomeAnnotation",$params->{workspace},$params->{metaanno_uid});
    $self->_clearContext();
    #END import_metagenome_annotation
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_metagenome_annotation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_metagenome_annotation');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to models_to_community_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'models_to_community_model');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($output);
    #BEGIN models_to_community_model
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["models","workspace"],{
		model_uid => undef,
		name => undef
	});
	my $kbid = $self->_get_new_id("kb|fbamdl");
	if (!defined($params->{model_uid})) {
		$params->{model_uid} = $kbid;
	}
	if (!defined($params->{name})) {
		$params->{name} = $params->{model_uid};
	}
	#Pulling first model to obtain biochemistry ID
	my $model = $self->_get_msobject("FBAModel",$params->{models}->[0]->[1],$params->{models}->[0]->[0]);
	my $gid = $self->_get_new_id("kb|g.");
	my $genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new({
		id => $gid,
		scientific_name => $params->{name}."Genome",
		domain => "Community",
		genetic_code => 11,
		dna_size => 0,
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "KBase",
		source_id => $gid,
		md5 => "",
		taxonomy => "Community",
		gc_content => 0,
		complete => 0,
		publications => [],
		features => [],
    });
    $genomeObj->parent($self->_KBaseStore());
	#Creating new community model
	my $commdl = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->new({
		source_id => $kbid,
		source => "KBase",
		id => $kbid,
		type => "CommunityModel",
		name => $params->{name},
		template_ref => $model->template_ref(),
		modelreactions => [],
		modelcompounds => [],
		modelcompartments => [],
		biomasses => [],
		gapgens => [],
		gapfillings => [],
	});
	$commdl->parent($self->_KBaseStore());
	my $cmpsHash = {
		e => $commdl->addCompartmentToModel({
			compartment => $model->template()->biochemistry()->getObject("compartments","e"),
			pH => 7,
			potential => 0,
			compartmentIndex => 0
		}),
		c => $commdl->addCompartmentToModel({
			compartment => $model->template()->biochemistry()->getObject("compartments","c"),
			pH => 7,
			potential => 0,
			compartmentIndex => 0
		})
	};
	my $totalAbundance = 0;
	for (my $i=0; $i < @{$params->{models}}; $i++) {
		$totalAbundance += $params->{models}->[$i]->[2];
	}
	my $biocount = 1;
	my $primbio = $commdl->add("biomasses",{
		id => "bio1",
		name => "bio1",
		other => 1,
		dna => 0,
		rna => 0,
		protein => 0,
		cellwall => 0,
		lipid => 0,
		cofactor => 0,
		energy => 0
	});
	my $biomassCompound = $model->template()->biochemistry()->getObject("compounds","cpd11416");
	my $biocpd = $commdl->add("modelcompounds",{
		id => $biomassCompound->id()."_".$cmpsHash->{c}->id(),
		compound_ref => $biomassCompound->_reference(),
		charge => 0,
		modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{c}->id()
	});
	$primbio->add("biomasscompounds",{
		modelcompound_ref => "~/modelcompounds/id/".$biocpd->id(),
		coefficient => 1
	});
	for (my $i=0; $i < @{$params->{models}}; $i++) {
		print "Loading model ".$params->{models}->[$i]->[1]."\n";
		if ($i > 0) {
			$model = $self->_get_msobject("FBAModel",$params->{models}->[$i]->[1],$params->{models}->[$i]->[0]);
		}
		my $biomassCpd = $model->getObject("modelcompounds","cpd11416_c0");
		#Adding genome, features, and roles to master mapping and annotation
		my $mdlgenome = $model->genome();
		$genomeObj->dna_size($genomeObj->dna_size()+$mdlgenome->dna_size());
		$genomeObj->num_contigs($genomeObj->num_contigs()+$mdlgenome->num_contigs());
		$genomeObj->gc_content($genomeObj->gc_content()+$mdlgenome->dna_size()*$mdlgenome->gc_content());
		push(@{$genomeObj->{contig_lengths}},@{$mdlgenome->{contig_lengths}});
		push(@{$genomeObj->{contig_ids}},@{$mdlgenome->{contig_ids}});	
		print "Loading features\n";
		for (my $j=0; $j < @{$mdlgenome->features()}; $j++) {
			$genomeObj->add("features",$mdlgenome->features()->[$j]);
		}
		#Adding compartments to community model
		my $cmps = $model->modelcompartments();
		print "Loading compartments\n";
		for (my $j=0; $j < @{$cmps}; $j++) {
			if ($cmps->[$j]->compartment()->id() ne "e") {
				$cmpsHash->{$cmps->[$j]->compartment()->id()} = $commdl->addCompartmentToModel({
					compartment => $cmps->[$j]->compartment(),
					pH => 7,
					potential => 0,
					compartmentIndex => ($i+1)
				});
			}
		}
		#Adding compounds to community model
		my $translation = {};
		print "Loading compounds\n";
		my $cpds = $model->modelcompounds();
		for (my $j=0; $j < @{$cpds}; $j++) {
			my $cpd = $cpds->[$j];
			my $comcpd = $commdl->queryObject("modelcompounds",{
				compound_ref => $cpd->compound_ref(),
				modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{$cpd->modelcompartment()->compartment()->id()}->id()
			});
			if (!defined($comcpd)) {
				$comcpd = $commdl->add("modelcompounds",{
					id => $cpd->compound()->id()."_".$cmpsHash->{$cpd->modelcompartment()->compartment()->id()}->id(),
					compound_ref => $cpd->compound_ref(),
					charge => $cpd->charge(),
					formula => $cpd->formula(),
					modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{$cpd->modelcompartment()->compartment()->id()}->id(),
				});
			}
			$translation->{$cpd->id()} = $comcpd->id();
		}
		print "Loading reactions\n";
		#Adding reactions to community model
		my $rxns = $model->modelreactions();
		for (my $j=0; $j < @{$rxns}; $j++) {
			my $rxn = $rxns->[$j];
			if (!defined($commdl->queryObject("modelreactions",{
				reaction_ref => $rxn->reaction_ref(),
				modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{$rxn->modelcompartment()->compartment()->id()}->id()
			}))) {
				my $comrxn = $commdl->add("modelreactions",{
					id => $rxn->reaction()->id()."_".$cmpsHash->{$rxn->modelcompartment()->compartment()->id()}->id(),
					reaction_ref => $rxn->reaction_ref(),
					direction => $rxn->direction(),
					protons => $rxn->protons(),
					modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{$rxn->modelcompartment()->compartment()->id()}->id(),
					probability => $rxn->probability()
				});
				for (my $k=0; $k < @{$rxn->modelReactionProteins()}; $k++) {
					$comrxn->add("modelReactionProteins",$rxn->modelReactionProteins()->[$k]);
				}
				for (my $k=0; $k < @{$rxn->modelReactionReagents()}; $k++) {
					$comrxn->add("modelReactionReagents",{
						modelcompound_ref => "~/modelcompounds/id/".$translation->{$rxn->modelReactionReagents()->[$k]->modelcompound()->id()},
						coefficient => $rxn->modelReactionReagents()->[$k]->coefficient()
					});
				}
			}
		}
		print "Loading biomass\n";
		#Adding biomass to community model
		my $bios = $model->biomasses();
		for (my $j=0; $j < @{$bios}; $j++) {
			my $bio = $bios->[$j];
			for (my $k=0; $k < @{$bio->biomasscompounds()}; $k++) {
				$bio->biomasscompounds()->[$k]->modelcompound_ref("~/modelcompounds/id/".$translation->{$bio->biomasscompounds()->[$k]->modelcompound()->id()});
			}
			$bio = $commdl->add("biomasses",$bio);
			$biocount++;
			$bio->id("bio".$biocount);
			$bio->name("bio".$biocount);
		}
		print "Loading primary biomass\n";
		#Adding biomass component to primary composite biomass reaction
		$primbio->add("biomasscompounds",{
			modelcompound_ref => "~/modelcompounds/id/".$translation->{$biomassCpd->id()},
			coefficient => -1*$params->{models}->[$i]->[2]/$totalAbundance
		});
	}
	print "Merged model complete!\n";
	#Saving object
	$output = $self->_save_msobject($genomeObj,"Genome",$params->{workspace},$genomeObj->id());
	$commdl->genome_ref($genomeObj->_reference());
	$output = $self->_save_msobject($commdl,"FBAModel",$params->{workspace},$params->{model_uid});
    $self->_clearContext();
    #END models_to_community_model
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to models_to_community_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'models_to_community_model');
    }
    return($output);
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
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to metagenome_to_fbamodels:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'metagenome_to_fbamodels');
    }

    my $ctx = $Bio::KBase::fbaModelServices::Server::CallContext;
    my($outputs);
    #BEGIN metagenome_to_fbamodels
    $self->_setContext($ctx,$params);
	$params = $self->_validateargs($params,["metaanno_uid","workspace"],{
		model_uids => {},
		metaanno_ws => $params->{workspace},
		min_abundance => 1,
		confidence_threshold => 0,
		max_otu_models => 2,
		min_reactions => 100,
		templates => {}
	});
	my $metaanno = $self->_get_msobject("MetagenomeAnnotation",$params->{metaanno_ws},$params->{metaanno_uid});
	#Sorting OTUs by coverage, placing highest coverage OTU first
	my $otus = $metaanno->otus();
	my $sortedOtus = [sort { $b->ave_coverage() <=> $a->ave_coverage() } @{$otus}];
	my $functions;
	my $nummodels = 0;
	for (my $i=0; $i < @{$sortedOtus}; $i++) {
		my $otu = $sortedOtus->[$i];
		my $built = 0;
		#Building OTU model if appropriate
		if ($otu->name() ne "tail" && $nummodels < $params->{max_otu_models} && $otu->ave_coverage() >= $params->{min_abundance}) {
			my $mdlfunc = {};
			my $functions = $otu->functions();
			for (my $j=0; $j < @{$functions}; $j++) {
				my $func = $functions->[$j];
				if ($self->_assess_confidence($metaanno->confidence_type(),$params->{confidence_threshold},$func->confidence()) == 1) {
					if (!defined($mdlfunc->{$func->functional_role()})) {
						$mdlfunc->{$func->functional_role()} = 0;
					}
					$mdlfunc->{$func->functional_role()} += $func->abundance();
				}
			}
			my $genome = $self->_buildGenomeFromFunctions($otu->id().".g.0",$mdlfunc,$otu->name());
			my $genomeMeta = $self->_save_msobject($genome,"Genome",$params->{workspace},$genome->id(),{hidden=>1});
			my $mdl = $self->_genome_to_model($genome,$genome->id().".fbamdl.0");
			print $otu->name()."\t".$otu->ave_coverage()."\t".@{$otu->functions()}."\t".@{$mdl->modelreactions()}."\n";
			#Saving OTU model if it's large enough
			if (@{$mdl->modelreactions()} > $params->{min_reactions}) {
				$nummodels++;
				$built = 1;
				my $ids = ["name","kbid","source_id"];
				my $modelid;
				for (my $j=0; $j < @{$ids}; $j++) {
					if (defined($params->{model_uids}->{$otu->{$ids->[$j]}})) {
						$modelid = $params->{model_uids}->{$otu->{$ids->[$j]}};
					}
				}
				if (!defined($modelid)) {
					$modelid = $mdl->id();
				}
				$mdl->name($otu->name());
				$mdl->source("KBase");
				$mdl->source_id($mdl->id());
				$mdl->metagenome_ref($metaanno->_reference());
				$mdl->metagenome_otu_ref($otu->_reference());
				push(@{$outputs},$self->_save_msobject($mdl,"FBAModel",$params->{workspace},$modelid));
			}
		}
		#Adding OTU functions to functions in tail
		if ($built == 0) {
			my $funcs = $otu->functions();
			for (my $j=0; $j < @{$otu->functions()}; $j++) {
				my $func = $funcs->[$j];
				if ($self->_assess_confidence($metaanno->confidence_type(),$params->{confidence_threshold},$func->confidence()) == 1) {
					if (!defined($functions->{$func->functional_role()})) {
						$functions->{$func->functional_role()} = {
							abundance => 0,
							confidence => 0,
							reference_genes => []
						};
					}
					$functions->{$func->functional_role()}->{abundance} += $func->abundance();
					$functions->{$func->functional_role()}->{confidence} += $func->abundance()*$func->confidence();
					push(@{$functions->{$func->{functional_role}}->{reference_genes}},@{$func->reference_genes()});
				}
			}
		}
	}
	#Building ensemble model
	my $mdlfunc = {};
	foreach my $function (keys(%{$functions})) {
		if ($self->_assess_confidence($metaanno->confidence_type(),$params->{confidence_threshold},$functions->{$function}->{confidence}) == 1) {
			if (!defined($mdlfunc->{$function})) {
				$mdlfunc->{$function} = 0;
			}
			$mdlfunc->{$function} += $functions->{$function}->{abundance};
		}
	}
	my $genome = $self->_buildGenomeFromFunctions($metaanno->id().".tail.0.g.0",$mdlfunc,$metaanno->id().".tail.0.g.0");
	my $genomeMeta = $self->_save_msobject($genome,"Genome",$params->{workspace},$genome->id(),{hidden=>1});
	my $mdl = $self->_genome_to_model($genome,$genome->id().".fbamdl.0");
	my $modelid;
	if (defined($params->{model_uids}->{tail})) {
		$modelid = $params->{model_uids}->{tail};
	}
	if (!defined($modelid)) {
		$modelid = $mdl->id();
	}
	$mdl->name("tailmodel");
	$mdl->source("KBase");
	$mdl->source_id($mdl->id());
	push(@{$outputs},$self->_save_msobject($mdl,"FBAModel",$params->{workspace},$modelid));
	$self->_clearContext();
    #END metagenome_to_fbamodels
    my @_bad_returns;
    (ref($outputs) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"outputs\" (value was \"$outputs\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to metagenome_to_fbamodels:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'metagenome_to_fbamodels');
    }
    return($outputs);
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

1;
