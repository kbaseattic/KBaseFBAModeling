package Bio::KBase::fbaModelServices::Server;


use Data::Dumper;
use Moose;
use POSIX;
use JSON;
use Bio::KBase::Log;
use Config::Simple;
my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday };
};

use Bio::KBase::AuthToken;

extends 'RPC::Any::Server::JSONRPC::PSGI';

has 'instance_dispatch' => (is => 'ro', isa => 'HashRef');
has 'user_auth' => (is => 'ro', isa => 'UserAuth');
has 'valid_methods' => (is => 'ro', isa => 'HashRef', lazy => 1,
			builder => '_build_valid_methods');
has 'loggers' => (is => 'ro', required => 1, builder => '_build_loggers');
has 'config' => (is => 'ro', required => 1, builder => '_build_config');

our $CallContext;

our %return_counts = (
        'get_models' => 1,
        'get_fbas' => 1,
        'get_gapfills' => 1,
        'get_gapgens' => 1,
        'get_reactions' => 1,
        'get_compounds' => 1,
        'get_alias' => 1,
        'get_aliassets' => 1,
        'get_media' => 1,
        'get_biochemistry' => 1,
        'import_probanno' => 1,
        'genome_object_to_workspace' => 1,
        'genome_to_workspace' => 1,
        'domains_to_workspace' => 1,
        'compute_domains' => 1,
        'add_feature_translation' => 1,
        'genome_to_fbamodel' => 1,
        'translate_fbamodel' => 1,
        'build_pangenome' => 1,
        'genome_heatmap_from_pangenome' => 1,
        'ortholog_family_from_pangenome' => 1,
        'pangenome_to_proteome_comparison' => 1,
        'import_fbamodel' => 1,
        'export_fbamodel' => 1,
        'export_object' => 1,
        'export_genome' => 1,
        'adjust_model_reaction' => 1,
        'adjust_biomass_reaction' => 1,
        'addmedia' => 1,
        'export_media' => 1,
        'runfba' => 1,
        'quantitative_optimization' => 1,
        'generate_model_stats' => 1,
        'minimize_reactions' => 1,
        'export_fba' => 1,
        'import_phenotypes' => 1,
        'simulate_phenotypes' => 1,
        'add_media_transporters' => 1,
        'export_phenotypeSimulationSet' => 1,
        'integrate_reconciliation_solutions' => 1,
        'queue_runfba' => 1,
        'queue_gapfill_model' => 1,
        'gapfill_model' => 1,
        'queue_gapgen_model' => 1,
        'gapgen_model' => 1,
        'queue_wildtype_phenotype_reconciliation' => 1,
        'queue_reconciliation_sensitivity_analysis' => 1,
        'queue_combine_wildtype_phenotype_reconciliation' => 1,
        'run_job' => 1,
        'queue_job' => 1,
        'set_cofactors' => 1,
        'find_reaction_synonyms' => 1,
        'role_to_reactions' => 1,
        'reaction_sensitivity_analysis' => 1,
        'filter_iterative_solutions' => 1,
        'delete_noncontributing_reactions' => 1,
        'annotate_workspace_Genome' => 1,
        'gtf_to_genome' => 1,
        'fasta_to_ProteinSet' => 1,
        'ProteinSet_to_Genome' => 1,
        'fasta_to_ContigSet' => 1,
        'ContigSet_to_Genome' => 1,
        'probanno_to_genome' => 1,
        'get_mapping' => 1,
        'subsystem_of_roles' => 1,
        'adjust_mapping_role' => 1,
        'adjust_mapping_complex' => 1,
        'adjust_mapping_subsystem' => 1,
        'get_template_model' => 1,
        'import_template_fbamodel' => 1,
        'adjust_template_reaction' => 1,
        'adjust_template_biomass' => 1,
        'add_stimuli' => 1,
        'import_regulatory_model' => 1,
        'compare_models' => 1,
        'compare_fbas' => 1,
        'compare_genomes' => 1,
        'import_metagenome_annotation' => 1,
        'models_to_community_model' => 1,
        'metagenome_to_fbamodels' => 1,
        'import_expression' => 1,
        'import_regulome' => 1,
        'create_promconstraint' => 1,
        'add_biochemistry_compounds' => 1,
        'update_object_references' => 1,
        'add_reactions' => 1,
        'remove_reactions' => 1,
        'modify_reactions' => 1,
        'add_features' => 1,
        'remove_features' => 1,
        'modify_features' => 1,
        'import_trainingset' => 1,
        'preload_trainingset' => 1,
        'build_classifier' => 1,
        'classify_genomes' => 1,
        'build_tissue_model' => 1,
        'version' => 1,
);

