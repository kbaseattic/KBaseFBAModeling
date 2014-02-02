#!/usr/bin/perl -w

use strict;
use Config::Simple;
#use Bio::KBase::workspaceService::Client;
use Bio::KBase::workspaceService::Impl;
$|=1;

my $config = $ARGV[0];
my $directory = $ARGV[1];
if (!defined($config)) {
	print STDERR "No config file provided!\n";
	exit(-1);
}
if (!-e $config) {
	print STDERR "Config file ".$config." not found!\n";
	exit(-1);
}

my $c = Config::Simple->new();
$c->read($config);

$Bio::KBase::workspaceService::Server::CallContext = {_override => {_authentication => ""}};
my $wserv = Bio::KBase::workspaceService::Impl->new({
	"mongodb-database" => "workspace_service",
	"mssserver-url" => "http://biologin-4.mcs.anl.gov:7050",
	"idserver-url" => "http://kbase.us/service/idserver",
	"mongodb-host" => "mongodb.kbase.us"
});

open( my $fh, "<", $directory."/ObjectList.txt");
while (my $str = <$fh>) {
	chomp($str);
	my $array = [split(/[\t;]/,$str)];
    if ($array->[0] eq "Genome") {
    	my $output = $wserv->get_object({
			id => $array->[2],
			workspace => $array->[1],
			type => $array->[0],
			auth => $c->param("kbclientconfig.auth")
		});
		print $array->[1]."/".$array->[2]."\t".$output->{data}->{annotation_uuid}."\n";
    }
}
close($fh);

1;
