package Bio::KBase::workspaceService::Client;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
use Bio::KBase::AuthToken;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

Bio::KBase::workspaceService::Client

=head1 DESCRIPTION


=head1 workspaceService

=head2 SYNOPSIS

Workspaces are used in KBase to provide an online location for all data, models, and
analysis results. Workspaces are a powerful tool for managing private data, tracking 
workflow provenance, storing and sharing large datasets, and tracking work history. They
have a number of useful characteristics which you will learn about over the course of the
workspace tutorials:

1.) Multiple users can read and write from the same workspace at the same time, 
facilitating collaboration

2.) When an object is overwritten in a workspace, the previous version is preserved and
easily accessible at any time, enabling the use of workspaces to track object versions

3.) Workspaces have default permissions and user-specific permissions, providing total 
control over the sharing and access of workspace contents

=head2 EXAMPLE OF API USE IN PERL

To use the API, first you need to instantiate a workspace client object:

my $client = Bio::KBase::workspaceService::Client->new(user_id => "user", 
                password => "password");
   
Next, you can run API commands on the client object:
   
my $ws = $client->create_workspace({
        workspace => "foo",
        default_permission => "n"
});
my $objs = $client->list_workspace_objects({
        workspace => "foo"
});
print map { $_->[0] } @$objs;

=head2 AUTHENTICATION

There are several ways to provide authentication for using the workspace
service.
Firstly, one can provide a username and password as in the example above.
Secondly, one can obtain an authorization token via the C<AuthToken.pm> module
(see the documentation for that module) and provide it to the Client->new()
method with the keyword argument C<token>.
Finally, one can provide the token directly to a method via the C<auth>
parameter. If a token is provided directly to a method, this token takes
precedence over any previously provided authorization.
If no authorization is provided only unauthenticated read operations are
allowed.

=head2 WORKSPACE

A workspace is a named collection of objects owned by a specific
user, that may be viewable or editable by other users. Functions that operate
on workspaces take a C<workspace_id>, which is an alphanumeric string that
uniquely identifies a workspace among all workspaces.


=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => Bio::KBase::workspaceService::Client::RpcClient->new,
	url => $url,
    };

    #
    # This module requires authentication.
    #
    # We create an auth token, passing through the arguments that we were (hopefully) given.

    {
	my $token = Bio::KBase::AuthToken->new(@args);
	
	if (!$token->error_message)
	{
	    $self->{token} = $token->token;
	    $self->{client}->{token} = $token->token;
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 load_media_from_bio

  $mediaMetas = $obj->load_media_from_bio($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a load_media_from_bio_params
$mediaMetas is a reference to a list where each element is an object_metadata
load_media_from_bio_params is a reference to a hash where the following keys are defined:
	mediaWS has a value which is a workspace_id
	bioid has a value which is an object_id
	bioWS has a value which is a workspace_id
	clearExisting has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
object_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a load_media_from_bio_params
$mediaMetas is a reference to a list where each element is an object_metadata
load_media_from_bio_params is a reference to a hash where the following keys are defined:
	mediaWS has a value which is a workspace_id
	bioid has a value which is an object_id
	bioWS has a value which is a workspace_id
	clearExisting has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
object_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Creates "Media" objects in the workspace for all media contained in the specified biochemistry

=back

=cut

sub load_media_from_bio
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function load_media_from_bio (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to load_media_from_bio:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'load_media_from_bio');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.load_media_from_bio",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'load_media_from_bio',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method load_media_from_bio",
					    status_line => $self->{client}->status_line,
					    method_name => 'load_media_from_bio',
				       );
    }
}



=head2 import_bio

  $metadata = $obj->import_bio($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an import_bio_params
$metadata is an object_metadata
import_bio_params is a reference to a hash where the following keys are defined:
	bioid has a value which is an object_id
	bioWS has a value which is a workspace_id
	url has a value which is a string
	compressed has a value which is a bool
	clearExisting has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an import_bio_params
$metadata is an object_metadata
import_bio_params is a reference to a hash where the following keys are defined:
	bioid has a value which is an object_id
	bioWS has a value which is a workspace_id
	url has a value which is a string
	compressed has a value which is a bool
	clearExisting has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Imports a biochemistry from a URL

=back

=cut

sub import_bio
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_bio (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_bio:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_bio');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.import_bio",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_bio',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_bio",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_bio',
				       );
    }
}



=head2 import_map

  $metadata = $obj->import_map($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an import_map_params
$metadata is an object_metadata
import_map_params is a reference to a hash where the following keys are defined:
	bioid has a value which is an object_id
	bioWS has a value which is a workspace_id
	mapid has a value which is an object_id
	mapWS has a value which is a workspace_id
	url has a value which is a string
	compressed has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an import_map_params
$metadata is an object_metadata
import_map_params is a reference to a hash where the following keys are defined:
	bioid has a value which is an object_id
	bioWS has a value which is a workspace_id
	mapid has a value which is an object_id
	mapWS has a value which is a workspace_id
	url has a value which is a string
	compressed has a value which is a bool
	overwrite has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Imports a mapping from a URL

=back

=cut

sub import_map
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_map (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_map:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_map');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.import_map",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_map',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_map",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_map',
				       );
    }
}



=head2 save_object

  $metadata = $obj->save_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a save_object_params
$metadata is an object_metadata
save_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	data has a value which is an ObjectData
	workspace has a value which is a workspace_id
	command has a value which is a string
	metadata has a value which is a reference to a hash where the key is a string and the value is a string
	auth has a value which is a string
	json has a value which is a bool
	compressed has a value which is a bool
	retrieveFromURL has a value which is a bool
	asHash has a value which is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a save_object_params
$metadata is an object_metadata
save_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	data has a value which is an ObjectData
	workspace has a value which is a workspace_id
	command has a value which is a string
	metadata has a value which is a reference to a hash where the key is a string and the value is a string
	auth has a value which is a string
	json has a value which is a bool
	compressed has a value which is a bool
	retrieveFromURL has a value which is a bool
	asHash has a value which is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Saves the input object data and metadata into the selected workspace, returning the object_metadata of the saved object

=back

=cut

sub save_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function save_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to save_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'save_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.save_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'save_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 delete_object

  $metadata = $obj->delete_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a delete_object_params
$metadata is an object_metadata
delete_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a delete_object_params
$metadata is an object_metadata
delete_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Deletes the specified object from the specified workspace, returning the object_metadata of the deleted object.
Object is only temporarily deleted and can be recovered by using the revert command.

=back

=cut

sub delete_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function delete_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'delete_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.delete_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'delete_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 delete_object_permanently

  $metadata = $obj->delete_object_permanently($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a delete_object_permanently_params
$metadata is an object_metadata
delete_object_permanently_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a delete_object_permanently_params
$metadata is an object_metadata
delete_object_permanently_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Permanently deletes the specified object from the specified workspace.
This permanently deletes the object and object history, and the data cannot be recovered.
Objects cannot be permanently deleted unless they've been deleted first.

=back

=cut

sub delete_object_permanently
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function delete_object_permanently (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_object_permanently:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'delete_object_permanently');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.delete_object_permanently",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'delete_object_permanently',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method delete_object_permanently",
					    status_line => $self->{client}->status_line,
					    method_name => 'delete_object_permanently',
				       );
    }
}



=head2 get_object

  $output = $obj->get_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_object_params
$output is a get_object_output
get_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	instance has a value which is an int
	auth has a value which is a string
	asHash has a value which is a bool
	asJSON has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
