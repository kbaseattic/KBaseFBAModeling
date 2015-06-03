#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspace::ScriptHelpers qw(get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(get_workspace_object fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Model ID"];
my $servercommand = "get_gapfills";
my $script = "fba-getgapfills";
my $translation = {
	"Model ID" => "model"
};
#Defining usage and options
my $specs = [
	[ 'modelws:s', 'Workspace with model' ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
my $ws = fbaws();
if (defined($opt->{modelws})) {
	$ws = $opt->{modelws};
}
(my $data,my $prov) = get_workspace_object($ws."/".$params->{model});
my $grefs;
my $gfs;
my $intgf = 0;
my $unintgf = 0;
if (defined($data->{gapfillings})) {
	for (my $i=0; $i < @{$data->{gapfillings}}; $i++) {
		$gfs->[$i] = $data->{gapfillings}->[$i];
		if (defined($gfs->[$i]->{gapfill_ref})) {
			push(@{$grefs},{"ref" => $gfs->[$i]->{gapfill_ref}});
		} else {
			push(@{$grefs},{"ref" => $gfs->[$i]->{fba_ref}});
		}
		if ($gfs->[$i]->{integrated} == 1) {
			$intgf++;
		} else {
			$unintgf++;
		}
	}
}
my $output = get_ws_client()->get_objects($grefs);
my $intsol;
my $unintsol;
my $allrows;
my $rxns = {};
my $count = 0;
for (my $i=0; $i < @{$output}; $i++) {
	for (my $j=0; $j < @{$output->[$i]->{data}->{gapfillingSolutions}}; $j++) {
		for (my $k=0; $k < @{$output->[$i]->{data}->{gapfillingSolutions}->[$j]->{gapfillingSolutionReactions}}; $k++) {
			my $rxn = $output->[$i]->{data}->{gapfillingSolutions}->[$j]->{gapfillingSolutionReactions}->[$k];
			my $rxnid = $rxn->{reaction_ref};
			if ($rxnid =~ m/(rxn\d+)/) {
				$rxnid = $1;
			}
			my $cmpid = $rxn->{compartment_ref};
			if ($cmpid =~ m/([a-zA-Z])$/) {
				$cmpid = $1;
			}
			$rxns->{$rxnid}->{$count} = 1;
			my $row = [
				$rxnid."_".$cmpid.$rxn->{compartmentIndex},"",$rxn->{direction}
			];
			$count++;
			if ($k == 0) {
				my $rxncount = @{$output->[$i]->{data}->{gapfillingSolutions}->[$j]->{gapfillingSolutionReactions}};
				if ($gfs->[$i]->{integrated} == 1 && $gfs->[$i]->{integrated_solution} eq $output->[$i]->{data}->{gapfillingSolutions}->[$j]->{id}) {
					$intsol->{$output->[$i]->{data}->{gapfillingSolutions}->[$j]->{id}} = {
						media => $gfs->[$i]->{media_ref},
						"time" => substr($output->[$i]->{info}->[3],0,length($output->[$i]->{info}->[3])-8),
						rxns => $rxncount,
						tbl => []
					};
				} elsif ($gfs->[$i]->{integrated} == 0) {
					$unintsol->{$output->[$i]->{data}->{gapfillingSolutions}->[$j]->{id}} = {
						media => $gfs->[$i]->{media_ref},
						"time" => substr($output->[$i]->{info}->[3],0,length($output->[$i]->{info}->[3])-8),
						rxns => $rxncount,
						tbl => []
					};
				}
			}
			push(@{$allrows},$row);
			if ($gfs->[$i]->{integrated} == 1 && $gfs->[$i]->{integrated_solution} eq $output->[$i]->{data}->{gapfillingSolutions}->[$j]->{id}) {
				push(@{$intsol->{$output->[$i]->{data}->{gapfillingSolutions}->[$j]->{id}}->{tbl}},$row);
			} elsif ($gfs->[$i]->{integrated} == 0) {
				push(@{$unintsol->{$output->[$i]->{data}->{gapfillingSolutions}->[$j]->{id}}->{tbl}},$row);
			}
		}
	}
}
my $rxnarray = [keys(%{$rxns})];
$output = get_fba_client()->get_reactions({reactions => $rxnarray});
$count = 0;
foreach my $rxn (@{$rxnarray}) {
	foreach my $index (keys(%{$rxns->{$rxn}})) {
		$allrows->[$index]->[1] = $output->[$count]->{definition};
		my $dir = $allrows->[$index]->[2];
		if ($dir eq ">") {
			$allrows->[$index]->[1] =~ s/\<=\>/=>/;
		} elsif ($dir eq "<") {
			$allrows->[$index]->[1] =~ s/\<=\>/<=/;
		}
	}
	$count++;
}

print "Integrated gapfillings (".$intgf."):\n";
foreach my $solution (keys(%{$intsol})) {
	print "New solution:".$solution."\tMedia:".$intsol->{$solution}->{media}."\tTime:".$intsol->{$solution}->{"time"}."\tRxns:".$intsol->{$solution}->{rxns}."\n";
	my $table = Text::Table->new(
		'Reaction','Equation'
	);
	$table->load(@{$intsol->{$solution}->{tbl}});
	print $table."\n";
}
print "\n\nUnintegrated gapfillings (".$unintgf."):\n";
foreach my $solution (keys(%{$unintsol})) {
	print "New solution:".$solution."\tMedia:".$unintsol->{$solution}->{media}."\tTime:".$unintsol->{$solution}->{"time"}."\tRxns:".$unintsol->{$solution}->{rxns}."\n";
	my $table = Text::Table->new(
		'Reaction','Equation'
	);
	$table->load(@{$unintsol->{$solution}->{tbl}});
	print $table."\n";
}