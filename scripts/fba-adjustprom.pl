#!/usr/bin/env perl
# Author: Chrsitopher Henry
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(save_workspace_object get_workspace_object load_file load_table fbaws get_fba_client runFBACommand universalFBAScriptCode getToken);
use File::Basename;

#Defining globals describing behavior
my $primaryArgs = ["PROM ID","Transcription factor", "Target gene","Probability"];
my $servercommand = undef;
my $script = "fba-prom-contraint";
my $translation = {};

my $manpage = 
"
NAME
      fba-adjustprom

DESCRIPTION

      Adjust probability between TF and TF target in specified PROM constraints

EXAMPLES

      fba-adjustprom MyPromConstraint bsu2100 bsu0200 0

SEE ALSO
      fba-runfba --prom

AUTHORS
      Chris Henry

";

#Defining usage and options
my $specs = [
    [ 'outputid=s', 'ID to save output PROM constraint' ],
    [ 'promws=s', 'Workspace containing the prom constraint' ],
    [ 'ononprob', 'Adjust on-on instead of off-on probability' ],
    [ 'deletemapping', 'Delete the mapping between specified TF and gene' ],
    [ 'deletetf', 'Delete the specified TF' ],
    [ 'addmapping', 'add mapping between specified TF and gene' ],
    [ 'workspace|w=s', 'Workspace to save PROM constraint object in', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation, $manpage);
my $outputid = $opt->{"PROM ID"};
if (defined($opt->{outputid})) {
	$outputid = $opt->{outputid};
}
my $ws = $opt->{workspace};
if (defined($opt->{promws})) {
	$ws = $opt->{promws};
}
(my $data,my $prov) = get_workspace_object($ws."/".$opt->{"PROM ID"});
my $tfindex = -1;
for (my $i=0; $i < @{$data->{transcriptionFactorMaps}}; $i++) {
	if ($data->{transcriptionFactorMaps}->[$i]->{transcriptionFactor_ref} eq $opt->{"Transcription factor"}) {
		$tfindex = $i;
		last;
	}
}
if ($tfindex == -1) {
	if (defined($opt->{addmapping}) && $opt->{addmapping} == 1) {	
		my $tfmap = {
			target_gene_ref => $opt->{"Target gene"},
			probTGonGivenTFoff => $opt->{"Probability"},
			probTGonGivenTFon => 1
		};
		if (defined($opt->{ononprob}) && $opt->{ononprob} == 1) {
			$tfmap->{probTGonGivenTFon} = $opt->{"Probability"};
			$tfmap->{probTGonGivenTFoff} = 0;
		}
		push(@{$data->{transcriptionFactorMaps}},{
			transcriptionFactor_ref => $opt->{"Transcription factor"},
			targetGeneProbs => [$tfmap]
		});
	} else {
		print STDERR "Cannot find specified TF in PromConstraint!\n";
		exit();
	}
} else {
	if (defined($opt->{addmapping}) && $opt->{addmapping} == 1) {	
		my $tfmap = {
			target_gene_ref => "Target gene",
			probTGonGivenTFoff => $opt->{"Probability"}+0,
			probTGonGivenTFon => 1
		};
		if (defined($opt->{ononprob}) && $opt->{ononprob} == 1) {
			$tfmap->{probTGonGivenTFon} = $opt->{"Probability"}+0;
			$tfmap->{probTGonGivenTFoff} = 0;
		}
		push(@{$data->{transcriptionFactorMaps}->[$tfindex]->{targetGeneProbs}},$tfmap);
	} elsif (defined($opt->{deletetf}) && $opt->{deletetf} == 1) {
		splice(@{$data->{transcriptionFactorMaps}},$tfindex,1);
	} else {
		my $targindex = -1;
		for (my $i=0; $i < @{$data->{transcriptionFactorMaps}->[$tfindex]->{targetGeneProbs}}; $i++) {
			if ($data->{transcriptionFactorMaps}->[$tfindex]->{targetGeneProbs}->[$i]->{target_gene_ref} eq $opt->{"Target gene"}) {
				$targindex = $i;
				last;
			}
		}
		if ($targindex == -1) {
			print STDERR "Cannot find specified gene target for specified TF!";
			exit();
		}
		if (defined($opt->{deletemapping}) && $opt->{deletemapping} ==1) {
			splice(@{$data->{transcriptionFactorMaps}->[$tfindex]->{targetGeneProbs}},$targindex,1);
		} elsif (defined($opt->{ononprob}) && $opt->{ononprob} == 1) {
			$data->{transcriptionFactorMaps}->[$tfindex]->{targetGeneProbs}->[$targindex]->{probTGonGivenTFon} = $opt->{"Probability"}+0;
		} else {
			$data->{transcriptionFactorMaps}->[$tfindex]->{targetGeneProbs}->[$targindex]->{probTGonGivenTFoff} = $opt->{"Probability"}+0;
		}
	}
}
my $output = save_workspace_object($opt->{workspace}."/".$outputid,$data,"KBaseFBA.PromConstraint");
printObjectInfo($output->[0]);