get_object_output is a reference to a hash where the following keys are defined:
	data has a value which is a string
	metadata has a value which is an object_metadata
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a get_object_params
$output is a get_object_output
get_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	instance has a value which is an int
	auth has a value which is a string
	asHash has a value which is a bool
	asJSON has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
get_object_output is a reference to a hash where the following keys are defined:
	data has a value which is a string
	metadata has a value which is an object_metadata
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Retrieves the specified object from the specified workspace.
Both the object data and metadata are returned.
This commands provides access to all versions of the object via the instance parameter.

=back

=cut

sub get_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 get_objects

  $output = $obj->get_objects($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_objects_params
$output is a reference to a list where each element is a get_object_output
get_objects_params is a reference to a hash where the following keys are defined:
	ids has a value which is a reference to a list where each element is an object_id
	types has a value which is a reference to a list where each element is an object_type
	workspaces has a value which is a reference to a list where each element is a workspace_id
	instances has a value which is a reference to a list where each element is an int
	auth has a value which is a string
	asHash has a value which is a bool
	asJSON has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
get_object_output is a reference to a hash where the following keys are defined:
	data has a value which is a string
	metadata has a value which is an object_metadata
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a get_objects_params
$output is a reference to a list where each element is a get_object_output
get_objects_params is a reference to a hash where the following keys are defined:
	ids has a value which is a reference to a list where each element is an object_id
	types has a value which is a reference to a list where each element is an object_type
	workspaces has a value which is a reference to a list where each element is a workspace_id
	instances has a value which is a reference to a list where each element is an int
	auth has a value which is a string
	asHash has a value which is a bool
	asJSON has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
get_object_output is a reference to a hash where the following keys are defined:
	data has a value which is a string
	metadata has a value which is an object_metadata
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Retrieves the specified objects from the specified workspaces.
Both the object data and metadata are returned.
This commands provides access to all versions of the objects via the instances parameter.

=back

=cut

sub get_objects
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_objects (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_objects');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_objects",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_objects',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_objects",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_objects',
				       );
    }
}



=head2 get_object_by_ref

  $output = $obj->get_object_by_ref($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_object_by_ref_params
$output is a get_object_output
get_object_by_ref_params is a reference to a hash where the following keys are defined:
	reference has a value which is a workspace_ref
	auth has a value which is a string
	asHash has a value which is a bool
	asJSON has a value which is a bool
workspace_ref is a string
bool is an int
get_object_output is a reference to a hash where the following keys are defined:
	data has a value which is a string
	metadata has a value which is an object_metadata
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_id is a string

</pre>

=end html

=begin text

$params is a get_object_by_ref_params
$output is a get_object_output
get_object_by_ref_params is a reference to a hash where the following keys are defined:
	reference has a value which is a workspace_ref
	auth has a value which is a string
	asHash has a value which is a bool
	asJSON has a value which is a bool
workspace_ref is a string
bool is an int
get_object_output is a reference to a hash where the following keys are defined:
	data has a value which is a string
	metadata has a value which is an object_metadata
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_id is a string


=end text

=item Description

Retrieves the specified object from the specified workspace.
Both the object data and metadata are returned.
This commands provides access to all versions of the object via the instance parameter.

=back

=cut

sub get_object_by_ref
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_object_by_ref (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_object_by_ref:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_object_by_ref');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_object_by_ref",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_object_by_ref',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_object_by_ref",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_object_by_ref',
				       );
    }
}



=head2 save_object_by_ref

  $metadata = $obj->save_object_by_ref($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a save_object_by_ref_params
$metadata is an object_metadata
save_object_by_ref_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	data has a value which is an ObjectData
	command has a value which is a string
	metadata has a value which is a reference to a hash where the key is a string and the value is a string
	reference has a value which is a workspace_ref
	json has a value which is a bool
	compressed has a value which is a bool
	retrieveFromURL has a value which is a bool
	replace has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_ref is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_id is a string

</pre>

=end html

=begin text

$params is a save_object_by_ref_params
$metadata is an object_metadata
save_object_by_ref_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	data has a value which is an ObjectData
	command has a value which is a string
	metadata has a value which is a reference to a hash where the key is a string and the value is a string
	reference has a value which is a workspace_ref
	json has a value which is a bool
	compressed has a value which is a bool
	retrieveFromURL has a value which is a bool
	replace has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_ref is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_id is a string


=end text

=item Description

Retrieves the specified object from the specified workspace.
Both the object data and metadata are returned.
This commands provides access to all versions of the object via the instance parameter.

=back

=cut

sub save_object_by_ref
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function save_object_by_ref (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to save_object_by_ref:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'save_object_by_ref');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.save_object_by_ref",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'save_object_by_ref',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method save_object_by_ref",
					    status_line => $self->{client}->status_line,
					    method_name => 'save_object_by_ref',
				       );
    }
}



=head2 get_objectmeta

  $metadata = $obj->get_objectmeta($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_objectmeta_params
$metadata is an object_metadata
get_objectmeta_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	instance has a value which is an int
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a get_objectmeta_params
$metadata is an object_metadata
get_objectmeta_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	instance has a value which is an int
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Retrieves the metadata for a specified object from the specified workspace.
This commands provides access to metadata for all versions of the object via the instance parameter.

=back

=cut

sub get_objectmeta
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_objectmeta (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_objectmeta:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_objectmeta');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_objectmeta",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_objectmeta',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_objectmeta",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_objectmeta',
				       );
    }
}



=head2 get_objectmeta_by_ref

  $metadata = $obj->get_objectmeta_by_ref($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_objectmeta_by_ref_params
$metadata is an object_metadata
get_objectmeta_by_ref_params is a reference to a hash where the following keys are defined:
	reference has a value which is a workspace_ref
	auth has a value which is a string
	asHash has a value which is a bool
workspace_ref is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_id is a string

</pre>

=end html

=begin text

$params is a get_objectmeta_by_ref_params
$metadata is an object_metadata
get_objectmeta_by_ref_params is a reference to a hash where the following keys are defined:
	reference has a value which is a workspace_ref
	auth has a value which is a string
	asHash has a value which is a bool
workspace_ref is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_id is a string


=end text

=item Description

Retrieves the specified object from the specified workspace.
Both the object data and metadata are returned.
This commands provides access to all versions of the object via the instance parameter.

=back

=cut

sub get_objectmeta_by_ref
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_objectmeta_by_ref (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_objectmeta_by_ref:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_objectmeta_by_ref');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_objectmeta_by_ref",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_objectmeta_by_ref',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_objectmeta_by_ref",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_objectmeta_by_ref',
				       );
    }
}



=head2 revert_object

  $metadata = $obj->revert_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a revert_object_params
$metadata is an object_metadata
revert_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	instance has a value which is an int
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a revert_object_params
$metadata is an object_metadata
revert_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	instance has a value which is an int
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Reverts a specified object in a specifed workspace to a previous version of the object.
Returns the metadata of the newly reverted object.
This command still makes a new instance of the object, copying data related to the target instance to the new instance.
This ensures that the object instance always increases and no portion of the object history is ever lost.

=back

=cut

sub revert_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function revert_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to revert_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'revert_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.revert_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'revert_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 copy_object

  $metadata = $obj->copy_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a copy_object_params
$metadata is an object_metadata
copy_object_params is a reference to a hash where the following keys are defined:
	new_workspace_url has a value which is a string
	new_id has a value which is an object_id
	new_workspace has a value which is a workspace_id
	source_id has a value which is an object_id
	instance has a value which is an int
	type has a value which is an object_type
	source_workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a copy_object_params
