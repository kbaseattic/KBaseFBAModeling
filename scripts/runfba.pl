########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use Getopt::Long::Descriptive;
use fbaModelServicesClient;
my $defaultURL = "http://kbase.us/services/fba";
my $config = {
    url => [ "url:s", "URL to use for fbaSerices", $defaultURL, "cli" ],
    fba_workspace => [ "fba_workspace:s", "Workspace to save FBA results into", undef, "call" ],
    fva => [ "fva", "Perform flux variability analysis", 0, "both" ],
    simulateko => [ "simulateko", "Simulate single gene knockouts", 0, "both" ],
    minimizeflux => [ "minimizeflux", "Minimize flux value", 0, "call" ],
    findminmedia => [ "findminmedia", "Find minimal media condition", 0, "call" ],
    notes => [ "notes:s", "Notes to add to FBA result", "", "call" ],
    save_as => [ "saveas:s", "Save FBA results as this", undef, "call" ],
    overwrite => [ "overwrite", "Overwrite existing results in workspace", 0, "call" ],
    add_to_model => [ "add_to_model", "Add FBA result to model", 0, "call" ],
    media => [ "media:s", "Media condition to run the FBA with", "Complete", "form" ],
    objfraction => [ "objfraction:f", "Objective fraction", 0.1, "form" ],
    allreversible => [ "allreversible", "Force all reactions to be reversible", 0, "form" ],
    maximizeObjective => [ "maximizeObjective", "Maximize objective", 1, "form" ],
    objectiveTerms => [ "objectiveterms:s@", "Objective terms", [], "form", \&parse_terms ],
    rxnko => [ "rxnko:s@", "Comma delimited list of reactions to be knocked out", [], "form" ],
    geneko => [ "geneko:s@", "Comma delimited list of genes to be knocked out", [], "form" ],
    bounds => [ "bounds:s@", "Comma delimted list of bounds", [], "form", \&parse_bounds ],
    uptakelim => [ "uptakelim:s@", "Uptake limits, as comma delimited list of colon delimited key:value pairs.", [], "form", \&parse_limits ],
    defaultmaxflux => [ "defaultmaxflux:f", "Maximum flux to use", 100, "form" ],
    defaultminupdate => [ "defaultminuptake:f", "Minimum uptake flux to use", -100, "form" ],
    simplethermoconst => [ "simplethermoconst" , "Use simple thernmodynamic constraints", 0, "form" ],
    thermoconst => [ "thermoconst", "Use standard thermodynamic constraints", 0, "form" ],
    nothermoerror => [ "nothermoerror", "Do not include uncertainty in thermodynamic constraints", 0, "form" ],
	minthermoerror => [ "minthermoerror","Minimize uncertainty in thermodynamic constraints",  0, "form" ],
};
my $usage = "$0 <workspace> <model> [options]\n";
my ($rtv, $options) = describe_options(
    "$0 %o <workspace> <model>",
    make_options($config)
);
my ($workspace, $model) = @ARGV;
die $usage unless defined $workspace && defined $model;
my $serv = fbaModelServicesClient->new($options->{url});
$options = apply_defaults($options, $config);
$options = process($options, $config);
my $fba  = get_formulation($options, $config);
my $call = get_call($options, $config);
$call->{formulation} = $fba;
$call->{model} = $model;
$call->{model_workspace} = $workspace;
if (!defined($call->{fba_workspace})) {
    $call->{fba_workspace} = $workspace;
}
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
        if ($type eq "form" || $type eq "both") {
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
        if ($type eq "call" || $type eq "both" ) {
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
