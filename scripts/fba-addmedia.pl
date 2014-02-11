#!/usr/bin/perl
   
use strict;
use Data::Dumper;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Media ID>  <Compounds/input media file"];
my $servercommand = "addmedia";
my $script = "fba-addmedia";
my $translation = {
    "Media ID>  <Compounds/input media file" => "media",
    name => "name",
    compounds => "compounds",
    concentrations => "concentrations",
    maxflux => "maxflux",
    minflux => "minflux",
    workspace => "workspace",
    "defined" => "isDefined",
    type => "type",
    minimal => "isMinimal",
    auth => "auth",
    overwrite => "overwrite",
};

 
#Defining usage and options
my $specs = [
    [ 'input=s', 'Name of file with media information (format Mg 0.05 -100 100 or cpd12345 0.05 -100 100)' ],
    [ 'compounds=s', 'Compound list (; delimiter)' ],
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

my @media_Array;

    my @compounds;
    my @concentrations;
    my @minflux;
    my @maxflux;


my $in_fh;

if ($opt->{input}) {
    open($in_fh, "<", $opt->{input}) or die "Cannot open input file";
} 

        while (defined($_ = <$in_fh>)){
        
            chop;
            my($m_id, $conc,$minf,$maxf) = split(/\s+/,$_);
        
                push (@compounds, $m_id);
                push (@concentrations, $conc);
                push (@minflux, $minf);
                push (@maxflux, $maxf);              

        }


if (!defined($params->{name})) {
    $params->{name} = $params->{media};
}

if (defined($params->{compounds})) {
    $params->{compounds} = [split(/;/,$params->{compounds})];
}
else {
    $params->{compounds} = \@compounds;

}

if (defined($params->{concentrations})) {
    $params->{concentrations} = [split(/;/,$params->{concentrations})];
}
else{
    $params->{concentrations} = \@concentrations;

}

if (defined($params->{minflux})) {
    $params->{minflux} = [split(/;/,$params->{minflux})];
}

else{
    $params->{minflux} = \@minflux;

}
if (defined($params->{maxflux})) {
    $params->{maxflux} = [split(/;/,$params->{maxflux})];
}

else{
    $params->{maxflux} = \@maxflux;


}



#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);

#Checking output and report results
if (!defined($output) ) {
    print "Media creation failed!\n";
}
elsif (!defined($params->{compounds}->[0])) {

    print "Media creation failed, compounds not found or did not used the --compounds or --input flag!\n";

}

 else {
    print "Successfully added media to workspace:\n";
    printObjectInfo($output);
}
 