our %method_authentication = (
        'get_models' => 'optional',
        'get_fbas' => 'optional',
        'get_gapfills' => 'optional',
        'get_gapgens' => 'optional',
        'get_reactions' => 'optional',
        'get_compounds' => 'optional',
        'get_alias' => 'optional',
        'get_aliassets' => 'optional',
        'get_media' => 'optional',
        'get_biochemistry' => 'optional',
        'import_probanno' => 'required',
        'genome_object_to_workspace' => 'required',
        'genome_to_workspace' => 'required',
        'domains_to_workspace' => 'required',
        'compute_domains' => 'required',
        'add_feature_translation' => 'required',
        'genome_to_fbamodel' => 'required',
        'translate_fbamodel' => 'required',
        'build_pangenome' => 'required',
        'genome_heatmap_from_pangenome' => 'required',
        'ortholog_family_from_pangenome' => 'required',
        'pangenome_to_proteome_comparison' => 'required',
        'import_fbamodel' => 'required',
        'export_fbamodel' => 'optional',
        'export_object' => 'optional',
        'export_genome' => 'optional',
        'adjust_model_reaction' => 'required',
        'adjust_biomass_reaction' => 'required',
        'addmedia' => 'required',
        'export_media' => 'optional',
        'runfba' => 'required',
        'quantitative_optimization' => 'required',
        'generate_model_stats' => 'required',
        'minimize_reactions' => 'required',
        'export_fba' => 'optional',
        'import_phenotypes' => 'required',
        'simulate_phenotypes' => 'required',
        'add_media_transporters' => 'required',
        'export_phenotypeSimulationSet' => 'optional',
        'integrate_reconciliation_solutions' => 'required',
        'queue_runfba' => 'required',
        'queue_gapfill_model' => 'required',
        'gapfill_model' => 'required',
        'queue_gapgen_model' => 'required',
        'gapgen_model' => 'required',
        'queue_wildtype_phenotype_reconciliation' => 'required',
        'queue_reconciliation_sensitivity_analysis' => 'required',
        'queue_combine_wildtype_phenotype_reconciliation' => 'required',
        'run_job' => 'required',
        'queue_job' => 'required',
        'set_cofactors' => 'required',
        'find_reaction_synonyms' => 'optional',
        'role_to_reactions' => 'optional',
        'reaction_sensitivity_analysis' => 'required',
        'filter_iterative_solutions' => 'required',
        'delete_noncontributing_reactions' => 'required',
        'annotate_workspace_Genome' => 'required',
        'gtf_to_genome' => 'required',
        'fasta_to_ProteinSet' => 'required',
        'ProteinSet_to_Genome' => 'required',
        'fasta_to_ContigSet' => 'required',
        'ContigSet_to_Genome' => 'required',
        'probanno_to_genome' => 'required',
        'get_mapping' => 'optional',
        'subsystem_of_roles' => 'optional',
        'adjust_mapping_role' => 'required',
        'adjust_mapping_complex' => 'required',
        'adjust_mapping_subsystem' => 'required',
        'get_template_model' => 'optional',
        'import_template_fbamodel' => 'required',
        'adjust_template_reaction' => 'required',
        'adjust_template_biomass' => 'required',
        'add_stimuli' => 'required',
        'import_regulatory_model' => 'required',
        'compare_models' => 'optional',
        'compare_fbas' => 'optional',
        'compare_genomes' => 'optional',
        'import_metagenome_annotation' => 'required',
        'models_to_community_model' => 'required',
        'metagenome_to_fbamodels' => 'required',
        'import_expression' => 'required',
        'import_regulome' => 'required',
        'create_promconstraint' => 'required',
        'add_biochemistry_compounds' => 'required',
        'update_object_references' => 'required',
        'add_reactions' => 'required',
        'remove_reactions' => 'required',
        'modify_reactions' => 'required',
        'add_features' => 'required',
        'remove_features' => 'required',
        'modify_features' => 'required',
        'import_trainingset' => 'required',
        'preload_trainingset' => 'required',
        'build_classifier' => 'required',
        'classify_genomes' => 'required',
        'build_tissue_model' => 'required',
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
        'get_alias' => 1,
        'get_aliassets' => 1,
        'get_media' => 1,
        'get_biochemistry' => 1,
        'import_probanno' => 1,
        'genome_object_to_workspace' => 1,
        'genome_to_workspace' => 1,
        'domains_to_workspace' => 1,
        'compute_domains' => 1,
        'add_feature_translation' => 1,
        'genome_to_fbamodel' => 1,
        'translate_fbamodel' => 1,
        'build_pangenome' => 1,
        'genome_heatmap_from_pangenome' => 1,
        'ortholog_family_from_pangenome' => 1,
        'pangenome_to_proteome_comparison' => 1,
        'import_fbamodel' => 1,
        'export_fbamodel' => 1,
        'export_object' => 1,
        'export_genome' => 1,
        'adjust_model_reaction' => 1,
        'adjust_biomass_reaction' => 1,
        'addmedia' => 1,
        'export_media' => 1,
        'runfba' => 1,
        'quantitative_optimization' => 1,
        'generate_model_stats' => 1,
        'minimize_reactions' => 1,
        'export_fba' => 1,
        'import_phenotypes' => 1,
        'simulate_phenotypes' => 1,
        'add_media_transporters' => 1,
        'export_phenotypeSimulationSet' => 1,
        'integrate_reconciliation_solutions' => 1,
        'queue_runfba' => 1,
        'queue_gapfill_model' => 1,
        'gapfill_model' => 1,
        'queue_gapgen_model' => 1,
        'gapgen_model' => 1,
        'queue_wildtype_phenotype_reconciliation' => 1,
        'queue_reconciliation_sensitivity_analysis' => 1,
        'queue_combine_wildtype_phenotype_reconciliation' => 1,
        'run_job' => 1,
        'queue_job' => 1,
        'set_cofactors' => 1,
        'find_reaction_synonyms' => 1,
        'role_to_reactions' => 1,
        'reaction_sensitivity_analysis' => 1,
        'filter_iterative_solutions' => 1,
        'delete_noncontributing_reactions' => 1,
        'annotate_workspace_Genome' => 1,
        'gtf_to_genome' => 1,
        'fasta_to_ProteinSet' => 1,
        'ProteinSet_to_Genome' => 1,
        'fasta_to_ContigSet' => 1,
        'ContigSet_to_Genome' => 1,
        'probanno_to_genome' => 1,
        'get_mapping' => 1,
        'subsystem_of_roles' => 1,
        'adjust_mapping_role' => 1,
        'adjust_mapping_complex' => 1,
        'adjust_mapping_subsystem' => 1,
        'get_template_model' => 1,
        'import_template_fbamodel' => 1,
        'adjust_template_reaction' => 1,
        'adjust_template_biomass' => 1,
        'add_stimuli' => 1,
        'import_regulatory_model' => 1,
        'compare_models' => 1,
        'compare_fbas' => 1,
        'compare_genomes' => 1,
        'import_metagenome_annotation' => 1,
        'models_to_community_model' => 1,
        'metagenome_to_fbamodels' => 1,
        'import_expression' => 1,
        'import_regulome' => 1,
        'create_promconstraint' => 1,
        'add_biochemistry_compounds' => 1,
        'update_object_references' => 1,
        'add_reactions' => 1,
        'remove_reactions' => 1,
        'modify_reactions' => 1,
        'add_features' => 1,
        'remove_features' => 1,
        'modify_features' => 1,
        'import_trainingset' => 1,
        'preload_trainingset' => 1,
        'build_classifier' => 1,
        'classify_genomes' => 1,
        'build_tissue_model' => 1,
        'version' => 1,
    };
    return $methods;
}

