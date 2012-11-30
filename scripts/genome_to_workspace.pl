#!/usr/bin/perl 
use strict;
use warnings;
use Bio::KBase::fbaModelServices::Client;
# TODO : Auth
my $defaultURL = "http://kbase.us/services/fbaModelServices";
my $serv = Bio::KBase::fbaModelServices::Client->new($defaultURL);
my $usage = "$0 [genome_id] [workspace_name]\n";
my ($genome_id, $workspace) = @ARGV;
die $usage unless defined $genome_id && defined $workspace;
$serv->genome_to_workspace({
        genome => $genome_id,
        workspace => $workspace,
});
