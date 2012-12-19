use strict;
use warnings;
use FindBin qw($Bin);
use lib $Bin.'/../lib';
use lib "../kb_model_seed/submodules/ModelSEED/blib/lib";
use Bio::KBase::fbaModelCLI::Impl;
use Test::More tests => 1;

my $api = Bio::KBase::fbaModelCLI::Impl->new;
ok defined $api;
