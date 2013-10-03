#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode );
#Defining globals describing behavior
my $primaryArgs = [];
my $servercommand = "role_to_reactions";
my $script = "fba-roles-used-in-models";
my $translation = {};
#Defining usage and options
my $specs = [
    [ 'grampos|g', 'Use the gram positive template' ],
    [ 'gramneg|n', 'Use the gram negative template' ],
    [ 'core|c', 'Use the core model template' ],
    [ 'plant|p', 'Use the plant template' ]
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);
my $comp;
$comp->{workspace} = 'KBaseTemplateModels';
$comp->{templateModel} = 'GramPosModelTemplate';
if (defined($opt->{grampos})) {
	$comp->{templateModel} = 'GramPosModelTemplate';
} elsif (defined($opt->{gramneg})) {
	$comp->{templateModel} = 'GramNegModelTemplate';
} elsif (defined($opt->{core})) {
	$comp->{templateModel} = 'CoreModelTemplate';
} elsif (defined($opt->{plant})) {
	$comp->{templateModel} = 'PlantModelTemplate';
}
#Calling the server
my $biochem;
if ($opt->{showerror} == 0){
    eval {
        $biochem = get_fba_client()->role_to_reactions($comp);
    };
}else{
    $biochem = get_fba_client()->role_to_reactions($comp);
}
#Checking output and report results
if (!defined($biochem)) {
	print "Failed to retrieve model roles!\n";
} else {
	print "Roles in model:\n";
	my %hash1;
	my %hash2;
	my $count =0;
	for(my $i =0; $i< @{$biochem}; $i++){
	
	  my $comp = $biochem->[$i]->{complexes};
	  my $role = $biochem->[$i]->{name};
	    
	    print "$role\n";
	
	}
}