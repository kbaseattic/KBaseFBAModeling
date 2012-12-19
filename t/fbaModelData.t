use strict;
use warnings;
use FindBin qw($Bin);
use lib $Bin.'/../lib';
use Bio::KBase::fbaModelData::Impl;
use Test::More tests => 2;

my $api = Bio::KBase::fbaModelData::Impl->new;
ok defined $api;
ok $api->does('ModelSEED::Database');
