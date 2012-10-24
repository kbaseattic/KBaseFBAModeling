package Bio::KBase::fbaModel::Workspaces::Impl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

workspaceDocumentDB

=head1 DESCRIPTION

=head1 workspaceDocumentDB

API for accessing and writing documents objects to a workspace.

=cut

#BEGIN_HEADER
use MongoDB;
use JSON::XS;
use Tie::IxHash;
use FileHandle;
use Data::UUID;
use DateTime;

sub _args {
    my $mandatory = shift;
    my $optional  = shift;
    my $args      = shift;
    my @errors;
    foreach my $arg (@$mandatory) {
        push(@errors, $arg) unless defined($args->{$arg});
    }
    if (@errors) {
        my $missing = join("; ", @errors);
        Bio::KBase::Exceptions::KBaseException->throw(error => "Mandatory arguments $missing missing.",
							       method_name => '_args');
    }
    foreach my $arg (keys %$optional) {
        $args->{$arg} = $optional->{$arg} unless defined $args->{$arg};
    }
    return $args;
}

sub _getUsername {
	return "KBase";
}

sub _mongodb {
    my ($self) = @_;
    if (!defined($self->{_mongodb})) {
    	my $config = {
	        host => $self->{_host},
	        host => $self->{_host},
	        db_name        => $self->{_db},
	        auto_connect   => 1,
	        auto_reconnect => 1
	    };
	    my $conn = MongoDB::Connection->new(%$config);
    	Bio::KBase::Exceptions::KBaseException->throw(error => "Unable to connect: $@",
							       method_name => 'workspaceDocumentDB::_mongodb') if (!defined($conn));
    	my $db_name = $self->{_db};
    	$self->{_mongodb} = $conn->$db_name;
    }    
    return $self->{_mongodb};
}

sub _createWorkspaceUser {
	my ($self,$data) = @_;
	my $wsu = Bio::KBase::fbaModel::Workspaces::WorkspaceUser->new(undef,$self,$data);
	$wsu->insertInDB();
	return $wsu;
}

sub _getWorkspaceUser {
	my ($self,$username,$options) = @_;
	if (!defined($username)) {
		$username = $self->_getUsername();
	}
	my $wsu = Bio::KBase::fbaModel::Workspaces::WorkspaceUser->new({
		parent => $self,
		username => $username,
		loadFromDatabase => 1,
		throwErrorIfMissing => $options->{throwErrorIfMissing},
		createIfMissing => $options->{createIfMissing},
	});
	return $wsu;
}

sub _getObjectsByUUID {
	my ($self,$uuids,$options) = @_;
    my $cursor = $self->_mongodb()->objectMetadatas->find({uuid => {'$in' => $uuids} });
	my $objHash = {};
	while (my $object = $cursor->next) {
        my $newObject = Bio::KBase::fbaModel::Workspaces::Object->new({
			uuid => $object->{uuid},
			type => $object->{type},
			workspace => $object->{workspace},
			parent => $self,
			ancestor => $object->{ancestor},
			owner => $object->{owner},
			lastModifiedBy => $object->{lastModifiedBy},
			command => $object->{command}
			alias => $object->{alias},
			instance => $object->{instance},
			meta => $object->{meta}
		});
        $objHash->{$newObject->uuid()} = $newObject;
    }
    my $objects = [];
    for (my $i=0; $i < @{$uuids}; $i++) {
    	if (defined($objHash->{$uuids->[$i]}) {
    		push(@{$objects},$objHash->{$uuids->[$i]);
    	} elsif ($options->{throwErrorIfMissing} == 1) {
    		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Workspace metaobject ".$uuids->[$i]." not found!",
							       method_name => '_getObjectsByUUID');
    	}
    }
	return $objects;
}

sub _getWorkspace {
	my ($self,$workspace,$options) = @_;
	my $wsu = Bio::KBase::fbaModel::Workspaces::Workspace->new({
		parent => $self,
		id => $workspace,
		loadFromDatabase => 1,
		throwErrorIfMissing => $options->{throwErrorIfMissing},
		createIfMissing => $options->{createIfMissing},
	});
	return ($wsu);
}

sub _addWorkspaceUserPermission {
	my ($self,$username,$workspace,$permission) = @_;
	$self->_checkPermission($permission);
	$self->_getWorkspace($workspace,1);
	$self->_getWorkspaceUser($username,1);
	$self->_mongodb()->workspaceUsers->update({id => $username}, {'$set' => {'workspaces.'.$workspace => $permission}});
}

sub _setWorkspaceDefaultPermissions {
	my ($self,$workspace,$new_permission) = @_;	
	$self->_checkPermission($new_permission);
    (my $ws,my $perm = $self->_getWorkspace($workspace,1);
    if ($perm ne "a") {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "User does not have rights to edit workspace permissions!",
							       method_name => '_setWorkspaceDefaultPermissions');
    }
	$self->_mongodb()->workspaces->update({id => $workspace}, {'$set' => {'defaultPermissions' => $new_permission}});
}





sub _checkWorkspaceName {
	my ($self,$name) = @_;
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Workspace name must contain only alphanumeric characters!",
		method_name => '_checkWorkspaceName') if ($name !~ m/^\w+$/);
}

