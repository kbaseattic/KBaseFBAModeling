use strict;
use warnings;
use FindBin qw($Bin);
use lib $Bin.'/../lib';
use Bio::KBase::fbaModel::CLI::Impl;
use Test::More tests => 1;

my $api = Bio::KBase::fbaModel::CLI::Impl->new;
ok defined $api;