$metadata is an object_metadata
copy_object_params is a reference to a hash where the following keys are defined:
	new_workspace_url has a value which is a string
	new_id has a value which is an object_id
	new_workspace has a value which is a workspace_id
	source_id has a value which is an object_id
	instance has a value which is an int
	type has a value which is an object_type
	source_workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Copies a specified object in a specifed workspace to a new ID and/or workspace.
Returns the metadata of the newly copied object.
It is possible to use the version parameter to copy any version of a workspace object.

=back

=cut

sub copy_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function copy_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to copy_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'copy_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.copy_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'copy_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 move_object

  $metadata = $obj->move_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a move_object_params
$metadata is an object_metadata
move_object_params is a reference to a hash where the following keys are defined:
	new_workspace_url has a value which is a string
	new_id has a value which is an object_id
	new_workspace has a value which is a workspace_id
	source_id has a value which is an object_id
	type has a value which is an object_type
	source_workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a move_object_params
$metadata is an object_metadata
move_object_params is a reference to a hash where the following keys are defined:
	new_workspace_url has a value which is a string
	new_id has a value which is an object_id
	new_workspace has a value which is a workspace_id
	source_id has a value which is an object_id
	type has a value which is an object_type
	source_workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Moves a specified object in a specifed workspace to a new ID and/or workspace.
Returns the metadata of the newly moved object.

=back

=cut

sub move_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function move_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to move_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'move_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.move_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'move_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 has_object

  $object_present = $obj->has_object($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a has_object_params
$object_present is a bool
has_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	instance has a value which is an int
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
object_id is a string
object_type is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$params is a has_object_params
$object_present is a bool
has_object_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	instance has a value which is an int
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
object_id is a string
object_type is a string
workspace_id is a string
bool is an int


=end text

=item Description

Checks if a specified object in a specifed workspace exists.
Returns "1" if the object exists, "0" if not

=back

=cut

sub has_object
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function has_object (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to has_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'has_object');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.has_object",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'has_object',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 object_history

  $metadatas = $obj->object_history($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an object_history_params
$metadatas is a reference to a list where each element is an object_metadata
object_history_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is an object_history_params
$metadatas is a reference to a list where each element is an object_metadata
object_history_params is a reference to a hash where the following keys are defined:
	id has a value which is an object_id
	type has a value which is an object_type
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Returns the metadata associated with every version of a specified object in a specified workspace.

=back

=cut

sub object_history
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function object_history (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to object_history:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'object_history');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.object_history",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'object_history',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method object_history",
					    status_line => $self->{client}->status_line,
					    method_name => 'object_history',
				       );
    }
}



=head2 create_workspace

  $metadata = $obj->create_workspace($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a create_workspace_params
$metadata is a workspace_metadata
create_workspace_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	default_permission has a value which is a permission
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
permission is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string

</pre>

=end html

=begin text

$params is a create_workspace_params
$metadata is a workspace_metadata
create_workspace_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	default_permission has a value which is a permission
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
permission is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string


=end text

=item Description

Creates a new workspace with the specified name and default permissions.

=back

=cut

sub create_workspace
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function create_workspace (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to create_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'create_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.create_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'create_workspace',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 get_workspacemeta

  $metadata = $obj->get_workspacemeta($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_workspacemeta_params
$metadata is a workspace_metadata
get_workspacemeta_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string
permission is a string

</pre>

=end html

=begin text

$params is a get_workspacemeta_params
$metadata is a workspace_metadata
get_workspacemeta_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string
permission is a string


=end text

=item Description

Retreives the metadata associated with the specified workspace.

=back

=cut

sub get_workspacemeta
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_workspacemeta (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_workspacemeta:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_workspacemeta');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_workspacemeta",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_workspacemeta',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_workspacemeta",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_workspacemeta',
				       );
    }
}



=head2 get_workspacepermissions

  $user_permissions = $obj->get_workspacepermissions($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_workspacepermissions_params
$user_permissions is a reference to a hash where the key is a username and the value is a permission
get_workspacepermissions_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	auth has a value which is a string
workspace_id is a string
username is a string
permission is a string

</pre>

=end html

=begin text

$params is a get_workspacepermissions_params
$user_permissions is a reference to a hash where the key is a username and the value is a permission
get_workspacepermissions_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	auth has a value which is a string
workspace_id is a string
username is a string
permission is a string


=end text

=item Description

Retreives a list of all users with custom permissions to the workspace if an admin, returns 
the user's own permissions otherwise.

=back

=cut

sub get_workspacepermissions
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_workspacepermissions (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_workspacepermissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_workspacepermissions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_workspacepermissions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_workspacepermissions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_workspacepermissions",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_workspacepermissions',
				       );
    }
}



=head2 delete_workspace

  $metadata = $obj->delete_workspace($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a delete_workspace_params
$metadata is a workspace_metadata
delete_workspace_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string
permission is a string

</pre>

=end html

=begin text

$params is a delete_workspace_params
$metadata is a workspace_metadata
delete_workspace_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string
permission is a string


=end text

=item Description

Deletes a specified workspace with all objects.

=back

=cut

sub delete_workspace
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function delete_workspace (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'delete_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.delete_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'delete_workspace',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method delete_workspace",
					    status_line => $self->{client}->status_line,
					    method_name => 'delete_workspace',
				       );
    }
}



