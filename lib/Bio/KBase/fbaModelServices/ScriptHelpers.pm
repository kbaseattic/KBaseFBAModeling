use strict;
use warnings;
package Bio::KBase::fbaModelServices::ScriptHelpers;
use Data::Dumper;
use Config::Simple;
use Getopt::Long::Descriptive;
use Text::Table;
use Bio::KBase::Auth;
use Bio::KBase::fbaModelServices::Client;
use Bio::KBase::workspace::ScriptHelpers qw(workspaceURL get_ws_client workspace parseObjectMeta parseWorkspaceMeta);
use Exporter;
use parent qw(Exporter);
our @EXPORT_OK = qw( printJobData fbaURL get_fba_client runFBACommand universalFBAScriptCode fbaTranslation roles_of_function );

our $defaultURL = "https://kbase.us/services/KBaseFBAModeling";
our $localhostURL = "http://127.0.0.1:4043";
our $devURL = "http://140.221.85.73:4043";

sub getKBaseCfg {
	my $kbConfPath = $Bio::KBase::Auth::ConfPath;
	if (!-e $kbConfPath) {
		my $newcfg = new Config::Simple(syntax=>'ini') or die Config::Simple->error();
		$newcfg->param("fbaModelServices.url",$defaultURL);
		$newcfg->write($kbConfPath);
		$newcfg->close();
	}
	my $cfg = new Config::Simple(filename=>$kbConfPath) or die Config::Simple->error();
	return $cfg;
}

sub getToken {
	my $token='';
	my $kbConfPath = $Bio::KBase::Auth::ConfPath;
	if (defined($ENV{KB_RUNNING_IN_IRIS})) {
		$token = $ENV{KB_AUTH_TOKEN};
	} elsif ( -e $kbConfPath ) {
		my $cfg = new Config::Simple($kbConfPath);
		$token = $cfg->param("authentication.token");
		$cfg->close();
	}
	return $token;
}

sub get_fba_client {
	my $url = shift;
	if (!defined($url)) {
		$url = fbaURL();
	}
	if ($url eq "impl") {
		require "Bio/KBase/fbaModelServices/Impl.pm";
		return Bio::KBase::fbaModelServices::Impl->new({workspace => get_ws_client()});
	}
	my $client = Bio::KBase::fbaModelServices::Client->new(fbaURL());
	$client->{token} = getToken();
	$client->{client}->{token} = getToken();
    return $client;
}

sub fbaURL {
	my $newUrl = shift;
	my $currentURL;
	if (defined($newUrl)) {
		if ($newUrl eq "default") {
			$newUrl = $defaultURL;
		} elsif ($newUrl eq "localhost") {
			$newUrl = $localhostURL;
		} elsif ($newUrl eq "dev") {
			$newUrl = $devURL;
		}
		
		$currentURL = $newUrl;
		if (!defined($ENV{KB_RUNNING_IN_IRIS})) {
			my $cfg = getKBaseCfg();
			$cfg->param("fbaModelServices.url",$newUrl);
			$cfg->save();
			$cfg->close();
		} elsif ($ENV{KB_FBAURL}) {
			$ENV{KB_FBAURL} = $currentURL;
		}
	} else {
		if (!defined($ENV{KB_RUNNING_IN_IRIS})) {
			my $cfg = getKBaseCfg();
			$currentURL = $cfg->param("fbaModelServices.url");
			if (!defined($currentURL)) {
				$cfg->param("fbaModelServices.url",$defaultURL);
				$cfg->save();
				$currentURL=$defaultURL;
			}
			$cfg->close();
		} else {
			$currentURL = $ENV{KB_FBAURL};
		}
	}
	return $currentURL;
}

sub universalFBAScriptCode {
    my $specs = shift;
    my $script = shift;
    my $primaryArgs = shift;
    my $translation = shift;
    my $manpage = shift;
    $translation->{workspace} = "workspace";
    #$translation->{auth} = "auth";
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
		wsurl => workspaceURL()
	};
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
    my $serv = get_fba_client();
    my $output;
    my $error;
    eval {
    	delete $params->{auth};
    	$output = $serv->$function($params);
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