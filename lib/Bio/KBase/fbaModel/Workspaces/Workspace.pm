package Bio::KBase::fbaModel::Workspaces::Workspace;
use strict;
use Bio::KBase::Exceptions;

our $VERSION = "0";

=head1 NAME

Workspace

=head1 DESCRIPTION

=head1 Workspace

API for manipulating workspaces

=cut

=head3 new

Definition:
	Workspace = Bio::KBase::fbaModel::Workspaces::Workspace->new({}:workspace data);
Description:
	Returns a Workspace object

=cut

sub new {
	my ($class,$args) = @_;
	$args = Bio::KBase::fbaModel::Workspaces::Impl::_args(["parent","id"],{
		data => undef,
		throwErrorIfMissing => 0,
		createIfMissing => 0
	},$args);
	my $self = {_id => $args->{id},_parent => $args->{parent}};
	if (!defined($args->{data})) {
		$self->loadFromDB({
			throwErrorIfMissing => $args->{throwErrorIfMissing},
			createIfMissing => $args->{createIfMissing},
		});
	} else {
		$self->{_data} = $args->{data};
	}
    return bless $self;
}

=head3 id

Definition:
	string = id()
Description:
	Returns the id for the workspace

=cut

sub id {
	my ($self) = @_;
	return $self->{_id};
}

=head3 data

Definition:
	string = data()
Description:
	Returns the raw data for the workspace

=cut

sub data {
	my ($self) = @_;
	return $self->{_data};
}

=head3 objects

Definition:
	{} = objects();
Description:
	Returns the workspace objects hash

=cut

sub objects {
	my ($self,$type,$alias) = @_;
	return $self->data()->{objects};
}

=head3 insertInDB

Definition:
	0/1 = insertInDB()
Description:
	Inserts WorkspaceUser object into database

=cut

sub insertInDB {
	my ($self) = @_;
	$self->data()->{moddate} = DateTime->now()->datetime();
	$self->parent()->_mongodb()->workspaces->insert($self->data());
}

=head3 loadFromDB

Definition:
	void loadFromDB()
Description:
	Loads workspace user data frm database

=cut

sub loadFromDB {
	my ($self,$args) = @_;
	$args = Bio::KBase::fbaModel::Workspaces::Impl::_args([],{
		throwErrorIfMissing => 0,
		createIfMissing => 0
	},$args);
	$self->{_data} = $self->_mongodb()->workspaces->find_one({ id => $self->id() });
	if (!defined($self->{_data})) {
		if ($args->{throwErrorIfMissing} == 1) {
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Workspace not found!",
				method_name => 'loadFromDB');
		} elsif ($args->{createIfMissing} == 1) {
			$self->{_data} = {
				id => $self->id(),
				owner => $self->parent()->getUsername(),
				defaultPermissions => "n",
				objects => {}
			};
			$self->insertInDB();
		}
	}
}

=head3 objectCache

Definition:
	string = objectCache()
Description:
	Returns the objectCache for the workspace

=cut

sub objectCache {
	my ($self) = @_;
	return $self->{_objectCache};
}

=head3 parent

Definition:
	string = parent()
Description:
	Returns the parent workspace implementation

=cut

sub parent {
	my ($self) = @_;
	return $self->{_parent};
}

=head3 permissions

Definition:
	string = permissions()
Description:
	Returns the current permissions for the workspace

=cut

sub permissions {
	my ($self) = @_;
	return $self->{_permissions};
}

=head3 defaultPermissions

Definition:
	string = defaultPermissions()
Description:
	Returns the defaultPermissons for the workspace

=cut

sub defaultPermissions {
	my ($self) = @_;
	return $self->data()->{defaultPermissions};
}

=head3 owner

Definition:
	string = owner()
Description:
	Returns the owner for the workspace

=cut

sub owner {
	my ($self) = @_;
	return $self->data()->{owner};
}

=head3 setDefaultPermissions

Definition:
	void setDefaultPermissions(string:permission)
