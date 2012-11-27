use Bio::KBase::fbaModelCLI::Impl;

use Bio::KBase::fbaModelCLI::Server;



my @dispatch;

{
    my $obj = Bio::KBase::fbaModelCLI::Impl->new;
    push(@dispatch, 'fbaModelCLI' => $obj);
}


my $server = Bio::KBase::fbaModelCLI::Server->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
