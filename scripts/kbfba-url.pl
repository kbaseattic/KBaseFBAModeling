#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Getopt::Long::Descriptive;
use Text::Table;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client fbaURL);
#Defining globals describing behavior
my $primaryArgs = ["New server URL"];
#Defining usage and options
my ($opt, $usage) = describe_options(
    'kbfba-url <'.join("> <",@{$primaryArgs}).'> %o',
    [ 'help|h|?', 'Print this usage information' ],
);
print "Current URL is:\n".fbaURL($ARGV[0])."\n";
