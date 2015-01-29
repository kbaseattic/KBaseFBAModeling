#!/usr/bin/perl
   
use strict;
use Data::Dumper;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(parse_input_table fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Media ID","Compound list (; delimiter) or Filename"];
my $servercommand = "addmedia";
my $script = "fba-addmedia";
my $translation = {
    "Media ID" => "media",
    name => "name",
    concentrations => "concentrations",
    maxflux => "maxflux",
    minflux => "minflux",
    workspace => "workspace",
    "defined" => "isDefined",
    type => "type",
    minimal => "isMinimal",
};
#Defining usage and options
my $specs = [
    [ 'concentrations=s', 'Compound concentrations (; delimiter)' ],
    [ 'minflux=s', 'Compound minimum fluxes (; delimiter)' ],
    [ 'maxflux=s', 'Compound maximum fluxes (; delimiter)' ],
    [ 'name:s', 'Media name' ],
    [ 'type|t=s', 'Type of media', { "default" => "unspecified" } ],
    [ 'defined|d', 'Media is defined', { "default" => 0 } ],
    [ 'minimal|m', 'Media is minimal', { "default" => 0 } ],
    [ 'workspace|w:s', 'Workspace with model', { "default" => fbaws() } ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
if (-e $opt->{"Compound list (; delimiter) or Filename"}) {
	open(my $fh, "<", $opt->{"Compound list (; delimiter) or Filename"}) or die "Cannot open input file";
	$params->{compounds} = [];
	$params->{maxflux} = [];
	$params->{minflux} = [];
	$params->{concentrations} = [];
	while(my $line = <$fh>){
		chomp($line);
		my($m_id, $conc,$minf,$maxf) = split(/\t/,$line);
		push (@{$params->{compounds}}, $m_id);
		push (@{$params->{concentrations}}, $conc);
		push (@{$params->{minflux}}, $minf);
		push (@{$params->{maxflux}}, $maxf);              
	}
	close($fh);
} else {
	$params->{compounds} = [split(";",$opt->{"Compound list (; delimiter) or Filename"})];
	if (defined($params->{concentrations})) {
	    $params->{concentrations} = [split(/;/,$params->{concentrations})];
	}
	if (defined($params->{minflux})) {
	    $params->{minflux} = [split(/;/,$params->{minflux})];
	}
	if (defined($params->{maxflux})) {
	    $params->{maxflux} = [split(/;/,$params->{maxflux})];
	}
}
if (!defined($params->{name})) {
    $params->{name} = $params->{media};
}
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output) ) {
    print "Media creation failed!\n";
} else {
    print "Successfully added media to workspace:\n";
    printObjectInfo($output);
}