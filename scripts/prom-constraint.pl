#!/usr/bin/env perl
# Author: Matt DeJongh @ Hope College, Holland, MI
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode getToken);
use Bio::KBase::ObjectAPI::utilities qw(LOADTABLE);
use File::Basename;
use POSIX qw/strftime/;

#Defining globals describing behavior
my $primaryArgs = ["Regulome ID","Expression Series ID", "Genome ID"];
my $servercommand = "create_promconstraint";
my $script = "prom-contraint";
my $translation = {
        "Genome ID" => "genome_id",
	"Regulome ID" => "regulome_id",
	"Expression Series ID" => "series_id",
	"expressionws" => "expression_workspace",
	"genomews" => "genome_workspace",
	"regulomews" => "regulome_workspace",
	"workspace" => "workspace",
	"promconstraintid" => "promconstraint_id"
};

my $manpage = 
"
NAME
      prom-constraint

DESCRIPTION

      Calculate the PROM constraint (probability that the Target Gene is on/off given that the Transcription Factor is on/off)
      given a series of Gene Expression data (in the form of on/off calls, where 1=on, -1=off, 0=unknown)
      and a regulome.

EXAMPLES

      prom-constraint bsu-regulome bsu-expression bsu-genome

SEE ALSO
      fba-runfba --prom

AUTHORS
      Matt DeJongh, Shinnosuke Kondo, Michael Sneddon, Chris Henry

";

#Defining usage and options
my $specs = [
    [ 'workspace|w=s', 'Workspace to save PROM constraint object in', { "default" => fbaws() } ],
    [ 'expressionws=s', 'Workspace containing expression data' ],
    [ 'genomews=s', 'Workspace where genome is located' ],
    [ 'regulomews=s', 'Workspace where regulome is located' ],
    [ 'promconstraintid|p=s', 'Name for new PROM constraint object' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);

#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "PROM constraint computation failed!\n";
} else {
    print "PROM constraint computation successful:\n";
    printObjectInfo($output);
}
