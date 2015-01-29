use strict;
use warnings;
package Bio::KBase::fbaModelServices::ScriptHelpers;
use Data::Dumper;
use Config::Simple;
use Getopt::Long::Descriptive;
use Text::Table;
use Bio::KBase::Auth;
use Bio::KBase::fbaModelServices::Client;
use Bio::KBase::fbaModelServices::ClientConfig;
use Bio::KBase::workspace::ScriptHelpers qw(workspaceURL get_ws_client workspace parseObjectMeta parseWorkspaceMeta);
use Exporter;
use parent qw(Exporter);
our @EXPORT_OK = qw(get_pa_client get_ws_objects_list save_workspace_object print_file load_file load_table parse_input_table get_workspace_object parse_arguments getToken get_old_ws_client fbaws printJobData fbaURL get_fba_client runFBACommand universalFBAScriptCode fbaTranslation roles_of_function );

=head3 print_file
Definition:
Description:	

=cut

sub print_file {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename);
    foreach my $Item (@{$arrayRef}) {
    	print $fh $Item."\n";
    }
    close($fh);
}

=head3 load_file
Definition:
	[string] = load_file(string);
Description:	

=cut

sub load_file {
    my ($filename) = @_;
    my $DataArrayRef = [];
    open (my $fh, "<", $filename) || die "Couldn't open $filename: $!";
    while (my $Line = <$fh>) {
        $Line =~ s/\r//;
        chomp($Line);
        push(@{$DataArrayRef},$Line);
    }
    close($fh);
    return $DataArrayRef;
}

=head3 load_table
Definition:
	
Description:	

=cut

sub load_table {
    my ($filename,$delim,$headingLine) = @_;
    if (!defined($headingLine)) {
    	$headingLine = 0;
    }
    my $output = {
    	headings => [],
    	data => []
    };
    if ($delim eq "|") {
    	$delim = "\\|";	
    }
    if ($delim eq "\t") {
    	$delim = "\\t";	
    }
    my $data = load_file($filename);
    if (defined($data->[0])) {
    	$output->{headings} = [split(/$delim/,$data->[$headingLine])];
	    for (my $i=($headingLine+1); $i < @{$data}; $i++) {
	    	push(@{$output->{data}},[split(/$delim/,$data->[$i])]);
	    }
    }
    return $output;
}

sub parse_input_table {
	my $filename = shift;
	my $columns = shift;#[name,required?(0/1),default,delimiter]
	if (!-e $filename) {
		print "Could not find input file:".$filename."!\n";
		exit();
	}
	open(my $fh, "<", $filename) || return;
	my $headingline = <$fh>;
	chomp($headingline);
	my $headings = [split(/\t/,$headingline)];
	my $data = [];
	while (my $line = <$fh>) {
		chomp($line);
		push(@{$data},[split(/\t/,$line)]);
	}
	close($fh);
	my $headingColums;
	for (my $i=0;$i < @{$headings}; $i++) {
		$headingColums->{$headings->[$i]} = $i;
	}
	my $error = 0;
	for (my $j=0;$j < @{$columns}; $j++) {
		if (!defined($headingColums->{$columns->[$j]->[0]}) && defined($columns->[$j]->[1]) && $columns->[$j]->[1] == 1) {
			$error = 1;
			print "Model file missing required column '".$columns->[$j]->[0]."'!\n";
		}
	}
	if ($error == 1) {
		exit();
	}
	my $objects = [];
	foreach my $item (@{$data}) {
		my $object = [];
		for (my $j=0;$j < @{$columns}; $j++) {
			$object->[$j] = undef;
			if (defined($columns->[$j]->[2])) {
				$object->[$j] = $columns->[$j]->[2];
			}
			if (defined($headingColums->{$columns->[$j]->[0]}) && defined($item->[$headingColums->{$columns->[$j]->[0]}])) {
				$object->[$j] = $item->[$headingColums->{$columns->[$j]->[0]}];
			}
			if (defined($columns->[$j]->[3])) {
				if (defined($object->[$j]) && length($object->[$j]) > 0) {
					my $d = $columns->[$j]->[3];
					$object->[$j] = [split(/$d/,$object->[$j])];
				} else {
					$object->[$j] = [];
				}
			}
		}
		push(@{$objects},$object);
	}
	return $objects;
}

