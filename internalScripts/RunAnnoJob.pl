#!/usr/bin/perl -w

########################################################################
# This perl script runs the designated queue for model reconstruction
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 10/6/2009
########################################################################
use strict;
use warnings;
use JSON::XS;
use Bio::KBase::workspaceService::Client;
use Bio::KBase::fbaModelServices::Client;
use Bio::KBase::GenomeAnnotation::GenomeAnnotationImpl;

$|=1;
if (!defined($ARGV[0])) {
	exit(0);
}
my $filename = $ARGV[0];
open( my $fh, "<", $filename."jobfile.json");
my $job;
{
    local $/;
    my $str = <$fh>;
    $job = decode_json $str;
}
close($fh);
if (!defined($job->{wsurl})) {
	$job->{wsurl} = "http://kbase.us/services/workspace";
}
if (!defined($job->{fbaurl})) {
	$job->{fbaurl} = "http://140.221.85.73:4043";
}
my $wsserv = Bio::KBase::workspaceService::Client->new($job->{wsurl});
my $output = $wsserv->get_object_by_ref({
	reference => $job->{jobdata}->{contig_reference},
	auth => $job->{auth}
});
my $annoserv = Bio::KBase::GenomeAnnotation::GenomeAnnotationImpl->new();
my $genome = {
	id => $job->{jobdata}->{genomeid},
	genetic_code => $output->{data}->{genetic_code},
	features => [],
	domain => $output->{data}->{domain},
	scientific_name => $output->{data}->{scientific_name},
	contigs => $output->{data}->{contigs},
	source => $job->{jobdata}->{source}
};
for (my $i=0; $i < @{$genome->{contigs}}; $i++) {
	$genome->{contigs}->[$i]->{dna} = $genome->{contigs}->[$i]->{seq};
	delete $genome->{contigs}->[$i]->{seq};
}
$genome = $annoserv->annotate_genome($genome);
my $fbaserv = Bio::KBase::fbaModelServices::Client->new($job->{jobdata}->{fbaurl});
$fbaserv->genome_object_to_workspace({
	genomeobj => $genome,
	workspace => $job->{jobdata}->{workspace},
	auth => $job->{auth}
});
$wsserv->set_job_status({
	auth => $job->{auth},
	jobid => $job->{id},
	currentStatus => "running",
	status => "done"
});

1;
