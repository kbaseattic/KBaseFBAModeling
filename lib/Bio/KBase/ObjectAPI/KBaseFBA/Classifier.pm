########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::Classifier - This is the moose object corresponding to the Classifier object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-11-15T18:17:11
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::Classifier;
package Bio::KBase::ObjectAPI::KBaseFBA::Classifier;
use Moose;
use namespace::autoclean;
use Bio::KBase::ObjectAPI::utilities;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::Classifier';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************



#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub classify_genomes {
	my $self = shift;
	my $ts = shift;
	$ts->createJobDirectory();
	$self->printClassifier($ts->jobDirectory());
	system("java -jar ".Bio::KBase::ObjectAPI::utilities::CLASSIFIER_BINARY()." ".$ts->jobDirectory());
	my $cr = $self->loadClassifierResult();
	if (defined(Bio::KBase::ObjectAPI::utilities::FinalJobCache())) {
		if (!-d Bio::KBase::ObjectAPI::utilities::FinalJobCache()) {
			File::Path::mkpath (Bio::KBase::ObjectAPI::utilities::FinalJobCache());
		}
		system("cd ".$ts->jobPath().";tar -czf ".Bio::KBase::ObjectAPI::utilities::FinalJobCache()."/".$ts->jobID().".tgz ".$ts->jobID());
	}
	if ($ts->jobDirectory() =~ m/\/fbajobs\/.+/) {
		rmtree($ts->jobDirectory());
	}
	return $cr;
}

sub printClassifier {
	my $self = shift;
}

sub loadClassifierResult {
	my $self = shift;
}

=head3 classifyAnnotation

Definition:
	string Bio::KBase::ObjectAPI::KBaseFBA::Classifier->classifyAnnotation({
		annotation => Bio::KBase::ObjectAPI::Annotation
	});
Description:
	Classifies the input annotation object

=cut

sub classifyAnnotation {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["annotation"],{},@_);
	my $anno = $args->{annotation};
	my $features = $anno->features();
	my $scores = {};
	my $classes = $self->classifierClassifications();
	my $sum = 0;
	foreach my $class (@{$classes}) {
		$scores->{$class->uuid()} = 0;
		$sum += $class->populationProbability();
	}
	for (my $i=0; $i < @{$features}; $i++) {
		my $feature = $features->[$i];
		my $roles = $feature->featureroles();
		foreach my $role (@{$roles}) {
			my $classrole = $self->queryObject("classifierRoles",{role_uuid => $role->role()->uuid()});
			if (defined($classrole)) {
				my $roleclasses = $classrole->classifications();
				foreach my $roleclass (@{$roleclasses}) {
					$scores->{$roleclass->uuid()} += $classrole->classificationProbabilities()->{$roleclass->uuid()};
				}
			}
		}
	}
	my $largest;
	my $largestClass;
	foreach my $class (@{$classes}) {
		$scores->{$class->uuid()} += log($class->populationProbability()/$sum);
		if (!defined($largest)) {
			$largest = $scores->{$class->uuid()};
			$largestClass = $class;
		} elsif ($largest > $scores->{$class->uuid()}) {
			$largest = $scores->{$class->uuid()};
			$largestClass = $class;
		}
	}
	return $largestClass;
}

=head3 classifyRoles

Definition:
	string Bio::KBase::ObjectAPI::KBaseFBA::Classifier->classifyRoles({
		functions => {}
	});
Description:
	Classifies based on input functions with relative abundance

=cut

sub classifyRoles {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["functions"],{},@_);
	my $scores = {};
	my $classes = $self->classifierClassifications();
	my $sum = 0;
	foreach my $class (@{$classes}) {
		$scores->{$class->uuid()} = 0;
		$sum += $class->populationProbability();
	}
	foreach my $function (keys(%{$args->{functions}})) {
		my $searchrole = Bio::KBase::ObjectAPI::Utilities::GlobalFunctions::convertRoleToSearchRole($function);
		my $subroles = [split(/;/,$searchrole)];
		for (my $m=0; $m < @{$subroles}; $m++) {
			my $roles = $self->mapping()->searchForRoles($subroles->[$m]);
			for (my $n=0; $n < @{$roles};$n++) {
				my $classrole = $self->queryObject("classifierRoles",{role_uuid => $roles->[$n]->uuid()});
				if (defined($classrole)) {
					my $roleclasses = $classrole->classifications();
					foreach my $roleclass (@{$roleclasses}) {
						$scores->{$roleclass->uuid()} += $args->{functions}->{$function}*$classrole->classificationProbabilities()->{$roleclass->uuid()};
					}
				}
			}
		}		
	}
	my $largest;
	my $largestClass;
	foreach my $class (@{$classes}) {
		$scores->{$class->uuid()} += log($class->populationProbability()/$sum);
		if (!defined($largest)) {
			$largest = $scores->{$class->uuid()};
			$largestClass = $class;
		} elsif ($largest > $scores->{$class->uuid()}) {
			$largest = $scores->{$class->uuid()};
			$largestClass = $class;
		}
	}
	return $largestClass;
}

__PACKAGE__->meta->make_immutable;
1;
