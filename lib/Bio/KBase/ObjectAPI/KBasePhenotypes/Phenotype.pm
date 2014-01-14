########################################################################
# Bio::KBase::ObjectAPI::KBasePhenotypes::Phenotype - This is the moose object corresponding to the KBasePhenotypes.Phenotype object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2014-01-05T15:36:51
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBasePhenotypes::DB::Phenotype;
package Bio::KBase::ObjectAPI::KBasePhenotypes::Phenotype;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBasePhenotypes::DB::Phenotype';
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


__PACKAGE__->meta->make_immutable;
1;
