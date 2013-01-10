#!/usr/bin/perl
#  
#  Simple test script built during the Aug. 2012 build meeting to test that an FBA server is
#  running and is returning some valid JSONs and can be connected to via the client libs.
#  It does not test that any return objects are actually correct output.  It also does not
#  necessarily pass correct parameter types, just some junk that passes through the client lib.
#
#  NOTES:
#  -seems to depend on Exception/Class.pm
#
#  author:  msneddon
#  created: 8/16/2012


use strict;
use warnings;

use Data::Dumper;
use Test::More;
use lib "lib"; #make sure that the fba client is on our path
use lib "../kb_seed/lib/";

#############################################################################
# HERE IS A LIST OF METHODS AND PARAMETERS THAT WE WANT TO TEST ARE UP
# NOTE THAT THE PARAMETERS ARE JUST MADE UP AT THE MOMENT
my $func_calls = {
                #funcdef genome_to_fbamodel(GenomeTO in_genome) returns (FBAModel out_model); 
                genome_to_fbamodel => ["my_genome"],
                
                #funcdef fbamodel_to_sbml(FBAModel in_model) returns (SBML out_model);
                fbamodel_to_sbml => [ "my_best_model" ],
                
                #funcdef gapfill_fbamodel(FBAModel in_model,GapfillingFormulation in_formulation,bool overwrite,string save) returns (FBAModel out_model);
                gapfill_fbamodel => [ ["kb|t1","kb|t2","kb|t4"], [FORMAT =>'first']],
                
                #funcdef runfba(FBAModel in_model,FBAFormulation in_formulation,bool overwrite,string save) returns (HTMLFile out_solution);
                runfba => [ "my_best_model", "some_formulation", 1, "saving_something"],
                
                #funcdef object_to_html(ObjectSpec inObject) returns (HTMLFile outHTML);
                object_to_html => [ ["kb|t1","kb|t2","kb|t4"], [FORMAT =>'first']],
                
                #funcdef gapgen_fbamodel(FBAModel in_model,GapgenFormulation in_formulation,bool overwrite,string save) returns (FBAModel out_model);
                gapgen_fbamodel => [ ["kb|t1","kb|t2","kb|t4"], [FORMAT =>'first']]
                
            };
#############################################################################
my $n_tests = (scalar(keys %$func_calls)*2+3); # set this to be the number of function calls + 3


# MAKE SURE WE LOCALLY HAVE JSON RPC LIBS
#  NOTE: for initial testing, you may have to modify TreesClient.pm to also
#        point to the legacy interface
use_ok("JSON::RPC::Legacy::Client");
use_ok("Bio::KBase::fbaModelServices::Client");

# MAKE A CONNECTION
my $fba_service_url = "http://localhost:7036"; 

my $fbaclient = Bio::KBase::fbaModelServices::Client->new($fba_service_url);
ok(defined($fbaclient),"instantiating Bio::KBase::fbaModelServices::Client");


# Ok, that's cool, we can create the client.  Now forget about it for now cause the structs are too
# complicated for me to understand in one afternoon.  Let's just do some direct JSON calls and see what happens.
my $client = new JSON::RPC::Legacy::Client;
#my $client = new JSON::RPC::Client;

# LOOP THROUGH ALL THE REMOTE CALLS  (EITHER THROUGH THE CLIENT OR DIRECTLY) AND MAKE SURE WE GOT SOMETHING
my $method_name;
for $method_name (keys %$func_calls) {
        print "==========\n$method_name => @{ $func_calls->{$method_name}}\n";
        
        ########
        # This code uses the client lib, and does not work
        #my $n_args = scalar @{ $func_calls->{$method_name}};
        #my $result;
        #print "calling function: \"$method_name\"\n";
        #{
        #    no strict "refs";
        #    $result = $fbaclient->$method_name(@{ $func_calls->{$method_name}});
        #}
        #ok($result,"looking for a response from \"$method_name\"");
        
        ########
        # This code sends a JSON directly
        my $callobj = {
            method  => $method_name,
            params  => $func_calls->{$method_name},
        };
        my $res = $client->call($fba_service_url, $callobj);
        #print $client->status_line."\n";
        # If Call is valid, then use this check
        #ok($client->status_line =~ m/^200/,"test valid rpc call");
        # If Call is not valid, then use these checks instead
        ok($client->status_line =~ m/^500/,"test an invalid rpc call");
        ok(!$res,"test an invalid rpc call returned nothing");
        
        
}

done_testing($n_tests);
