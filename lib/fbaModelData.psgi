use Bio::KBase::fbaModel::Data::Impl;

use Bio::KBase::fbaModel::Data::Service;



my @dispatch;

{
    my $obj = Bio::KBase::fbaModel::Data::Impl->new;
    push(@dispatch, 'fbaModelData' => $obj);
}


my $server = Bio::KBase::fbaModel::Data::Service->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
