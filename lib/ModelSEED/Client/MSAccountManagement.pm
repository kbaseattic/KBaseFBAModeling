package ModelSEED::Client::MSAccountManagement;
use strict;

use base qw(myRAST::ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = myRAST::ClientThing::FixOptions(@options);
    if (!defined($options{url})) {
	$options{url} = "http://pubseed.theseed.org/model-prod/MSAccountManagement.cgi";
    }
    return $class->SUPER::new("MSAccountManagement" => %options);
}

1;