sub _checkPermission {
	my ($self,$permission) = @_;
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Specified permission not valid!",
		method_name => '_checkPermission') if ($permission !~ m/^[awrn]$/);
}

sub _checkType {
	my ($self,$type) = @_;
	my $types = {
		Genome => 1,
		
	};
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Specified type not valid!",
		method_name => '_checkType') if (!defined($types->{$type}));
}

sub _interpret_ref {
	my ($self,$ref) = @_;
	if ($ref =~ m/(.+)::(.+)/) {
		return ($1,$2);
	}
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Input reference not recognized!",
		method_name => '_interpret_ref');
}

sub _make_ref {
	my ($self,$type,$id) = @_;
	return $type."::".$id;
}

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    if (my $e = $ENV{KB_DEPLOYMENT_CONFIG}) {
        my $service = $ENV{KB_SERVICE_NAME};
        my $c = new Config::Simple($e);
        $self->{_host} = $c->param("$service.mongodb-hostname");
        $self->{_db}   = $c->param("$service.mongodb-database");
    } else {
        warn "No deployment configuration found;\n";
    }
    if (!$self->{_host}) {
        $self->{_host} = "mongodb.kbase.us";
        warn "\tfalling back to ".$self->{_host}." for database!\n";
    }
    if (!$self->{_db}) {
        $self->{_db} = "modelObjectStore";
        warn "\tfalling back to ".$self->{_db}." for collection\n";
    } 
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 save_object

  $success = $obj->save_object($id, $type, $data, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is an object_id
$type is an object_type
$data is an ObjectData
$workspace is a workspace_id
$success is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$id is an object_id
$type is an object_type
$data is an ObjectData
$workspace is a workspace_id
$success is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_id is a string
bool is an int


=end text



=item Description

Object management routines

=back

=cut

sub save_object
{
    my $self = shift;
    my($id, $type, $data, $workspace) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (ref($data) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"data\" (value was \"$data\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to save_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'save_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN save_object
    my $ws = $self->_getWorkspace($workspace,{throwErrorIfMissing => 1});
    $ws->saveObject($type,$id,$data);
    #END save_object
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to save_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'save_object');
    }
    return($success);
}




