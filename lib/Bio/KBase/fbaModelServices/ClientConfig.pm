package Bio::KBase::fbaModelServices::ClientConfig;
use strict;
use warnings;
use Bio::KBase::fbaModelServices::ScriptConfig;

=head3 ConfigFilename
Definition:
	void Bio::KBase::fbaModelServices::ClientConfig::ConfigFilename;
Description:
	Returns the filename where the config file is currently stashed

=cut
sub ConfigFilename {
    my $filename = glob "~/.kbase_config";
    if (defined($ENV{ KB_CLIENT_CONFIG })) {
    	$filename = $ENV{ KB_CLIENT_CONFIG };
    } elsif (defined($ENV{ HOME })) {
    	$filename = $ENV{ HOME }."/.kbase_config";
    }
   	return $filename;
}

=head3 GetConfigs
Definition:
	void Bio::KBase::fbaModelServices::ClientConfig::GetConfigs;
Description:
	Loads the local config file if it exists, and creates default config file if not

=cut
sub GetConfigs {
    my $filename = ConfigFilename();
    my $c;
    if (!-e $filename) {
    	SetDefaultConfig("fbaModelServices");
    	SetDefaultConfig("oldworkspace");
    }
	$c = Config::Simple->new( filename => $filename);
    if (!defined($c->param("fbaModelServices.url")) || length($c->param("fbaModelServices.url")) == 0 || $c->param("fbaModelServices.url") =~ m/ARRAY/) {
    	SetDefaultConfig("fbaModelServices");
    	$c = GetConfigs();
    }
    if (!defined($c->param("oldworkspace.url")) || length($c->param("oldworkspace.url")) == 0 || $c->param("oldworkspace.url") =~ m/ARRAY/) {
    	SetDefaultConfig("oldworkspace");
    	$c = GetConfigs();
    }
    return $c;
}

=head3 GetConfigParam
Definition:
	string = Bio::KBase::fbaModelServices::ClientConfig::GetConfigParam;
Description:
	Returns a single config parameter

=cut
sub GetConfigParam {
	my($param) = @_;
	my $c = GetConfigs();
    return $c->param($param);
}

=head3 SetDefaultConfig
Definition:
	void Bio::KBase::fbaModelServices::ClientConfig::SetDefaultConfig;
Description:
	Sets default configurations using parameters specified in ScriptConfig

=cut
sub SetDefaultConfig {
	my($class) = @_;
	my $filename = ConfigFilename();
    my $c;
    if (-e $filename) {
    	$c = Config::Simple->new( filename => $filename);
    } else {
	    $c = Config::Simple->new( syntax => 'ini');
    }
    if ($class eq "fbaModelServices") {
		$c->set_block('fbaModelServices', {
			url => $Bio::KBase::fbaModelServices::ScriptConfig::defaultFBAURL		
		});
	} elsif ($class eq "oldworkspace") {
		$c->set_block('oldworkspace', {
			url => $Bio::KBase::fbaModelServices::ScriptConfig::defaultOldWSURL
		});
	} else {
		$c->set_block('fbaModelServices', {
			url => $Bio::KBase::fbaModelServices::ScriptConfig::defaultFBAURL		
		});
		$c->set_block('oldworkspace', {
			url => $Bio::KBase::fbaModelServices::ScriptConfig::defaultOldWSURL
		});
	}
    $c->write($filename);
}

=head3 SetConfig
Definition:
	void Bio::KBase::fbaModelServices::ClientConfig::SetConfig;
Description:
	Sets specified parameters to the specified values

=cut
sub SetConfig {
    my($params) = @_;
    my $c = GetConfigs();
	$c->autosave( 0 ); # disable autosaving so that update is "atomic"
	for my $key (keys(%{$params})) {
	    unless ($key =~ /^[a-zA-Z]\w*$/) {
			die "Parameter key '$key' is not a legitimate key value";
	    }
	    unless ((ref $params->{$key} eq '') ||
		    (ref $params->{$key} eq 'ARRAY')) {
			die "Parameter value for $key is not a legal value: ".$params->{$key};
	    }
    	my $fullkey = "fbaModelServices." . $key;
    	if (! defined($params->{$key})) {
			if (defined($c->param($fullkey))) {
			    $c->delete($fullkey);
			}
	    } else {
			$c->param($fullkey, $params->{$key});
	    }
	}
	$c->save(ConfigFilename());
	chmod 0600, ConfigFilename();  
}

1;