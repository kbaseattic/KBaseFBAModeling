use strict;
use warnings;
use Bio::KBase::AuthToken;
use Bio::KBase::fbaModelServices::Client;
use JSON::XS;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
use LWP::Simple qw(getstore);
my $test_count = 33;
my $genomeObj;
my $token;

#Logging in
my $tokenObj = Bio::KBase::AuthToken->new(
    user_id => 'kbasetest', password => '@Suite525'
);
$token = $tokenObj->token();


