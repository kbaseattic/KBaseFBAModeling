#!/usr/bin/perl
   
use strict;
use FindBin qw($Bin);
use LWP::Simple qw(getstore);
use Data::UUID;
use Bio::KBase::fbaModelServices::Impl;
use JSON::XS;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
my $test_count = 17;

use Data::Dumper;
use Bio::KBase::workspace::ScriptHelpers qw(printObjectInfo get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(parse_input_table fbaws get_fba_client runFBACommand universalFBAScriptCode );

my $pipe_list = [glob($Bin."/*.json")];
my $obj = get_fba_client();
my $ws = get_ws_client();
for (my $i=0; $i < @{$pipe_list}; $i++) {
	my $uuid = Data::UUID->new()->create_str();
	print "Pipeline:".$pipe_list->[$i].";Workspace:".$uuid."\n";
	$ws->create_workspace({
		workspace => $uuid,
		globalread => "n",
		description => $pipe_list->[$i]." test"
	});
	my $pipeline;
	open( my $fh, "<", $pipe_list->[$i]);
	{
	    local $/;
	    my $str = <$fh>;
	    $pipeline = decode_json $str;
	}
	close($fh);
	for (my $j=0; $j<@{$pipeline}; $j++) {
		my $func = $pipeline->[$j]->[0];
		my $wsname = $pipeline->[$j]->[1];
		open( my $fhh, "<", $Bin."/test-data/".$func.".json");
		my $params;
		{
		    local $/;
		    my $str = <$fhh>;
		    $str =~ s/$wsname/$uuid/g;
		    print "\n\n".$str."\n\n";
		    $params = decode_json $str;
		}
		close($fhh);
		for (my $k=0; $k < @{$params}; $k++) {
			print "Running step:".$pipeline->[$j]->[0].".".$k."\n";
			my $output = undef;
			eval {
				$output = $obj->$func($params->[$k]);
			};
			if (!defined($output)) {
				print STDERR $func.".".$k." failed!\n";
			}
			if (defined($pipeline->[$j]->[2]->[$k])) {
				my $objinfo = undef;
				eval {
					$objinfo = $ws->get_object_info([{
						workspace => $uuid,
						name => $pipeline->[$j]->[2]->[$k]
					}],1);
				};
				if (!defined($objinfo)) {
					print STDERR $func.".".$k." failed to produce expected object:".$uuid."/".$pipeline->[$j]->[0]."\n";
				}
			}
		}
	}
	$ws->delete_workspace({
		workspace => $uuid
	});
}