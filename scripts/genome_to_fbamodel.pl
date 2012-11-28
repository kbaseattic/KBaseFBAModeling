#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use fbaModelServicesClient;
my $defaultURL = "http://bio-data-1.mcs.anl.gov/services/fba";
my $serv = fbaModelServicesClient->new($defaultURL);
my $usage = "$0 <workspace> <genome_name> <model_name>\n";
my ($workspace, $genome, $model) = @ARGV;
die $usage unless defined $workspace && defined $genome && defined $model;
$serv->genome_to_fbamodel({
    genome => $genome,
    genome_workspace => $workspace,
    model_workspace => $workspace,
    model => $model,
});
