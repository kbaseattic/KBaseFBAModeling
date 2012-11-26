#!/usr/bin/perl 
#===============================================================================
#
#         FILE: export_fbamodel.pl
#
#        USAGE: ./export_fbamodel.pl [workspace] [model] [format]
#
#  DESCRIPTION: Export FBA model from workspace with the supplied format.
#               Supported: "html", "sbml", "readable", "json"
#
#===============================================================================
use strict;
use warnings;
use fbaModelServicesClient;
my $defaultURL = "http://kbase.us/services/fbaModelServices";
my $serv = fbaModelServicesClient->new($defaultURL);
my ($workspace, $model, $format) = @ARGV;
my $supported = { map { $_ => 1 } qw( html sbml readable json ) };
my $usage = "$0 [workspace] [model] [format]\n" . 
"Supported formats: " . join(", ", keys %$supported) . "\n";
unless (defined $workspace && defined $model &&
        defined $format && $supported->{$format}) {
    die $usage;
}
my ($string) = $serv->export_fbamodel({
        model => $model,
        workspace => $workspace,
        format => $format,
});
print $string;
