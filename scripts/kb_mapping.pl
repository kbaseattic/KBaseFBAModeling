#!/usr/bin/perl 
use strict;
use warnings;
use Bio::KBase::fbaModel::CLI;
my $serv = Bio::KBase::fbaModel::CLI->new("http://kbase.us/services/fbaModelCLI");

my @args = @ARGV;
unshift @args, "mapping";
my $stdin;
if ( ! -t STDIN ) {
    local $/;
    $stdin = <STDIN>;
}
my ($status, $stdout, $stderr) = $serv->execute_command(\@args, $stdin);
print STDERR $stderr if defined $stderr;
print STDOUT $stdout if defined $stdout;
exit($status);
