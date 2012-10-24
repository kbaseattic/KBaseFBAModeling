package Bio::KBase::fbaModel::Workspaces::Object;
use strict;
use Bio::KBase::Exceptions;

our $VERSION = "0";

=head1 NAME

Workspace

=head1 DESCRIPTION

=head1 Object

API for manipulating Objects

=cut

=head3 new

Definition:
	Object = Bio::KBase::fbaModel::Workspaces::Object->new();
Description:
	Returns a Workspace object

=cut

sub new {
	my ($class,$args) = @_;
	$args = Bio::KBase::fbaModel::Workspaces::Impl::_args(["parent","id","workspace","type"],{
		ancestor => undef,
		owner => $args->{parent}->_getUsername(),
		lastModifiedBy => $args->{parent}->_getUsername(),
		instance => 0,
		data => undef
	},$args);
	my $self;
	$self->{_metadata}->{ancestor} = $args->{ancestor};
	$self->{_metadata}->{owner} = $args->{owner};
	$self->{_metadata}->{lastModifiedBy} = $args->{lastModifiedBy};
	$self->{_metadata}->{instance} = $args->{instance};
	$self->{_metadata}->{ancestor} = $args->{ancestor};
	$self->{_metadata}->{workspace} = $args->{workspace};
	$self->{_metadata}->{id} = $args->{id};
	if (defined($args->{data})) {
		$self->setData($args->{data});
	}
	$self->{_parent} => $args->{parent};
    return bless $self;
}

=head3 setData

Definition:
	setData()
Description:
	Loads core data

=cut

sub setData {
	my ($self,$data) = @_;
	
	$self->{_coredata}->{data} = $data;
	
	
	return $self->{_name};
}


=head3 name

Definition:
	string = name()
Description:
	Returns the name for the workspace

=cut

sub name {
	my ($self) = @_;
	return $self->{_name};
}

=head3 isInDB

Definition:
	0/1 = isInDB()
Description:
	Returns a boolean indicating if the user is in the database

=cut

sub isInDB {
	my ($self) = @_;
	return $self->{_isInDB};
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
	if (!defined($self->data()->{$type}->{$alias})) {
		return undef;
	}
	if (!defined($self->objectCache()->{$type}->{$alias})) {
		$self->objectCache()->{$type}->{$alias} = Bio::KBase::fbaModel::Workspaces::Object->new($data->{$type}->{$alias},$self);
	}
	return $self->objectCache()->{$type}->{$alias};
}

=head3 getAllObjects

Definition:
	Bio::KBase::fbaModel::Workspaces::Object = getAllObjects(string:type)
Description:
	Returns all workspace objects of the specified type

=cut

sub getAllObjects {
	my ($self,$type) = @_;
	if (!defined($type)) {
		return undef;
	}
	if (!defined($self->objectCache()->{$type}->{$alias})) {
		$self->objectCache()->{$type}->{$alias} = Bio::KBase::fbaModel::Workspaces::Object->new($data->{$type}->{$alias},$self);
	}
	return $self->objectCache()->{$type}->{$alias};
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
	my $userObjects = $self->parent()->_getWorkspaceUsers($users);
	for (my $i=0; $i < @{$userObjects}; $i++) {
		if ($userObjects->[$i]->isInDB() == 0) {
			$userObjects->[$i]->insertInDB();
		}
	
	
    	my $wsUser = $self->_mongodb()->workspaceUsers->find_one({ id => $users->[$i] });
    	if (!defined($wsUser)) {
	    	$self->_createWorkspaceUser({
	    		id => $users->[$i],
	    		workspaces => {$workspace => $new_permission}
	    	});
	    } else {
	       	$self->_mongodb()->workspaceUsers->update({id => $user}, {'$set' => {'workspaces.'.$workspace => $new_permission}});
	    }
    }
	

    $self->_checkPermission($new_permission);
    my $ws = $self->_getWorkspace($workspace);
	my $user = $self->_getUsername();
	my $wsUser = $self->_getWorkspaceUser($user);
	
	
    
    
    

1;