=head2 clone_workspace

  $metadata = $obj->clone_workspace($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a clone_workspace_params
$metadata is a workspace_metadata
clone_workspace_params is a reference to a hash where the following keys are defined:
	new_workspace has a value which is a workspace_id
	new_workspace_url has a value which is a string
	current_workspace has a value which is a workspace_id
	default_permission has a value which is a permission
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
permission is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string

</pre>

=end html

=begin text

$params is a clone_workspace_params
$metadata is a workspace_metadata
clone_workspace_params is a reference to a hash where the following keys are defined:
	new_workspace has a value which is a workspace_id
	new_workspace_url has a value which is a string
	current_workspace has a value which is a workspace_id
	default_permission has a value which is a permission
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
permission is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string


=end text

=item Description

Copies a specified workspace with all objects.

=back

=cut

sub clone_workspace
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function clone_workspace (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to clone_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'clone_workspace');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.clone_workspace",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'clone_workspace',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 list_workspaces

  $workspaces = $obj->list_workspaces($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a list_workspaces_params
$workspaces is a reference to a list where each element is a workspace_metadata
list_workspaces_params is a reference to a hash where the following keys are defined:
	auth has a value which is a string
	asHash has a value which is a bool
	excludeGlobal has a value which is a bool
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
workspace_id is a string
username is a string
timestamp is a string
permission is a string

</pre>

=end html

=begin text

$params is a list_workspaces_params
$workspaces is a reference to a list where each element is a workspace_metadata
list_workspaces_params is a reference to a hash where the following keys are defined:
	auth has a value which is a string
	asHash has a value which is a bool
	excludeGlobal has a value which is a bool
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
workspace_id is a string
username is a string
timestamp is a string
permission is a string


=end text

=item Description

Lists the metadata of all workspaces a user has access to.

=back

=cut

sub list_workspaces
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function list_workspaces (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_workspaces:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'list_workspaces');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.list_workspaces",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'list_workspaces',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 list_workspace_objects

  $objects = $obj->list_workspace_objects($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a list_workspace_objects_params
$objects is a reference to a list where each element is an object_metadata
list_workspace_objects_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	type has a value which is a string
	showDeletedObject has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string

</pre>

=end html

=begin text

$params is a list_workspace_objects_params
$objects is a reference to a list where each element is an object_metadata
list_workspace_objects_params is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
	type has a value which is a string
	showDeletedObject has a value which is a bool
	auth has a value which is a string
	asHash has a value which is a bool
workspace_id is a string
bool is an int
object_metadata is a reference to a list containing 11 items:
	0: (id) an object_id
	1: (type) an object_type
	2: (moddate) a timestamp
	3: (instance) an int
	4: (command) a string
	5: (lastmodifier) a username
	6: (owner) a username
	7: (workspace) a workspace_id
	8: (ref) a workspace_ref
	9: (chsum) a string
	10: (metadata) a reference to a hash where the key is a string and the value is a string
object_id is a string
object_type is a string
timestamp is a string
username is a string
workspace_ref is a string


=end text

=item Description

Lists the metadata of all objects in the specified workspace with the specified type (or with any type).

=back

=cut

sub list_workspace_objects
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function list_workspace_objects (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_workspace_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'list_workspace_objects');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.list_workspace_objects",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'list_workspace_objects',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 set_global_workspace_permissions

  $metadata = $obj->set_global_workspace_permissions($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a set_global_workspace_permissions_params
$metadata is a workspace_metadata
set_global_workspace_permissions_params is a reference to a hash where the following keys are defined:
	new_permission has a value which is a permission
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
permission is a string
workspace_id is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string

</pre>

=end html

=begin text

$params is a set_global_workspace_permissions_params
$metadata is a workspace_metadata
set_global_workspace_permissions_params is a reference to a hash where the following keys are defined:
	new_permission has a value which is a permission
	workspace has a value which is a workspace_id
	auth has a value which is a string
	asHash has a value which is a bool
permission is a string
workspace_id is a string
bool is an int
workspace_metadata is a reference to a list containing 6 items:
	0: (id) a workspace_id
	1: (owner) a username
	2: (moddate) a timestamp
	3: (objects) an int
	4: (user_permission) a permission
	5: (global_permission) a permission
username is a string
timestamp is a string


=end text

=item Description

Sets the default permissions for accessing a specified workspace for all users.
Must have admin privelages to change workspace global permissions.

=back

=cut

sub set_global_workspace_permissions
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_global_workspace_permissions (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_global_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_global_workspace_permissions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.set_global_workspace_permissions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_global_workspace_permissions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 set_workspace_permissions

  $success = $obj->set_workspace_permissions($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a set_workspace_permissions_params
$success is a bool
set_workspace_permissions_params is a reference to a hash where the following keys are defined:
	users has a value which is a reference to a list where each element is a username
	new_permission has a value which is a permission
	workspace has a value which is a workspace_id
	auth has a value which is a string
username is a string
permission is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$params is a set_workspace_permissions_params
$success is a bool
set_workspace_permissions_params is a reference to a hash where the following keys are defined:
	users has a value which is a reference to a list where each element is a username
	new_permission has a value which is a permission
	workspace has a value which is a workspace_id
	auth has a value which is a string
username is a string
permission is a string
workspace_id is a string
bool is an int


=end text

=item Description

Sets the permissions for a list of users for accessing a specified workspace.
Must have admin privelages to change workspace permissions. Note that only the workspace owner can change the owner's permissions;
any other user's attempt to do will silently fail.

=back

=cut

sub set_workspace_permissions
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_workspace_permissions (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_workspace_permissions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.set_workspace_permissions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_workspace_permissions',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
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



=head2 get_user_settings

  $output = $obj->get_user_settings($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_user_settings_params
$output is a user_settings
get_user_settings_params is a reference to a hash where the following keys are defined:
	auth has a value which is a string
user_settings is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
workspace_id is a string

</pre>

=end html

=begin text

$params is a get_user_settings_params
$output is a user_settings
get_user_settings_params is a reference to a hash where the following keys are defined:
	auth has a value which is a string
user_settings is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
workspace_id is a string


=end text

=item Description

Retrieves settings for user account, including currently selected workspace

=back

=cut

sub get_user_settings
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_user_settings (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_user_settings:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_user_settings');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_user_settings",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_user_settings',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_user_settings",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_user_settings',
				       );
    }
}



=head2 set_user_settings

  $output = $obj->set_user_settings($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a set_user_settings_params
$output is a user_settings
set_user_settings_params is a reference to a hash where the following keys are defined:
	setting has a value which is a string
	value has a value which is a string
	auth has a value which is a string
user_settings is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
workspace_id is a string

</pre>

=end html

=begin text

$params is a set_user_settings_params
$output is a user_settings
set_user_settings_params is a reference to a hash where the following keys are defined:
	setting has a value which is a string
	value has a value which is a string
	auth has a value which is a string
user_settings is a reference to a hash where the following keys are defined:
	workspace has a value which is a workspace_id
workspace_id is a string


=end text

=item Description

Retrieves settings for user account, including currently selected workspace

=back

=cut

sub set_user_settings
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_user_settings (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_user_settings:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_user_settings');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.set_user_settings",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_user_settings',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_user_settings",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_user_settings',
				       );
    }
}



=head2 queue_job

  $job = $obj->queue_job($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a queue_job_params
$job is a JobObject
queue_job_params is a reference to a hash where the following keys are defined:
	auth has a value which is a string
	state has a value which is a string
	type has a value which is a string
	queuecommand has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$params is a queue_job_params
$job is a JobObject
queue_job_params is a reference to a hash where the following keys are defined:
	auth has a value which is a string
	state has a value which is a string
	type has a value which is a string
	queuecommand has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Queues a new job in the workspace.

=back

=cut

sub queue_job
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function queue_job (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to queue_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'queue_job');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.queue_job",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'queue_job',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method queue_job",
					    status_line => $self->{client}->status_line,
					    method_name => 'queue_job',
				       );
    }
}



=head2 set_job_status

  $job = $obj->set_job_status($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a set_job_status_params
$job is a JobObject
set_job_status_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a string
	status has a value which is a string
	auth has a value which is a string
	currentStatus has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$params is a set_job_status_params
$job is a JobObject
set_job_status_params is a reference to a hash where the following keys are defined:
	jobid has a value which is a string
	status has a value which is a string
	auth has a value which is a string
	currentStatus has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description

Changes the current status of a currently queued jobs 
Used to manage jobs by ensuring multiple server don't claim the same job.

=back

=cut

sub set_job_status
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_job_status (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_job_status:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_job_status');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.set_job_status",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_job_status',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_job_status",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_job_status',
				       );
    }
}



=head2 get_jobs

  $jobs = $obj->get_jobs($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a get_jobs_params
$jobs is a reference to a list where each element is a JobObject
get_jobs_params is a reference to a hash where the following keys are defined:
	jobids has a value which is a reference to a list where each element is a string
	type has a value which is a string
	status has a value which is a string
	auth has a value which is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string

</pre>

=end html

=begin text

$params is a get_jobs_params
$jobs is a reference to a list where each element is a JobObject
get_jobs_params is a reference to a hash where the following keys are defined:
	jobids has a value which is a reference to a list where each element is a string
	type has a value which is a string
	status has a value which is a string
	auth has a value which is a string
JobObject is a reference to a hash where the following keys are defined:
	id has a value which is a job_id
	type has a value which is a string
	auth has a value which is a string
	status has a value which is a string
	jobdata has a value which is a reference to a hash where the key is a string and the value is a string
	queuetime has a value which is a string
	starttime has a value which is a string
	completetime has a value which is a string
	owner has a value which is a string
	queuecommand has a value which is a string
job_id is a string


=end text

=item Description



=back

=cut

sub get_jobs
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_jobs (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_jobs:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_jobs');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_jobs",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_jobs',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_jobs",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_jobs',
				       );
    }
}



=head2 get_types

  $types = $obj->get_types()

=over 4

=item Parameter and return types

=begin html

<pre>
$types is a reference to a list where each element is a string

</pre>

=end html

=begin text

$types is a reference to a list where each element is a string


=end text

=item Description

Returns a list of all permanent and optional types currently accepted by the workspace service.
An object cannot be saved in any workspace if it's type is not on this list.

=back

=cut

sub get_types
{
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 0)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_types (received $n, expecting 0)");
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.get_types",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'get_types',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_types",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_types',
				       );
    }
}