Description:
	Alters the default permissions for workspace

=cut

sub setDefaultPermissions {
	my ($self,$perm) = @_;
	$parent->_validatePermission($perm);
	if ($self->permissions() ne "a") {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "User does not have rights to edit workspace permissions!",
							       method_name => 'setDefaultPermissions');
	}
	$self->data()->{defaultPermissions} = $perm;
	$self->parent()->_mongod()->workspaces->update({id => $self->name()}, {'$set' => {'defaultPermissions' => $perm}});
}

=head3 getObject

Definition:
	Bio::KBase::fbaModel::Workspaces::Object = getObject(string:type,string:alias)
Description:
	Returns a Workspace object

=cut

sub getObject {
	my ($self,$type,$alias) = @_;
	my $objects = $self->objects();
	if (!defined($objects->{$type}->{$alias})) {
		return undef;
	}
	my $uuid = $objects->{$type}->{$alias};
	return $self->parent()->_getObjectsByUUID([$uuid],{throwErrorIfMissing => 1});
}

=head3 getAllObjects

Definition:
	Bio::KBase::fbaModel::Workspaces::Object = getAllObjects(string:type)
Description:
	Returns all workspace objects of the specified type

=cut

sub getAllObjects {
	my ($self,$type) = @_;
	my $uuids = [];
	my $objects = $self->objects();
	if (!defined($type)) {
		foreach my $type (keys(%{$objects})) {
			foreach my $alias (keys(%{$objects->{$type}})) {
				push(@{$uuids},$objects->{$type}->{$alias});
			}
		}
	} else {
		foreach my $alias (keys(%{$objects->{$type}})) {
			push(@{$uuids},$objects->{$type}->{$alias});	
		}
	}
	return $self->parent()->_getObjectsByUUID($uuids,{throwErrorIfMissing => 1});
}

=head3 saveObject

Definition:
	Bio::KBase::fbaModel::Workspaces::Object = saveObject(string:type)
Description:
	Returns saved object

=cut

sub saveObject {
	my ($self,$type,$id,$data,$command,$meta) = @_;
	$self->_validateType($type);
	if ($self->permissions() =~ m/[vn]/) {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "User does not have rights to save an object in the workspace!",
							       method_name => 'saveObject');
	}
	my $ancestor = undef;
	my $instance = 0;
	my $owner = $self->parent()->_getUsername();
	my $obj = $self->getObject($type,$id);
	if (defined($obj)) {
		$ancestor = $obj->uuid();
		$owner = $obj->owner();
		$instance = ($obj->instance()+1);
	}
	my $newObject = Bio::KBase::fbaModel::Workspaces::Object->new({
		type => $type,
		workspace => $self->id(),
		parent => $self->parent(),
		ancestor => $ancestor,
		owner => $owner,
		lastModifiedBy => $self->parent()->_getUsername(),
		command => $command
		alias => $id,
		instance => $instance,
		data => $data,
		meta => $meta
	});
	$self->parent()->_mongod()->workspaces->update({id => $self->id()}, {'$set' => {'objects.'.$type.'.'.$id => $newObject->uuid()}});
	$newObject->savePrimaryData();
	$newObject->saveMetaData();
	return $newObject;
}

=head3 setUserPermissions

Definition:
	void setUserPermissions([string]:usernames,string:permission)
Description:
	Sets user permissions

=cut

sub setUserPermissions {
	my ($self,$users,$perm) = @_;
	$self->parent()->_validatePermission($perm);
	if ($self->permissions() ne "a") {
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "User does not have rights to set user permissions for workspace!",
							       method_name => 'setUserPermissions');
	}
	my $userObjects = $self->parent()->_getWorkspaceUsers($users,{
		throwErrorIfMissing => 0,
		createIfMissing => 1
	});
	for (my $i=0; $i < @{$userObjects}; $i++) {
		$userObjects->[$i]->setWorkspacePermission($self->id(),$perm)
	}
} 

1;
