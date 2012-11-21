#!/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use JSON;
use Try::Tiny;

use Bio::KBase::workspaceService;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::GapfillingFormulation;
use fbaModelServicesClient;

our $WORKSPACE_SERVICE_URL = "http://140.221.92.150:8080";
our $FBA_SERVICE_URL = "http://kbase.us/services/fbaModelService";

# Process arguments
my ($job_filename, $job_id);
my $usage = "app.pl --jobfile <filename> --job 32\n";
die $usage unless GetOptions(
    "jobfile=s" => \$job_filename,
    "job=i" => \$job_id,
);
die $usage unless $job_filename && defined $job_id;

# Parse basic jobfile, get job
my ($jobid, $mem, $wall, $auth, $job) = parse_jobfile($job_filename, $job_id);

# Initialize workspace and fbaModelServices clients
my $serv = Bio::KBase::workspaceService->new(
    $WORKSPACE_SERVICE_URL
);
my $fba_serv = fbaModelServicesClient->new(
    $FBA_SERVICE_URL
);
# Fetch objects based on the job
my ($bio, $map, $anno, $model, $fba) = build_objects($job, $auth, $serv);
# Run the fba
my $result = $fba->runFBA();
# Save the results
save_fba_result($job, $result, $auth, $serv);
# Try to notify fba server
try {
    $fba_serv->jobs_done({ jobid => $jobid, authentication => $auth });
};
exit;

# HELPER FUNCTIONS
# Walltime may either be 00:00:00
# or time in seconds
sub parse_walltime {
    my $walltime = shift;
    if ($walltime =~ m/(\d{2}):(\d{2}):(\d{2})/) {
        return $1 * 3600 + $2 * 60 + $3;
    } else {
        return $walltime;
    }
}

# Open JSON file and extract i-th element
sub parse_jobfile {
    my ($filename, $i) = @_;
    my $json;
    {
        die "No file $filename!" unless -f $filename;
        open(my $fh, "<", $filename) 
            or die "Could not open $filename: $!";
        local $/;
        my $str = <$fh>;
        $json = decode_json $str;
        close($fh);
    } 
    return ($json->{jobid}, $json->{mem}, $json->{time}, $json->{auth}, $json->{jobs}->[$i]);
}

# Build objects given a job and a workspace server 
sub build_objects {
    my ($job, $auth, $serv) = @_;
    my $rules = [
        {
            prefix => 'bio',
            type => 'Biochemistry',
            class => 'ModelSEED::MS::Biochemistry',
            link_fn => sub {},
        },
        {   
            # Special case, see for loop below
            prefix => 'media',
        },
        {
            prefix => 'map',
            type => 'Mapping',
            class => 'ModelSEED::MS::Mapping',
            link_fn => sub {
                my ($json, $objs) = @_;
                $json->{biochemistry} = $objs->{bio};
                $json->{biochemistry_uuid} = $objs->{bio}->uuid;
            },
        },
        {
            prefix => 'anno',
            type => 'Annotation',
            class => 'ModelSEED::MS::Annotation',
            link_fn => sub {
                my ($json, $objs) = @_;
                $json->{mapping} = $objs->{map};
                $json->{mapping_uuid} = $objs->{map}->uuid;

            },
        },
        {
            prefix => 'model',
            type => 'Model',
            class => 'ModelSEED::MS::Model',
            link_fn => sub {
                my ($json, $objs) = @_;
                $json->{annotation} = $objs->{anno};
                $json->{annotation_uuid} = $objs->{anno}->uuid;
                $json->{mapping} = $objs->{map};
                $json->{mapping_uuid} = $objs->{map}->uuid;
                $json->{biochemistry} = $objs->{bio};
                $json->{biochemistry_uuid} = $objs->{bio}->uuid;
            },
        },
        {
            prefix => 'fba',
            type => 'FBAObject',
            class => 'ModelSEED::MS::FBAFormulation',
            link_fn => sub {
                my ($json, $objs) = @_;
                $json->{model} = $objs->{model};
                $json->{model_uuid} = $objs->{model}->uuid;
            },
        }
    ];
    my $objs = { bio => undef, 'map' => undef, 'anno' => undef, 'model' => undef, fba => undef };
    foreach my $rule (@$rules) {
        my $prefix  = $rule->{prefix};
        if ($prefix eq 'media') {
            apply_media_to_biochemistry($job, $objs->{bio}, $auth, $serv);
        } else {
            my $ws   = $job->{$prefix."ws"};
            my $id   = $job->{$prefix."id"};
            my $inst = $job->{$prefix."inst"};
            my $conf = {
                workspace => $ws,
                id => $id,
                type => $rule->{type},
                authentication => $auth,
            };
            my ($rtv) = $serv->get_object($conf);
            my $object_json = $rtv->{data};
            $rule->{link_fn}->($object_json, $objs);
            my $class   = $rule->{class};
            $objs->{$prefix} = $class->new($object_json);
        }
    }
    return ( $objs->{bio}, $objs->{map}, $objs->{anno}, $objs->{model}, $objs->{fba}, $objs->{postprocess} );
}

sub apply_media_to_biochemistry {
    my ($job, $bio, $auth, $serv) = @_;
    my $ids        = $job->{mediaids};
    my $workspaces = $job->{mediawss};
    my $instances  = $job->{mediainsts};
    return unless @$ids        == @$workspaces
               && @$workspaces == @$instances
               && @$instances  == @$ids;
    for(my $i=0; $i<@$ids; $i++) {
        my $id = $ids->[$i];
        my $ws = $workspaces->[$i];
        my $inst = $instances->[$i];
        try {
            my ($rtv) = $serv->get_object({
                workspace => $ws,
                id => $id,
                instance => $inst,
                authentication => $auth,
            });
            my $media = $rtv->{data};
            $bio->add("media", $media);
        };
    }
}

sub save_fba_result {
    my ($job, $result, $auth, $serv) = @_;
    my $conf = {
        workspace => $job->{fbaws},
        id => $job->{fbaid},
        type => "FBAObject",
        authentication => $auth,
        data => $result->serializeToDB,
    };
    $serv->save_object($conf);
}
