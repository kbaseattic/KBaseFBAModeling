#!/usr/bin/perl -w

########################################################################
# This perl script annotates plant genomes for the PlantSEED
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
require '/homes/seaver/public_html/FIGdisk/config/FIG_Config.pm';
use FIG;
use gjoseqlib qw( translate_seq %reverse_genetic_code_DNA);
use ANNOserver;

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
my $genome = {
	source => "PlantSEED",
	domain => "Plant",
	genetic_code => 11,
	features=>[]
};
my $jobdata = $job->{jobdata};
my $sequences;
my $proteins = 1;
my $GenomeID = $jobdata->{genome_id};
################################################################
## 
## Checking if the input job contains a protein set
##
################################################################
if (defined($jobdata->{ProteinSet_uid})) {
	$genome->{source_id} = $GenomeID;
	$genome->{scientific_name} = $jobdata->{name};
	my $output = $wsserv->get_object({
		id => $jobdata->{ProteinSet_uid},
		type => "ProteinSet",
		workspace => $jobdata->{ProteinSet_ws},
		instance => $jobdata->{ProteinSet_inst},
		auth => $job->{auth}
	});
	$sequences = $output->{data}->{proteins};
################################################################
## 
## Checking if the input job contains a transcript set
##
################################################################
} elsif (defined($jobdata->{TranscriptSet_uid})) {
	$genome->{source_id} = $GenomeID;
	$genome->{scientific_name} = $jobdata->{name};
	my $output = $wsserv->get_object({
		id => $jobdata->{TranscriptSet_uid},
		type => "TranscriptSet",
		workspace => $jobdata->{TranscriptSet_ws},
		instance => $jobdata->{TranscriptSet_inst},
		auth => $job->{auth}
	});
	$proteins = 0;
	$sequences = $output->{data}->{transcripts};
################################################################
## 
## Checking if the input job contains a genome
##
################################################################
} elsif defined($jobdata->{Genome_uid})() {
	my $output = $wsserv->get_object({
		id => $job->{jobdata}->{Genome_uid},
		type => "Genome",
		workspace => $job->{jobdata}->{Genome_ws},
		instance => $job->{jobdata}->{Genome_inst},
		auth => $job->{auth}
	});
	if (defined($output->{data}->{protein_wsid})) {
		if ($output->{data}->{protein_wsid} =~ m/(.+)\/(.+)\/v(.+)/) {
			$proteins = 1;
			my $output = $wsserv->get_object({
				id => $2,
				type => "ProteinSet",
				workspace => $1,
				instance => $3,
				auth => $job->{auth}
			});
			$sequences = $output->{data}->{proteins};
		}
	} elsif (defined($output->{data}->{transcript_wsid})) {
		if ($output->{data}->{transcript_wsid} =~ m/(.+)\/(.+)\/v(.+)/) {
			$proteins = 0;
			my $output = $wsserv->get_object({
				id => $2,
				type => "TranscriptSet",
				workspace => $1,
				instance => $3,
				auth => $job->{auth}
			});
			$sequences = $output->{data}->{transcripts};
		}
	}
	$output->{data}->{domain} = "Plant";
}
################################################################
## 
## Translating sequencing data
##
################################################################
my $size = 0;
my $gc = 0;
for (my $i=0; $i < @{$sequences}; $i++) {
	my $sequence = $sequences->[$i];
	if ($proteins == 1) {
		$sequence->{prot} = $sequence->{sequence};
		$sequence->{dna} = "";
		foreach my $aa (split(//,$sequence->{prot})) {
			$sequence->{dna} .= $reverse_genetic_code_DNA{$aa};
		}
		delete $sequence->{sequence};
	} else {
		$sequence->{dna} = $sequence->{sequence};
		$sequence->{prot} = translate_seq($sequence->{sequence});
		delete $sequence->{sequence};		
	}
	for ( my $j = 0; $j < length($sequence->{dna}); $j++ ) {
		if ( substr( $sequence->{dna}, $j, 1 ) =~ m/[gcGC]/ ) {
			$gc++;
		}
	}
	$size += length($sequence->{dna});
	my $counter = ($i+1);
	my $geneid = "fig|".$GenomeID.".peg.".$counter;
	push(@{$genome->{features}},{
		id => $geneid,
		location => [[$geneid,1,"+",length($sequence->{dna})]],
		type => "peg",
		function => "",
		alternative_functions => [],
		protein_translation => $sequence->{prot},
		aliases => [$sequence->{sourceid}],
		annotations => []};
	});
}
$genome->{size} = $size;
$genome->{gc} = $gc/$size;
################################################################
## 
## Retrieve PlantRAST Genome id and build directory structure
##
################################################################
my $PlantRast_Root = "/vol/model-prod/rast-plants/";
my $GenomeDir = $PlantRast_Root."Genomes/".$GenomeID."/";

my %Files = (GENETIC_CODE=>11,
	     GENOME=>$jobdata->{name},
	     GENOME_ID=>$GenomeID,
	     PROJECT=>"PlantRAST",
	     TAXONOMY=>"unknown",
	     USER=>$jobdata->{owner},
	     USER_ID=>$jobdata->{user_id});

mkdir $GenomeDir;

#Not for Apple or Foxtail Millet
if($GenomeID !~ /\.[12]$/){
    foreach my $file (keys %Files){
		open(FH, "> ".$GenomeDir.$file);
		print FH $Files{$file}."\n";
		close(FH);
    }
}

mkdir $GenomeDir."Features/";
my $FeaturesDir = $GenomeDir."Features/peg/";
mkdir $FeaturesDir;
mkdir $GenomeDir."Subsystems/";
mkdir $GenomeDir."QsubOutput/";

