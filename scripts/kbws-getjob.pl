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
use JSON -support_by_pp;
use Bio::KBase::fbaModelServices::ScriptHelpers qw(getToken get_old_ws_client fbaURL get_fba_client runFBACommand universalFBAScriptCode fbaTranslation roles_of_function );

my $serv = get_old_ws_client();
#Defining globals describing behavior
my $primaryArgs = ["Job ID"];
my $servercommand = "get_jobs";
my $script = "kbws-getjob";
#Defining usage and options
my ($opt, $usage) = describe_options(
    'kbws-getjob <Job ID> %o',
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
my $params = {
	jobids => [$opt->{"Job ID"}]
};
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
	print "Could not retreive job!\n";
} else {
    print to_json( $output->[0], { utf8 => 1, pretty => 1 } )."\n";
}