sub save_workspace_object {
	my $ref = shift;
	my $data = shift;
	my $type = shift;
	my $array = [split(/\//,$ref)];
	my $object = {
		type => $type,
		data => $data,
		provenance => [],
	};
	if ($array->[1] =~ m/^\d+$/) {
		$object->{objid} = $array->[1];
	} else {
		$object->{name} = $array->[1];
	}
	if (defined($array->[2])) {
		$object->{ver} = $array->[2];
	}
	my $input = {
    	objects => [$object], 	
    };
    if ($array->[0]  =~ m/^\d+$/) {
    	$input->{id} = $array->[0];
    } else {
    	$input->{workspace} = $array->[0];
    }
    my $ws = get_ws_client();
    return $ws->save_objects($input);
}

sub get_workspace_object {
	my $ref = shift;
	my $array = [split(/\//,$ref)];
	my $ws = get_ws_client();
	my $input = {};
	if ($array->[0] =~ m/^\d+$/) {
		$input->{wsid} = $array->[0];
	} else {
		$input->{workspace} = $array->[0];
	}
	if ($array->[1] =~ m/^\d+$/) {
		$input->{objid} = $array->[1];
	} else {
		$input->{name} = $array->[1];
	}
	if (defined($array->[2])) {
		$input->{ver} = $array->[2];
	}
	my $objdatas = $ws->get_objects([$input]);
	return ($objdatas->[0]->{data},$objdatas->[0]->{info});
}

sub get_ws_objects_list {
	my $workspace = shift;
	my $type = shift;
	my $ws = get_ws_client();
	my $continue = 1;
	my $skip = 0;
	my $allobjects = [];
	while($continue) {
		my $input = {
			skip => $skip,
			limit => 10000
		};
		$skip += 10000;
		if ($workspace =~ m/^\d+$/) {
			$input->{ids} = [$workspace];
		} else {
			$input->{workspaces} = [$workspace];	
		}
		if (defined($type)) {
			$input->{type} = $type;
		}
		my $currobjects = $ws->list_objects($input);
		if (@{$currobjects} == 0) {
			$continue = 0;
		} else {
			print $skip."\t".@{$currobjects}."\n";
			push(@{$allobjects},@{$currobjects});
		}
	}
	return $allobjects;
}

sub getToken {
	my $token='';
	if (defined($ENV{KB_RUNNING_IN_IRIS})) {
		$token = $ENV{KB_AUTH_TOKEN};
	} else {
		my $configs = Bio::KBase::Auth::GetConfigs();
		$token = $configs->{token};
	}
	return $token;
}

sub fbaws {
	my $ws;
	eval {
		$ws = Bio::KBase::workspace::ScriptHelpers::workspace();
	};
	return $ws;
}

sub oldwsurl {
	return Bio::KBase::fbaModelServices::ClientConfig::GetConfigParam("oldworkspace.url");
}

sub get_old_ws_client {
	return undef;
}

sub get_fba_client {
	my $url = shift;
	if (!defined($url)) {
		$url = fbaURL();
	}
	if ($url eq "impl") {
		$Bio::KBase::fbaModelServices::Server::CallContext = {token => getToken()};
		require "Bio/KBase/fbaModelServices/Impl.pm";
		return Bio::KBase::fbaModelServices::Impl->new({"workspace-url" => workspaceURL()});
	}
	return Bio::KBase::fbaModelServices::Client->new($url);
}

sub fbaURL {
	my $newUrl = shift;
	my $currentURL;
	if (defined($newUrl)) {
		if ($newUrl eq "default") {
			$newUrl = $Bio::KBase::fbaModelServices::ScriptConfig::FBAprodURL;
		} elsif ($newUrl eq "localhost") {
			$newUrl = $Bio::KBase::fbaModelServices::ScriptConfig::FBAlocalURL;
		} elsif ($newUrl eq "dev") {
			$newUrl = $Bio::KBase::fbaModelServices::ScriptConfig::FBAdevURL;
		}
		Bio::KBase::fbaModelServices::ClientConfig::SetConfig({url => $newUrl});
		$currentURL = $newUrl;
	} else {
		$currentURL = Bio::KBase::fbaModelServices::ClientConfig::GetConfigParam("fbaModelServices.url");
	}
	return $currentURL;
}

sub get_pa_client {
	require "Bio/KBase/probabilistic_annotation/Helpers.pm";
	return Bio::KBase::probabilistic_annotation::Helpers::get_probanno_client();
}

sub parse_arguments {
	my $specs = shift;
	my $options = [];
	push(@{$options},@{$specs});
	push(@{$options},[ 'showerror|e', 'Set as 1 to show any errors in execution',{"default"=>0}]);
	push(@{$options},[ 'help|h|?', 'Print this usage information' ]);
	my ($opt, $usage) = describe_options(@{$options});
	return $opt;
}

sub universalFBAScriptCode {
    my $specs = shift;
    my $script = shift;
    my $primaryArgs = shift;
    my $translation = shift;
    my $manpage = shift;
    my $command_param = shift;
    my $overides = shift;
    my $in_fh;
    #Setting arguments to "describe_options" function
    my $options = [];
    if (@{$primaryArgs} > 0) {
    	push(@{$options},$script.' <'.join("> <",@{$primaryArgs}).'> %o');
    } else {
    	push(@{$options},$script.' %o');
    }
    push(@{$options},@{$specs});
    #Adding universal options:
    push(@{$options},[ 'showerror|e', 'Set as 1 to show any errors in execution',{"default"=>0}]);
    push(@{$options},[ 'help|h|?', 'Print this usage information' ]);
    #Defining usage and options
	my ($opt, $usage) = describe_options(@{$options});
	#Reading any piped data
	if ( -p \*STDIN) {
		my $in_fh = \*STDIN;
		my $data;
		{
		    local $/;
		    undef $/;
		    $data = <$in_fh>;
		    
		}
		if ($command_param->{primary}->{type} eq "json") {
			my $json = JSON::XS->new;
			$data = $json->decode($data);
		}
		$opt->{$command_param->{primary}->{dest}} = {data => $data,type => "data"};
	}
	#Reading data from files
	#TODO
    $translation->{workspace} = "workspace";
    if (defined($opt->{help})) {
        if (defined($manpage)) {
            print "SYNOPSIS\n      ".$usage;
            print $manpage;
        }
        else {
            print $usage;
        }
	    exit;
	}
	#Instantiating parameters
	my $params = {
		wsurl => workspaceURL()
	};
	if (defined($overides)) {
		for (my $i=0; $i < @{$overides}; $i++) {
			if ($opt->{$overides->[$i]}) {
				return ($opt,$params);
			}
		}
	}
	#Processing primary arguments
	foreach my $arg (@{$primaryArgs}) {
		$opt->{$arg} = shift @ARGV;
		if (!defined($opt->{$arg})) {
			print $usage;
	    	exit;
		}
	}
	foreach my $key (keys(%{$translation})) {
		if (defined($opt->{$key})) {
			$params->{$translation->{$key}} = $opt->{$key};
		}
	}
    return ($opt,$params);
}

sub runFBACommand {
    my $params = shift;
    my $function = shift;
    my $opt = shift;
    my $queuejob = shift;
    my $serv = get_fba_client();
    my $output;
    my $error;
    delete $params->{auth};
    eval {
    	if (defined($queuejob) && $queuejob == 1) {
	    	$output = $serv->queue_job({
	    		method => $function,
				parameters => $params
	    	});
    	} else {
	    	$output = $serv->$function($params);
		}
	};$error = $@ if $@;
	if ($opt->{showerror} == 1 && defined($error)){
	   print STDERR $error;
	}elsif (defined($error) && $error =~ m/_ERROR_(.+)_ERROR_/) {
		print STDERR $1."\n";
	}
    return ($output);
}

sub process {
    my $job = shift;
    print "Job ID: ".$job->{id}."\n";
    print "Job WS: ".$job->{workspace}."\n";
    print "Command: ".$job->{queuing_command}."\n";
    print "Queue time: ".$job->{queuetime}."\n";
    print "Is complete: ".$job->{complete}."\n";
}

sub roles_of_function {
	my $function = shift;
	my $array = [split(/\#/,$function)];
	$function = shift(@{$array});
	$function =~ s/\s+$//;
	return [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
}


sub printJobData {
	my $job = shift;
	print "Job ID: ".$job->{id}."\n";
	print "Job Type: ".$job->{type}."\n";
	print "Job Owner: ".$job->{owner}."\n";
	print "Command: ".$job->{queuecommand}."\n";
	print "Queue time: ".$job->{queuetime}."\n";
	if (defined($job->{starttime})) {
		print "Start time: ".$job->{starttime}."\n";
	}
	if (defined($job->{completetime})) {
		print "Complete time: ".$job->{completetime}."\n";
	}
	print "Job Status: ".$job->{status}."\n";
	if (defined($job->{jobdata}->{postprocess_args}->[0]->{model_workspace})) {
		print "Model: ".$job->{jobdata}->{postprocess_args}->[0]->{model_workspace}."/".$job->{jobdata}->{postprocess_args}->[0]->{model}."\n";
	}
	if (defined($job->{jobdata}->{postprocess_args}->[0]->{formulation}->{formulation}->{media})) {
		print "Media: ".$job->{jobdata}->{postprocess_args}->[0]->{formulation}->{formulation}->{media}."\n";
	}
	if (defined($job->{jobdata}->{postprocess_args}->[0]->{formulation}->{media})) {
		print "Media: ".$job->{jobdata}->{postprocess_args}->[0]->{formulation}->{media}."\n";
	}
	if (defined($job->{jobdata}->{qsubid})) {
		print "Qsub ID: ".$job->{jobdata}->{qsubid}."\n";
	}
	if (defined($job->{jobdata}->{error})) {
		print "Error: ".$job->{jobdata}->{error}."\n";
	}
}

1;