=head2 add_type

  $success = $obj->add_type($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is an add_type_params
$success is a bool
add_type_params is a reference to a hash where the following keys are defined:
	type has a value which is a string
	auth has a value which is a string
bool is an int

</pre>

=end html

=begin text

$params is an add_type_params
$success is a bool
add_type_params is a reference to a hash where the following keys are defined:
	type has a value which is a string
	auth has a value which is a string
bool is an int


=end text

=item Description

Adds a new custom type to the workspace service, so that objects of this type may be retreived.
Cannot add a type that already exists.

=back

=cut

sub add_type
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function add_type (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to add_type:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'add_type');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.add_type",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'add_type',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method add_type",
					    status_line => $self->{client}->status_line,
					    method_name => 'add_type',
				       );
    }
}



=head2 remove_type

  $success = $obj->remove_type($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a remove_type_params
$success is a bool
remove_type_params is a reference to a hash where the following keys are defined:
	type has a value which is a string
	auth has a value which is a string
bool is an int

</pre>

=end html

=begin text

$params is a remove_type_params
$success is a bool
remove_type_params is a reference to a hash where the following keys are defined:
	type has a value which is a string
	auth has a value which is a string
bool is an int


=end text

=item Description

Removes a custom type from the workspace service.
Permanent types cannot be removed.

=back

=cut

sub remove_type
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function remove_type (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to remove_type:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'remove_type');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.remove_type",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'remove_type',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method remove_type",
					    status_line => $self->{client}->status_line,
					    method_name => 'remove_type',
				       );
    }
}



