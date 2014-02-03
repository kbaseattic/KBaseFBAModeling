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
use Bio::KBase::fbaModelServices::ScriptHelpers qw( fbaURL get_fba_client runFBACommand universalFBAScriptCode fbaTranslation roles_of_function );

#Defining globals describing behavior
my $primaryArgs = ["New server URL"];
#Defining usage and options
my ($opt, $usage) = describe_options(
    'fba-url <'.join("> <",@{$primaryArgs}).'> %o',
    [ 'help|h|?', 'Print this usage information' ],
);
print "Current URL is:\n".fbaURL($ARGV[0])."\n";
