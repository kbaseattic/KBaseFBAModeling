#!/usr/bin/perl 
#===============================================================================
#
#         FILE: fbamodel_to_html.pl
#
#        USAGE: ./fbamodel_to_html.pl [workspace] [model]
#
#  DESCRIPTION: Export FBA model from workspace to html format.
#
#===============================================================================
use strict;
use warnings;
use Bio::KBase::fbaModelServices::Client;
my $defaultURL = "http://kbase.us/services/fbaModelServices";
my $serv = Bio::KBase::fbaModelServices::Client->new($defaultURL);
my ($workspace, $model) = @ARGV;
my $usage = "$0 [workspace] [model]\n" . 
unless (defined $workspace && defined $model) {
    die $usage;
}
my ($string) = $serv->export_fbamodel({
        model => $model,
        workspace => $workspace,
        format => "html",
});
print $string;