=head2 patch

  $success = $obj->patch($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a patch_params
$success is a bool
patch_params is a reference to a hash where the following keys are defined:
	patch_id has a value which is a string
	auth has a value which is a string
bool is an int

</pre>

=end html

=begin text

$params is a patch_params
$success is a bool
patch_params is a reference to a hash where the following keys are defined:
	patch_id has a value which is a string
	auth has a value which is a string
bool is an int


=end text

=item Description

This function patches the database after an update. Called remotely, but only callable by the admin user.

=back

=cut

sub patch
{
    my($self, @args) = @_;

# Authentication: optional

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function patch (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to patch:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'patch');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "workspaceService.patch",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'patch',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method patch",
					    status_line => $self->{client}->status_line,
					    method_name => 'patch',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "workspaceService.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'patch',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method patch",
            status_line => $self->{client}->status_line,
            method_name => 'patch',
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
        warn "New client version available for Bio::KBase::workspaceService::Client\n";
    }
    if ($sMajor == 0) {
        warn "Bio::KBase::workspaceService::Client version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 bool

=over 4



=item Description

indicates true or false values, false <= 0, true >=1


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



=head2 job_id

=over 4



=item Description

ID of a job object


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



=head2 workspace_id

=over 4



=item Description

A string used as an ID for a workspace. Any string consisting of alphanumeric characters and "_" is acceptable


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



=head2 object_type

=over 4



=item Description

A string indicating the "type" of an object stored in a workspace. Acceptable types are returned by the "get_types()" command


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



=head2 object_id

=over 4



=item Description

ID of an object stored in the workspace. Any string consisting of alphanumeric characters and "-" is acceptable


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



=head2 permission

=over 4



=item Description

Single letter indicating permissions on access to workspace. Options are: 'a' for administative access, 'w' for read/write access, 'r' for read access, and 'n' for no access. For default permissions (e.g. permissions for any user) only 'n' and 'r' are allowed.


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



=head2 username

=over 4



=item Description

Login name of KBase useraccount to which permissions for workspaces are mapped


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



=head2 timestamp

=over 4



=item Description

Exact time for workspace operations. e.g. 2012-12-17T23:24:06


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



=head2 workspace_ref

=over 4



=item Description

A 36 character string referring to a particular instance of an object in a workspace that lasts forever. Objects should always be retreivable using this ID


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



=head2 ObjectData

=over 4



=item Description

Generic definition for object data stored in the workspace
Data objects stored in the workspace could be either a string or a reference to a complex perl data structure. So we can't really formulate a strict type definition for this data.

version - for complex data structures, the datastructure should include a version number to enable tracking of changes that may occur to the structure of the data over time


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
version has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
version has a value which is an int


=end text

=back



=head2 object_metadata

=over 4



=item Description

Meta data associated with an object stored in a workspace.

        object_id id - ID of the object assigned by the user or retreived from the IDserver (e.g. kb|g.0)
        object_type type - type of the object (e.g. Genome)
        timestamp moddate - date when the object was modified by the user (e.g. 2012-12-17T23:24:06)
        int instance - instance of the object, which is equal to the number of times the user has overwritten the object
        string command - name of the command last used to modify or create the object
        username lastmodifier - name of the user who last modified the object
        username owner - name of the user who owns (who created) this object
        workspace_id workspace - ID of the workspace in which the object is currently stored
        workspace_ref ref - a 36 character ID that provides permanent undeniable access to this specific instance of this object
        string chsum - checksum of the associated data object
        mapping<string,string> metadata - custom metadata entered for data object during save operation


=item Definition

=begin html

<pre>
a reference to a list containing 11 items:
0: (id) an object_id
1: (type) an object_type
2: (moddate) a timestamp
3: (instance) an int
4: (command) a string
5: (lastmodifier) a username
6: (owner) a username
7: (workspace) a workspace_id
8: (ref) a workspace_ref
9: (chsum) a string
10: (metadata) a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a list containing 11 items:
0: (id) an object_id
1: (type) an object_type
2: (moddate) a timestamp
3: (instance) an int
4: (command) a string
5: (lastmodifier) a username
6: (owner) a username
7: (workspace) a workspace_id
8: (ref) a workspace_ref
9: (chsum) a string
10: (metadata) a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 workspace_metadata

=over 4



=item Description

Meta data associated with a workspace.

        workspace_id id - ID of the object assigned by the user or retreived from the IDserver (e.g. kb|g.0)
        username owner - name of the user who owns (who created) this object
        timestamp moddate - date when the workspace was last modified
        int objects - number of objects currently stored in the workspace
        permission user_permission - permissions for the currently logged user for the workspace
        permission global_permission - default permissions for the workspace for all KBase users


=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: (id) a workspace_id
1: (owner) a username
2: (moddate) a timestamp
3: (objects) an int
4: (user_permission) a permission
5: (global_permission) a permission

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: (id) a workspace_id
1: (owner) a username
2: (moddate) a timestamp
3: (objects) an int
4: (user_permission) a permission
5: (global_permission) a permission


=end text

=back



=head2 JobObject

=over 4



=item Description

Data structures for a job object

job_id id - ID of the job object
string type - type of the job
string auth - authentication token of job owner
string status - current status of job
mapping<string,string> jobdata;
string queuetime - time when job was queued
string starttime - time when job started running
string completetime - time when the job was completed
string owner - owner of the job
string queuecommand - command used to queue job


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a job_id
type has a value which is a string
auth has a value which is a string
status has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string
queuetime has a value which is a string
starttime has a value which is a string
completetime has a value which is a string
owner has a value which is a string
queuecommand has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a job_id
type has a value which is a string
auth has a value which is a string
status has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string
queuetime has a value which is a string
starttime has a value which is a string
completetime has a value which is a string
owner has a value which is a string
queuecommand has a value which is a string


=end text

=back



=head2 user_settings

=over 4



=item Description

Settings for user accounts stored in the workspace

        workspace_id workspace - the workspace currently selected by the user


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id


=end text

=back



=head2 load_media_from_bio_params

=over 4



=item Description

Input parameters for the "load_media_from_bio" function.

        workspace_id mediaWS - ID of workspace where media will be loaded (an optional argument with default "KBaseMedia")
        object_id bioid - ID of biochemistry from which media will be loaded (an optional argument with default "default")
        workspace_id bioWS - ID of workspace with biochemistry from which media will be loaded (an optional argument with default "kbase")
        bool clearExisting - A boolean indicating if existing media in the specified workspace should be cleared (an optional argument with default "0")
        bool overwrite - A boolean indicating if a matching existing media should be overwritten (an optional argument with default "0")


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
mediaWS has a value which is a workspace_id
bioid has a value which is an object_id
bioWS has a value which is a workspace_id
clearExisting has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
mediaWS has a value which is a workspace_id
bioid has a value which is an object_id
bioWS has a value which is a workspace_id
clearExisting has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 import_bio_params

=over 4



=item Description

Input parameters for the "import_bio" function.

        object_id bioid - ID of biochemistry to be imported (an optional argument with default "default")
        workspace_id bioWS - ID of workspace to which biochemistry will be imported (an optional argument with default "kbase")
        string url - URL from which biochemistry should be retrieved
        bool compressed - boolean indicating if biochemistry is compressed
        bool overwrite - A boolean indicating if a matching existing biochemistry should be overwritten (an optional argument with default "0")


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
bioid has a value which is an object_id
bioWS has a value which is a workspace_id
url has a value which is a string
compressed has a value which is a bool
clearExisting has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
bioid has a value which is an object_id
bioWS has a value which is a workspace_id
url has a value which is a string
compressed has a value which is a bool
clearExisting has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 import_map_params

=over 4



=item Description

Input parameters for the "import_map" function.

        object_id mapid - ID of mapping to be imported (an optional argument with default "default")
        workspace_id mapWS - ID of workspace to which mapping will be imported (an optional argument with default "kbase")
        string url - URL from which mapping should be retrieved
        bool compressed - boolean indicating if mapping is compressed
        bool overwrite - A boolean indicating if a matching existing mapping should be overwritten (an optional argument with default "0")


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
bioid has a value which is an object_id
bioWS has a value which is a workspace_id
mapid has a value which is an object_id
mapWS has a value which is a workspace_id
url has a value which is a string
compressed has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
bioid has a value which is an object_id
bioWS has a value which is a workspace_id
mapid has a value which is an object_id
mapWS has a value which is a workspace_id
url has a value which is a string
compressed has a value which is a bool
overwrite has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 save_object_params

=over 4



=item Description

Input parameters for the "save_objects function.

        object_type type - type of the object to be saved (an essential argument)
        workspace_id workspace - ID of the workspace where the object is to be saved (an essential argument)
        object_id id - ID behind which the object will be saved in the workspace (an essential argument)
        ObjectData data - string or reference to complex datastructure to be saved in the workspace (an essential argument)
        string command - the name of the KBase command that is calling the "save_object" function (an optional argument with default "unknown")
        mapping<string,string> metadata - a hash of metadata to be associated with the object (an optional argument with default "{}")
        string auth - the authentication token of the KBase account to associate this save command
        bool retrieveFromURL - a flag indicating that the "data" argument contains a URL from which the actual data should be downloaded (an optional argument with default "0")
        bool json - a flag indicating if the input data is encoded as a JSON string (an optional argument with default "0")
        bool compressed - a flag indicating if the input data in zipped (an optional argument with default "0")
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
data has a value which is an ObjectData
workspace has a value which is a workspace_id
command has a value which is a string
metadata has a value which is a reference to a hash where the key is a string and the value is a string
auth has a value which is a string
json has a value which is a bool
compressed has a value which is a bool
retrieveFromURL has a value which is a bool
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
data has a value which is an ObjectData
workspace has a value which is a workspace_id
command has a value which is a string
metadata has a value which is a reference to a hash where the key is a string and the value is a string
auth has a value which is a string
json has a value which is a bool
compressed has a value which is a bool
retrieveFromURL has a value which is a bool
asHash has a value which is a bool


=end text

=back



=head2 delete_object_params

=over 4



=item Description

Input parameters for the "delete_object" function.

        object_type type - type of the object to be deleted (an essential argument)
        workspace_id workspace - ID of the workspace where the object is to be deleted (an essential argument)
        object_id id - ID of the object to be deleted (an essential argument)
        string auth - the authentication token of the KBase account to associate this deletion command
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 delete_object_permanently_params

=over 4



=item Description

Input parameters for the "delete_object_permanently" function.

        object_type type - type of the object to be permanently deleted (an essential argument)
        workspace_id workspace - ID of the workspace where the object is to be permanently deleted (an essential argument)
        object_id id - ID of the object to be permanently deleted (an essential argument)
        string auth - the authentication token of the KBase account to associate with this permanent deletion command
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 get_object_params

=over 4



=item Description

Input parameters for the "get_object" function.

        object_type type - type of the object to be retrieved (an essential argument)
        workspace_id workspace - ID of the workspace containing the object to be retrieved (an essential argument)
        object_id id - ID of the object to be retrieved (an essential argument)
        int instance - Version of the object to be retrieved, enabling retrieval of any previous version of an object (an optional argument; the current version is retrieved if no version is provides)
        string auth - the authentication token of the KBase account to associate with this object retrieval command (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash
        bool asJSON - indicates that data should be returned in JSON format (an optional argument; default is '0')


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
instance has a value which is an int
auth has a value which is a string
asHash has a value which is a bool
asJSON has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
instance has a value which is an int
auth has a value which is a string
asHash has a value which is a bool
asJSON has a value which is a bool


=end text

=back



=head2 get_object_output

=over 4



=item Description

Output generated by the "get_object" function.

        string data - data for object retrieved in json format (an essential argument)
        object_metadata metadata - metadata for object retrieved (an essential argument)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
data has a value which is a string
metadata has a value which is an object_metadata

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
data has a value which is a string
metadata has a value which is an object_metadata


=end text

=back



=head2 get_objects_params

=over 4



=item Description

Input parameters for the "get_object" function.

        list<object_id> ids - ID of the object to be retrieved (an essential argument)
        list<object_type> types - type of the object to be retrieved (an essential argument)
        list<workspace_id> workspaces - ID of the workspace containing the object to be retrieved (an essential argument)
        list<int> instances  - Version of the object to be retrieved, enabling retrieval of any previous version of an object (an optional argument; the current version is retrieved if no version is provides)
        string auth - the authentication token of the KBase account to associate with this object retrieval command (an optional argument; user is "public" if auth is not provided)
        bool asHash - a boolean indicating if metadata should be returned as a hash
        bool asJSON - indicates that data should be returned in JSON format (an optional argument; default is '0')


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ids has a value which is a reference to a list where each element is an object_id
types has a value which is a reference to a list where each element is an object_type
workspaces has a value which is a reference to a list where each element is a workspace_id
instances has a value which is a reference to a list where each element is an int
auth has a value which is a string
asHash has a value which is a bool
asJSON has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ids has a value which is a reference to a list where each element is an object_id
types has a value which is a reference to a list where each element is an object_type
workspaces has a value which is a reference to a list where each element is a workspace_id
instances has a value which is a reference to a list where each element is an int
auth has a value which is a string
asHash has a value which is a bool
asJSON has a value which is a bool


=end text

=back



=head2 get_object_by_ref_params

=over 4



=item Description

Input parameters for the "get_object_by_ref" function.

        workspace_ref reference - reference to a specific instance of a specific object in a workspace (an essential argument)
        string auth - the authentication token of the KBase account to associate with this object retrieval command (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash
        bool asJSON - indicates that data should be returned in JSON format (an optional argument; default is '0')


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
auth has a value which is a string
asHash has a value which is a bool
asJSON has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
auth has a value which is a string
asHash has a value which is a bool
asJSON has a value which is a bool


=end text

=back



=head2 save_object_by_ref_params

=over 4



=item Description

Input parameters for the "save_object_by_ref" function.

        object_id id - ID to which the model should be saved (an essential argument)
        object_type type - type of the object for which metadata is to be retrieved (an essential argument)
        ObjectData data - string or reference to complex datastructure to be saved in the workspace (an essential argument)
        string command - the name of the KBase command that is calling the "save_object" function (an optional argument with default "unknown")
        mapping<string,string> metadata - a hash of metadata to be associated with the object (an optional argument with default "{}")
        workspace_ref reference - reference the object should be saved in
        bool json - a flag indicating if the input data is encoded as a JSON string (an optional argument with default "0")
        bool compressed - a flag indicating if the input data in zipped (an optional argument with default "0")
        bool retrieveFromURL - a flag indicating that the "data" argument contains a URL from which the actual data should be downloaded (an optional argument with default "0")
        bool replace - a flag indicating any existing object located at the specified reference should be overwritten (an optional argument with default "0")
        string auth - the authentication token of the KBase account to associate this save command
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
data has a value which is an ObjectData
command has a value which is a string
metadata has a value which is a reference to a hash where the key is a string and the value is a string
reference has a value which is a workspace_ref
json has a value which is a bool
compressed has a value which is a bool
retrieveFromURL has a value which is a bool
replace has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
data has a value which is an ObjectData
command has a value which is a string
metadata has a value which is a reference to a hash where the key is a string and the value is a string
reference has a value which is a workspace_ref
json has a value which is a bool
compressed has a value which is a bool
retrieveFromURL has a value which is a bool
replace has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 get_objectmeta_params

=over 4



=item Description

Input parameters for the "get_objectmeta" function.

        object_type type - type of the object for which metadata is to be retrieved (an essential argument)
        workspace_id workspace - ID of the workspace containing the object for which metadata is to be retrieved (an essential argument)
        object_id id - ID of the object for which metadata is to be retrieved (an essential argument)
        int instance - Version of the object for which metadata is to be retrieved, enabling retrieval of any previous version of an object (an optional argument; the current metadata is retrieved if no version is provides)
        string auth - the authentication token of the KBase account to associate with this object metadata retrieval command (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
instance has a value which is an int
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
instance has a value which is an int
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 get_objectmeta_by_ref_params

=over 4



=item Description

Input parameters for the "get_objectmeta_by_ref" function.

        workspace_ref reference - reference to a specific instance of a specific object in a workspace (an essential argument)
        string auth - the authentication token of the KBase account to associate with this object retrieval command (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reference has a value which is a workspace_ref
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 revert_object_params

=over 4



=item Description

Input parameters for the "revert_object" function.

        object_type type - type of the object to be reverted (an essential argument)
        workspace_id workspace - ID of the workspace containing the object to be reverted (an essential argument)
        object_id id - ID of the object to be reverted (an essential argument)
        int instance - Previous version of the object to which the object should be reset (an essential argument)
        string auth - the authentication token of the KBase account to associate with this object reversion command
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
instance has a value which is an int
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
instance has a value which is an int
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 copy_object_params

=over 4



=item Description

Input parameters for the "copy_object" function.

        object_type type - type of the object to be copied (an essential argument)
        workspace_id source_workspace - ID of the workspace containing the object to be copied (an essential argument)
        object_id source_id - ID of the object to be copied (an essential argument)
        int instance - Version of the object to be copied, enabling retrieval of any previous version of an object (an optional argument; the current object is copied if no version is provides)
        workspace_id new_workspace - ID of the workspace the object to be copied to (an essential argument)
        object_id new_id - ID the object is to be copied to (an essential argument)
        string new_workspace_url - URL of workspace server where object should be copied (an optional argument - object will be saved in the same server if not provided)
        string auth - the authentication token of the KBase account to associate with this object copy command (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_workspace_url has a value which is a string
new_id has a value which is an object_id
new_workspace has a value which is a workspace_id
source_id has a value which is an object_id
instance has a value which is an int
type has a value which is an object_type
source_workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_workspace_url has a value which is a string
new_id has a value which is an object_id
new_workspace has a value which is a workspace_id
source_id has a value which is an object_id
instance has a value which is an int
type has a value which is an object_type
source_workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 move_object_params

=over 4



=item Description

Input parameters for the "move_object" function.

        object_type type - type of the object to be moved (an essential argument)
        workspace_id source_workspace - ID of the workspace containing the object to be moved (an essential argument)
        object_id source_id - ID of the object to be moved (an essential argument)
         workspace_id new_workspace - ID of the workspace the object to be moved to (an essential argument)
        object_id new_id - ID the object is to be moved to (an essential argument)
        string new_workspace_url - URL of workspace server where object should be copied (an optional argument - object will be saved in the same server if not provided)
        string auth - the authentication token of the KBase account to associate with this object move command
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_workspace_url has a value which is a string
new_id has a value which is an object_id
new_workspace has a value which is a workspace_id
source_id has a value which is an object_id
type has a value which is an object_type
source_workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_workspace_url has a value which is a string
new_id has a value which is an object_id
new_workspace has a value which is a workspace_id
source_id has a value which is an object_id
type has a value which is an object_type
source_workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 has_object_params

=over 4



=item Description

Input parameters for the "has_object" function.

        object_type type - type of the object to be checked for existance (an essential argument)
        workspace_id workspace - ID of the workspace containing the object to be checked for existance (an essential argument)
        object_id id - ID of the object to be checked for existance (an essential argument)
        int instance - Version of the object to be checked for existance (an optional argument; the current object is checked if no version is provided)
        string auth - the authentication token of the KBase account to associate with this object check command (an optional argument)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
instance has a value which is an int
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
instance has a value which is an int
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 object_history_params

=over 4



=item Description

Input parameters for the "object_history" function.

        object_type type - type of the object to have history printed (an essential argument)
        workspace_id workspace - ID of the workspace containing the object to have history printed (an essential argument)
        object_id id - ID of the object to have history printed (an essential argument)
        string auth - the authentication token of the KBase account to associate with this object history command (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an object_id
type has a value which is an object_type
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 create_workspace_params

=over 4



=item Description

Input parameters for the "create_workspace" function.

        workspace_id workspace - ID of the workspace to be created (an essential argument)
        permission default_permission - Default permissions of the workspace to be created. Accepted values are 'a' => admin, 'w' => write, 'r' => read, 'n' => none (optional argument with default "n")
        string auth - the authentication token of the KBase account that will own the created workspace
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
default_permission has a value which is a permission
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
default_permission has a value which is a permission
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 get_workspacemeta_params

=over 4



=item Description

Input parameters for the "get_workspacemeta" function.

        workspace_id workspace - ID of the workspace for which metadata should be returned (an essential argument)
        string auth - the authentication token of the KBase account accessing workspace metadata (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 get_workspacepermissions_params

=over 4



=item Description

Input parameters for the "get_workspacepermissions" function.

        workspace_id workspace - ID of the workspace for which custom user permissions should be returned (an essential argument)
        string auth - the authentication token of the KBase account accessing workspace permissions (an optional argument)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 delete_workspace_params

=over 4



=item Description

Input parameters for the "delete_workspace" function.

        workspace_id workspace - ID of the workspace to be deleted (an essential argument)
        string auth - the authentication token of the KBase account deleting the workspace; must be the workspace owner
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 clone_workspace_params

=over 4



=item Description

Input parameters for the "clone_workspace" function.

        workspace_id current_workspace - ID of the workspace to be cloned (an essential argument)
        workspace_id new_workspace - ID of the workspace to which the cloned workspace will be copied (an essential argument)
        string new_workspace_url - URL of workspace server where workspace should be cloned (an optional argument - workspace will be cloned in the same server if not provided)
        permission default_permission - Default permissions of the workspace created by the cloning process. Accepted values are 'a' => admin, 'w' => write, 'r' => read, 'n' => none (an essential argument)
        string auth - the authentication token of the KBase account that will own the cloned workspace (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_workspace has a value which is a workspace_id
new_workspace_url has a value which is a string
current_workspace has a value which is a workspace_id
default_permission has a value which is a permission
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_workspace has a value which is a workspace_id
new_workspace_url has a value which is a string
current_workspace has a value which is a workspace_id
default_permission has a value which is a permission
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 list_workspaces_params

=over 4



=item Description

Input parameters for the "list_workspaces" function.

        string auth - the authentication token of the KBase account accessing the list of workspaces (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash
        bool excludeGlobal - if credentials are supplied and excludeGlobal is true exclude world readable workspaces


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
auth has a value which is a string
asHash has a value which is a bool
excludeGlobal has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
auth has a value which is a string
asHash has a value which is a bool
excludeGlobal has a value which is a bool


=end text

=back



=head2 list_workspace_objects_params

=over 4



=item Description

Input parameters for the "list_workspace_objects" function.

        workspace_id workspace - ID of the workspace for which objects should be listed (an essential argument)
        string type - type of the objects to be listed (an optional argument; all object types will be listed if left unspecified)
        bool showDeletedObject - a flag that, if set to '1', causes any deleted objects to be included in the output (an optional argument; default is '0')
        string auth - the authentication token of the KBase account listing workspace objects; must have at least 'read' privileges (an optional argument)
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
type has a value which is a string
showDeletedObject has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a workspace_id
type has a value which is a string
showDeletedObject has a value which is a bool
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 set_global_workspace_permissions_params

=over 4



=item Description

Input parameters for the "set_global_workspace_permissions" function.

        workspace_id workspace - ID of the workspace for which permissions will be set (an essential argument)
        permission new_permission - New default permissions to which the workspace should be set. Accepted values are 'a' => admin, 'w' => write, 'r' => read, 'n' => none (an essential argument)
        string auth - the authentication token of the KBase account changing workspace default permissions; must have 'admin' privelages to workspace
        bool asHash - a boolean indicating if metadata should be returned as a hash


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_permission has a value which is a permission
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_permission has a value which is a permission
workspace has a value which is a workspace_id
auth has a value which is a string
asHash has a value which is a bool


=end text

=back



=head2 set_workspace_permissions_params

=over 4



=item Description

Input parameters for the "set_workspace_permissions" function.

        workspace_id workspace - ID of the workspace for which permissions will be set (an essential argument)
        list<username> users - list of users for which workspace privileges are to be reset (an essential argument)
        permission new_permission - New permissions to which all users in the user list will be set for the workspace. Accepted values are 'a' => admin, 'w' => write, 'r' => read, 'n' => none (an essential argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
users has a value which is a reference to a list where each element is a username
new_permission has a value which is a permission
workspace has a value which is a workspace_id
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
users has a value which is a reference to a list where each element is a username
new_permission has a value which is a permission
workspace has a value which is a workspace_id
auth has a value which is a string


=end text

=back



=head2 get_user_settings_params

=over 4



=item Description

Input parameters for the "get_user_settings" function.

        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
auth has a value which is a string


=end text

=back



=head2 set_user_settings_params

=over 4



=item Description

Input parameters for the "set_user_settings" function.

        string setting - the setting to be set (an essential argument)
        string value - new value to be set (an essential argument)
        string auth - the authentication token of the KBase account changing workspace permissions; must have 'admin' privelages to workspace


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
setting has a value which is a string
value has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
setting has a value which is a string
value has a value which is a string
auth has a value which is a string


=end text

=back



=head2 queue_job_params

=over 4



=item Description

Input parameters for the "queue_job" function.

        string auth - the authentication token of the KBase account queuing the job; must have access to the job being queued (an optional argument)
        string state - the initial state to assign to the job being queued (an optional argument; default is "queued")
        string type - the type of the job being queued
        mapping<string,string> jobdata - hash of data associated with job


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
auth has a value which is a string
state has a value which is a string
type has a value which is a string
queuecommand has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
auth has a value which is a string
state has a value which is a string
type has a value which is a string
queuecommand has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 set_job_status_params

=over 4



=item Description

Input parameters for the "set_job_status" function.

        string jobid - ID of the job to be have status changed (an essential argument)
        string status - Status to which job should be changed; accepted values are 'queued', 'running', and 'done' (an essential argument)
        string auth - the authentication token of the KBase account requesting job status; only status for owned jobs can be retrieved (an optional argument)
        string currentStatus - Indicates the current statues of the selected job (an optional argument; default is "undef")
        mapping<string,string> jobdata - hash of data associated with job


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobid has a value which is a string
status has a value which is a string
auth has a value which is a string
currentStatus has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobid has a value which is a string
status has a value which is a string
auth has a value which is a string
currentStatus has a value which is a string
jobdata has a value which is a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 get_jobs_params

=over 4



=item Description

Input parameters for the "get_jobs" function.

list<string> jobids - list of specific jobs to be retrieved (an optional argument; default is an empty list)
string status - Status of all jobs to be retrieved; accepted values are 'queued', 'running', and 'done' (an essential argument)
string auth - the authentication token of the KBase account accessing job list; only owned jobs will be returned (an optional argument)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobids has a value which is a reference to a list where each element is a string
type has a value which is a string
status has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobids has a value which is a reference to a list where each element is a string
type has a value which is a string
status has a value which is a string
auth has a value which is a string


=end text

=back



=head2 add_type_params

=over 4



=item Description

Input parameters for the "add_type" function.

        string type - Name of type being added (an essential argument)
        string auth - the authentication token of the KBase account adding a type


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
type has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
type has a value which is a string
auth has a value which is a string


=end text

=back



=head2 remove_type_params

=over 4



=item Description

Input parameters for the "remove_type" function.

        string type - name of custom type to be removed from workspace service (an essential argument)
        string auth - the authentication token of the KBase account removing a custom type


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
type has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
type has a value which is a string
auth has a value which is a string


=end text

=back



=head2 patch_params

=over 4



=item Description

Input parameters for the "patch" function.

string patch_id - ID of the patch that should be run on the workspace
string auth - the authentication token of the KBase account removing a custom type


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
patch_id has a value which is a string
auth has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
patch_id has a value which is a string
auth has a value which is a string


=end text

=back



=cut

package Bio::KBase::workspaceService::Client::RpcClient;
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
