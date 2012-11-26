#!/usr/bin/perl 
use strict;
use warnings;
use fbaModelServicesClient;
# TODO : Auth
my $defaultURL = "http://kbase.us/services/fbaModelServices";
my $serv = fbaModelServicesClient->new($defaultURL);
my $usage = "$0 [genome_id] [workspace_name]\n";
my ($genome_id, $workspace) = @ARGV;
die $usage unless defined $genome_id && defined $workspace;
$serv->genome_to_workspace({
        genome => $genome_id,
        workspace => $workspace,
});
