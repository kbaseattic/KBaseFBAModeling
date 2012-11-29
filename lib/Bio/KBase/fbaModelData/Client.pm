package Bio::KBase::fbaModelData::Client;

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

Bio::KBase::fbaModelData::Client

=head1 DESCRIPTION


=head1 fbaModelData

Data access library for fbaModel services. This API is meant for
interanl use only. Do not distribute or expose publically.


=cut

sub new
{
    my($class, $url, @args) = @_;

    my $self = {
	client => Bio::KBase::fbaModelData::Client::RpcClient->new,
	url => $url,
    };


    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 has_data

  $existence = $obj->has_data($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$existence is a Bool
Ref is a string
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$existence is a Bool
Ref is a string
Bool is an int


=end text

=item Description



=back

=cut

sub has_data
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function has_data (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to has_data:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'has_data');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.has_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'has_data',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method has_data",
					    status_line => $self->{client}->status_line,
					    method_name => 'has_data',
				       );
    }
}



=head2 get_data

  $data = $obj->get_data($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$data is a Data
Ref is a string
Data is a string

</pre>

=end html

=begin text

$ref is a Ref
$data is a Data
Ref is a string
Data is a string


=end text

=item Description



=back

=cut

sub get_data
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_data (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_data:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_data');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.get_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_data',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_data",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_data',
				       );
    }
}



=head2 save_data

  $success = $obj->save_data($ref, $data, $config)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$data is a Data
$config is a SaveConf
$success is a Bool
Ref is a string
Data is a string
SaveConf is a reference to a hash where the following keys are defined:
	is_merge has a value which is a Bool
	schema_update has a value which is a Bool
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$data is a Data
$config is a SaveConf
$success is a Bool
Ref is a string
Data is a string
SaveConf is a reference to a hash where the following keys are defined:
	is_merge has a value which is a Bool
	schema_update has a value which is a Bool
Bool is an int


=end text

=item Description



=back

=cut

sub save_data
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 3)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function save_data (received $n, expecting 3)");
    }
    {
	my($ref, $data, $config) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        (!ref($data)) or push(@_bad_arguments, "Invalid type for argument 2 \"data\" (value was \"$data\")");
        (ref($config) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 3 \"config\" (value was \"$config\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to save_data:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'save_data');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.save_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'save_data',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method save_data",
					    status_line => $self->{client}->status_line,
					    method_name => 'save_data',
				       );
    }
}



=head2 get_aliases

  $aliases = $obj->get_aliases($query)

=over 4

=item Parameter and return types

=begin html

<pre>
$query is an Alias
$aliases is an Aliases
Alias is a reference to a hash where the following keys are defined:
	uuid has a value which is an UUID
	owner has a value which is a Username
	type has a value which is a string
	alias has a value which is a string
UUID is a string
Username is a string
Aliases is a reference to a list where each element is an Alias

</pre>

=end html

=begin text

$query is an Alias
$aliases is an Aliases
Alias is a reference to a hash where the following keys are defined:
	uuid has a value which is an UUID
	owner has a value which is a Username
	type has a value which is a string
	alias has a value which is a string
UUID is a string
Username is a string
Aliases is a reference to a list where each element is an Alias


=end text

=item Description



=back

=cut

sub get_aliases
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_aliases (received $n, expecting 1)");
    }
    {
	my($query) = @args;

	my @_bad_arguments;
        (ref($query) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"query\" (value was \"$query\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_aliases:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_aliases');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.get_aliases",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_aliases',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_aliases",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_aliases',
				       );
    }
}



=head2 update_alias

  $success = $obj->update_alias($ref, $uuid)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$uuid is an UUID
$success is a Bool
Ref is a string
UUID is a string
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$uuid is an UUID
$success is a Bool
Ref is a string
UUID is a string
Bool is an int


=end text

=item Description



=back

=cut

sub update_alias
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function update_alias (received $n, expecting 2)");
    }
    {
	my($ref, $uuid) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        (!ref($uuid)) or push(@_bad_arguments, "Invalid type for argument 2 \"uuid\" (value was \"$uuid\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to update_alias:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'update_alias');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.update_alias",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'update_alias',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method update_alias",
					    status_line => $self->{client}->status_line,
					    method_name => 'update_alias',
				       );
    }
}



=head2 add_viewer

  $success = $obj->add_viewer($ref, $viewer)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$viewer is a Username
$success is a Bool
Ref is a string
Username is a string
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$viewer is a Username
$success is a Bool
Ref is a string
Username is a string
Bool is an int


=end text

=item Description



=back

=cut

sub add_viewer
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function add_viewer (received $n, expecting 2)");
    }
    {
	my($ref, $viewer) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        (!ref($viewer)) or push(@_bad_arguments, "Invalid type for argument 2 \"viewer\" (value was \"$viewer\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to add_viewer:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'add_viewer');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.add_viewer",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'add_viewer',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method add_viewer",
					    status_line => $self->{client}->status_line,
					    method_name => 'add_viewer',
				       );
    }
}



