#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(parse_input_table get_workspace_object fbaws get_fba_client runFBACommand universalFBAScriptCode );

my $manpage =
"
NAME
      fba-modify-reaction - modify reaction in model

DESCRIPTION
      

EXAMPLES
      
SEE ALSO
      

AUTHORS
      Christopher Henry
";

#Defining globals describing behavior
my $primaryArgs = ["Model","Reaction ID or Filename"];
my $servercommand = "modify_reactions";
my $script = "fba-modify-reaction";
my $translation = {
	Model => "model",
	modelws => "model_workspace",
	outputid => "output_id",
	workspace => "workspace",
};
#Defining usage and options
my $specs = [
    [ 'modelws=s', 'Workspace where model is located' ],
	[ 'list|l', 'List reactions available for modification' ],
    [ 'outputid=s', 'ID to which model should be saved'],
    [ 'direction=s', 'Direction of reaction (</=/>)'],
    [ 'gpr=s', 'Gene-protein-reaction association of reaction'],
    [ 'pathway=s', 'Pathway of reaction'],
    [ 'name=s', 'Name of reaction'],
    [ 'reference=s', 'Literature reference of reaction'],
    [ 'enzyme=s', 'EC number of reaction'],
    [ 'workspace|w=s', 'Reference default workspace', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation,$manpage,undef,["list"]);
if (defined($opt->{list})) {
	my $ws = fbaws();
	if (defined($opt->{modelws})) {
		$ws = $opt->{modelws};
	}
	(my $data,my $prov) = get_workspace_object($ws."/".$ARGV[0]);
	print "Listing reactions available for modification:\n";
	for (my $i=0; $i < @{$data->{modelreactions}}; $i++) {
		print $data->{modelreactions}->[$i]->{id}."\n";
	}
	exit;
}
if (-e $opt->{"Reaction ID or Filename"}) {
	$params->{reactions} = parse_input_table($opt->{"Reaction ID or Filename"},[
		["id",1,undef,undef],
		["direction",0,undef,undef],
		["gpr",0,undef,undef],
		["pathway",0,undef,undef],
		["name",0,undef,undef],
		["reference",0,undef,undef],
		["enzyme",0,undef,undef]
	]);
} else {
	$params->{reactions} = [[
		$opt->{"Reaction ID or Filename"},
		undef,
		undef,
		undef,
		undef,
		undef,
		undef
	]];
	if (defined($opt->{direction})) {
		$params->{reactions}->[0]->[1] = $opt->{direction};
	}
	if (defined($opt->{gpr})) {
		$params->{reactions}->[0]->[2] = $opt->{gpr};
	}
	if (defined($opt->{pathway})) {
		$params->{reactions}->[0]->[3] = $opt->{pathway};
	}
	if (defined($opt->{name})) {
		$params->{reactions}->[0]->[4] = $opt->{name};
	}
	if (defined($opt->{name})) {
		$params->{reactions}->[0]->[5] = $opt->{reference};
	}
	if (defined($opt->{name})) {
		$params->{reactions}->[0]->[6] = $opt->{enzyme};
	}
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Reaction modification failed!\n";
} else {
	print "Reaction successfully modified:\n";
	printObjectInfo($output);
}