package Bio::ModelSEED::MSSeedSupportServer::Client;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

Bio::ModelSEED::MSSeedSupportServer::Client

=head1 DESCRIPTION


=head1 MSSeedSupportServer

=head2 SYNOPSIS

=head2 EXAMPLE OF API USE IN PERL

=head2 AUTHENTICATION

=head2 MSSEEDSUPPORTSERVER


=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => Bio::ModelSEED::MSSeedSupportServer::Client::RpcClient->new,
	url => $url,
    };


    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 getRastGenomeData

  $output = $obj->getRastGenomeData($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a getRastGenomeData_params
$output is a RastGenome
getRastGenomeData_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	genome has a value which is a string
	getSequences has a value which is an int
	getDNASequence has a value which is an int
RastGenome is a reference to a hash where the following keys are defined:
	source has a value which is a string
	genome has a value which is a string
	features has a value which is a reference to a list where each element is a string
	DNAsequence has a value which is a reference to a list where each element is a string
	name has a value which is a string
	taxonomy has a value which is a string
	size has a value which is an int
	owner has a value which is a string

</pre>

=end html

=begin text

$params is a getRastGenomeData_params
$output is a RastGenome
getRastGenomeData_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	genome has a value which is a string
	getSequences has a value which is an int
	getDNASequence has a value which is an int
RastGenome is a reference to a hash where the following keys are defined:
	source has a value which is a string
	genome has a value which is a string
	features has a value which is a reference to a list where each element is a string
	DNAsequence has a value which is a reference to a list where each element is a string
	name has a value which is a string
	taxonomy has a value which is a string
	size has a value which is an int
	owner has a value which is a string


=end text

=item Description

Retrieves a RAST genome based on the input genome ID

=back

=cut

sub getRastGenomeData
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function getRastGenomeData (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to getRastGenomeData:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'getRastGenomeData');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.getRastGenomeData",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'getRastGenomeData',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method getRastGenomeData",
					    status_line => $self->{client}->status_line,
					    method_name => 'getRastGenomeData',
				       );
    }
}



=head2 get_user_info

  $output = $obj->get_user_info($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_user_info_params
$output is a SEEDUser
get_user_info_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
SEEDUser is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	firstname has a value which is a string
	lastname has a value which is a string
	email has a value which is a string
	id has a value which is an int

</pre>

=end html

=begin text

$params is a get_user_info_params
$output is a SEEDUser
get_user_info_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
SEEDUser is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	firstname has a value which is a string
	lastname has a value which is a string
	email has a value which is a string
	id has a value which is an int


=end text

=item Description

Retrieves a RAST genome based on the input genome ID

=back

=cut

sub get_user_info
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_user_info (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_user_info:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_user_info');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.get_user_info",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_user_info',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_user_info",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_user_info',
				       );
    }
}



=head2 authenticate

  $username = $obj->authenticate($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an authenticate_params
$username is a string
authenticate_params is a reference to a hash where the following keys are defined:
	token has a value which is a string

</pre>

=end html

=begin text

$params is an authenticate_params
$username is a string
authenticate_params is a reference to a hash where the following keys are defined:
	token has a value which is a string


=end text

=item Description

Authenticate against the SEED account

=back

=cut

sub authenticate
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function authenticate (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to authenticate:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'authenticate');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.authenticate",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'authenticate',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method authenticate",
					    status_line => $self->{client}->status_line,
					    method_name => 'authenticate',
				       );
    }
}



=head2 load_model_to_modelseed

  $success = $obj->load_model_to_modelseed($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a load_model_to_modelseed_params
$success is an int
load_model_to_modelseed_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	owner has a value which is a string
	genome has a value which is a string
	reactions has a value which is a reference to a list where each element is a string
	biomass has a value which is a string

</pre>

=end html

=begin text

$params is a load_model_to_modelseed_params
$success is an int
load_model_to_modelseed_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	owner has a value which is a string
	genome has a value which is a string
	reactions has a value which is a reference to a list where each element is a string
	biomass has a value which is a string


=end text

=item Description

Loads the input model to the model seed database

=back

=cut

sub load_model_to_modelseed
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function load_model_to_modelseed (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to load_model_to_modelseed:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'load_model_to_modelseed');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.load_model_to_modelseed",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'load_model_to_modelseed',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method load_model_to_modelseed",
					    status_line => $self->{client}->status_line,
					    method_name => 'load_model_to_modelseed',
				       );
    }
}



