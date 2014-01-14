package Bio::KBase::ObjectAPI::Attribute::KBTyped;
use strict;
use warnings;
use Moose;
use namespace::autoclean;
extends 'Moose::Meta::Attribute';
has type => (
      is        => 'rw',
      isa       => 'Str',
      predicate => 'has_type',
);

has printOrder => (
      is        => 'rw',
      isa       => 'Int',
      predicate => 'has_printOrder',
      default => '-1',
);
1;

package Moose::Meta::Attribute::Custom::KBTyped;
sub register_implementation { 'Bio::KBase::ObjectAPI::Attribute::KBTyped' }
1;
