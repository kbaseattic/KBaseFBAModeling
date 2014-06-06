########################################################################
# Bio::KBase::ObjectAPI::KBaseRegulatoryFBA::EfluxExpressionCollection - This is the moose object corresponding to the KBaseRegulatoryFBA.EfluxExpressionCollection object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2014-06-06T18:46:51
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseRegulatoryFBA::DB::EfluxExpressionCollection;
package Bio::KBase::ObjectAPI::KBaseRegulatoryFBA::EfluxExpressionCollection;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseRegulatoryFBA::DB::EfluxExpressionCollection';
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
