package Bio::KBase::fbaModel::CLI::Impl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

fbaModelCLI

=head1 DESCRIPTION

API for executing command line functions. This API acts as a
pass-through service for executing command line functions for FBA
modeling hosted in KBase. This aleviates the need to have specifically
tailored CLI commands.

=cut

#BEGIN_HEADER
use ModelSEED::App::mseed;
use ModelSEED::App::import;
use ModelSEED::App::bio;
use ModelSEED::App::mapping;
use ModelSEED::App::genome;
use ModelSEED::App::model;
use Data::Dumper;
use Try::Tiny;

sub app {
    my ($self, $app_name) = @_;
    if(defined($self->{_apps}->{$app_name})) {
        return $self->{_apps}->{$app_name};
    }
    # die with an error
}

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    my @apps = qw( mseed import bio mapping genome model );
    my $allowed_apps = { 
        map { my $pkg = "ModelSEED::App::$_"; $_ => $pkg->new }
        @apps
    };
    $self->{_apps} = $allowed_apps;
    $self->{_app_commands} = {
        map { $_ => [ $allowed_apps->{$_}->command_names ] }
        @apps
    };
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



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
    my $self = shift;
    my($args, $stdin) = @_;

    my @_bad_arguments;
    (ref($args) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"args\" (value was \"$args\")");
    (!ref($stdin)) or push(@_bad_arguments, "Invalid type for argument \"stdin\" (value was \"$stdin\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to execute_command:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'execute_command');
    }

    my $ctx = $Bio::KBase::fbaModel::CLI::Service::CallContext;
    my($status, $stdout, $stderr);
    #BEGIN execute_command
    $status = 0;
    my $app_name = shift @$args;
    my $app;
    my $error = 0;
    if (!defined $app_name || !defined $self->app($app_name)) {
        $stdout = "No such application $app_name under this service!\n";
        $status = 1;
        $error  = 1;
    } else {
        $app = $self->app($app_name); 
    }
    unless ($error) {
        # Redirect STDOUT, STDERR, construct STDIN
        local *STDIN;
        local *STDOUT;
        local *STDERR;
        open(STDIN, "<", \$stdin);
        open(STDOUT, ">", \$stdout);
        open(STDERR, ">", \$stderr);
        try {
            my ($cmd, $opt, @args) = $app->prepare_command(@$args);
            $app->execute_command($cmd, $opt, @args);
        } catch {
            $status = 1;
            warn $_;
        };
        close(STDIN);
        close(STDOUT);
        close(STDERR);
    }
    #END execute_command
    my @_bad_returns;
    (!ref($status)) or push(@_bad_returns, "Invalid type for return variable \"status\" (value was \"$status\")");
    (!ref($stdout)) or push(@_bad_returns, "Invalid type for return variable \"stdout\" (value was \"$stdout\")");
    (!ref($stderr)) or push(@_bad_returns, "Invalid type for return variable \"stderr\" (value was \"$stderr\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to execute_command:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'execute_command');
    }
    return($status, $stdout, $stderr);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
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

1;
