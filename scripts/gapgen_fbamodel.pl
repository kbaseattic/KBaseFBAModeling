#!/usr/bin/perl 
#===============================================================================
#
#         FILE: gapgen_fbamodel.pl
#
#        USAGE: ./gapgen_fbamodel.pl [workspace] [model] [options]
#
#  DESCRIPTION: Queues a model for gap generation.
#
#===============================================================================
use strict;
use warnings;
use Getopt::Long::Descriptive;
use Bio::KBase::fbaModelServices::Client;
my $defaultURL = "http://kbase.us/services/fba";

my $config = {
    integrate_solution => [ "integratesol:s", "Integrate first solution in model", 1, "call" ],
	num_solutions => [ "numsol:s", "Number of solutions to obtain", 1, "formulation" ],
	phenotypeSet => [ "phenotypes:s", "Phenotypes to run gapfilling solutions against",undef, "call" ],
	phenotypeSet_workspace => [ "phenotypews:s", "Workspace for phenotypes",undef, "call" ],
	refmedia => [ "refmedia:s", "Reference media in which growth should be preserved",undef, "formulation" ],
	refmedia_workspace => [ "refmediaws:s", "Workspace for reference media",undef, "formulation" ],
	nomediahyp => ["nomediahyp","Set this flag to turn off media hypothesis",0,"formulation"],
	nobiomasshyp => ["nobiomasshyp","Set this flag to turn off biomass hypothesis",0,"formulation"],
	nogprhyp => ["nogprhyp","Set this flag to turn off GPR hypothesis",0,"formulation"],
	nopathwayhyp => ["nopathwayhyp","Set this flag to turn off pathway hypothesis",0,"formulation"],
    media => [ "media:s", "Media condition to run the FBA with", "Complete", "fbaformulation" ],
	media_workspace => [ "mediaws:s", "Media condition to run the FBA with", "Complete", "fbaformulation" ],
    objfraction => [ "objfraction:f", "Objective fraction", 0.1, "fbaformulation" ],
    allreversible => [ "allreversible", "Force all reactions to be reversible", 0, "fbaformulation" ],
    maximizeObjective => [ "maxobjective", "Maximize objective", 1, "fbaformulation" ],
    objectiveTerms => [ "objterms:s@", "Objective terms", [], "fbaformulation", \&parse_terms ],
    rxnko => [ "rxnko:s@", "Comma delimited list of reactions to be knocked out", [], "fbaformulation" ],
    geneko => [ "geneko:s@", "Comma delimited list of genes to be knocked out", [], "fbaformulation" ],
    bounds => [ "bounds:s@", "Comma delimted list of bounds", [], "fbaformulation", \&parse_bounds ],
    uptakelim => [ "uptakelim:s@", "Uptake limits, as comma delimited list of colon delimited key:value pairs.", [], "fbaformulation", \&parse_limits ],
    defaultmaxflux => [ "defaultmaxflux:f", "Maximum flux to use", 100, "fbaformulation" ],
    defaultminupdate => [ "defaultminuptake:f", "Minimum uptake flux to use", -100, "fbaformulation" ],
    simplethermoconst => [ "simplethermoconst" , "Use simple thernmodynamic constraints", 0, "fbaformulation" ],
    thermoconst => [ "thermoconst", "Use standard thermodynamic constraints", 0, "fbaformulation" ],
    nothermoerror => [ "nothermoerror", "Do not include uncertainty in thermodynamic constraints", 0, "fbaformulation" ],
	minthermoerror => [ "minthermoerror","Minimize uncertainty in thermodynamic constraints",  0, "fbaformulation" ],
    donot_submit_job => [ "nosubmit", "Do not actually submit job to cluster", 0, "call" ],
    url => [ "url:s", "URL to use for fbaSerices", $defaultURL, "cli" ],
    fbaworkspace => [ "fba_workspace:s", "Workspace to save FBA results into", undef, "call" ],
	overwrite => ["overwrite","Overwrite existing model with gapfilled model",1,"call"],
	out_model => ["saveas:s","Save gapfilled model to new model name",undef,"call"],
	out_workspace => ["saveworkspace:s","Workspace where gapfilled model should be saved",undef,"call"],
};

