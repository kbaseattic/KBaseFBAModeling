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
my $wsserv = Bio::KBase::workspaceService::Client->new($job->{wsurl});
my $output = $wsserv->get_object_by_ref({
	reference => $job->{jobdata}->{contig_reference},
	auth => $job->{auth}
});
my $annoserv = Bio::KBase::GenomeAnnotation::GenomeAnnotationImpl->new();
my $genome = $output->{data};
$genome = $annoserv->annotate_genome($genome);
my $fbaserv = Bio::KBase::fbaModelServices::Client->new($job->{jobdata}->{fbaurl});
$fbaserv->genome_to_workspace({
	genome => $job->{jobdata}->{genomeid},
	workspace => $job->{jobdata}->{workspace},
	auth => $job->{auth}
});
$wserv->set_job_status({
	auth => $job->{auth},
	jobid => $job->{id},
	currentStatus => "running",
	status => "done"
});

1;
