use Bio::KBase::fbaModelData::Impl;

use Bio::KBase::fbaModelData::Server;



my @dispatch;

{
    my $obj = Bio::KBase::fbaModelData::Impl->new;
    push(@dispatch, 'fbaModelData' => $obj);
}


my $server = Bio::KBase::fbaModelData::Server->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
