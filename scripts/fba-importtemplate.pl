#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(loadTableFile printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Reaction file","Biomass file","Biomass components file"];
my $servercommand = "import_template_fbamodel";
my $script = "fba-importtemplate";
my $translation = {
	"Reaction file" => "Reaction file",
	"Biomass file" => "Biomass file",
	"Biomass components file" => "Biomass components file",
	mapping => "map",
	mappingws => "mapping_workspace",
	biochem => "biochem",
	biochemws => "biochem_workspace",
	templateReactions=> "templateReactions",
	templateBiomass => "templateBiomass",
	name => "name",
	type => "modelType",
	domain => "domain",
	templateid => "uid",
	workspace => "workspace",
	ignoreerrors => "ignore_errors",
	auth => "auth"
};

#Defining usage and options
my $specs = [
	["name|n=s", "Name for imported template model"],
	["domain|d=s", "Domain of life for template model"],
	["type|t=s", "Type of model produced by template"],
	[ 'templateid=s', 'ID for imported template in workspace' ],
	["mapping=s", "Mapping to which the template should be linked"],
    ["mappingws=s", "Workspace with mapping to which the template should be linked"],
    ["biochem=s", "ID of the biochemistry database"],
    ["biochemws=s", "ID of workspace containing biochemistry database"],
	[ 'ignoreerrors|i', 'Ignore errors encountered during load' ],
    [ 'workspace|w=s', 'Workspace to save imported template', { "default" => fbaws() } ],
    [ 'overwrite|o', 'Overwrite any existing phenotypes with same name' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
my $rxnTbl = loadTableFile($params->{"Reaction file"});
my $bioTbl = loadTableFile($params->{"Biomass file"});
my $bioCompTbl = loadTableFile($params->{"Biomass components file"});
my $tempRxns = [];
my $tempBioComp = [];
my $tempBio = [];
for (my $i=0; $i < @{$rxnTbl->{data}}; $i++) {
	my $complexes = [];
	if (defined($rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{complexes}])) {
		$complexes = [split(/\|/,$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{complexes}])];
	}
	my $rxnRow = [
		$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{id}],
		$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{compartment}],
		$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{direction}],
		$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{type}],
		$complexes
	];
	push(@{$tempRxns},$rxnRow);
}
my $bioNameHash;
for (my $i=0; $i < @{$bioTbl->{data}}; $i++) {
	my $bioRow = [
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{name}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{type}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{dna}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{rna}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{protein}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{lipid}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{cellwall}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{cofactor}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{energy}],
		$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{other}]
	];
	$bioNameHash->{$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{name}]} = @{$tempBio};
	push(@{$tempBio},$bioRow);
}
for (my $i=0; $i < @{$bioCompTbl->{data}}; $i++) {
	if (defined($bioNameHash->{$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{biomass}]})) {
		my $index = $bioNameHash->{$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{biomass}]};
		my $links = [];
		if (defined($bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{linked}])) {
			$links = [split(/;/,$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{linked}])];
			for (my $j=0; $j < @{$links}; $j++) {
				$links->[$j] = [split(/:/,$links->[$j])];
		}
		my $bioRow = [
			$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{id}],
			$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{compartment}],
			$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{class}],
			$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{coefficientType}],
			$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{coefficient}],
			$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{conditions}],
			$links
		];
		push(@{$tempBio->[$index]->[10]},$bioRow);
	}
}
$params->{templateReactions} = $tempRxns;
$params->{templateBiomass} = $tempBio;
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Template model import failed!\n";
} else {
	print "Template model import successful:\n";
	printObjectInfo($output);
}