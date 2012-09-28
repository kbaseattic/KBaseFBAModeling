use Bio::KBase::fbaModel::CLI::Impl;

use Bio::KBase::fbaModel::CLI::Service;



my @dispatch;

{
    my $obj = Bio::KBase::fbaModel::CLI::Impl->new;
    push(@dispatch, 'fbaModelCLI' => $obj);
}


my $server = Bio::KBase::fbaModel::CLI::Service->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
