########################################################################
# Bio::KBase::ObjectAPI::KBaseStore - A class for managing KBase object retrieval from KBase
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2014-01-4
########################################################################

=head1 Bio::KBase::ObjectAPI::KBaseStore 

Class for managing KBase object retreival from KBase

=head2 ABSTRACT

=head2 NOTE


=head2 METHODS

=head3 new

    my $Store = Bio::KBase::ObjectAPI::KBaseStore->new(\%);
    my $Store = Bio::KBase::ObjectAPI::KBaseStore->new(%);

This initializes a Storage interface object. This accepts a hash
or hash reference to configuration details:

=over

=item auth

Authentication token to use when retrieving objects

=item workspace

Client or server class for accessing a KBase workspace

=back

=head3 Object Methods

=cut

package Bio::KBase::ObjectAPI::KBaseStore;
use Moose;
use Bio::KBase::ObjectAPI::utilities;

use Class::Autouse qw(
    Bio::KBase::workspace::Client
    Bio::KBase::ObjectAPI::KBaseRegulation::Regulome
    Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry
    Bio::KBase::ObjectAPI::KBaseGenomes::Genome
    Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet
    Bio::KBase::ObjectAPI::KBaseBiochem::Media
    Bio::KBase::ObjectAPI::KBaseFBA::ModelTemplate
    Bio::KBase::ObjectAPI::KBaseOntology::Mapping
    Bio::KBase::ObjectAPI::KBaseFBA::FBAModel
    Bio::KBase::ObjectAPI::KBaseBiochem::BiochemistryStructures
    Bio::KBase::ObjectAPI::KBaseFBA::Gapfilling
    Bio::KBase::ObjectAPI::KBaseFBA::FBA
    Bio::KBase::ObjectAPI::KBaseFBA::Gapgeneration
    Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSet
    Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSimulationSet
);
use Module::Load;

#***********************************************************************************************************
# ATTRIBUTES:
#***********************************************************************************************************
has workspace => ( is => 'rw', isa => 'Ref', required => 1);
has cache => ( is => 'rw', isa => 'HashRef',default => sub { return {}; });
has uuid_refs => ( is => 'rw', isa => 'HashRef',default => sub { return {}; });
has updated_refs => ( is => 'rw', isa => 'HashRef',default => sub { return {}; });
has provenance => ( is => 'rw', isa => 'ArrayRef',default => sub { return []; });
has user_override => ( is => 'rw', isa => 'Str',default => "");
has file_cache => ( is => 'rw', isa => 'Str',default => "");
has cache_targets => ( is => 'rw', isa => 'HashRef',default => sub { return {}; });

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub get_objects {
	my ($self,$refs,$options) = @_;
	#Checking cache for objects
	my $newrefs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		if ($refs->[$i] =~ m/^489\/6\/\d+$/ || $refs->[$i] =~ m/^kbase\/default\/\d+$/) {
			$refs->[$i] = "kbase/default";
		}
		if (!defined($self->cache()->{$refs->[$i]}) || defined($options->{refreshcache})) {
    		if ($self->read_object_from_file_cache($refs->[$i]) == 0) {
    			push(@{$newrefs},$refs->[$i]);
    		}
    	}
	}
	#Pulling objects from workspace
	if (@{$newrefs} > 0) {
		my $objids = [];
		for (my $i=0; $i < @{$newrefs}; $i++) {		
			push(@{$objids},$self->ref_to_identify($newrefs->[$i]));
		}
		my $objdatas = $self->workspace()->get_objects($objids);
		for (my $i=0; $i < @{$objdatas}; $i++) {
			$self->process_object($objdatas->[$i]->{info},$objdatas->[$i]->{data},$newrefs->[$i]);
		}
	}
	#Gathering objects out of the cache
	my $objs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		$objs->[$i] = $self->cache()->{$refs->[$i]};
	}
	return $objs;
}

