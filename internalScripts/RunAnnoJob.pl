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
	$job->{fbaurl} = "http://kbase.us/services/fba_model_services";
}
my $wsserv = Bio::KBase::workspaceService::Client->new($job->{wsurl});
my $output = $wsserv->get_object({
	id => $job->{jobdata}->{Genome_uid},
	type => "Genome",
	workspace => $job->{jobdata}->{Genome_ws},
	instance => $job->{jobdata}->{Genome_inst},
	auth => $job->{auth}
});
my $inGenome = $output->{data};
my $annoserv = Bio::KBase::GenomeAnnotation::GenomeAnnotationImpl->new();
#Setting full pipeline 
if (!defined($job->{jobdata}->{stages})) {
	$job->{jobdata}->{stages} = [
		{
			id => "call_selenoproteins",
			enable => 1,
			parameters => {}
		},
		{
			id => "call_pyrrolysoproteins",
			enable => 1,
			parameters => {}
		},
		{
			id => "call_RNAs",
			enable => 1,
			parameters => {}
		},
		{
			id => "call_CDSs",
			enable => 1,
			parameters => {}
		},
		{
			id => "find_close_neighbors",
			enable => 1,
			parameters => {}
		},
		{
			id => "assign_functions_to_CDSs",
			enable => 1,
			parameters => {}
		}
	];
}
#Removing gene calling steps if only proteins are provided
if (defined($inGenome->{protein_wsid}) && !defined($inGenome->{transcript_wsid}) && !defined($inGenome->{contig_wsid})) {
	my $newstages;
	for (my $i=0; $i < @{$job->{jobdata}->{stages}}; $i++) {
		if ($job->{jobdata}->{stages}->[$i]->{id} !~ m/^call_/) {
			push(@{$newstages},$job->{jobdata}->{stages}->[$i]);
		}
	}
	$job->{jobdata}->{stages} = $newstages;
} elsif (defined($inGenome->{contig_wsid})) {
	if ($inGenome->{contig_wsid} =~ m/(.+)\/(.+)\/v(.+)/) {
		my $output = $wsserv->get_object({
			id => $2,
			type => "ContigSet",
			workspace => $1,
			instance => $3,
			auth => $job->{auth}
		});
		for (my $i=0; $i < @{$output->{data}->{contigs}}; $i++) {
			$inGenome->{contigs}->[$i] = {
				id => $output->{data}->{contigs}->[$i]->{sourceid},
				dna => $output->{data}->{contigs}->[$i]->{sequence},
			};
		}
	}
} elsif (defined($inGenome->{transcript_wsid})) {
	if ($inGenome->{transcript_wsid} =~ m/(.+)\/(.+)\/v(.+)/) {
		my $output = $wsserv->get_object({
			id => $2,
			type => "TranscriptSet",
			workspace => $1,
			instance => $3,
			auth => $job->{auth}
		});
		for (my $i=0; $i < @{$output->{data}->{transcripts}}; $i++) {
			$inGenome->{contigs}->[$i] = {
				id => $output->{data}->{contigs}->[$i]->{sourceid},
				dna => $output->{data}->{contigs}->[$i]->{sequence},
			};
		}
	}
}
#Running annotation pipeline
for (my $i=0; $i < @{$job->{jobdata}->{stages}}; $i++) {
	if ($job->{jobdata}->{stages}->[$i]->{id} eq "call_selenoproteins") {
		#$inGenome = $annoserv->call_selenoproteins($inGenome);
	} elsif ($job->{jobdata}->{stages}->[$i]->{id} eq "call_pyrrolysoproteins") {
		#$inGenome = $annoserv->call_pyrrolysoproteins($inGenome);
	} elsif ($job->{jobdata}->{stages}->[$i]->{id} eq "call_RNAs") {
		$inGenome = $annoserv->call_RNAs($inGenome);
	} elsif ($job->{jobdata}->{stages}->[$i]->{id} eq "call_CDSs") {
		$inGenome = $annoserv->call_CDSs($inGenome);
	} elsif ($job->{jobdata}->{stages}->[$i]->{id} eq "find_close_neighbors") {
		#$inGenome = $annoserv->find_close_neighbors($inGenome);
	} elsif ($job->{jobdata}->{stages}->[$i]->{id} eq "assign_functions_to_CDSs") {
		$inGenome = $annoserv->assign_functions_to_CDSs($inGenome);
	}
}
my $fbaserv = Bio::KBase::fbaModelServices::Client->new($job->{fbaurl});
delete $inGenome->{contigs};
$fbaserv->genome_object_to_workspace({
	uid => $job->{jobdata}->{Genome_uid},
	genomeobj => $inGenome,
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