=head2 remove_viewer

  $success = $obj->remove_viewer($ref, $viewer)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$viewer is a Username
$success is a Bool
Ref is a string
Username is a string
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$viewer is a Username
$success is a Bool
Ref is a string
Username is a string
Bool is an int


=end text

=item Description



=back

=cut

sub remove_viewer
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function remove_viewer (received $n, expecting 2)");
    }
    {
	my($ref, $viewer) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        (!ref($viewer)) or push(@_bad_arguments, "Invalid type for argument 2 \"viewer\" (value was \"$viewer\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to remove_viewer:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'remove_viewer');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.remove_viewer",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'remove_viewer',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method remove_viewer",
					    status_line => $self->{client}->status_line,
					    method_name => 'remove_viewer',
				       );
    }
}



=head2 set_public

  $success = $obj->set_public($ref, $public)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$public is a Bool
$success is a Bool
Ref is a string
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$public is a Bool
$success is a Bool
Ref is a string
Bool is an int


=end text

=item Description



=back

=cut

sub set_public
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_public (received $n, expecting 2)");
    }
    {
	my($ref, $public) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        (!ref($public)) or push(@_bad_arguments, "Invalid type for argument 2 \"public\" (value was \"$public\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_public:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_public');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.set_public",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'set_public',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_public",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_public',
				       );
    }
}



=head2 alias_owner

  $owner = $obj->alias_owner($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$owner is a Username
Ref is a string
Username is a string

</pre>

=end html

=begin text

$ref is a Ref
$owner is a Username
Ref is a string
Username is a string


=end text

=item Description



=back

=cut

sub alias_owner
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function alias_owner (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to alias_owner:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'alias_owner');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.alias_owner",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'alias_owner',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method alias_owner",
					    status_line => $self->{client}->status_line,
					    method_name => 'alias_owner',
				       );
    }
}



=head2 alias_public

  $public = $obj->alias_public($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$public is a Bool
Ref is a string
Bool is an int

</pre>

=end html

=begin text

$ref is a Ref
$public is a Bool
Ref is a string
Bool is an int


=end text

=item Description



=back

=cut

sub alias_public
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function alias_public (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to alias_public:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'alias_public');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.alias_public",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'alias_public',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method alias_public",
					    status_line => $self->{client}->status_line,
					    method_name => 'alias_public',
				       );
    }
}



=head2 alias_viewers

  $viewers = $obj->alias_viewers($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$viewers is a Usernames
Ref is a string
Usernames is a reference to a list where each element is a Username
Username is a string

</pre>

=end html

=begin text

$ref is a Ref
$viewers is a Usernames
Ref is a string
Usernames is a reference to a list where each element is a Username
Username is a string


=end text

=item Description



=back

=cut

sub alias_viewers
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function alias_viewers (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to alias_viewers:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'alias_viewers');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.alias_viewers",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'alias_viewers',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method alias_viewers",
					    status_line => $self->{client}->status_line,
					    method_name => 'alias_viewers',
				       );
    }
}



=head2 ancestors

  $ancestors = $obj->ancestors($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$ancestors is an UUIDs
Ref is a string
UUIDs is a reference to a list where each element is an UUID
UUID is a string

</pre>

=end html

=begin text

$ref is a Ref
$ancestors is an UUIDs
Ref is a string
UUIDs is a reference to a list where each element is an UUID
UUID is a string


=end text

=item Description



=back

=cut

sub ancestors
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function ancestors (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ancestors:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'ancestors');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.ancestors",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'ancestors',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method ancestors",
					    status_line => $self->{client}->status_line,
					    method_name => 'ancestors',
				       );
    }
}



=head2 ancestor_graph

  $graph = $obj->ancestor_graph($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$graph is an AncestorGraph
Ref is a string
AncestorGraph is a reference to a hash where the following keys are defined:
	object has a value which is an UUIDs
	objectParents has a value which is a reference to a list where each element is an UUIDs
UUIDs is a reference to a list where each element is an UUID
UUID is a string

</pre>

=end html

=begin text

$ref is a Ref
$graph is an AncestorGraph
Ref is a string
AncestorGraph is a reference to a hash where the following keys are defined:
	object has a value which is an UUIDs
	objectParents has a value which is a reference to a list where each element is an UUIDs
UUIDs is a reference to a list where each element is an UUID
UUID is a string


=end text

=item Description



=back

=cut

sub ancestor_graph
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function ancestor_graph (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ancestor_graph:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'ancestor_graph');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.ancestor_graph",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'ancestor_graph',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method ancestor_graph",
					    status_line => $self->{client}->status_line,
					    method_name => 'ancestor_graph',
				       );
    }
}



=head2 descendants

  $descendants = $obj->descendants($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$descendants is an UUIDs
Ref is a string
UUIDs is a reference to a list where each element is an UUID
UUID is a string

</pre>

=end html

=begin text

$ref is a Ref
$descendants is an UUIDs
Ref is a string
UUIDs is a reference to a list where each element is an UUID
UUID is a string


=end text

=item Description



=back

=cut

sub descendants
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function descendants (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to descendants:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'descendants');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.descendants",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'descendants',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method descendants",
					    status_line => $self->{client}->status_line,
					    method_name => 'descendants',
				       );
    }
}



