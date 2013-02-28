use Bio::KBase::fbaModelServices::Impl;

use Bio::KBase::fbaModelServices::Server;
use Plack::Middleware::CrossOrigin;



my @dispatch;

{
    my $obj = Bio::KBase::fbaModelServices::Impl->new;
    push(@dispatch, 'fbaModelServices' => $obj);
}


my $server = Bio::KBase::fbaModelServices::Server->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
