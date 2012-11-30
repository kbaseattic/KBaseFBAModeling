#!/usr/bin/perl 
#===============================================================================
#
#         FILE: genome_object_to_workspace.pl
#
#        USAGE: ./genome_object_to_workspace.pl -f <filename> <workspace>
#
#  DESCRIPTION: Upload a genome from file / stdin to workspace
#
#===============================================================================
use strict;
use warnings;
use Getopt::Long;
use Bio::KBase::fbaModelServices::Client;
use JSON;
my $defaultURL = "http://kbase.us/services/fbaModelServices";
my $serv = Bio::KBase::fbaModelServices::Client->new($defaultURL);
my $usage = "$0 <workspace> [ < file || --file [-f] filename ]\n"; 
my $filename;
my $rtv = GetOptions( "file|f=s" => \$filename );
my $workspace = shift @ARGV;
if (!defined $workspace) {
    die $usage;
}
my $fh = \*STDIN;
if (defined $filename && -f $filename) {
    open( $fh, "<", $filename) || die "Could not open $filename: $!";
}
if ( -t $fh ) {
    die $usage; 
}
my $genome_obj;
{
    local $/;
    my $str = <$fh>;
    $genome_obj = decode_json $str;
}
$serv->genome_object_to_worksapce({
        genomeobj => $genome_obj,
        workspace => $workspace,
});
close($fh);