=head2 descendant_graph

  $graph = $obj->descendant_graph($ref)

=over 4

=item Parameter and return types

=begin html

<pre>
$ref is a Ref
$graph is a DescendantGraph
Ref is a string
DescendantGraph is a reference to a hash where the following keys are defined:
	object has a value which is an UUIDs
	objectChildren has a value which is a reference to a list where each element is an UUIDs
UUIDs is a reference to a list where each element is an UUID
UUID is a string

</pre>

=end html

=begin text

$ref is a Ref
$graph is a DescendantGraph
Ref is a string
DescendantGraph is a reference to a hash where the following keys are defined:
	object has a value which is an UUIDs
	objectChildren has a value which is a reference to a list where each element is an UUIDs
UUIDs is a reference to a list where each element is an UUID
UUID is a string


=end text

=item Description



=back

=cut

sub descendant_graph
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function descendant_graph (received $n, expecting 1)");
    }
    {
	my($ref) = @args;

	my @_bad_arguments;
        (!ref($ref)) or push(@_bad_arguments, "Invalid type for argument 1 \"ref\" (value was \"$ref\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to descendant_graph:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'descendant_graph');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.descendant_graph",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'descendant_graph',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method descendant_graph",
					    status_line => $self->{client}->status_line,
					    method_name => 'descendant_graph',
				       );
    }
}



=head2 init_database

  $success = $obj->init_database()

=over 4

=item Parameter and return types

=begin html

<pre>
$success is a Bool
Bool is an int

</pre>

=end html

=begin text

$success is a Bool
Bool is an int


=end text

=item Description



=back

=cut

sub init_database
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 0)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function init_database (received $n, expecting 0)");
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.init_database",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'init_database',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method init_database",
					    status_line => $self->{client}->status_line,
					    method_name => 'init_database',
				       );
    }
}



=head2 delete_database

  $success = $obj->delete_database($config)

=over 4

=item Parameter and return types

=begin html

<pre>
$config is a DeleteConf
$success is a Bool
DeleteConf is a reference to a hash where the following keys are defined:
	keep_data has a value which is a Bool
Bool is an int

</pre>

=end html

=begin text

$config is a DeleteConf
$success is a Bool
DeleteConf is a reference to a hash where the following keys are defined:
	keep_data has a value which is a Bool
Bool is an int


=end text

=item Description



=back

=cut

sub delete_database
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function delete_database (received $n, expecting 1)");
    }
    {
	my($config) = @args;

	my @_bad_arguments;
        (ref($config) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"config\" (value was \"$config\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_database:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'delete_database');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelData.delete_database",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'delete_database',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method delete_database",
					    status_line => $self->{client}->status_line,
					    method_name => 'delete_database',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "fbaModelData.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'delete_database',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method delete_database",
            status_line => $self->{client}->status_line,
            method_name => 'delete_database',
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
        warn "New client version available for Bio::KBase::fbaModelData::Client\n";
    }
    if ($sMajor == 0) {
        warn "Bio::KBase::fbaModelData::Client version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 Bool

=over 4



=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 Ref

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



=head2 Username

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



=head2 UUID

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



=head2 Data

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



=head2 UUIDs

=over 4



=item Definition

=begin html

<pre>
a reference to a list where each element is an UUID
</pre>

=end html

=begin text

a reference to a list where each element is an UUID

=end text

=back



=head2 Usernames

=over 4



=item Definition

=begin html

<pre>
a reference to a list where each element is a Username
</pre>

=end html

=begin text

a reference to a list where each element is a Username

=end text

=back



=head2 Alias

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
uuid has a value which is an UUID
owner has a value which is a Username
type has a value which is a string
alias has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
uuid has a value which is an UUID
owner has a value which is a Username
type has a value which is a string
alias has a value which is a string


=end text

=back



=head2 Aliases

=over 4



=item Definition

=begin html

<pre>
a reference to a list where each element is an Alias
</pre>

=end html

=begin text

a reference to a list where each element is an Alias

=end text

=back



=head2 AncestorGraph

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
object has a value which is an UUIDs
objectParents has a value which is a reference to a list where each element is an UUIDs

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
object has a value which is an UUIDs
objectParents has a value which is a reference to a list where each element is an UUIDs


=end text

=back



=head2 DescendantGraph

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
object has a value which is an UUIDs
objectChildren has a value which is a reference to a list where each element is an UUIDs

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
object has a value which is an UUIDs
objectChildren has a value which is a reference to a list where each element is an UUIDs


=end text

=back



=head2 SaveConf

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
is_merge has a value which is a Bool
schema_update has a value which is a Bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
is_merge has a value which is a Bool
schema_update has a value which is a Bool


=end text

=back



=head2 DeleteConf

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
keep_data has a value which is a Bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
keep_data has a value which is a Bool


=end text

=back



=cut

package Bio::KBase::fbaModelData::Client::RpcClient;
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
