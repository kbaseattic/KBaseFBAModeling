package fbaModelServicesClient;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

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
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




=head2 $result = get_genomeobject(id, options)



=cut

sub get_genomeobject
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_genomeobject (received $n, expecting 2)");
    }
    {
	my($id, $options) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"options\" (value was \"$options\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_genomeobject:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_genomeobject');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_genomeobject",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_genomeobject',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_genomeobject",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_genomeobject',
				       );
    }
}



=head2 $result = genome_to_fbamodel(in_genome)

This function creates a new metabolic model given an input genome id

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
        (!ref($in_genome)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_genome\" (value was \"$in_genome\")");
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
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
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



=head2 $result = fbamodel_to_html(in_model)



=cut

sub fbamodel_to_html
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fbamodel_to_html (received $n, expecting 1)");
    }
    {
	my($in_model) = @args;

	my @_bad_arguments;
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fbamodel_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fbamodel_to_html');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fbamodel_to_html",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'fbamodel_to_html',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fbamodel_to_html",
					    status_line => $self->{client}->status_line,
					    method_name => 'fbamodel_to_html',
				       );
    }
}



=head2 $result = runfba(in_model, formulation)

This function runs flux balance analysis on the input FBAModel and produces HTML as output

=cut

sub runfba
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function runfba (received $n, expecting 2)");
    }
    {
	my($in_model, $formulation) = @args;

	my @_bad_arguments;
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        (ref($formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"formulation\" (value was \"$formulation\")");
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



=head2 $result = fba_check_results(in_fba)



=cut

sub fba_check_results
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fba_check_results (received $n, expecting 1)");
    }
    {
	my($in_fba) = @args;

	my @_bad_arguments;
        (!ref($in_fba)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_fba\" (value was \"$in_fba\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fba_check_results:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fba_check_results');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fba_check_results",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'fba_check_results',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fba_check_results",
					    status_line => $self->{client}->status_line,
					    method_name => 'fba_check_results',
				       );
    }
}



=head2 $result = fba_results_to_html(in_fba)



=cut

sub fba_results_to_html
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fba_results_to_html (received $n, expecting 1)");
    }
    {
	my($in_fba) = @args;

	my @_bad_arguments;
        (!ref($in_fba)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_fba\" (value was \"$in_fba\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fba_results_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fba_results_to_html');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.fba_results_to_html",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'fba_results_to_html',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fba_results_to_html",
					    status_line => $self->{client}->status_line,
					    method_name => 'fba_results_to_html',
				       );
    }
}



=head2 $result = gapfill_model(in_model, formulation)

These functions run gapfilling on the input FBAModel and produce gapfill objects as output

=cut

sub gapfill_model
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_model (received $n, expecting 2)");
    }
    {
	my($in_model, $formulation) = @args;

	my @_bad_arguments;
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        (ref($formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"formulation\" (value was \"$formulation\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapfill_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapfill_model',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_model',
				       );
    }
}



=head2 $result = gapfill_check_results(in_gapfill)



=cut

sub gapfill_check_results
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_check_results (received $n, expecting 1)");
    }
    {
	my($in_gapfill) = @args;

	my @_bad_arguments;
        (!ref($in_gapfill)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapfill\" (value was \"$in_gapfill\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_check_results:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_check_results');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapfill_check_results",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapfill_check_results',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_check_results",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_check_results',
				       );
    }
}



=head2 $result = gapfill_to_html(in_gapfill)



=cut

sub gapfill_to_html
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_to_html (received $n, expecting 1)");
    }
    {
	my($in_gapfill) = @args;

	my @_bad_arguments;
        (!ref($in_gapfill)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapfill\" (value was \"$in_gapfill\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_to_html');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapfill_to_html",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapfill_to_html',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_to_html",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_to_html',
				       );
    }
}



=head2 $result = gapfill_integrate(in_gapfill, in_model)



=cut

sub gapfill_integrate
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_integrate (received $n, expecting 2)");
    }
    {
	my($in_gapfill, $in_model) = @args;

	my @_bad_arguments;
        (!ref($in_gapfill)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapfill\" (value was \"$in_gapfill\")");
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 2 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_integrate:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_integrate');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapfill_integrate",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapfill_integrate',
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_integrate",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_integrate',
				       );
    }
}



=head2 $result = gapgen_model(in_model, formulation)

These functions run gapgeneration on the input FBAModel and produce gapgen objects as output

=cut

sub gapgen_model
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapgen_model (received $n, expecting 2)");
    }
    {
	my($in_model, $formulation) = @args;

	my @_bad_arguments;
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_model\" (value was \"$in_model\")");
        (ref($formulation) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"formulation\" (value was \"$formulation\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapgen_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapgen_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapgen_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapgen_model',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapgen_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapgen_model',
				       );
    }
}



=head2 $result = gapgen_check_results(in_gapgen)



=cut

sub gapgen_check_results
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapgen_check_results (received $n, expecting 1)");
    }
    {
	my($in_gapgen) = @args;

	my @_bad_arguments;
        (!ref($in_gapgen)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapgen\" (value was \"$in_gapgen\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapgen_check_results:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapgen_check_results');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapgen_check_results",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapgen_check_results',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapgen_check_results",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapgen_check_results',
				       );
    }
}



=head2 $result = gapgen_to_html(in_gapgen)



=cut

