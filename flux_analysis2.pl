
use strict;
use Bio::KBase::fbaModelServices::Impl;
use Bio::KBase::ObjectAPI::KBaseFBA::FBA;
use Bio::KBase::Auth;

my $configs = Bio::KBase::Auth::GetConfigs();
my $token = $configs->{token};
$Bio::KBase::fbaModelServices::Server::CallContext = {token => $token};
my $impl = Bio::KBase::fbaModelServices::Impl->new({"workspace-url" => "http://kbase.us/services/ws"});
$impl->_setContext({token=>$token},{});
$impl->_test_comp_FBA;
