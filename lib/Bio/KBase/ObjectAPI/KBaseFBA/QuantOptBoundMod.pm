########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::QuantOptBoundMod - This is the moose object corresponding to the KBaseFBA.QuantOptBoundMod object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2014-11-20T02:29:26
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::QuantOptBoundMod;
package Bio::KBase::ObjectAPI::KBaseFBA::QuantOptBoundMod;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::QuantOptBoundMod';
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