my $DEPLOY = 'KB_DEPLOYMENT_CONFIG';
my $SERVICE = 'KB_SERVICE_NAME';

sub get_config_file
{
    my ($self) = @_;
    if(!defined $ENV{$DEPLOY}) {
        return undef;
    }
    return $ENV{$DEPLOY};
}

sub get_service_name
{
    my ($self) = @_;
    if(!defined $ENV{$SERVICE}) {
        return 'fbaModelServices';
    }
    return $ENV{$SERVICE};
}

sub _build_config
{
    my ($self) = @_;
    my $sn = $self->get_service_name();
    my $cf = $self->get_config_file();
    if (!($cf)) {
        return {};
    }
    my $cfg = new Config::Simple($cf);
    my $cfgdict = $cfg->get_block($sn);
    if (!($cfgdict)) {
        return {};
    }
    return $cfgdict;
}

sub logcallback
{
    my ($self) = @_;
    $self->loggers()->{serverlog}->set_log_file(
        $self->{loggers}->{userlog}->get_log_file());
}

sub log
{
    my ($self, $level, $context, $message, $tag) = @_;
    my $user = defined($context->user_id()) ? $context->user_id(): undef; 
    $self->loggers()->{serverlog}->log_message($level, $message, $user, 
        $context->module(), $context->method(), $context->call_id(),
        $context->client_ip(), $tag);
}

