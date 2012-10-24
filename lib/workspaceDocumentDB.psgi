use Bio::KBase::fbaModel::Workspaces::Impl;

use Bio::KBase::fbaModel::Workspaces::Service;



my @dispatch;

{
    my $obj = Bio::KBase::fbaModel::Workspaces::Impl->new;
    push(@dispatch, 'workspaceDocumentDB' => $obj);
}


my $server = Bio::KBase::fbaModel::Workspaces::Service->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