my $usage = "$0 <workspace> <model> [options]\n";
my ($rtv, $options) = describe_options(
    "$0 %o <workspace> <model>",
    make_options($config)
);
my ($workspace, $model) = @ARGV;
die $usage unless defined $workspace && defined $model;
my $serv = Bio::KBase::fbaModelServices::Client->new($options->{url});
$options = apply_defaults($options, $config);
$options = process($options, $config);
my $call = get_call($options, $config);
$call->{formulation} = get_formulation($options, $config);;
$call->{model} = $model;
$call->{model_workspace} = $workspace;
my ($res) = $serv->runfba($call);

sub make_options {
    my ($config) = @_;
    my @options;
    foreach my $key (keys %$config) {
        my $c = $config->{$key}->[0];
        my $description = $config->{$key}->[1];
        my $default = $config->{$key}->[2];
        if (defined $default) {
            $description .= " Default: $default";
        }
        push(@options, [ $c, $description ]);
    }
    return @options;
}

sub apply_defaults {
    my ($options, $config) = @_;
    my $new_options = {};
    foreach my $key (keys %$config) {
        my $default = $config->{$key}->[2];
        if (defined $options->{$key})  {
            $new_options->{$key} = $options->{$key};
        } elsif (!defined $options->{$key} && defined $default) {
            $new_options->{$key} = $default;
        }
    }
    return $new_options;
}

sub process {
    my ($options, $config) = @_;
    my $new_options = {};
    foreach my $key (keys %$config) {
        my $fn = $config->{$key}->[4];
        if (defined $fn) {
            $new_options->{$key} = $fn->($options->{$key});
        } elsif (defined $options->{$key}) {
            $new_options->{$key} = $options->{$key};
        }
    }
    return $new_options;
}

sub get_formulation {
    my ($options, $config) = @_;
    my $form = {};
    foreach my $key (keys %$config) {
        next unless defined $options->{$key};
        my $type = $config->{$key}->[3];
        if ($type eq "formulation") {
            $form->{$key} = $options->{$key};
        }
    }
    $form->{formulation} = get_fbaformulation($options,$config);
    return $form;
}

sub get_fbaformulation {
    my ($options, $config) = @_;
    my $form = {};
    foreach my $key (keys %$config) {
        next unless defined $options->{$key};
        my $type = $config->{$key}->[3];
        if ($type eq "fbaformulation") {
            $form->{$key} = $options->{$key};
        }
    }
    return $form;
}

sub get_call {
    my ($options, $config) = @_;
    my $call = {};
    foreach my $key (keys %$config) {
        next unless defined $options->{$key};
        my $type = $config->{$key}->[3];
        if ($type eq "call") {
            $call->{$key} = $options->{$key};
        }
    }
    return $call;
}

# A comma delimited list of semicolon delimited tuples
sub parse_terms {
    my ($terms) = @_;
    my @terms;
    foreach my $set (@$terms) {
        push( @terms, split(/,/, $set) );
    }
    foreach my $term (@terms) {
        $term = [ split(/;/, $term) ];
    }
    return \@terms;
}

# Also a comma delimited list of semicolon delimited tuples
sub parse_bounds {
    return parse_terms(@_);
}

# A comma delimited list of colon delimited key-value pairs
sub parse_limits {
    my ($limits) = @_;
    my @limits;
    my %limits_hash;
    foreach my $limit (@$limits) {
        push( @limits, split(/,/, $limit) );
    }
    foreach my $limit (@limits) {
        my ($k, $v) = split(/:/, $limit);
        $limits_hash{$k} = $v;
    }
    return \%limits_hash;
}