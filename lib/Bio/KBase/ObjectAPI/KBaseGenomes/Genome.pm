########################################################################
# Bio::KBase::ObjectAPI::KBaseGenomes::Genome - This is the moose object corresponding to the Genome object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseGenomes::DB::Genome;
package Bio::KBase::ObjectAPI::KBaseGenomes::Genome;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseGenomes::DB::Genome';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has geneAliasHash => ( is => 'rw',printOrder => 2, isa => 'HashRef', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgeneAliasHash' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildgeneAliasHash {
	my ($self) = @_;
	my $geneAliases = {};
	my $ftrs = $self->features();
    foreach my $ftr (@{$ftrs}) {
    	$geneAliases->{$ftr->id()} = $ftr;
    	foreach my $alias (@{$ftr->aliases()}) {
    		$geneAliases->{$alias} = $ftr;
    	}
    }
    return $geneAliases;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub genome_typed_object {
    my ($self) = @_;
	my $output = $self->serializeToDB();
	my $contigset = $self->contigset();
	my $contigserial = $contigset->serializeToDB();
	$output->{contigs} = $contigserial->{contigs};
	for (my $i=0; $i < @{$output->{contigs}}; $i++) {
		$output->{contigs}->[$i]->{dna} = $output->{contigs}->[$i]->{sequence};
		delete $output->{contigs}->[$i]->{sequence};
	}
	return $output;
}

=head3 searchForFeature
Definition:
	Bio::KBase::ObjectAPI::KBaseGenomes::Feature = Bio::KBase::ObjectAPI::KBaseGenomes::Feature->searchForFeature(string);
Description:
	Searches for a gene by ID, name, or alias.

=cut

sub searchForFeature {
	my ($self,$id) = @_;
	return $self->geneAliasHash()->{$id};
}

=head3 gtf_to_features

Definition:
	$self->gtf_to_features({gtffile => string,clear_features => 1});
Description:
	Builds feature array from gtf file
		
=cut
sub gtf_to_features {
	my($self,$parameters) = @_;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["gtffile"], {clear_features => 1}, $parameters );
	if ($args->{clear_features}) {
		$self->features([]);
	}
	my $array = [split(/\n/,$args->{gtffile})];
	foreach my $line (@{$array}) {
		my $row = [split(/\t/,$line)];
		my $start = $row->[3];
		my $length = abs($row->[4]-$row->[3]);
		if ($row->[6] eq "-") {
			$start += $length;
		}
		my $feature = {
			location => [[$row->[0],$start,$row->[6],$length]],
			protein_translation_length => int(abs($row->[4]-$row->[3])/3),
			dna_sequence_length => int(abs($row->[4]-$row->[3])),
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
		
		my $items = [split(/;\s*/,$row->[8])];
		foreach my $item (@{$items}){
			if ($item =~ m/(.+)\s+\"(.+)\"/) {
				my $field = $1;
				my $value = $2;
				if ($field eq "alias") {
					push(@{$feature->{aliases}},split(/,/,$value));
				} elsif ($field eq "gene_id") {
					$feature->{id} = $value;
				} elsif ($field eq "product") {
					$feature->{function} = $value;
					$feature->{annotations} = [[$value,"GTF import",time()]];
				} elsif ($field eq "orig_coding_type") {
					$feature->{type} = $value;
				} elsif ($field eq "transcript_id") {
					push(@{$feature->{aliases}},$value);
				}
			}
		}
		$self->add("features",$feature);
	}
}

=head3 integrate_contigs

Definition:
	$self->integrate_contigs({contigobj => Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet,update_features => 0});
Description:
	Loads contigs into genome and updates all relevant stats
		
=cut
sub integrate_contigs {
	my($self,$parameters) = @_;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["contigobj"], {update_features => 0}, $parameters );
	my $contigobj = $args->{contigobj};
	$self->contigset_ref($contigobj->_reference());
	my $numcontigs = @{$contigobj->contigs()};
	$self->num_contigs($numcontigs);
	my $size = 0;
	my $gc_content = 0;
	my $contigs = $contigobj->contigs();
	for (my $i=0; $i < @{$contigs}; $i++) {
		$size += length($contigs->[$i]->sequence());
		$self->contig_lengths()->[$i] = length($contigs->[$i]->sequence());
		$self->contig_ids()->[$i] = $contigs->[$i]->id();
		my $copy = $contigs->[$i]->sequence();
		$copy =~ s/[gcGC]//g;
		$gc_content += ($self->contig_lengths()->[$i]-length($copy));
	}
	$self->md5($contigobj->md5());
	$self->dna_size($size);
	$self->gc_content($gc_content/$size);
	if ($args->{update_features} == 1) {
		my $ftrs = $self->features();
		for (my $i=0; $i< @{$ftrs};$i++) {
			my $ftr = $ftrs->[$i];
			$ftr->integrate_contigs($contigobj);
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
