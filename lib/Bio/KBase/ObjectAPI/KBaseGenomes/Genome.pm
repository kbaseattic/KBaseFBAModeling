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


__PACKAGE__->meta->make_immutable;
1;
