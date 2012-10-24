package Bio::KBase::fbaModel::Workspaces::WorkspaceUser;
use strict;
use Bio::KBase::Exceptions;

our $VERSION = "0";

=head1 NAME

Workspace

=head1 DESCRIPTION

=head1 Object

API for manipulating WorkspaceUser

=cut

=head3 new

Definition:
	Object = Bio::KBase::fbaModel::Workspaces::WorkspaceUser->new();
Description:
	Returns a WorkspaceUser object

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
	$self->{_data} = $self->_mongodb()->workspaceUsers->find_one({ id => $self->id() });
	if (!defined($self->{_data})) {
		if ($args->{throwErrorIfMissing} == 1) {
			Bio::KBase::Exceptions::ArgumentValidationError->throw(error => "Specified user not found!",
				method_name => 'loadFromDB');
		} elsif ($args->{createIfMissing} == 1) {
			$self->{_data} = {id => $self->id()};
			$self->insertInDB();
		}
	}
}

=head3 setWorkspacePermission

Definition:
	void setWorkspacePermission(string:workspace,string:permission)
Description:
	Sets permission for user for input workspace

=cut

sub setWorkspacePermission {
	my ($self,$workspace,$perm) = @_;
	$self->parent()->_validatePermission($perm);
	$self->parent()->_mongodb()->workspaceUsers->update({id => $self->id()}, {'$set' => {'workspaces.'.$workspace => $perm}});
}

1;