sub _build_loggers
{
    my ($self) = @_;
    my $submod = $self->get_service_name();
    my $loggers = {};
    my $callback = sub {$self->logcallback();};
    $loggers->{userlog} = Bio::KBase::Log->new(
            $submod, {}, {ip_address => 1, authuser => 1, module => 1,
            method => 1, call_id => 1, changecallback => $callback,
	    tag => 1,
            config => $self->get_config_file()});
    $loggers->{serverlog} = Bio::KBase::Log->new(
            $submod, {}, {ip_address => 1, authuser => 1, module => 1,
            method => 1, call_id => 1,
	    tag => 1,
            logfile => $loggers->{userlog}->get_log_file()});
    $loggers->{serverlog}->set_log_level(6);
    return $loggers;
}

#override of RPC::Any::Server
sub handle_error {
    my ($self, $error) = @_;
    
    unless (ref($error) eq 'HASH' ||
           (blessed $error and $error->isa('RPC::Any::Exception'))) {
        $error = RPC::Any::Exception::PerlError->new(message => $error);
    }
    my $output;
    eval {
        my $encoded_error = $self->encode_output_from_exception($error);
        $output = $self->produce_output($encoded_error);
    };
    
    return $output if $output;
    
    die "$error\n\nAlso, an error was encountered while trying to send"
        . " this error: $@\n";
}

#override of RPC::Any::JSONRPC
sub encode_output_from_exception {
    my ($self, $exception) = @_;
    my %error_params;
    if (ref($exception) eq 'HASH') {
        %error_params = %{$exception};
        if(defined($error_params{context})) {
            my @errlines;
            $errlines[0] = $error_params{message};
            push @errlines, split("\n", $error_params{data});
            $self->log($Bio::KBase::Log::ERR, $error_params{context}, \@errlines);
            delete $error_params{context};
        }
    } else {
        %error_params = (
            message => $exception->message,
            code    => $exception->code,
        );
    }
    my $json_error;
    if ($self->_last_call) {
        $json_error = $self->_last_call->return_error(%error_params);
    }
    # Default to default_version. This happens when we throw an exception
    # before inbound parsing is complete.
    else {
        $json_error = $self->_default_error(%error_params);
    }
    return $self->encode_output_from_object($json_error);
}

