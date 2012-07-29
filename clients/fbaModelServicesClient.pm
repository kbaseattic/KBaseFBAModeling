package fbaModelServicesClient;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;

=head1 NAME

fbaModelServicesClient

=head1 DESCRIPTION



=cut

sub new
{
    my($class, $url) = @_;

    my $self = {
	client => fbaModelServicesClient::RpcClient->new,
	url => $url,
    };
    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);

    return bless $self, $class;
}




=head2 $result = genome_to_fbamodel(in_genome)

This function creates a metabolic model object from the annotated genome object.

=cut

sub genome_to_fbamodel
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function genome_to_fbamodel (received $n, expecting 1)");
    }
    {
	my($in_genome) = @args;

	my @_bad_arguments;
        (ref($in_genome) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"in_genome\" (value was \"$in_genome\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to genome_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'genome_to_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.genome_to_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'genome_to_fbamodel',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method genome_to_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'genome_to_fbamodel',
				       );
    }
}



=head2 $result = fbamodel_to_exchangeFormat(in_model)



=cut

sub fbamodel_to_exchangeFormat
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fbamodel_to_exchangeFormat (received $n, expecting 1)");
    }
    {
	my($in_model) = @args;

	my @_bad_arguments;
        (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fbamodel_to_exchangeFormat:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fbamodel_to_exchangeFormat');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fbamodel_to_exchangeFormat",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'fbamodel_to_exchangeFormat',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fbamodel_to_exchangeFormat",
					    status_line => $self->{client}->status_line,
					    method_name => 'fbamodel_to_exchangeFormat',
				       );
    }
}



=head2 $result = exchangeFormat_to_fbamodel(in_model)



=cut

sub exchangeFormat_to_fbamodel
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function exchangeFormat_to_fbamodel (received $n, expecting 1)");
    }
    {
	my($in_model) = @args;

	my @_bad_arguments;
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to exchangeFormat_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'exchangeFormat_to_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.exchangeFormat_to_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'exchangeFormat_to_fbamodel',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method exchangeFormat_to_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'exchangeFormat_to_fbamodel',
				       );
    }
}



=head2 $result = fbamodel_to_sbml(in_model)



=cut

sub fbamodel_to_sbml
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fbamodel_to_sbml (received $n, expecting 1)");
    }
    {
	my($in_model) = @args;

	my @_bad_arguments;
        (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fbamodel_to_sbml:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fbamodel_to_sbml');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fbamodel_to_sbml",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'fbamodel_to_sbml',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fbamodel_to_sbml",
					    status_line => $self->{client}->status_line,
					    method_name => 'fbamodel_to_sbml',
				       );
    }
}



=head2 $result = sbml_to_fbamodel(in_model)



=cut

sub sbml_to_fbamodel
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function sbml_to_fbamodel (received $n, expecting 1)");
    }
    {
	my($in_model) = @args;

	my @_bad_arguments;
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to sbml_to_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'sbml_to_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.sbml_to_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'sbml_to_fbamodel',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method sbml_to_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'sbml_to_fbamodel',
				       );
    }
}



=head2 $result = gapfill_fbamodel(in_model, in_formulation, overwrite, save)



=cut

sub gapfill_fbamodel
{
    my($self, @args) = @_;

    if ((my $n = @args) != 4)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_fbamodel (received $n, expecting 4)");
    }
    {
	my($in_model, $in_formulation, $overwrite, $save) = @args;

	my @_bad_arguments;
        (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        (ref($in_formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"in_formulation\" (value was \"$in_formulation\")");
        (!ref($overwrite)) or push(@_bad_arguments, "Invalid type for argument 3 \"overwrite\" (value was \"$overwrite\")");
        (!ref($save)) or push(@_bad_arguments, "Invalid type for argument 4 \"save\" (value was \"$save\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapfill_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapfill_fbamodel',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_fbamodel',
				       );
    }
}



=head2 $result = runfba(in_model, in_formulation, overwrite, save)



=cut

sub runfba
{
    my($self, @args) = @_;

    if ((my $n = @args) != 4)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function runfba (received $n, expecting 4)");
    }
    {
	my($in_model, $in_formulation, $overwrite, $save) = @args;

	my @_bad_arguments;
        (ref($in_model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        (ref($in_formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"in_formulation\" (value was \"$in_formulation\")");
        (!ref($overwrite)) or push(@_bad_arguments, "Invalid type for argument 3 \"overwrite\" (value was \"$overwrite\")");
        (!ref($save)) or push(@_bad_arguments, "Invalid type for argument 4 \"save\" (value was \"$save\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to runfba:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'runfba');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.runfba",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'runfba',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method runfba",
					    status_line => $self->{client}->status_line,
					    method_name => 'runfba',
				       );
    }
}



=head2 $result = object_to_html(inObject)



=cut

sub object_to_html
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function object_to_html (received $n, expecting 1)");
    }
    {
	my($inObject) = @args;

	my @_bad_arguments;
        (ref($inObject) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"inObject\" (value was \"$inObject\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to object_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'object_to_html');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.object_to_html",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'object_to_html',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method object_to_html",
					    status_line => $self->{client}->status_line,
					    method_name => 'object_to_html',
				       );
    }
}




package fbaModelServicesClient::RpcClient;
use base 'JSON::RPC::Client';

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $obj) = @_;
    my $result;

    if ($uri =~ /\?/) {
       $result = $self->_get($uri);
    }
    else {
        Carp::croak "not hashref." unless (ref $obj eq 'HASH');
        $result = $self->_post($uri, $obj);
    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


1;