=head2 delete_object

  $success = $obj->delete_object($id, $type, $data, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is an object_id
$type is an object_type
$data is an ObjectData
$workspace is a workspace_id
$success is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$id is an object_id
$type is an object_type
$data is an ObjectData
$workspace is a workspace_id
$success is a bool
object_id is a string
object_type is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int
workspace_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub delete_object
{
    my $self = shift;
    my($id, $type, $data, $workspace) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (ref($data) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"data\" (value was \"$data\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to delete_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN delete_object
    #END delete_object
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to delete_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_object');
    }
    return($success);
}




=head2 get_object

  $data = $obj->get_object($id, $type, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is an object_id
$type is an object_type
$workspace is a workspace_id
$data is an ObjectData
object_id is a string
object_type is a string
workspace_id is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int

</pre>

=end html

=begin text

$id is an object_id
$type is an object_type
$workspace is a workspace_id
$data is an ObjectData
object_id is a string
object_type is a string
workspace_id is a string
ObjectData is a reference to a hash where the following keys are defined:
	version has a value which is an int


=end text



=item Description



=back

=cut

sub get_object
{
    my $self = shift;
    my($id, $type, $workspace) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($data);
    #BEGIN get_object
    #END get_object
    my @_bad_returns;
    (ref($data) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"data\" (value was \"$data\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_object');
    }
    return($data);
}




=head2 revert_object

  $success = $obj->revert_object($id, $type, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is an object_id
$type is an object_type
$workspace is a workspace_id
$success is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$id is an object_id
$type is an object_type
$workspace is a workspace_id
$success is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub revert_object
{
    my $self = shift;
    my($id, $type, $workspace) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to revert_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'revert_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN revert_object
    #END revert_object
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to revert_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'revert_object');
    }
    return($success);
}




=head2 copy_object

  $success = $obj->copy_object($new_id, $new_workspace, $source_id, $type, $source_workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$new_id is an object_id
$new_workspace is a workspace_id
$source_id is an object_id
$type is an object_type
$source_workspace is a workspace_id
$success is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int

</pre>

=end html

=begin text

$new_id is an object_id
$new_workspace is a workspace_id
$source_id is an object_id
$type is an object_type
$source_workspace is a workspace_id
$success is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int


=end text



=item Description



=back

=cut

sub copy_object
{
    my $self = shift;
    my($new_id, $new_workspace, $source_id, $type, $source_workspace) = @_;

    my @_bad_arguments;
    (!ref($new_id)) or push(@_bad_arguments, "Invalid type for argument \"new_id\" (value was \"$new_id\")");
    (!ref($new_workspace)) or push(@_bad_arguments, "Invalid type for argument \"new_workspace\" (value was \"$new_workspace\")");
    (!ref($source_id)) or push(@_bad_arguments, "Invalid type for argument \"source_id\" (value was \"$source_id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (!ref($source_workspace)) or push(@_bad_arguments, "Invalid type for argument \"source_workspace\" (value was \"$source_workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to copy_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'copy_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN copy_object
    #END copy_object
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to copy_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'copy_object');
    }
    return($success);
}




=head2 move_object

  $success = $obj->move_object($new_id, $new_workspace, $source_id, $type, $source_workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$new_id is an object_id
$new_workspace is a workspace_id
$source_id is an object_id
$type is an object_type
$source_workspace is a workspace_id
$success is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int

</pre>

=end html

=begin text

$new_id is an object_id
$new_workspace is a workspace_id
$source_id is an object_id
$type is an object_type
$source_workspace is a workspace_id
$success is a bool
object_id is a string
workspace_id is a string
object_type is a string
bool is an int


=end text



=item Description



=back

=cut

sub move_object
{
    my $self = shift;
    my($new_id, $new_workspace, $source_id, $type, $source_workspace) = @_;

    my @_bad_arguments;
    (!ref($new_id)) or push(@_bad_arguments, "Invalid type for argument \"new_id\" (value was \"$new_id\")");
    (!ref($new_workspace)) or push(@_bad_arguments, "Invalid type for argument \"new_workspace\" (value was \"$new_workspace\")");
    (!ref($source_id)) or push(@_bad_arguments, "Invalid type for argument \"source_id\" (value was \"$source_id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (!ref($source_workspace)) or push(@_bad_arguments, "Invalid type for argument \"source_workspace\" (value was \"$source_workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to move_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'move_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN move_object
    #END move_object
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to move_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'move_object');
    }
    return($success);
}




=head2 has_object

  $object_present = $obj->has_object($id, $type, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is an object_id
$type is an object_type
$workspace is a workspace_id
$object_present is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$id is an object_id
$type is an object_type
$workspace is a workspace_id
$object_present is a bool
object_id is a string
object_type is a string
workspace_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub has_object
{
    my $self = shift;
    my($id, $type, $workspace) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to has_object:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'has_object');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($object_present);
    #BEGIN has_object
    (my $ws,my $perm) = $self->_getWorkspace($workspace,1);
    if ($perm eq "n") {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Do not have read permissions on the workspace!",
			method_name => 'clone_workspace');
    }
    $object_present = 0;
    if (defined($ws->{objects}->{$self->_make_ref($type,$id)})) {
    	$object_present = 1;
    }
    #END has_object
    my @_bad_returns;
    (!ref($object_present)) or push(@_bad_returns, "Invalid type for return variable \"object_present\" (value was \"$object_present\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to has_object:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'has_object');
    }
    return($object_present);
}




