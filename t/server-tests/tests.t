use FindBin qw($Bin);
use Bio::KBase::fbaModelServices::KBaseFBAModelingTests;

my $tester = Bio::KBase::fbaModelServices::KBaseFBAModelingTests->new($Bin);
$tester->run_tests();