sub process_object {
	my ($self,$info,$data,$ref) = @_;
	$self->write_object_to_file_cache($info,$data);
	if ($info->[2] =~ m/^(.+)\.(.+)-/) {
		my $module = $1;
		my $type = $2;
		my $class = "Bio::KBase::ObjectAPI::".$module."::".$type;
		$self->cache()->{$ref} = $class->new($data);
		if (!defined($self->cache()->{$info->[6]."/".$info->[0]."/".$info->[4]})) {
			$self->cache()->{$info->[6]."/".$info->[0]."/".$info->[4]} = $self->cache()->{$ref};
		}
		$self->cache()->{$ref}->parent($self);
		if ($type eq "Biochemistry") {
			$self->cache()->{$ref}->add("compounds",{
				id => "cpd00000",
		    	isCofactor => 0,
		    	name => "CustomCompound",
		    	abbreviation => "CustomCompound",
		    	md5 => "",
		    	formula => "",
		    	unchargedFormula => "",
		    	mass => 0,
		    	defaultCharge => 0,
		    	deltaG => 0,
		    	deltaGErr => 0,
		    	comprisedOfCompound_refs => [],
		    	cues => {},
		    	pkas => {},
		    	pkbs => {}
			});
			$self->cache()->{$ref}->add("reactions",{
				id => "rxn00000",
		    	name => "CustomReaction",
		    	abbreviation => "CustomReaction",
		    	md5 => "",
		    	direction => "=",
		    	thermoReversibility => "=",
		    	status => "OK",
		    	defaultProtons => 0,
		    	deltaG => 0,
		    	deltaGErr => 0,
		    	cues => {},
		    	reagents => []
			});
		}
		if ($type eq "FBAModel") {
			if (defined($self->cache()->{$ref}->template_ref())) {
				if ($self->cache()->{$ref}->template_ref() =~ m/(\w+)\/(\w+)\/\d+/) {
					$self->cache()->{$ref}->template_ref($1."/".$2);
				}
			}
			if (defined($self->cache()->{$ref}->template_refs())) {
				my $temprefs = $self->cache()->{$ref}->template_refs();
				for (my $i=0; $i < @{$temprefs}; $i++) {
					if ($temprefs->[$i] =~ m/(\w+)\/(\w+)\/\d+/) {
						$temprefs->[$i] = $1."/".$2;
					}
				}
			}
		}
		$self->cache()->{$ref}->_wsobjid($info->[0]);
		$self->cache()->{$ref}->_wsname($info->[1]);
		$self->cache()->{$ref}->_wstype($info->[2]);
		$self->cache()->{$ref}->_wssave_date($info->[3]);
		$self->cache()->{$ref}->_wsversion($info->[4]);
		$self->cache()->{$ref}->_wssaved_by($info->[5]);
		$self->cache()->{$ref}->_wswsid($info->[6]);
		$self->cache()->{$ref}->_wsworkspace($info->[7]);
		$self->cache()->{$ref}->_wschsum($info->[8]);
		$self->cache()->{$ref}->_wssize($info->[9]);
		$self->cache()->{$ref}->_wsmeta($info->[10]);
		$self->cache()->{$ref}->_reference($info->[6]."/".$info->[0]."/".$info->[4]);
		$self->uuid_refs()->{$self->cache()->{$ref}->uuid()} = $info->[6]."/".$info->[0]."/".$info->[4];
	}
}

sub ref_to_identify {
	my ($self,$ref) = @_;
	my $array = [split(/\//,$ref)];
	my $objid = {};
	if (@{$array} < 2) {
		Bio::KBase::ObjectAPI::utilities->error("Invalid reference:".$ref);
	}
	if ($array->[0] =~ m/^\d+$/) {
		$objid->{wsid} = $array->[0];
	} else {
		$objid->{workspace} = $array->[0];
	}
	if ($array->[1] =~ m/^\d+$/) {
		$objid->{objid} = $array->[1];
	} else {
		$objid->{name} = $array->[1];
	}
	if (defined($array->[2])) {
		$objid->{ver} = $array->[2];
	}
	return $objid;
}

#This function writes data to file cache if it's been flagged for local file caching
sub write_object_to_file_cache {
	my ($self,$info,$data) = @_;
	if (length($self->file_cache()) > 0 && defined($self->cache_targets()->{$info->[6]."/".$info->[0]."/".$info->[4]}) && !-e $self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4]."/meta") {
		print "Saving to cache!\n";
		File::Path::mkpath $self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4];
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4]."/meta",[Bio::KBase::ObjectAPI::utilities::TOJSON($info)]);
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4]."/data",[Bio::KBase::ObjectAPI::utilities::TOJSON($data)]);
	}
}

#This function writes data to file cache if it's been flagged for local file caching
sub read_object_from_file_cache {
	my ($self,$ref) = @_;
	if (defined($self->cache_targets()->{$ref})) {
		print "Checking cache!\n";
		#Get WS metadata
		my $infos = $self->workspace()->get_object_info([$self->ref_to_identify($ref)],0);
		my $info = $infos->[0];
		if (-e $self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4]."/meta") {
			my $filearray = Bio::KBase::ObjectAPI::utilities::LOADFILE($self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4]."/meta");
			my $meta = Bio::KBase::ObjectAPI::utilities::FROMJSON(join("\n",@{$filearray}));
			$filearray = Bio::KBase::ObjectAPI::utilities::LOADFILE($self->file_cache()."/KBCache/".$info->[6]."/".$info->[0]."/".$info->[4]."/data");
			my $data = Bio::KBase::ObjectAPI::utilities::FROMJSON(join("\n",@{$filearray}));
			$self->process_object($meta,$data,$ref);
			return 1;
		}
	}
	return 0;
}