=head2 create_workspace

  $success = $obj->create_workspace($name, $default_permission)

=over 4

=item Parameter and return types

=begin html

<pre>
$name is a workspace_id
$default_permission is a permission
$success is a bool
workspace_id is a string
permission is a string
bool is an int

</pre>

=end html

=begin text

$name is a workspace_id
$default_permission is a permission
$success is a bool
workspace_id is a string
permission is a string
bool is an int


=end text



=item Description

Workspace management routines

=back

=cut

sub create_workspace
{
    my $self = shift;
    my($name, $default_permission) = @_;

    my @_bad_arguments;
    (!ref($name)) or push(@_bad_arguments, "Invalid type for argument \"name\" (value was \"$name\")");
    (!ref($default_permission)) or push(@_bad_arguments, "Invalid type for argument \"default_permission\" (value was \"$default_permission\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to create_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_workspace');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN create_workspace
    $self->_checkWorkspaceName($name);
    $self->_checkPermission($default_permission);
    (my $ws,my $perm) = $self->_getWorkspace($name,0);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Cannot create workspace because workspace already exists!",
		method_name => 'create_workspace') if (defined($ws));
   	my $user = $self->_getUsername();
   	$self->_createWorkspace({
   		id => $name,
    	defaultPermissions => $default_permission,
    	objects => {},
    	owner => $user,
   	});
   	my $wsUser = $self->_getWorkspaceUser($user,0);
    if (!defined($wsUser)) {
    	$self->_createWorkspaceUser({
    		id => $user
    	});
    }
    $self->_addWorkspaceUserPermission($user,$name,"a");
    $success = 1;
    #END create_workspace
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to create_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_workspace');
    }
    return($success);
}




=head2 clone_workspace

  $success = $obj->clone_workspace($new_workspace, $current_workspace, $default_permission)

=over 4

=item Parameter and return types

=begin html

<pre>
$new_workspace is a workspace_id
$current_workspace is a workspace_id
$default_permission is a permission
$success is a bool
workspace_id is a string
permission is a string
bool is an int

</pre>

=end html

=begin text

$new_workspace is a workspace_id
$current_workspace is a workspace_id
$default_permission is a permission
$success is a bool
workspace_id is a string
permission is a string
bool is an int


=end text



=item Description



=back

=cut

