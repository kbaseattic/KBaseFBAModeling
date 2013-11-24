#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Genome ID","Translation file","ID type"];
my $servercommand = "add_feature_translation";
my $script = "kbfba-importtranslation";
my $translation = {
	"ID type" => "id_type",
	"Genome ID" => "genome",
	genomews => "genome_workspace",
	workspace => "workspace",
	auth => "auth",
	overwrite => "overwrite"
};

my $manpage = 
"
NAME
      kbfba-importtranslation

DESCRIPTION

      Adds aliases to an existing Genome file based on a translation file. This allows the user to
      use those aliases as arguments to other functions that take genes as inputs.

      The translation file is a tab-delimited file with two columns without any header row. The two 
      columns must be in this order:

      alias   feature ID

      Feature ID is the ID of the gene in the Genome object and alias is the alias you wish to add. An
      example translation file could look like this:


      ECOLI_GENE1  kb|g.0.peg.1

EXAMPLES

      kbfba-importtranslation 'kb|g.0' 'kb|g.0.translationfile' 'madeup'

SEE ALSO
      kbfba-loadgenome
      kbfba-runfba
      kbfba-buildfbamodel

AUTHORS
      Christopher Henry

";


#Defining usage and options
my $specs = [
    [ 'genomews:s', 'Workspace with genome object' ],
    [ 'workspace|w:s', 'Workspace to save imported model in', { "default" => workspace() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
$params->{translations} = [];
if (!-e $opt->{"Translation file"}) {
	print "Could not find input translation file!\n";
	exit();
}
open(my $fh, "<", $opt->{"Translation file"}) || return;
$opt->{"Translation file"} = "";
my $data = [];
while (my $line = <$fh>) {
	chomp($line);
	push(@{$data},[split(/\t/,$line)]);
}
close($fh);
foreach my $trans (@{$data}) {
	if (@{$trans} >= 2) {
		push(@{$params->{translations}},$trans);
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Translation import failed!\n";
} else {
	print "Translation import successful:\n";
	printObjectMeta($output);
}
