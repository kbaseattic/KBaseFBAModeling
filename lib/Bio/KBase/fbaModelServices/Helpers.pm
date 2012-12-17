package Bio::KBase::fbaModelServices::Helpers;
use strict;
use warnings;
use Exporter;
use Getopt::Long::Descriptive;
use Text::Table;
use JSON;
use Bio::KBase::fbaModelServices::Client;
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use parent qw(Exporter);
our @EXPORT_OK = qw( fbaURL get_fba_client printJobData runFBACommand universalFBAScriptCode );
our $defaultURL = "http://kbase.us/services/fbaServices/";

sub get_fba_client {
    return Bio::KBase::fbaModelServices::Client->new(fbaURL());
}

sub fbaURL {
    my $set = shift;
    my $url;
    my $filename = "$ENV{HOME}/.kbase_fbaURL";
    if ( defined $set ) {
        if ($set eq "default") {
        	$set = $defaultURL;
        }
       	open(my $fh, ">", $filename) || return;
       	print $fh $set;
       	close($fh);
       	$url = $set;
    } elsif( -e $filename ) {
        open(my $fh, "<", $filename) || return;
        $url = <$fh>;
        chomp $url;
        close($fh);
    } else {
        $url = $defaultURL;	
    }
    return $url;
}

sub printJobData {
    my $job = shift;
    print "Job ID: ".$job->{id}."\n";
    print "Job WS: ".$job->{workspace}."\n";
    print "Command: ".$job->{queuing_command}."\n";
    print "Queue time: ".$job->{queuetime}."\n";
    print "Is complete: ".$job->{complete}."\n";
}

sub universalFBAScriptCode {
    my $specs = shift;
    my $script = shift;
    my $primaryArgs = shift;
    my $translation = shift;
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
		auth => auth(),
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
	if ($opt->{showerror} == 0){
	    eval {
	        $output = $serv->$function($params);
	    };
	}else{
	    $output = $serv->$function($params);
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

1;