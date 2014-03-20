#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Getopt::Long::Descriptive;
use Text::Table;
use Bio::KBase::fbaModelServices::ScriptHelpers qw(getToken get_old_ws_client fbaURL get_fba_client runFBACommand universalFBAScriptCode fbaTranslation roles_of_function );

my $serv = get_old_ws_client();
#Defining globals describing behavior
my $primaryArgs = [];
my $servercommand = "get_jobs";
my $translation = {
    status => "status",
    type => "type"
};
#Defining usage and options
my ($opt, $usage) = describe_options(
    'ws-jobs %o',
    [ 'type|t:s', 'Job type' ],
    [ 'status|s:s', 'Job status (queued,running,done)' ],
    [ 'showqsub|q', 'Use flag to show qsub ID for jobs',{"default"=>0}],
    [ 'showerror|e', 'Use flag to show any errors in execution',{"default"=>0}],
    [ 'help|h|?', 'Print this usage information' ]
);
if (defined($opt->{help})) {
	print $usage;
    exit;
}
#Processing primary arguments
foreach my $arg (@{$primaryArgs}) {
	$opt->{$arg} = shift @ARGV;
	if (!defined($opt->{$arg})) {
		print $usage;
    	exit;
	}
}
#Instantiating parameters
my $params = {};
foreach my $key (keys(%{$translation})) {
	if (defined($opt->{$key})) {
		$params->{$translation->{$key}} = $opt->{$key};
	}
}
$params->{auth} = getToken();
#Calling the server
my $output;
if ($opt->{showerror} == 0){
    eval {
        $output = $serv->$servercommand($params);
    };
}else{
    $output = $serv->$servercommand($params);
}
#Checking output and report results
if (!defined($output)) {
	print "Could not retreive job status!\n";
} else {
    if (defined($opt->{status})) {
        print "Jobs listed with status '".$opt->{status}."'\n";
    } else {
        print "Jobs listed with any status:\n";
    }
	my $tbl = [];
    for (my $i=0; $i < @{$output};$i++) {
        my $j = $output->[$i];
        my $row = [
            $j->{id},
            $j->{owner},
            $j->{status},
            $j->{type},
            $j->{queuetime},
            $j->{starttime},
            $j->{completetime}
        ];
        if ($opt->{showqsub} == 1) {
        	push(@{$row},$j->{jobdata}->{qsubid});
        }
        push(@{$tbl},$row);
    }
    my $table;
    if ($opt->{showqsub} == 1) {
    	$table = Text::Table->new(
    		'ID', 'Owner','Status','Type','Queue time','Start time','Complete time','Qsub ID'
    	);
    } else {
    	$table = Text::Table->new(
	    	'ID', 'Owner','Status','Type','Queue time','Start time','Complete time'
	    );
    }
    $table->load(@$tbl);
    print $table;
}
