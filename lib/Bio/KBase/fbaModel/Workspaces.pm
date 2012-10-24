package Bio::KBase::fbaModel::Workspaces;

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

Bio::KBase::fbaModel::Workspaces

=head1 DESCRIPTION



=cut

sub new
{
    my($class, $url) = @_;

    my $self = {
	client => Bio::KBase::fbaModel::Workspaces::RpcClient->new,
	url => $url,
    };
    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 $result = save_object(id, type, data, workspace)

Object management routines

=cut

sub save_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 4)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function save_object (received $n, expecting 4)");
    }
    {
	my($id, $type, $data, $workspace) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 2 \"type\" (value was \"$type\")");
        (ref($data) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 3 \"data\" (value was \"$data\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 4 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to save_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'save_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.save_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'save_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method save_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'save_object',
				       );
    }
}



=head2 $result = delete_object(id, type, data, workspace)



=cut

sub delete_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 4)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function delete_object (received $n, expecting 4)");
    }
    {
	my($id, $type, $data, $workspace) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 2 \"type\" (value was \"$type\")");
        (ref($data) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 3 \"data\" (value was \"$data\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 4 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'delete_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.delete_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'delete_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method delete_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'delete_object',
				       );
    }
}



=head2 $result = get_object(id, type, workspace)



=cut

sub get_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 3)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_object (received $n, expecting 3)");
    }
    {
	my($id, $type, $workspace) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 2 \"type\" (value was \"$type\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 3 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.get_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_object',
				       );
    }
}



=head2 $result = revert_object(id, type, workspace)



=cut

sub revert_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 3)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function revert_object (received $n, expecting 3)");
    }
    {
	my($id, $type, $workspace) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 2 \"type\" (value was \"$type\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 3 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to revert_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'revert_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.revert_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'revert_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method revert_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'revert_object',
				       );
    }
}



=head2 $result = copy_object(new_id, new_workspace, source_id, type, source_workspace)



=cut

sub copy_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 5)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function copy_object (received $n, expecting 5)");
    }
    {
	my($new_id, $new_workspace, $source_id, $type, $source_workspace) = @args;

	my @_bad_arguments;
        (!ref($new_id)) or push(@_bad_arguments, "Invalid type for argument 1 \"new_id\" (value was \"$new_id\")");
        (!ref($new_workspace)) or push(@_bad_arguments, "Invalid type for argument 2 \"new_workspace\" (value was \"$new_workspace\")");
        (!ref($source_id)) or push(@_bad_arguments, "Invalid type for argument 3 \"source_id\" (value was \"$source_id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 4 \"type\" (value was \"$type\")");
        (!ref($source_workspace)) or push(@_bad_arguments, "Invalid type for argument 5 \"source_workspace\" (value was \"$source_workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to copy_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'copy_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.copy_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'copy_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method copy_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'copy_object',
				       );
    }
}



=head2 $result = move_object(new_id, new_workspace, source_id, type, source_workspace)



=cut

sub move_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 5)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function move_object (received $n, expecting 5)");
    }
    {
	my($new_id, $new_workspace, $source_id, $type, $source_workspace) = @args;

	my @_bad_arguments;
        (!ref($new_id)) or push(@_bad_arguments, "Invalid type for argument 1 \"new_id\" (value was \"$new_id\")");
        (!ref($new_workspace)) or push(@_bad_arguments, "Invalid type for argument 2 \"new_workspace\" (value was \"$new_workspace\")");
        (!ref($source_id)) or push(@_bad_arguments, "Invalid type for argument 3 \"source_id\" (value was \"$source_id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 4 \"type\" (value was \"$type\")");
        (!ref($source_workspace)) or push(@_bad_arguments, "Invalid type for argument 5 \"source_workspace\" (value was \"$source_workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to move_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'move_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.move_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'move_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method move_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'move_object',
				       );
    }
}



=head2 $result = has_object(id, type, workspace)



=cut

sub has_object
{
    my($self, @args) = @_;

    if ((my $n = @args) != 3)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function has_object (received $n, expecting 3)");
    }
    {
	my($id, $type, $workspace) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (!ref($type)) or push(@_bad_arguments, "Invalid type for argument 2 \"type\" (value was \"$type\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 3 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to has_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'has_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.has_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'has_object',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method has_object",
					    status_line => $self->{client}->status_line,
					    method_name => 'has_object',
				       );
    }
}