sub gapgen_to_html
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapgen_to_html (received $n, expecting 1)");
    }
    {
	my($in_gapgen) = @args;

	my @_bad_arguments;
        (!ref($in_gapgen)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapgen\" (value was \"$in_gapgen\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapgen_to_html:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapgen_to_html');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapgen_to_html",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapgen_to_html',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapgen_to_html",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapgen_to_html',
				       );
    }
}



=head2 $result = gapgen_integrate(in_gapgen, in_model)



=cut

sub gapgen_integrate
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapgen_integrate (received $n, expecting 2)");
    }
    {
	my($in_gapgen, $in_model) = @args;

	my @_bad_arguments;
        (!ref($in_gapgen)) or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapgen\" (value was \"$in_gapgen\")");
        (!ref($in_model)) or push(@_bad_arguments, "Invalid type for argument 2 \"in_model\" (value was \"$in_model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapgen_integrate:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapgen_integrate');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.gapgen_integrate",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'gapgen_integrate',
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapgen_integrate",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapgen_integrate',
				       );
    }
}



=head2 $result = get_models(in_model_ids)

This function returns model data for input ids

=cut

sub get_models
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_models (received $n, expecting 1)");
    }
    {
	my($in_model_ids) = @args;

	my @_bad_arguments;
        (ref($in_model_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_model_ids\" (value was \"$in_model_ids\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_models');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_models",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_models',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_models",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_models',
				       );
    }
}



=head2 $result = get_fbas(in_fba_ids)

This function returns fba data for input ids

=cut

sub get_fbas
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_fbas (received $n, expecting 1)");
    }
    {
	my($in_fba_ids) = @args;

	my @_bad_arguments;
        (ref($in_fba_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_fba_ids\" (value was \"$in_fba_ids\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_fbas:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_fbas');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_fbas",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_fbas',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_fbas",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_fbas',
				       );
    }
}



=head2 $result = get_gapfills(in_gapfill_ids)

This function returns gapfill data for input ids

=cut

sub get_gapfills
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_gapfills (received $n, expecting 1)");
    }
    {
	my($in_gapfill_ids) = @args;

	my @_bad_arguments;
        (ref($in_gapfill_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapfill_ids\" (value was \"$in_gapfill_ids\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_gapfills:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_gapfills');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_gapfills",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_gapfills',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_gapfills",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_gapfills',
				       );
    }
}



=head2 $result = get_gapgens(in_gapgen_ids)

This function returns gapgen data for input ids

=cut

sub get_gapgens
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_gapgens (received $n, expecting 1)");
    }
    {
	my($in_gapgen_ids) = @args;

	my @_bad_arguments;
        (ref($in_gapgen_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_gapgen_ids\" (value was \"$in_gapgen_ids\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_gapgens:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_gapgens');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_gapgens",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_gapgens',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_gapgens",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_gapgens',
				       );
    }
}



=head2 $result = get_reactions(in_reaction_ids, biochemistry)

This function returns reaction data for input ids

=cut

sub get_reactions
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_reactions (received $n, expecting 2)");
    }
    {
	my($in_reaction_ids, $biochemistry) = @args;

	my @_bad_arguments;
        (ref($in_reaction_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_reaction_ids\" (value was \"$in_reaction_ids\")");
        (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument 2 \"biochemistry\" (value was \"$biochemistry\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_reactions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_reactions');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_reactions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_reactions',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_reactions",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_reactions',
				       );
    }
}



=head2 $result = get_compounds(in_compound_ids, biochemistry)

This function returns compound data for input ids

=cut

sub get_compounds
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_compounds (received $n, expecting 2)");
    }
    {
	my($in_compound_ids, $biochemistry) = @args;

	my @_bad_arguments;
        (ref($in_compound_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_compound_ids\" (value was \"$in_compound_ids\")");
        (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument 2 \"biochemistry\" (value was \"$biochemistry\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_compounds:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_compounds');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_compounds",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_compounds',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_compounds",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_compounds',
				       );
    }
}



=head2 $result = get_media(in_media_ids, biochemistry)

This function returns media data for input ids

=cut

sub get_media
{
    my($self, @args) = @_;

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_media (received $n, expecting 2)");
    }
    {
	my($in_media_ids, $biochemistry) = @args;

	my @_bad_arguments;
        (ref($in_media_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"in_media_ids\" (value was \"$in_media_ids\")");
        (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument 2 \"biochemistry\" (value was \"$biochemistry\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_media');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_media",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_media',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_media",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_media',
				       );
    }
}



=head2 $result = get_biochemistry(biochemistry)

This function returns biochemistry object

=cut

sub get_biochemistry
{
    my($self, @args) = @_;

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function get_biochemistry (received $n, expecting 1)");
    }
    {
	my($biochemistry) = @args;

	my @_bad_arguments;
        (!ref($biochemistry)) or push(@_bad_arguments, "Invalid type for argument 1 \"biochemistry\" (value was \"$biochemistry\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_biochemistry:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'get_biochemistry');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "fbaModelServices.get_biochemistry",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{code},
					       method_name => 'get_biochemistry',
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method get_biochemistry",
					    status_line => $self->{client}->status_line,
					    method_name => 'get_biochemistry',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "fbaModelServices.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'get_biochemistry',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method get_biochemistry",
            status_line => $self->{client}->status_line,
            method_name => 'get_biochemistry',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for fbaModelServicesClient\n";
    }
    if ($sMajor == 0) {
        warn "fbaModelServicesClient version is $svr_version. API subject to change.\n";
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
