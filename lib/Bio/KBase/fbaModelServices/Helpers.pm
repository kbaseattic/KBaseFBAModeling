package Bio::KBase::fbaModelServices::Helpers;
use strict;
use warnings;
use Exporter;
use Getopt::Long::Descriptive;
use Text::Table;
use Bio::KBase::fbaModelServices::Client;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use parent qw(Exporter);
our @EXPORT_OK = qw( fbaURL get_fba_client runFBACommand universalFBAScriptCode fbaTranslation roles_of_function );
our $defaultURL = "https://kbase.us/services/KBaseFBAModeling";
my $CurrentURL;

sub get_fba_client {
	if (fbaURL() eq "impl") {
		require "Bio/KBase/fbaModelServices/Impl.pm";
		return Bio::KBase::fbaModelServices::Impl->new({workspace => get_ws_client()});
	}
    return Bio::KBase::fbaModelServices::Client->new(fbaURL());
}

sub fbaURL {
    my $set = shift;
    if (defined($set)) {
    	if ($set eq "default") {
        	$set = $defaultURL;
        }
    	$CurrentURL = $set;
    	if (!defined($ENV{KB_RUNNING_IN_IRIS})) {
	    	my $filename = "$ENV{HOME}/.kbase_fbaURL";
	    	open(my $fh, ">", $filename) || return;
		    print $fh $CurrentURL;
		    close($fh);
    	} elsif ($ENV{KB_FBAURL}) {
    		$ENV{KB_FBAURL} = $CurrentURL;
    	}
    } elsif (!defined($CurrentURL)) {
    	if (!defined($ENV{KB_RUNNING_IN_IRIS})) {
	    	my $filename = "$ENV{HOME}/.kbase_fbaURL";
	    	if( -e $filename ) {
		   		open(my $fh, "<", $filename) || return;
		        $CurrentURL = <$fh>;
		        chomp $CurrentURL;
		        close($fh);
	    	} else {
	    		$CurrentURL = $defaultURL;
	    	}
    	} elsif (defined($ENV{KB_FBAURL})) {
	    	$CurrentURL = $ENV{KB_FBAURL};
	    } else {
			$CurrentURL = "http://bio-data-1.mcs.anl.gov/services/fba";
    		#$CurrentURL = $defaultURL;
    	}
    }
    return $CurrentURL;
}

sub universalFBAScriptCode {
    my $specs = shift;
    my $script = shift;
    my $primaryArgs = shift;
    my $translation = shift;
    my $manpage = shift;
    $translation->{workspace} = "workspace";
    $translation->{auth} = "auth";
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
    push(@{$options},[ 'verbose|v', 'Print verbose messages' ]);
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
		auth => auth(),
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
    	$output = $serv->$function($params);
	};$error = $@ if $@;
	if ($opt->{showerror} == 0 && defined($error)){
	    print STDERR $error;
	}elsif (defined($error) && $error =~ m/ERROR\{(.+)\}ERROR/) {
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

1;