=head2 create_plantseed_job

  $output = $obj->create_plantseed_job($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a create_plantseed_job_params
$output is a string
create_plantseed_job_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	fasta has a value which is a string
	contigid has a value which is a string
	source has a value which is a string
	genetic_code has a value which is a string
	domain has a value which is a string
	scientific_name has a value which is a string

</pre>

=end html

=begin text

$params is a create_plantseed_job_params
$output is a string
create_plantseed_job_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
	fasta has a value which is a string
	contigid has a value which is a string
	source has a value which is a string
	genetic_code has a value which is a string
	domain has a value which is a string
	scientific_name has a value which is a string


=end text

=item Description

Creates a plant seed job for the input fasta file

=back

=cut

sub create_plantseed_job
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function create_plantseed_job (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to create_plantseed_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'create_plantseed_job');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.create_plantseed_job",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'create_plantseed_job',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method create_plantseed_job",
					    status_line => $self->{client}->status_line,
					    method_name => 'create_plantseed_job',
				       );
    }
}



=head2 get_plantseed_genomes

  $output = $obj->get_plantseed_genomes($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_plantseed_genomes_params
$output is a reference to a list where each element is a plantseed_genomes
get_plantseed_genomes_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
plantseed_genomes is a reference to a hash where the following keys are defined:
	owner has a value which is a string
	genome has a value which is a string
	contigs has a value which is a string
	model has a value which is a string
	status has a value which is a string

</pre>

=end html

=begin text

$params is a get_plantseed_genomes_params
$output is a reference to a list where each element is a plantseed_genomes
get_plantseed_genomes_params is a reference to a hash where the following keys are defined:
	username has a value which is a string
	password has a value which is a string
plantseed_genomes is a reference to a hash where the following keys are defined:
	owner has a value which is a string
	genome has a value which is a string
	contigs has a value which is a string
	model has a value which is a string
	status has a value which is a string


=end text

=item Description

Retrieves a list of plantseed genomes owned by user

=back

=cut

sub get_plantseed_genomes
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_plantseed_genomes (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_plantseed_genomes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_plantseed_genomes');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.get_plantseed_genomes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_plantseed_genomes',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_plantseed_genomes",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_plantseed_genomes',
				       );
    }
}



=head2 kblogin

  $authtoken = $obj->kblogin($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a kblogin_params
$authtoken is a string
kblogin_params is a reference to a hash where the following keys are defined:
	kblogin has a value which is a string
	kbpassword has a value which is a string

</pre>

=end html

=begin text

$params is a kblogin_params
$authtoken is a string
kblogin_params is a reference to a hash where the following keys are defined:
	kblogin has a value which is a string
	kbpassword has a value which is a string


=end text

=item Description

Login for specified kbase account

=back

=cut

sub kblogin
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function kblogin (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to kblogin:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'kblogin');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.kblogin",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'kblogin',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method kblogin",
					    status_line => $self->{client}->status_line,
					    method_name => 'kblogin',
				       );
    }
}