sub clone_workspace
{
    my $self = shift;
    my($new_workspace, $current_workspace, $default_permission) = @_;

    my @_bad_arguments;
    (!ref($new_workspace)) or push(@_bad_arguments, "Invalid type for argument \"new_workspace\" (value was \"$new_workspace\")");
    (!ref($current_workspace)) or push(@_bad_arguments, "Invalid type for argument \"current_workspace\" (value was \"$current_workspace\")");
    (!ref($default_permission)) or push(@_bad_arguments, "Invalid type for argument \"default_permission\" (value was \"$default_permission\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to clone_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'clone_workspace');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN clone_workspace
    if ($new_workspace eq $current_workspace) {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "New workspace name must be different than current workspace name!",
			method_name => 'clone_workspace');
    }
    (my $ws,my $perm) = $self->_getWorkspace($current_workspace,1);
    if ($perm eq "n") {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Do not have read permissions on the source workspace!",
			method_name => 'clone_workspace');
    }
    (my $newws,$perm) = $self->_getWorkspace($new_workspace,0);
    if (!defined($newws)) {
    	$self->create_workspace($new_workspace,$default_permission);
    	($newws,$perm) = $self->_getWorkspace($new_workspace,1);
    }
    if ($perm ne "a") {
    	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Do not have admin permissions on the target workspace!",
			method_name => 'clone_workspace');
    }
    foreach my $key (keys(%{$ws->{objects}})) {
    	if (!defined($newws->{objects}->{$key})) {
    		$self->_mongodb()->workspaces->update({id => $new_workspace}, {'$set' => {'objects.'.$key => $ws->{objects}->{$key} }});
    		#TODO:Need to add the new alias to the DB
    	}
    }
    $success = 1;
    #END clone_workspace
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to clone_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'clone_workspace');
    }
    return($success);
}




=head2 list_workspaces

  $workspaces = $obj->list_workspaces()

=over 4

=item Parameter and return types

=begin html

<pre>
$workspaces is a reference to a list where each element is a workspace_metadata
workspace_metadata is a reference to a list containing 6 items:
	0: a workspace_id
	1: a username
	2: a timestamp
	3: an int
	4: a permission
	5: a permission
workspace_id is a string
username is a string
timestamp is a string
permission is a string

</pre>

=end html

=begin text

$workspaces is a reference to a list where each element is a workspace_metadata
workspace_metadata is a reference to a list containing 6 items:
	0: a workspace_id
	1: a username
	2: a timestamp
	3: an int
	4: a permission
	5: a permission
workspace_id is a string
username is a string
timestamp is a string
permission is a string


=end text



=item Description



=back

=cut

sub list_workspaces
{
    my $self = shift;

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($workspaces);
    #BEGIN list_workspaces
    #Getting user-specific permissions
    my $user = $self->_getUsername();
    my $wsUser = $self->_getWorkspaceUser($user);
    my $workspaceHash = {};
    if (defined($wsUser)) {
    	foreach $key (keys(%{$wsUser->{workspaces}})) {
    		if ($wsUser->{workspaces}->{$key} ne "n") {
    			$workspaceHash->{$key} = $wsUser->{workspaces}->{$key};
    		}
    	}
    }
	#Getting workspace documents
    my $workspaceKeys = [keys(%{$workspaceHash})];
    my $query = {defaultPermissions => {'$in' => ["a","w","r"]} };
    if (@{$workspaceKeys} > 0) {
    	$query = { '$or' => [ {id => {'$in' => $workspaceKeys} },{defaultPermissions => {'$in' => ["a","w","r"]} } ] };
    }
    my $cursor = $self->_mongodb()->workspaces->find($query);
    while (my $object = $cursor->next) {
        my $meta = [
        	$object->{id},
        	$object->{owner},
       		$object->{moddate},
       		keys($object->{objects}),
       		$object->{defaultPermissions},
       		$object->{defaultPermissions},
        ];
        if (defined($workspaceHash->{$object->{id}})) {
        	$meta->[4] = $workspaceHash->{$object->{id}};
        }
        push(@{$workspaces},$meta);
    }
    #END list_workspaces
    my @_bad_returns;
    (ref($workspaces) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"workspaces\" (value was \"$workspaces\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_workspaces:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspaces');
    }
    return($workspaces);
}




