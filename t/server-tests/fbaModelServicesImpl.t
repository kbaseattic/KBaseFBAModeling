use FindBin qw($Bin);
use lib $Bin.'/../lib';
use lib $Bin.'/../../workspace_service/lib/';
use lib $Bin.'/../../kb_seed/lib/';
use lib $Bin.'/../../idserver/lib/';
use lib "/kb/deployment/lib/perl5/site_perl/5.16.0/Bio/";
use lib "/kb/deployment/lib/perl5/site_perl/5.16.1/";
use Bio::KBase::workspace::Client;
use LWP::Simple qw(getstore);
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);
use Bio::KBase::fbaModelServices::Impl;
use JSON::XS;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
my $test_count = 17;

#Logging in
my $tokenObj = Bio::KBase::AuthToken->new(
    user_id => 'kbasetest', password => '@Suite525'
);
my $token = $tokenObj->token();

done_testing($test_count);