sub trim {
    my ($str) = @_;
    if (!(defined $str)) {
        return $str;
    }
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub getIPAddress {
    my ($self) = @_;
    my $xFF = trim($self->_plack_req->header("X-Forwarded-For"));
    my $realIP = trim($self->_plack_req->header("X-Real-IP"));
    my $nh = $self->config->{"dont_trust_x_ip_headers"};
    my $trustXHeaders = !(defined $nh) || $nh ne "true";

    if ($trustXHeaders) {
        if ($xFF) {
            my @tmp = split(",", $xFF);
            return trim($tmp[0]);
        }
        if ($realIP) {
            return $realIP;
        }
    }
    return $self->_plack_req->address;
}

sub call_method {
    my ($self, $data, $method_info) = @_;

    my ($module, $method, $modname) = @$method_info{qw(module method modname)};
    
    my $ctx = Bio::KBase::fbaModelServices::ServerContext->new($self->{loggers}->{userlog},
                           client_ip => $self->getIPAddress());
    $ctx->module($modname);
    $ctx->method($method);
    $ctx->call_id($self->{_last_call}->{id});
    
    my $args = $data->{arguments};

{
    # Service fbaModelServices requires authentication.

    my $method_auth = $method_authentication{$method};
    $ctx->authenticated(0);
    if ($method_auth eq 'none')
    {
	# No authentication required here. Move along.
    }
    else
    {
	my $token = $self->_plack_req->header("Authorization");

	if (!$token && $method_auth eq 'required')
	{
	    $self->exception('PerlError', "Authentication required for fbaModelServices but no authentication header was passed");
	}

	my $auth_token = Bio::KBase::AuthToken->new(token => $token, ignore_authrc => 1);
	my $valid = $auth_token->validate();
	# Only throw an exception if authentication was required and it fails
	if ($method_auth eq 'required' && !$valid)
	{
	    $self->exception('PerlError', "Token validation failed: " . $auth_token->error_message);
	} elsif ($valid) {
	    $ctx->authenticated(1);
	    $ctx->user_id($auth_token->user_id);
	    $ctx->token( $token);
	}
    }
}
    my $new_isa = $self->get_package_isa($module);
    no strict 'refs';
    local @{"${module}::ISA"} = @$new_isa;
    local $CallContext = $ctx;
    my @result;
    {
	# 
	# Process tag and metadata information if present.
	#
	my $tag = $self->_plack_req->header("Kbrpc-Tag");
	if (!$tag)
	{
	    my ($t, $us) = &$get_time();
	    $us = sprintf("%06d", $us);
	    my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
	    $tag = "S:$self->{hostname}:$$:$ts";
	}
	local $ENV{KBRPC_TAG} = $tag;
	my $kb_metadata = $self->_plack_req->header("Kbrpc-Metadata");
	my $kb_errordest = $self->_plack_req->header("Kbrpc-Errordest");
	local $ENV{KBRPC_METADATA} = $kb_metadata if $kb_metadata;
	local $ENV{KBRPC_ERROR_DEST} = $kb_errordest if $kb_errordest;

	my $stderr = Bio::KBase::fbaModelServices::ServerStderrWrapper->new($ctx, $get_time);
	$ctx->stderr($stderr);

        my $xFF = $self->_plack_req->header("X-Forwarded-For");
        if ($xFF) {
            $self->log($Bio::KBase::Log::INFO, $ctx,
                "X-Forwarded-For: " . $xFF, $tag);
        }
	
        my $err;
        eval {
            $self->log($Bio::KBase::Log::INFO, $ctx, "start method", $tag);
	    local $SIG{__WARN__} = sub {
		my($msg) = @_;
		$stderr->log($msg);
		print STDERR $msg;
	    };

            @result = $module->$method(@{ $data->{arguments} });
            $self->log($Bio::KBase::Log::INFO, $ctx, "end method", $tag);
        };
	
        if ($@)
        {
            my $err = $@;
	    $stderr->log($err);
	    $ctx->stderr(undef);
	    undef $stderr;
            $self->log($Bio::KBase::Log::INFO, $ctx, "fail method", $tag);
            my $nicerr;
            if(ref($err) eq "Bio::KBase::Exceptions::KBaseException") {
                $nicerr = {code => -32603, # perl error from RPC::Any::Exception
                           message => $err->error,
                           data => $err->trace->as_string,
                           context => $ctx
                           };
            } else {
                my $str = "$err";
                $str =~ s/Bio::KBase::CDMI::Service::call_method.*//s; # is this still necessary? not sure
                my $msg = $str;
                $msg =~ s/ at [^\s]+.pm line \d+.\n$//;
                $nicerr =  {code => -32603, # perl error from RPC::Any::Exception
                            message => $msg,
                            data => $str,
                            context => $ctx
                            };
            }
            die $nicerr;
        }
	$ctx->stderr(undef);
	undef $stderr;
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
    
    return { module => $module, method => $method, modname => $package };
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

__PACKAGE__->mk_accessors(qw(user_id client_ip authenticated token
                             module method call_id hostname stderr));

sub new
{
    my($class, $logger, %opts) = @_;
    
    my $self = {
        %opts,
    };
    chomp($self->{hostname} = `hostname`);
    $self->{hostname} ||= 'unknown-host';
    $self->{_logger} = $logger;
    $self->{_debug_levels} = {7 => 1, 8 => 1, 9 => 1,
                              'DEBUG' => 1, 'DEBUG2' => 1, 'DEBUG3' => 1};
    return bless $self, $class;
}

sub _get_user
{
    my ($self) = @_;
    return defined($self->user_id()) ? $self->user_id(): undef; 
}

sub _log
{
    my ($self, $level, $message) = @_;
    $self->{_logger}->log_message($level, $message, $self->_get_user(),
        $self->module(), $self->method(), $self->call_id(),
        $self->client_ip());
}

sub log_err
{
    my ($self, $message) = @_;
    $self->_log($Bio::KBase::Log::ERR, $message);
}

sub log_info
{
    my ($self, $message) = @_;
    $self->_log($Bio::KBase::Log::INFO, $message);
}

sub log_debug
{
    my ($self, $message, $level) = @_;
    if(!defined($level)) {
        $level = 1;
    }
    if($self->{_debug_levels}->{$level}) {
    } else {
        if ($level =~ /\D/ || $level < 1 || $level > 3) {
            die "Invalid log level: $level";
        }
        $level += 6;
    }
    $self->_log($level, $message);
}

sub set_log_level
{
    my ($self, $level) = @_;
    $self->{_logger}->set_log_level($level);
}

sub get_log_level
{
    my ($self) = @_;
    return $self->{_logger}->get_log_level();
}

sub clear_log_level
{
    my ($self) = @_;
    $self->{_logger}->clear_user_log_level();
}

package Bio::KBase::fbaModelServices::ServerStderrWrapper;

use strict;
use POSIX;
use Time::HiRes 'gettimeofday';

sub new
{
    my($class, $ctx, $get_time) = @_;
    my $self = {
	get_time => $get_time,
    };
    my $dest = $ENV{KBRPC_ERROR_DEST} if exists $ENV{KBRPC_ERROR_DEST};
    my $tag = $ENV{KBRPC_TAG} if exists $ENV{KBRPC_TAG};
    my ($t, $us) = gettimeofday();
    $us = sprintf("%06d", $us);
    my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);

    my $name = join(".", $ctx->module, $ctx->method, $ctx->hostname, $ts);

    if ($dest && $dest =~ m,^/,)
    {
	#
	# File destination
	#
	my $fh;

	if ($tag)
	{
	    $tag =~ s,/,_,g;
	    $dest = "$dest/$tag";
	    if (! -d $dest)
	    {
		mkdir($dest);
	    }
	}
	if (open($fh, ">", "$dest/$name"))
	{
	    $self->{file} = "$dest/$name";
	    $self->{dest} = $fh;
	}
	else
	{
	    warn "Cannot open log file $dest/$name: $!";
	}
    }
    else
    {
	#
	# Log to string.
	#
	my $stderr;
	$self->{dest} = \$stderr;
    }
    
    bless $self, $class;

    for my $e (sort { $a cmp $b } keys %ENV)
    {
	$self->log_cmd($e, $ENV{$e});
    }
    return $self;
}

sub redirect
{
    my($self) = @_;
    if ($self->{dest})
    {
	return("2>", $self->{dest});
    }
    else
    {
	return ();
    }
}

sub redirect_both
{
    my($self) = @_;
    if ($self->{dest})
    {
	return(">&", $self->{dest});
    }
    else
    {
	return ();
    }
}

sub timestamp
{
    my($self) = @_;
    my ($t, $us) = $self->{get_time}->();
    $us = sprintf("%06d", $us);
    my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
    return $ts;
}

sub log
{
    my($self, $str) = @_;
    my $d = $self->{dest};
    my $ts = $self->timestamp();
    if (ref($d) eq 'SCALAR')
    {
	$$d .= "[$ts] " . $str . "\n";
	return 1;
    }
    elsif ($d)
    {
	print $d "[$ts] " . $str . "\n";
	return 1;
    }
    return 0;
}

sub log_cmd
{
    my($self, @cmd) = @_;
    my $d = $self->{dest};
    my $str;
    my $ts = $self->timestamp();
    if (ref($cmd[0]))
    {
	$str = join(" ", @{$cmd[0]});
    }
    else
    {
	$str = join(" ", @cmd);
    }
    if (ref($d) eq 'SCALAR')
    {
	$$d .= "[$ts] " . $str . "\n";
    }
    elsif ($d)
    {
	print $d "[$ts] " . $str . "\n";
    }
	 
}

sub dest
{
    my($self) = @_;
    return $self->{dest};
}

sub text_value
{
    my($self) = @_;
    if (ref($self->{dest}) eq 'SCALAR')
    {
	my $r = $self->{dest};
	return $$r;
    }
    else
    {
	return $self->{file};
    }
}


1;