sub get_object {
    my ($self,$ref,$options) = @_;
    print "Getting ".$ref."\n";
    return $self->get_objects([$ref])->[0];
    print "Done getting ".$ref."\n";
}

sub get_object_by_handle {
    my ($self,$handle,$type,$options) = @_;
    Bio::KBase::ObjectAPI::utilities->error($handle);
    my $typehandle = [split(/\./,$type)];
    my $class = "Bio::KBase::ObjectAPI::".$typehandle->[0]."::".$typehandle->[1];
    my $data;
    if ($handle->{type} eq "data") {
    	$data = $handle->{data};
    } elsif ($handle->{type} eq "workspace") {
    	$options->{url} = $handle->{url};
    	return $self->get_object($handle->{reference},$options);
    }
    return $class->new($data);
}

sub save_object {
    my ($self,$object,$ref,$params) = @_;
    my $output = $self->save_objects({$ref => {hidden => $params->{hidden},meta => $params->{meta},object => $object}});
    return $output->{$ref};
}

sub save_objects {
    my ($self,$refobjhash) = @_;
    my $wsdata;
    foreach my $ref (keys(%{$refobjhash})) {
    	my $obj = $refobjhash->{$ref};
    	my $objdata = {
    		type => $obj->{object}->_type(),
    		data => $obj->{object}->serializeToDB(),
    		provenance => $self->provenance()
    	};
    	if (defined($obj->{hidden})) {
    		$objdata->{hidden} = $obj->{hidden};
    	}
    	if (defined($obj->{meta})) {
    		$objdata->{meta} = $obj->{meta};
    	}
    	if (defined($objdata->{provenance}->[0]->{method_params}->[0]->{notes})) {
    		$objdata->{meta}->{notes} = $objdata->{provenance}->[0]->{method_params}->[0]->{notes};
    	}
    	my $array = [split(/\//,$ref)];
		if (@{$array} < 2) {
			Bio::KBase::ObjectAPI::utilities->error("Invalid reference:".$ref);
		}
		if ($array->[1] =~ m/^\d+$/) {
			$objdata->{objid} = $array->[1];
		} else {
			$objdata->{name} = $array->[1];
		}
		push(@{$wsdata->{$array->[0]}->{refs}},$ref);
		push(@{$wsdata->{$array->[0]}->{objects}},$objdata);
    }
	foreach my $ws (keys(%{$wsdata})) {
    	my $input = {objects => $wsdata->{$ws}->{objects}};
    	if ($ws  =~ m/^\d+$/) {
    		$input->{id} = $ws;
    	} else {
    		$input->{workspace} = $ws;
    	}
    	my $listout;
    	if (defined($self->user_override()) && length($self->user_override()) > 0) {
    		$listout = $self->workspace()->administer({
    			"command" => "saveObjects",
    			"user" => $self->user_override(),
    			"params" => $input
    		});
    	} else {
    		$listout = $self->workspace()->save_objects($input);
    	}    	
	    #Placing output into a hash of references pointing to object infos
	    my $output = {};
	    for (my $i=0; $i < @{$listout}; $i++) {
	    	$self->cache()->{$listout->[$i]->[6]."/".$listout->[$i]->[0]."/".$listout->[$i]->[4]} = $refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object};
	    	$self->cache()->{$listout->[$i]->[7]."/".$listout->[$i]->[1]."/".$listout->[$i]->[4]} = $refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object};
	    	$self->uuid_refs()->{$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->uuid()} = $listout->[$i]->[6]."/".$listout->[$i]->[0]."/".$listout->[$i]->[4];
	    	if ($refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_reference() =~ m/^\w+\/\w+\/\w+$/) {
	    		$self->updated_refs()->{$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_reference()} = $listout->[$i]->[6]."/".$listout->[$i]->[0]."/".$listout->[$i]->[4];
	    	}
	    	$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_reference($listout->[$i]->[6]."/".$listout->[$i]->[0]."/".$listout->[$i]->[4]);
	    	$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wsobjid($listout->[$i]->[0]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wsname($listout->[$i]->[1]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wstype($listout->[$i]->[2]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wssave_date($listout->[$i]->[3]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wsversion($listout->[$i]->[4]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wssaved_by($listout->[$i]->[5]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wswsid($listout->[$i]->[6]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wsworkspace($listout->[$i]->[7]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wschsum($listout->[$i]->[8]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wssize($listout->[$i]->[9]);
			$refobjhash->{$wsdata->{$ws}->{refs}->[$i]}->{object}->_wsmeta($listout->[$i]->[10]);
	    	$output->{$wsdata->{$ws}->{refs}->[$i]} = $listout->[$i];
	    }
	    return $output;
    }
}

sub uuid_to_ref {
	my ($self,$uuid) = @_;
	return $self->uuid_refs()->{$uuid};
}

sub updated_reference {
	my ($self,$oldref) = @_;
	return $self->updated_refs()->{$oldref};
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
