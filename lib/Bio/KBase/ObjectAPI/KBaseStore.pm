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
		if (!defined($self->cache()->{$refs->[$i]}) || defined($options->{refreshcache})) {
    		push(@{$newrefs},$refs->[$i]);
    	}
	}
	#Pulling objects from workspace
	if (@{$newrefs} > 0) {
		my $objids = [];
		for (my $i=0; $i < @{$newrefs}; $i++) {
			my $array = [split(/\//,$newrefs->[$i])];
			my $objid = {};
			if (@{$array} < 2) {
				Bio::KBase::ObjectAPI::utilities->error("Invalid reference:".$newrefs->[$i]);
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
			push(@{$objids},$objid);
		}
		my $objdatas = $self->workspace()->get_objects($objids);
		for (my $i=0; $i < @{$objdatas}; $i++) {
			my $info = $objdatas->[$i]->{info};
			if ($info->[2] =~ m/^(.+)\.(.+)-/) {
				my $module = $1;
				my $type = $2;
				my $class = "Bio::KBase::ObjectAPI::".$module."::".$type;
				if ($type eq "FBAModel") {
					for (my $j=0; $j < @{$objdatas->[$i]->{data}->{gapfillings}}; $j++) {
						delete $objdatas->[$i]->{data}->{gapfillings}->[$j]->{integrated_solution};
						$objdatas->[$i]->{data}->{gapfillings}->[$j]->{id} = $objdatas->[$i]->{data}->{gapfillings}->[$j]->{gapfill_id};
					}
				} 
				$self->cache()->{$newrefs->[$i]} = $class->new($objdatas->[$i]->{data});
				$self->cache()->{$info->[6]."/".$info->[0]."/".$info->[4]} = $self->cache()->{$newrefs->[$i]};
				$self->cache()->{$newrefs->[$i]}->parent($self);
				$self->cache()->{$newrefs->[$i]}->_wsobjid($info->[0]);
				$self->cache()->{$newrefs->[$i]}->_wsname($info->[1]);
				$self->cache()->{$newrefs->[$i]}->_wstype($info->[2]);
				$self->cache()->{$newrefs->[$i]}->_wssave_date($info->[3]);
				$self->cache()->{$newrefs->[$i]}->_wsversion($info->[4]);
				$self->cache()->{$newrefs->[$i]}->_wssaved_by($info->[5]);
				$self->cache()->{$newrefs->[$i]}->_wswsid($info->[6]);
				$self->cache()->{$newrefs->[$i]}->_wsworkspace($info->[7]);
				$self->cache()->{$newrefs->[$i]}->_wschsum($info->[8]);
				$self->cache()->{$newrefs->[$i]}->_wssize($info->[9]);
				$self->cache()->{$newrefs->[$i]}->_wsmeta($info->[10]);
				$self->cache()->{$newrefs->[$i]}->_reference($info->[6]."/".$info->[0]."/".$info->[4]);
				$self->uuid_refs()->{$self->cache()->{$newrefs->[$i]}->uuid()} = $info->[6]."/".$info->[0]."/".$info->[4];
			}
		}
	}
	#Gathering objects out of the cache
	my $objs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		$objs->[$i] = $self->cache()->{$refs->[$i]};
	}
	return $objs;
}

sub get_object {
    my ($self,$ref,$options) = @_;
    return $self->get_objects([$ref])->[0];
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