################################################################
## 
## Using ANNOserver::assign_function_to_prot() to annotate
##
################################################################

#Creating duplicate array because assign_function_to_prot() 
# 'empties' array via reference
my @TmpSequences = @Sequences;

#print scalar(@TmpSequences),"\n";
#print join("\n",map { $_->[0]." ".$_->[2] } @TmpSequences[0..10]),"\n";
#exit();

my $ffServer = ANNOserver->new();

# Pass the input file to the FIGfam server to get assignments.
my $AnnoResults = $ffServer->assign_function_to_prot(-input => \@TmpSequences,
						     -kmer => 8,
						     (-kmerDataset => "Release64"),
						     (), #(-determineFamily => 1),
						     -scoreThreshold => 3,
						     -assignToAll => 0);

my %Assigned_Functions=();
open(OUT, "> ".$GenomeDir."annoresults_release64");
while (my $result = $AnnoResults->get_next()) {
    if($result && scalar(@$result)>0){
		my($id, $function, $otu, $score, $nonoverlap_hits, $overlap_hits, $details, $fam) = @$result;
		if($function){
		    $Assigned_Functions{$id}=$function;
		}
    }
}
close(OUT);

if(scalar(keys %Assigned_Functions) < 100){
    print STDERR "Not enough functions assigned\n";
}

################################################################
## 
## Simultaneously building genome files and genome object
##
################################################################
open(TBL, "> ".$FeaturesDir."tbl");
open(FAS, "> ".$FeaturesDir."fasta");
open(FUN, "> ".$GenomeDir."assigned_functions");
open(CON, "> ".$GenomeDir."contigs");
my $counter=1;
for (my $i=0; $i < @{$sequences}; $i++) {
	my $sequence = $sequences->[$i];
	print CON ">".$sequence->{id}."\n";
    print CON join("\n", $sequence->{dna} =~ m/.{1,60}/g)."\n";
	print TBL $sequence->{id}."\t".$sequence->{id}."_1_".length($sequence->{dna})."\t".$seq->[0]."\t".join("\t",split(/\s+/,$seq->[1]))."\n";
    print FAS ">".$sequence->{id}."\n";
    print FAS join("\n", $sequence->{dna} =~ m/.{1,60}/g)."\n";
    if($Assigned_Functions{$seq->[0]}){
		$featureHash->{function}=$Assigned_Functions{$seq->[0]};
		print FUN $PegId,"\t",$Assigned_Functions{$seq->[0]},"\n";
    }
}
close(TBL);
close(FAS);
close(FUN);
close(CON);
################################################################
## 
## Uploading Genome Object to workspace
##
################################################################
my $fbaserv = Bio::KBase::fbaModelServices::Client->new($job->{fbaurl});
delete $genome->{contigs};
$fbaserv->genome_object_to_workspace({
	uid => $GenomeID.".".$jobdata->{user_id},
	genomeobj => $genome,
	workspace => $jobdata->{workspace},
	auth => $job->{auth}
});
################################################################
## 
## Creating Subsystem bindings for genome files
##
################################################################
system("cat ".$GenomeDir."assigned_functions | rapid_subsystem_inference ".$GenomeDir."Subsystems > ".$GenomeDir."rsi_output 2>&1");
################################################################
## 
## Index files in Genome directory
##
################################################################
system("make_fasta_btree","$GenomeDir/contigs","$GenomeDir/contigs.btree","$GenomeDir/contig_len.btree");
system("index_feature_dir_fasta","$GenomeDir/Features/peg");
system("index_figv_annos",$GenomeDir);
################################################################
## 
## Re-construct model from genome
##
################################################################
my $model = "Seed".$GenomeID.".".$jobdata->{user_id};
$fbaserv->genome_to_fbamodel({
	workspace=>$job->{workspace},
	auth=>$job->{auth},
	genome=>$GenomeID.".".$jobdata->{user_id},
	model => $model
});
################################################################
## 
## Gap-fill reconstructed model
##
################################################################


################################################################
## 
## Export all data
##
################################################################
my $ExportDir = "/vol/ftp.theseed.org/Plants/genomes-rast/".$GenomeID."/";
system("./Data_Exporter.pl",$GenomeDir,$ExportDir);
my $output = eval{
	return $fbaserv->export_fbamodel({
		workspace=>$job->{workspace},
		model=>$model,
		format=>"html"
	});
};
if($output){
    open(OUT, "> ".$WebRoot."Html/".$obj->[0].".html");
    print OUT $output;
    close(OUT);
} else {
    print "\tHtml Failed\n";
}
################################################################
## 
## Run BLAST Qsub job and process/index resulting files
##
################################################################
#prepare Blast command
my @Command = ("/vol/rast-bcr/2010-1124/linux-rhel5-x86_64/bin/blastall");
push(@Command,"-p");push(@Command,"blastp");
push(@Command,"-FF");
push(@Command,"-e");push(@Command,"1.0e-3");
push(@Command,"-m");push(@Command,"8");

#prepare Blast files
push(@Command,"-d");push(@Command,$PlantRast_Root."DBs/PubSEED_Plants_Families_Shortened");
push(@Command,"-i");push(@Command,$FeaturesDir."fasta");
push(@Command,"-o");push(@Command,$GenomeDir."plant_families_similarities");

my $cmd=join(" ",@Command);
system($cmd);

system("./PostProcessing_Sims.pl $GenomeDir");
system("./Index_Blast_Results.pl $GenomeDir");
################################################################
## 
## Completing job
##
################################################################
$wsserv->set_job_status({
	auth => $job->{auth},
	jobid => $job->{id},
	currentStatus => "running",
	status => "done"
});
1;