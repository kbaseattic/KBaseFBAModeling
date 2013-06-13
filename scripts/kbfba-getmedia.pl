#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Text::Table;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = ["Media IDs (; delimiter)","Workspace IDs (; delimiter)"];
my $servercommand = "get_media";
my $script = "kbfba-getmedia";
my $translation = {};
#Defining usage and options
my $specs = [
    [ 'pretty|p', 'Pretty print output' ],
    [ 'long|l', "Long format output" ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
$params->{medias} = [split(/;/,$opt->{"Media IDs (; delimiter)"})];
$params->{workspaces} = [split(/;/,$opt->{"Workspace IDs (; delimiter)"})];
#Calling the server
my $output = runFBACommand($params,$servercommand,$opt);
#Checking output and report results
if (!defined($output)) {
	print "Media retreival failed!\n";
} elsif ($opt->{long}) {
	for (my $i=0; $i < @{$output}; $i++) {
		my $media = $output->[$i];
		my $cpdparams = { "compounds" => $media->{compounds}, "id_type" => "all" };
		my $cpdoutput = runFBACommand($cpdparams,"get_compounds",$opt);
		print "Media: ".$media->{name}.", pH: ".$media->{pH}.", temperature: ".$media->{temperature}."\n";
		print "Compounds:\n";
		my $tbl = [];
		for (my $j=0; $j < @{$cpdoutput}; $j++) {
	        my $cpd = $cpdoutput->[$j];
	        my $listlen = @{$cpd->{aliases}};
	        if ($listlen >= 4) { $listlen = 3; }
	        my $aliases = join(';',@{$cpd->{aliases}}[0..$listlen]);
	        my $row = [
	            $cpd->{name},
	            $cpd->{formula},
	            $media->{concentrations}->[$j],
	            $aliases
	        ];
	        push(@{$tbl},$row);
		}
    	my $table = Text::Table->new(
    		'Name', 'Formula', "Concentration", "Aliases"
    	);
	    $table->load(@$tbl);
    	print $table."\n";
	}
} else {
	print to_json( $output, { utf8 => 1, pretty => $opt->{pretty} } )."\n";
}