=head2 $result = create_workspace(name, default_permission)

Workspace management routines

=cut

sub create_workspace
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function create_workspace (received $n, expecting 2)");
    }
    {
	my($name, $default_permission) = @args;

	my @_bad_arguments;
        (!ref($name)) or push(@_bad_arguments, "Invalid type for argument 1 \"name\" (value was \"$name\")");
        (!ref($default_permission)) or push(@_bad_arguments, "Invalid type for argument 2 \"default_permission\" (value was \"$default_permission\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to create_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'create_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.create_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'create_workspace',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method create_workspace",
					    status_line => $self->{client}->status_line,
					    method_name => 'create_workspace',
				       );
    }
}



=head2 $result = clone_workspace(new_workspace, current_workspace, default_permission)



=cut

sub clone_workspace
{
    my($self, @args) = @_;

    if ((my $n = @args) != 3)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function clone_workspace (received $n, expecting 3)");
    }
    {
	my($new_workspace, $current_workspace, $default_permission) = @args;

	my @_bad_arguments;
        (!ref($new_workspace)) or push(@_bad_arguments, "Invalid type for argument 1 \"new_workspace\" (value was \"$new_workspace\")");
        (!ref($current_workspace)) or push(@_bad_arguments, "Invalid type for argument 2 \"current_workspace\" (value was \"$current_workspace\")");
        (!ref($default_permission)) or push(@_bad_arguments, "Invalid type for argument 3 \"default_permission\" (value was \"$default_permission\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to clone_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'clone_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.clone_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'clone_workspace',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method clone_workspace",
					    status_line => $self->{client}->status_line,
					    method_name => 'clone_workspace',
				       );
    }
}



=head2 $result = list_workspaces()



=cut

sub list_workspaces
{
    my($self, @args) = @_;

    if ((my $n = @args) != 0)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function list_workspaces (received $n, expecting 0)");
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.list_workspaces",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'list_workspaces',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method list_workspaces",
					    status_line => $self->{client}->status_line,
					    method_name => 'list_workspaces',
				       );
    }
}



=head2 $result = list_workspace_objects(workspace)



=cut

sub list_workspace_objects
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function list_workspace_objects (received $n, expecting 1)");
    }
    {
	my($workspace) = @args;

	my @_bad_arguments;
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 1 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_workspace_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'list_workspace_objects');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.list_workspace_objects",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'list_workspace_objects',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method list_workspace_objects",
					    status_line => $self->{client}->status_line,
					    method_name => 'list_workspace_objects',
				       );
    }
}



=head2 $result = set_global_workspace_permissions(new_permission, workspace)



=cut

sub set_global_workspace_permissions
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_global_workspace_permissions (received $n, expecting 2)");
    }
    {
	my($new_permission, $workspace) = @args;

	my @_bad_arguments;
        (!ref($new_permission)) or push(@_bad_arguments, "Invalid type for argument 1 \"new_permission\" (value was \"$new_permission\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 2 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_global_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_global_workspace_permissions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.set_global_workspace_permissions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'set_global_workspace_permissions',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_global_workspace_permissions",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_global_workspace_permissions',
				       );
    }
}



=head2 $result = set_workspace_permissions(users, new_permission, workspace)



=cut

sub set_workspace_permissions
{
    my($self, @args) = @_;

    if ((my $n = @args) != 3)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_workspace_permissions (received $n, expecting 3)");
    }
    {
	my($users, $new_permission, $workspace) = @args;

	my @_bad_arguments;
        (ref($users) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"users\" (value was \"$users\")");
        (!ref($new_permission)) or push(@_bad_arguments, "Invalid type for argument 2 \"new_permission\" (value was \"$new_permission\")");
        (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument 3 \"workspace\" (value was \"$workspace\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_workspace_permissions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceDocumentDB.set_workspace_permissions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'set_workspace_permissions',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_workspace_permissions",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_workspace_permissions',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "workspaceDocumentDB.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'set_workspace_permissions',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method set_workspace_permissions",
            status_line => $self->{client}->status_line,
            method_name => 'set_workspace_permissions',
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
        warn "New client version available for Bio::KBase::fbaModel::Workspaces\n";
    }
    if ($sMajor == 0) {
        warn "Bio::KBase::fbaModel::Workspaces version is $svr_version. API subject to change.\n";
    }
}

package Bio::KBase::fbaModel::Workspaces::RpcClient;
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

1;
