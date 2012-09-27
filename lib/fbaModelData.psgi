use fbaModelServicesImpl;

use fbaModelServicesServer;



my @dispatch;

{
    my $obj = fbaModelServicesImpl->new;
    push(@dispatch, 'fbaModelServices' => $obj);
}


my $server = fbaModelServicesServer->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;