=head2 list_workspace_objects

  $objects = $obj->list_workspace_objects($workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$workspace is a workspace_id
$objects is a reference to a list where each element is an object_metadata
workspace_id is a string
object_metadata is a reference to a list containing 6 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a username
	5: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string

</pre>

=end html

=begin text

$workspace is a workspace_id
$objects is a reference to a list where each element is an object_metadata
workspace_id is a string
object_metadata is a reference to a list containing 6 items:
	0: an object_id
	1: an object_type
	2: a timestamp
	3: an int
	4: a username
	5: a username
object_id is a string
object_type is a string
timestamp is a string
username is a string


=end text



=item Description



=back

=cut

sub list_workspace_objects
{
    my $self = shift;
    my($workspace) = @_;

    my @_bad_arguments;
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to list_workspace_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_objects');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($objects);
    #BEGIN list_workspace_objects
    my $ws = $self->_getWorkspace($workspace,{throwErrorIfMissing => 1});
	$objects = [];
	my $objs = $ws->getAllObjects($options->{type});    
	foreach my $obj (@{$objs}) {
		push(@{$objects},[
			$obj->id(),
			$obj->type(),
			$obj->modDate(),
			$obj->instance(),
			$obj->command(),
			$obj->lastModifier(),
			$obj->owner()
		]);
	}
    #END list_workspace_objects
    my @_bad_returns;
    (ref($objects) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"objects\" (value was \"$objects\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_workspace_objects:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_objects');
    }
    return($objects);
}




=head2 set_global_workspace_permissions

  $success = $obj->set_global_workspace_permissions($new_permission, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$new_permission is a permission
$workspace is a workspace_id
$success is a bool
permission is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$new_permission is a permission
$workspace is a workspace_id
$success is a bool
permission is a string
workspace_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub set_global_workspace_permissions
{
    my $self = shift;
    my($new_permission, $workspace) = @_;

    my @_bad_arguments;
    (!ref($new_permission)) or push(@_bad_arguments, "Invalid type for argument \"new_permission\" (value was \"$new_permission\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_global_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_global_workspace_permissions');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN set_global_workspace_permissions
    my $ws = $self->_getWorkspace($workspace,{throwErrorIfMissing => 1});
    $ws->setDefaultPermissions($new_permission);
    $success = 1;
    #END set_global_workspace_permissions
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to set_global_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_global_workspace_permissions');
    }
    return($success);
}




=head2 set_workspace_permissions

  $success = $obj->set_workspace_permissions($users, $new_permission, $workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$users is a reference to a list where each element is a username
$new_permission is a permission
$workspace is a workspace_id
$success is a bool
username is a string
permission is a string
workspace_id is a string
bool is an int

</pre>

=end html

=begin text

$users is a reference to a list where each element is a username
$new_permission is a permission
$workspace is a workspace_id
$success is a bool
username is a string
permission is a string
workspace_id is a string
bool is an int


=end text



=item Description



=back

=cut

sub set_workspace_permissions
{
    my $self = shift;
    my($users, $new_permission, $workspace) = @_;

    my @_bad_arguments;
    (ref($users) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"users\" (value was \"$users\")");
    (!ref($new_permission)) or push(@_bad_arguments, "Invalid type for argument \"new_permission\" (value was \"$new_permission\")");
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_workspace_permissions');
    }

    my $ctx = $Bio::KBase::fbaModel::Workspaces::Service::CallContext;
    my($success);
    #BEGIN set_workspace_permissions
    my $ws = $self->_getWorkspace($workspace,{throwErrorIfMissing => 1});
    $ws->setUserPermissions($users,$new_permission);
	$success = 1;    
    #END set_workspace_permissions
    my @_bad_returns;
    (!ref($success)) or push(@_bad_returns, "Invalid type for return variable \"success\" (value was \"$success\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to set_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_workspace_permissions');
    }
    return($success);
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



=head2 bool

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



=head2 workspace_id

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



=head2 object_type

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



=head2 object_id

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



=head2 permission

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



=head2 username

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



=head2 timestamp

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



=head2 ObjectData

=over 4



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



=head2 WorkspaceData

=over 4



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



=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a username
5: a username

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: an object_id
1: an object_type
2: a timestamp
3: an int
4: a username
5: a username


=end text

=back



=head2 workspace_metadata

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: a workspace_id
1: a username
2: a timestamp
3: an int
4: a permission
5: a permission

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: a workspace_id
1: a username
2: a timestamp
3: an int
4: a permission
5: a permission


=end text

=back



=cut

1;
