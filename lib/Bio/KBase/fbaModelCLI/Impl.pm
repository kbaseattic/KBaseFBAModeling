package Bio::KBase::fbaModelCLI::Impl;
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
use ModelSEED::Configuration;
use Getopt::Long::Descriptive;
use Exception::Class;
use Data::Dumper;
use Try::Tiny;

sub app {
    my ($self, $app_name) = @_;
    if(defined($self->{_apps}->{$app_name})) {
        return $self->{_apps}->{$app_name};
    }
    # die with an error
}

sub realAppName {
    my ($self, $app_name) = @_;
    return "ms" if $app_name eq "mseed";
    return $app_name;
}

sub commandInWhitelist {
    my ( $self, $app_name, $cmd_name ) = @_;
    my $whitelist = {
        ms => {
            commands => 1,
            help     => 1,
            bio      => 1,
            genome   => 1,
            import   => 1,
            get      => 1,
            history  => 1,
            list     => 1,
            mapping  => 1,
            model    => 1,
            save     => 1,
        },
        bio => {
            commands      => 1,
            help          => 1,
            addcpd        => 1,
            addcpdtable   => 1,
            addmedia      => 1,
            addrxn        => 1,
            addrxntable   => 1,
            aliasset      => 1,
            calcdistances => 1,
            create        => 1,
            findcpd       => 1,
            readable      => 1,
            validate      => 1,
        },
        genome => {
            commands   => 1,
            help       => 1,
            buildmodel => 1,
            mapping    => 1,
            readable   => 1,
            roles      => 1,
            subsystems => 1,
        },
        import => {
            commands     => 1,
            help         => 1,
            annotation   => 1,
            biochemistry => 1,
            mapping      => 1,
            model        => 1,
        },
        mapping => {
            commands => 1,
            help     => 1,
            bio      => 1,
            readable => 1,
        },
        model => {
            commands         => 1,
            help             => 1,
            calcdistances    => 1,
            gapfill          => 1,
            gapgen           => 1,
            genome           => 1,
            readable         => 1,
            runfba           => 1,
            sbml             => 1,
            simphenotypes    => 1,
            tohtml           => 1,
            updateprovenance => 1,
        },
    };
    return 1 if defined $whitelist->{$app_name}->{$cmd_name};
    return 0;
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
    my $apps_to_app_names = { qw(
          mseed     ms
          bio       bio
          mapping   mapping
          genome    genome
          model     model
    )};
    my $allowed_apps = { 
        map { my $pkg = "ModelSEED::App::$_"; $_ => $pkg->new }
        @apps
    };
    $self->{_apps} = $allowed_apps;
    $self->{_app_commands} = {
        map { $_ => [ $allowed_apps->{$_}->command_names ] }
        @apps
    };
    # Make sure ModelSEED::Configuration is set up correctly
    my ($host, $db);
    if (my $e = $ENV{KB_DEPLOYMENT_CONFIG}) {
        my $service = $ENV{KB_SERVICE_NAME};
        my $c = new Config::Simple($e);
        $host = $c->param("$service.mongodb-hostname");
        $db   = $c->param("$service.mongodb-database");
    } else {
        warn "No deployment configuration found;\n";
    }
    if (!$host) {
        $host = "mongodb.kbase.us";
        warn "\tfalling back to $host for database!\n";
    }
    if (!$db) {
        $db = "modelObjectStore";
        warn "\tfalling back to $db for collection\n";
    }
    my $config = ModelSEED::Configuration->new;
    $config->config->{stores} = [];
    push(@{$config->config->{stores}},
        {
            class   => "ModelSEED::Database::MongoDBSimple",
            type    => "mongo",
            name    => "kbase",
            db_name => $db,
            host    => $host,
        }
    );
    $config->config->{login} = { username => "kbase", password => "kbase" };
    $config->save();
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

    my $ctx = $Bio::KBase::fbaModelCLI::Server::CallContext;
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
    # Convert app name to expected format
    $app_name = $self->realAppName($app_name);
    Getopt::Long::Descriptive::prog_name($app_name);
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
            my @names = $cmd->command_names;
            my $cmd_name = shift @names;
            # Return error if unknown or non-whitelist function called
            unless($self->commandInWhitelist($app_name, $cmd_name)) {
                die "Cannot execute that command in this environment!\n";
            }
            $app->execute_command($cmd, $opt, @args);
        } catch {
            $status = 1;
            local $@ = $_;
            if ( my $e = Exception::Class->caught('ModelSEED::Exception::CLI') ) {
                warn $e->cli_error_text();
            } else {
                warn $@;
            }
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
