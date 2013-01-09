package Bio::KBase::fbaModelServices::Server;

use Data::Dumper;
use Moose;

extends 'RPC::Any::Server::JSONRPC::PSGI';

has 'instance_dispatch' => (is => 'ro', isa => 'HashRef');
has 'user_auth' => (is => 'ro', isa => 'UserAuth');
has 'valid_methods' => (is => 'ro', isa => 'HashRef', lazy => 1,
			builder => '_build_valid_methods');

our $CallContext;

our %return_counts = (
        'get_models' => 1,
        'get_fbas' => 1,
        'get_gapfills' => 1,
        'get_gapgens' => 1,
        'get_reactions' => 1,
        'get_compounds' => 1,
        'get_media' => 1,
        'get_biochemistry' => 1,
        'genome_object_to_workspace' => 1,
        'genome_to_workspace' => 1,
        'add_feature_translation' => 1,
        'genome_to_fbamodel' => 1,
        'export_fbamodel' => 1,
        'adjust_model_reaction' => 1,
        'adjust_biomass_reaction' => 1,
        'addmedia' => 1,
        'export_media' => 1,
        'runfba' => 1,
        'export_fba' => 1,
        'import_phenotypes' => 1,
        'simulate_phenotypes' => 1,
        'export_phenotypeSimulationSet' => 1,
        'integrate_reconciliation_solutions' => 1,
        'queue_runfba' => 1,
        'queue_gapfill_model' => 1,
        'queue_gapgen_model' => 1,
        'queue_wildtype_phenotype_reconciliation' => 1,
        'queue_reconciliation_sensitivity_analysis' => 1,
        'queue_combine_wildtype_phenotype_reconciliation' => 1,
        'jobs_done' => 1,
        'check_job' => 1,
        'run_job' => 1,
        'version' => 1,
);



sub _build_valid_methods
{
    my($self) = @_;
    my $methods = {
        'get_models' => 1,
        'get_fbas' => 1,
        'get_gapfills' => 1,
        'get_gapgens' => 1,
        'get_reactions' => 1,
        'get_compounds' => 1,
        'get_media' => 1,
        'get_biochemistry' => 1,
        'genome_object_to_workspace' => 1,
        'genome_to_workspace' => 1,
        'add_feature_translation' => 1,
        'genome_to_fbamodel' => 1,
        'export_fbamodel' => 1,
        'adjust_model_reaction' => 1,
        'adjust_biomass_reaction' => 1,
        'addmedia' => 1,
        'export_media' => 1,
        'runfba' => 1,
        'export_fba' => 1,
        'import_phenotypes' => 1,
        'simulate_phenotypes' => 1,
        'export_phenotypeSimulationSet' => 1,
        'integrate_reconciliation_solutions' => 1,
        'queue_runfba' => 1,
        'queue_gapfill_model' => 1,
        'queue_gapgen_model' => 1,
        'queue_wildtype_phenotype_reconciliation' => 1,
        'queue_reconciliation_sensitivity_analysis' => 1,
        'queue_combine_wildtype_phenotype_reconciliation' => 1,
        'jobs_done' => 1,
        'check_job' => 1,
        'run_job' => 1,
        'version' => 1,
    };
    return $methods;
}

sub call_method {
    my ($self, $data, $method_info) = @_;

    my ($module, $method) = @$method_info{qw(module method)};
    
    my $ctx = Bio::KBase::fbaModelServices::ServerContext->new(client_ip => $self->_plack_req->address);
    
    my $args = $data->{arguments};

    # Service fbaModelServices does not require authentication.
    
    my $new_isa = $self->get_package_isa($module);
    no strict 'refs';
    local @{"${module}::ISA"} = @$new_isa;
    local $CallContext = $ctx;
    my @result;
    {
	my $err;
	eval {
	    @result = $module->$method(@{ $data->{arguments} });
	};
	if ($@)
	{
	    #
	    # Reraise the string version of the exception because
	    # the RPC lib can't handle exception objects (yet).
	    #
	    my $err = $@;
	    my $str = "$err";
	    $str =~ s/Bio::KBase::CDMI::Service::call_method.*//s;
	    $str =~ s/^/>\t/mg;
	    die "The JSONRPC server invocation of the method \"$method\" failed with the following error:\n" . $str;
	}
    }
    my $result;
    if ($return_counts{$method} == 1)
    {
        $result = [[$result[0]]];
    }
    else
    {
        $result = \@result;
    }
    return $result;
}


sub get_method
{
    my ($self, $data) = @_;
    
    my $full_name = $data->{method};
    
    $full_name =~ /^(\S+)\.([^\.]+)$/;
    my ($package, $method) = ($1, $2);
    
    if (!$package || !$method) {
	$self->exception('NoSuchMethod',
			 "'$full_name' is not a valid method. It must"
			 . " contain a package name, followed by a period,"
			 . " followed by a method name.");
    }

    if (!$self->valid_methods->{$method})
    {
	$self->exception('NoSuchMethod',
			 "'$method' is not a valid method in service fbaModelServices.");
    }
	
    my $inst = $self->instance_dispatch->{$package};
    my $module;
    if ($inst)
    {
	$module = $inst;
    }
    else
    {
	$module = $self->get_module($package);
	if (!$module) {
	    $self->exception('NoSuchMethod',
			     "There is no method package named '$package'.");
	}
	
	Class::MOP::load_class($module);
    }
    
    if (!$module->can($method)) {
	$self->exception('NoSuchMethod',
			 "There is no method named '$method' in the"
			 . " '$package' package.");
    }
    
    return { module => $module, method => $method };
}

package Bio::KBase::fbaModelServices::ServerContext;

use strict;

=head1 NAME

Bio::KBase::fbaModelServices::ServerContext

head1 DESCRIPTION

A KB RPC context contains information about the invoker of this
service. If it is an authenticated service the authenticated user
record is available via $context->user. The client IP address
is available via $context->client_ip.

=cut

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw(user_id client_ip authenticated));

sub new
{
    my($class, %opts) = @_;
    
    my $self = {
	%opts,
    };
    return bless $self, $class;
}

1;
