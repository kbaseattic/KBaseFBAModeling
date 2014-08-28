########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::ClassifierTrainingSet - This is the moose object corresponding to the KBaseFBA.ClassifierTrainingSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2014-08-26T21:34:17
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::ClassifierTrainingSet;
package Bio::KBase::ObjectAPI::KBaseFBA::ClassifierTrainingSet;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::ClassifierTrainingSet';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has jobID => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobid' );
has jobPath => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobpath' );
has jobDirectory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildjobdirectory' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildjobid {
	my ($self) = @_;
	my $path = $self->jobPath();
	my $jobid = Bio::KBase::ObjectAPI::utilities::CurrentJobID();
	if (!defined($jobid)) {
		my $fulldir = File::Temp::tempdir(DIR => $path);
		if (!-d $fulldir) {
			File::Path::mkpath ($fulldir);
		}
		$jobid = substr($fulldir,length($path."/"));
	}
	return $jobid
}

sub _buildjobpath {
	my ($self) = @_;
	my $path = Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY();
	if (!defined($path) || length($path) == 0) {
		$path = "/tmp/fbajobs/";
	}
	if (!-d $path) {
		File::Path::mkpath ($path);
	}
	return $path;
}

sub _buildjobdirectory {
	my ($self) = @_;
	return $self->jobPath()."/".$self->jobID();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub load_trainingset {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([],{}, @_);
	if ($self->attribute_type() eq "functional_roles") {
		my $wsg = $self->workspace_training_set();
		for (my $i=0; $i < @{$wsg}; $i++) {
			my $g = $self->getLinkedObject($wsg->[$i]->[0]);
			my $rh = $g->rolehash();
			$wsg->[$i]->[2] = [keys(%{$rh})];
		}
		my $eg = $self->external_training_set();
		for (my $i=0; $i < @{$eg}; $i++) {
			my $rh;
			if ($eg->[$i]->[0] eq "seed") {
				require "ModelSEED/Client/SAP.pm";
				my $sapsvr = ModelSEED::Client::SAP->new();
				my $featureHash = $sapsvr->all_features({-ids => $eg->[$i]->[1]});
				my $functions = $sapsvr->ids_to_functions({-ids => $featureHash->{$eg->[$i]->[1]}});
				for (my $j=0;$j < @{$featureHash->{$eg->[$i]->[1]}}; $j++) {
					my $roles = [split(/\s*;\s+|\s+[\@\/]\s+/,$functions->{$featureHash->{$eg->[$i]->[1]}->[$j]})];
					for (my $k=0; $k < @{$roles}; $k++) {
						push(@{$rh->{$roles->[$k]}},$featureHash->{$eg->[$i]->[1]}->[$j]); 
					}
				}			
			} elsif ($eg->[$i]->[0] eq "kbase") {
				require "Bio/KBase/CDMI/CDMIClient.pm";
				my $cdmi = Bio::KBase::CDMI::CDMIClient->new_for_script();
				#TODO
			}
			$eg->[$i]->[2] = [keys(%{$rh})];	
		}
	}
}

sub createJobDirectory {
	my $self = shift;
	my $dir = $self->jobDirectory();
	my $classdata;
	my $attdata;
	my $wsg = $self->workspace_training_set();
	for (my $i=0; $i < @{$wsg}; $i++) {
		push(@{$classdata},$wsg->[$i]->[0]."\t".$wsg->[$i]->[1]);
		for (my $j=0; $j < @{$wsg->[$i]->[2]}; $j++) {
			push(@{$attdata},$wsg->[$i]->[0]."\t".$wsg->[$i]->[2]->[$j]);
		}
	}
	my $eg = $self->external_training_set();
	for (my $i=0; $i < @{$eg}; $i++) {
		push(@{$classdata},$eg->[$i]->[0]."/".$eg->[$i]->[1]."\t".$eg->[$i]->[2]);
		for (my $j=0; $j < @{$eg->[$i]->[2]}; $j++) {
			push(@{$attdata},$eg->[$i]->[0]."/".$eg->[$i]->[1]."\t".$eg->[$i]->[3]->[$j]);
		}
	}	
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($dir."class.txt",$classdata);
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($dir."attributes.txt",$attdata);
}

sub runjob {
	my $self = shift;
	if (!-e $self->jobDirectory()) {
		$self->createJobDirectory();
	}
	system("java -jar ".Bio::KBase::ObjectAPI::utilities::CLASSIFIER_BINARY()." ".$self->jobDirectory());
	my $cf = $self->loadClassifier();
	if (defined(Bio::KBase::ObjectAPI::utilities::FinalJobCache())) {
		if (!-d Bio::KBase::ObjectAPI::utilities::FinalJobCache()) {
			File::Path::mkpath (Bio::KBase::ObjectAPI::utilities::FinalJobCache());
		}
		system("cd ".$self->jobPath().";tar -czf ".Bio::KBase::ObjectAPI::utilities::FinalJobCache()."/".$self->jobID().".tgz ".$self->jobID());
	}
	if ($self->jobDirectory() =~ m/\/fbajobs\/.+/) {
		rmtree($self->jobDirectory());
	}
	return $cf;
}

sub loadClassifier {
	my $self = shift;
}

sub load_trainingset_from_input {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([],{
		workspace_training_set => [],
    	external_training_set => [],
    	description => undef,
    	source => undef,
    	class_data => [],
    	attribute_type => "functional_roles",
    	preload_attributes => 0,
	}, @_);
	print "Here!".Data::Dumper->Dump([$args]);
	my $classdata = {};
    for (my $i=0; $i < @{$args->{class_data}}; $i++) {
    	push(@{$self->class_data()},$args->{class_data}->[$i]);
    	$classdata->{$args->{class_data}->[$i]->[0]} = 1;
    }
    for (my $i=0; $i < @{$args->{workspace_training_set}}; $i++) {
    	push(@{$self->workspace_training_set()},$args->{workspace_training_set}->[$i]);
    	if (!defined($classdata->{$args->{workspace_training_set}->[$i]->[1]})) {
    		push(@{$self->class_data()},[$args->{workspace_training_set}->[$i]->[1],"none"]);
    		$classdata->{$args->{workspace_training_set}->[$i]->[1]} = 1;
    	}
    }
    for (my $i=0; $i < @{$args->{external_training_set}}; $i++) {
    	push(@{$self->external_training_set()},$args->{external_training_set}->[$i]);
    	if (!defined($classdata->{$args->{external_training_set}->[$i]->[1]})) {
    		push(@{$self->class_data()},[$args->{external_training_set}->[$i]->[1],"none"]);
    		$classdata->{$args->{external_training_set}->[$i]->[1]} = 1;
    	}
    }
    if (defined($args->{source})) {
    	$self->source($args->{source});
    }
    if (defined($args->{attribute_type})) {
    	$self->attribute_type($args->{attribute_type});
    }
    if (defined($args->{description})) {
    	$self->description($args->{description});
    }
    if ($args->{preload_attributes} == 1) {
    	$self->load_trainingset();	
    }
}

__PACKAGE__->meta->make_immutable;
1;
