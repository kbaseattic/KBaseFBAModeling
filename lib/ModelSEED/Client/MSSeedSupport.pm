#
# This is a SAS Component
#
package ModelSEED::Client::MSSeedSupport;

use strict;
use base qw(myRAST::ClientThing);

sub new {
    my($class, @options) = @_;
    my %options = myRAST::ClientThing::FixOptions(@options);
	if (!defined($options{url})) {
		$options{url} = "http://bioseed.mcs.anl.gov/~chenry/FIG/CGI/MSSeedSupport_server.cgi";
	}
    return $class->SUPER::new("MSSeedSupport" => %options);
}

1;