=head2 kblogin_from_token

  $login = $obj->kblogin_from_token($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a kblogin_from_token_params
$login is a string
kblogin_from_token_params is a reference to a hash where the following keys are defined:
	authtoken has a value which is a string

</pre>

=end html

=begin text

$params is a kblogin_from_token_params
$login is a string
kblogin_from_token_params is a reference to a hash where the following keys are defined:
	authtoken has a value which is a string


=end text

=item Description

Login for specified kbase auth token

=back

=cut

sub kblogin_from_token
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function kblogin_from_token (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to kblogin_from_token:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'kblogin_from_token');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "MSSeedSupportServer.kblogin_from_token",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'kblogin_from_token',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method kblogin_from_token",
					    status_line => $self->{client}->status_line,
					    method_name => 'kblogin_from_token',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "MSSeedSupportServer.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'kblogin_from_token',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method kblogin_from_token",
            status_line => $self->{client}->status_line,
            method_name => 'kblogin_from_token',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for Bio::ModelSEED::MSSeedSupportServer::Client\n";
    }
    if ($sMajor == 0) {
        warn "Bio::ModelSEED::MSSeedSupportServer::Client version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 RastGenome

=over 4



=item Description

RAST genome data

        string source;
        string genome;
        list<string> features;
        list<string> DNAsequence;
        string name;
        string taxonomy;
        int size;
        string owner;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
source has a value which is a string
genome has a value which is a string
features has a value which is a reference to a list where each element is a string
DNAsequence has a value which is a reference to a list where each element is a string
name has a value which is a string
taxonomy has a value which is a string
size has a value which is an int
owner has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
source has a value which is a string
genome has a value which is a string
features has a value which is a reference to a list where each element is a string
DNAsequence has a value which is a reference to a list where each element is a string
name has a value which is a string
taxonomy has a value which is a string
size has a value which is an int
owner has a value which is a string


=end text

=back



=head2 getRastGenomeData_params

=over 4



=item Description

Input parameters for the "getRastGenomeData" function.

        string genome;
        int getSequences;
        int getDNASequence;
        string username;
        string password;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
genome has a value which is a string
getSequences has a value which is an int
getDNASequence has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
genome has a value which is a string
getSequences has a value which is an int
getDNASequence has a value which is an int


=end text

=back



=head2 SEEDUser

=over 4



=item Description

SEED user account

        string username;
    string password;
    string firstname;
    string lastname;
    string email;
    int id;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
firstname has a value which is a string
lastname has a value which is a string
email has a value which is a string
id has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
firstname has a value which is a string
lastname has a value which is a string
email has a value which is a string
id has a value which is an int


=end text

=back



=head2 get_user_info_params

=over 4



=item Description

Input parameters for the "get_user_info" function.

        string username;
        string password;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string


=end text

=back



=head2 authenticate_params

=over 4



=item Description

Input parameters for the "authenticate" function.

        string token;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
token has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
token has a value which is a string


=end text

=back



=head2 load_model_to_modelseed_params

=over 4



=item Description

Input parameters for the "load_model_to_modelseed" function.

        string token;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
owner has a value which is a string
genome has a value which is a string
reactions has a value which is a reference to a list where each element is a string
biomass has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
owner has a value which is a string
genome has a value which is a string
reactions has a value which is a reference to a list where each element is a string
biomass has a value which is a string


=end text

=back



=head2 create_plantseed_job_params

=over 4



=item Description

Input parameters for the "create_plantseed_job" function.

        string username - username of owner of new genome
        string password - password of owner of new genome
        string fasta - fasta file data


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
fasta has a value which is a string
contigid has a value which is a string
source has a value which is a string
genetic_code has a value which is a string
domain has a value which is a string
scientific_name has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string
fasta has a value which is a string
contigid has a value which is a string
source has a value which is a string
genetic_code has a value which is a string
domain has a value which is a string
scientific_name has a value which is a string


=end text

=back



=head2 get_plantseed_genomes_params

=over 4



=item Description

Input parameters for the "get_plantseed_genomes" function.

        string username - username of owner of new genome
        string password - password of owner of new genome


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
username has a value which is a string
password has a value which is a string


=end text

=back



=head2 plantseed_genomes

=over 4



=item Description

Output for the "get_plantseed_genomes" function.

        string owner - owner of the plantseed genome
        string genome - ID of the plantseed genome
        string contigs - ID of the contigs for plantseed genome
        string model - ID of model for PlantSEED genome
        string status - status of plantseed genome


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
owner has a value which is a string
genome has a value which is a string
contigs has a value which is a string
model has a value which is a string
status has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
owner has a value which is a string
genome has a value which is a string
contigs has a value which is a string
model has a value which is a string
status has a value which is a string


=end text

=back



=head2 kblogin_params

=over 4



=item Description

Input for "kblogin" function.

        string kblogin - KBase username
        string kbpassword - KBase password


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kblogin has a value which is a string
kbpassword has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kblogin has a value which is a string
kbpassword has a value which is a string


=end text

=back



=head2 kblogin_from_token_params

=over 4



=item Description

Input for "kblogin" function.

        string authtoken - KBase token


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
authtoken has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
authtoken has a value which is a string


=end text

=back



=cut

package Bio::ModelSEED::MSSeedSupportServer::Client::RpcClient;
use base 'JSON::RPC::Client';

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $obj) = @_;
    my $result;

    if ($uri =~ /\?/) {
       $result = $self->_get($uri);
    }
    else {
        Carp::croak "not hashref." unless (ref $obj eq 'HASH');
        $result = $self->_post($uri, $obj);
    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;
