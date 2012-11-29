package Bio::KBase::fbaModelCLI::Client;

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

Bio::KBase::fbaModelCLI::Client

=head1 DESCRIPTION


API for executing command line functions. This API acts as a
pass-through service for executing command line functions for FBA
modeling hosted in KBase. This aleviates the need to have specifically
tailored CLI commands.


=cut

sub new
{
    my($class, $url, @args) = @_;

    my $self = {
	client => Bio::KBase::fbaModelCLI::Client::RpcClient->new,
	url => $url,
    };


    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 execute_command

  $status, $stdout, $stderr = $obj->execute_command($args, $stdin)

=over 4

=item Parameter and return types

=begin html

<pre>
$args is an ARGV
$stdin is an STDIN
$status is an int
$stdout is an STDOUT
$stderr is an STDERR
ARGV is a reference to a list where each element is a string
STDIN is a string
STDOUT is a string
STDERR is a string

</pre>

=end html

=begin text

$args is an ARGV
$stdin is an STDIN
$status is an int
$stdout is an STDOUT
$stderr is an STDERR
ARGV is a reference to a list where each element is a string
STDIN is a string
STDOUT is a string
STDERR is a string


=end text

=item Description



=back

=cut

sub execute_command
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function execute_command (received $n, expecting 2)");
    }
    {
	my($args, $stdin) = @args;

	my @_bad_arguments;
        (ref($args) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"args\" (value was \"$args\")");
        (!ref($stdin)) or push(@_bad_arguments, "Invalid type for argument 2 \"stdin\" (value was \"$stdin\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to execute_command:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'execute_command');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelCLI.execute_command",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'execute_command',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method execute_command",
					    status_line => $self->{client}->status_line,
					    method_name => 'execute_command',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "fbaModelCLI.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'execute_command',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method execute_command",
            status_line => $self->{client}->status_line,
            method_name => 'execute_command',
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
        warn "New client version available for Bio::KBase::fbaModelCLI::Client\n";
    }
    if ($sMajor == 0) {
        warn "Bio::KBase::fbaModelCLI::Client version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 ARGV

=over 4



=item Definition

=begin html

<pre>
a reference to a list where each element is a string
</pre>

=end html

=begin text

a reference to a list where each element is a string

=end text

=back



=head2 STDIN

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 STDOUT

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 STDERR

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=cut

package Bio::KBase::fbaModelCLI::Client::RpcClient;
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
        $obj->{id} = $self->id if (defined $self->id);
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
