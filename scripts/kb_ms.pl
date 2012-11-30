#!/usr/bin/perl 
use strict;
use warnings;
use Bio::KBase::fbaModelCLI::Client;
my $serv = Bio::KBase::fbaModelCLI::Client->new("http://kbase.us/services/fbaModelCLI");

my @args = @ARGV;
unshift @args, "mseed";
my $stdin;
if ( ! -t STDIN ) {
    local $/;
    $stdin = <STDIN>;
}
my ($status, $stdout, $stderr) = $serv->execute_command(\@args, $stdin);
print STDERR $stderr if defined $stderr;
print STDOUT $stdout if defined $stdout;
exit($status);
