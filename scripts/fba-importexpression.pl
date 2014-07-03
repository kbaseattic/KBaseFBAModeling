#!/usr/bin/env perl
# Author: Shinnosuke Kondo @ Hope College, Holland, MI
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode getToken);
use Bio::KBase::ObjectAPI::utilities qw(LOADTABLE);
use File::Basename;
use POSIX qw/strftime/;

#Defining globals describing behavior
my $primaryArgs = ["Gene expression flat file"];
my $servercommand = "import_expression";
my $script = "fba-importexpression";
my $translation = {
	workspace => "workspace",
	sourceid => "source_id",
	sourcedate => "source_date",
	description => "description",
	processing_comments => "processing_comments",
	ignoreerrors => "ignore_errors",
	genomeid => "genome_id",
	numinterpret => "numerical_interpretation",
};

my $manpage = 
"
NAME
      fba-importexpression

DESCRIPTION

      Import an expression data sample series from a flat file and save the results as a ExpressionSeries object in a workspace.
      The flat file describes expression values of a feature in given sample.
      Each row (except the header row) in the data file contains gene expression value for one
      feature.

      The first line of the model file is required and contains the ID of samples. Lines follows it
      should contain a feature ID in the first column, and expression values in any other column.
      Notice that since the first row does not contain a feature ID, it is shorter than other rows
      By one column.

      The following is an example data file

      10_FB1-2.CEL.gz	11_FB2-2.CEL.gz	12_FB2-2.CEL.gz
      kb|g.0.peg.634	8.63830081697123	8.64678476189026	8.66268102487218
      kb|g.0.peg.167	9.79555993848683	8.89302312434434	8.67845774993186
      kb|g.0.peg.236	8.6230928295351	8.07082173268051	8.23579628596348
      kb|g.0.peg.252	10.8347290927555	10.6194852417206	10.5003587573257

EXAMPLES

      fba-importexpression 'sample.gexp'

SEE ALSO
      fba-loadgenome

AUTHORS
      Shinnosuke Kondo

";

#Defining usage and options
my $specs = [
    [ 'workspace|w:s', 'Workspace to save imported gene expression in', { "default" => fbaws() } ],
    [ 'sourceid:s', 'ID of the source'],
    [ 'description|d:s', 'Optional description', { "default" => ""}],
    [ 'processing_comments|p:s', 'Optional comments', { "default" => ""}],
    [ 'sourcedate:s', 'Date of the source', { "default", => strftime("%Y-%m-%d", localtime)}],
    [ 'genomeid|g:s', "ID of genome to which features belong"],
    [ 'numinterpret|n:s', "Numerical Interpretation:[ 'Log2 level intensities',  'Log2 level ratios','Log2 level ratios genomic DNA control','FPKM',]"  ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
if (!-e $opt->{"Gene expression flat file"}) {
	print "Could not find input gene expressioni file!\n";
	exit();
}
$params->{"series"} = basename($opt->{"Gene expression flat file"});

my $data = Bio::KBase::ObjectAPI::utilities::LOADTABLE($opt->{"Gene expression flat file"},"\t",0);

for (my $col_i = 0; $col_i < @{$data->{"headings"}}; $col_i++) {
    $params->{"expression_data_sample_series"}->{$data->{"headings"}->[$col_i]} = {};
    my $sample_id = $data->{"headings"}->[$col_i];
    foreach my $row (@{$data->{"data"}}) {
	# Associate gene feature ID with expession value
	$params->{"expression_data_sample_series"}->{$sample_id}->{"sample_id"} = $sample_id;
	#Make sure that it is treated as a number so that Json conversion can work.
	$params->{"expression_data_sample_series"}->{$sample_id}->{"data_expression_levels_for_sample"}->{$row->[0]} = 0+$row->[$col_i+1];
    }
}

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Gene expression import failed!\n";
} else {
	print "Gene expression import successful:\n";
	printObjectInfo($output);
}
