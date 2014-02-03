use FindBin qw($Bin);
use lib $Bin.'/../lib';
use lib $Bin.'/../../workspace_service/lib/';
use lib $Bin.'/../../kb_seed/lib/';
use lib $Bin.'/../../idserver/lib/';
use lib "/kb/deployment/lib/perl5/site_perl/5.16.0/Bio/";
use lib "/kb/deployment/lib/perl5/site_perl/5.16.1/";
use Bio::KBase::workspaceService::Impl;
use LWP::Simple qw(getstore);
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);
use Bio::KBase::fbaModelServices::Impl;
use JSON::XS;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
my $test_count = 25;

$ENV{KB_SERVICE_NAME}="fbaModelServices";
$ENV{KB_DEPLOYMENT_CONFIG}=$Bin."/../configs/test.cfg";
$ENV{MODELSEED_CONF}=$Bin."/../configs/testconfig.json";
my $obj = Bio::KBase::fbaModelServices::Impl->new({workspace => $ws});
################################################################################
#Tests 0: loading template model
################################################################################
my $temp = $obj->import_template_fbamodel(_processTemplateFiles());
ok defined($temp), "Successfully imported template!";

################################################################################
#Tests 1-3: retrieving a biochemistry object and reaction and compound data
################################################################################
#Testing biochemistry retrieval method
my $biochemistry = $obj->get_biochemistry({});
ok defined($biochemistry), "Successfully printed biochemistry!";

#Testing reaction retrieval method
my $rxns = $obj->get_reactions({
	reactions => ["rxn00001","rxn00002"],
});
ok defined($rxns->[0]), "Successfully printed reactions!";

#Testing compound retrieval method
my $cpds = $obj->get_compounds({
	compounds => ["cpd00001","cpd00002"]
});
ok defined($cpds->[0]), "Successfully printed compounds!";
################################################################################
#Tests 4: adding a genome object to the database
################################################################################
my $genome = $obj->genome_to_workspace({
	genome => "kb|g.0",
	workspace => "testworkspace"
});
ok defined($genome), "Successfully loaded genome object to workspace!";
################################################################################
#Tests 5-7: adding and retrieving a media formulation
################################################################################
#Now adding media formulation to workspace
my $media = $obj->addmedia({
	media => "CustomMedia",
	workspace => "testworkspace",
	name => "CustomMedia",
	isDefined => 1,
	isMinimal => 1,
	type => "Minimal media",
	compounds => ["H2O","cpd00002","ADP"],
	concentrations => [0.001,0.001,0.001],
	maxflux => [1000,1000,1000],
	minflux => [-1000,-1000,-1000]
});
ok defined($media), "Media successfully added to workspace!";

#Now exporting media formulation
my $html = $obj->export_media({
	media => $media->[0],
	workspace => "testworkspace",
	format => "html",
});
ok defined($html), "Successfully exported media to html format!";

#Testing media retrieval method
my $medias = $obj->get_media({
	medias => ["Carbon-D-Glucose","CustomMedia"],
	workspaces => ["NO_WORKSPACE","testworkspace"],
});
ok defined($medias->[0]), "Successfully printed media!";
################################################################################
#Test 8-12: building and exporting an metabolic model
################################################################################
#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	genome => $genome->[0],
	workspace => "testworkspace",
	coremodel => 1
});
ok defined($model), "Model successfully constructed from input genome!";
#Testing model export
my $cytoseed = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "cytoseed"
});
ok defined($cytoseed), "Successfully exported model to cytoseed format!";

$html = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported model to html format!";

my $sbml = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "sbml"
});
ok defined($sbml), "Successfully exported model to sml format!";

my $mdls = $obj->get_models({
	models => [$model->[0]],
	workspaces => ["testworkspace"],
});
ok defined($mdls->[0]), "Successfully printed model data!";

################################################################################
#Test 13-15: importing a phenotypes set, simulating phenotypes, and export simulation results
################################################################################
#Now test phenotype import
my $phenos = $obj->import_phenotypes({
	workspace => "testworkspace",
	genome => $genome->[0],
	genome_workspace => "testworkspace",
	phenotypes => [
		[[],"CustomMedia","testworkspace",["ADP"],1],
		[[],"Carbon-D-Glucose","NO_WORKSPACE",["H2O"],1],
		[["kb|g.0.peg.1","kb|g.0.peg.2"],"Carbon-Glycerol","NO_WORKSPACE",[],1]
	],
	notes => ""
});
ok defined($phenos), "Successfully imported phenotypes!";

#Now test phenotype simulation
my $phenosim = $obj->simulate_phenotypes({
	model => $model->[0],
	model_workspace => "testworkspace",
	phenotypeSet => $phenos->[0],
	workspace => "testworkspace",
	formulation => {},
	notes => "",
});
ok defined($phenosim), "Successfully simulated phenotypes!";

#Now test phenotype simulation export
$html = $obj->export_phenotypeSimulationSet({
	phenotypeSimulationSet => $phenosim->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported phenotype simulations to html format!";

################################################################################
#Test 6: runfba, gapfill, and gapgen
################################################################################
#Now test flux balance analysis
my $fba = $obj->runfba({
	model => $model->[0],
	model_workspace => "testworkspace",
	formulation => {
		media => "CustomMedia",
		media_workspace => "testworkspace"
	},
	fva => 0,
	simulateko => 0,
	minimizeflux => 0,
	findminmedia => 0,
	notes => "",
	workspace => "testworkspace"
});
ok defined($fba), "FBA successfully run on input model!";

#Testing fba retrieval method
my $fbas = $obj->get_fbas({
	fbas => [$fba->[0]],
	workspaces => ["testworkspace"],
});
ok defined($fbas->[0]), "Successfully printed fba data!";

#Now test flux balance analysis export
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported FBA to html format!";

#Now test the queue fba function, without submitting the job to the cluster
my $job = $obj->queue_runfba({
	model => $model->[0],
	model_workspace => "testworkspace",
	formulation => {
		media => "CustomMedia",
		media_workspace => "testworkspace"
	},
	fva => 0,
	simulateko => 0,
	minimizeflux => 0,
	findminmedia => 0,
	notes => "",
	workspace => "testworkspace",
});
ok defined($job), "FBA successfully queued for input model!";

#Now running queued FBA job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	job => $job->{id},
	workspace => "testworkspace"
});
ok defined($job), "Successfully ran queued FBA job!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $job->{jobdata}->{fbaref},
	workspace => "NO_WORKSPACE",
	format => "html"
});
ok defined($html), "Successfully exported FBA to html format!";

#Now queuing gapfilling in complete media
$job = $obj->queue_gapfill_model({
	model => $model->[0],
	workspace => "testworkspace",
	formulation => {
		formulation => {
			media => "CustomMedia",
			media_workspace => "testworkspace"
		},
		num_solutions => 1
	},
	integrate_solution => 1,
	out_model => $model->[0].".gf",
});
ok defined($html), "Successfully queued gapfill job!";

##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	job => $job->{id},
#	workspace => "testworkspace"
#});
#ok defined($job), "Successfully ran queued gapfill job!";
#
##Now queuing gapfilling in custom media
#$job = $obj->queue_gapfill_model({
#	model => $model->[0].".gf",
#	workspace => "testworkspace",
#	formulation => {
#		formulation => {
#			media => "Complete",
#			media_workspace => "NO_WORKSPACE"
#		},
#		num_solutions => 1
#	},
#	integrate_solution => 1,
#	out_model => $model->[0].".gf2",
#	donot_submit_job => 1
#});
#ok defined($html), "Successfully queued gapfill job!";
#
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->{id},
#	workspace => "testworkspace"
#});
#ok defined($job), "Successfully ran queued gapfill job!";

##Now test flux balance analysis
#$fba = $obj->runfba({
#	model => $model->[0].".gf2",
#	model_workspace => "testworkspace",
#	formulation => {
#		media => "CustomMedia",
#		media_workspace => "testworkspace"
#	},
#	fva => 0,
#	simulateko => 0,
#	minimizeflux => 0,
#	findminmedia => 0,
#	notes => "",
#	workspace => "testworkspace"
#});
#ok defined($fba), "FBA successfully run on gapfilled model!";
#
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $fba->[0],
#	workspace => "testworkspace",
#	format => "html"
#});
#ok defined($html), "Successfully exported FBA to html format!";

##Now exporting queued FBA
#$job = $obj->queue_gapgen_model({
#	model => $model->[0].".gf2",
#	workspace => "testworkspace",
#	formulation => {
#		formulation => {
#			media => "CustomMedia",
#			media_workspace => "testworkspace"
#		},
#		refmedia => "Complete",
#		refmedia_workspace => "NO_WORKSPACE",
#		num_solutions => 1
#	},
#	integrate_solution => 1,
#	out_model => $model->[0].".gg",
#	donot_submit_job => 1
#});
#ok defined($html), "Successfully queued gapgen job!";

#Now checking job retreival
my $jobs = $obj->_workspaceServices()->get_jobs({status => "done"});
ok @{$jobs} >= 3,"Correct number of done jobs in the job queue!";
$jobs = $obj->_workspaceServices()->get_jobs({status => "queued"});
ok @{$jobs} >= 1,"Correct number of queued jobs in the job queue!";

##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	job => $job->{id},
#	workspace => "testworkspace"
#});
#ok defined($job), "Successfully ran queued gapgen job!";
#
##Now test flux balance analysis
#$fba = $obj->runfba({
#	model => $model->[0].".gg",
#	model_workspace => "testworkspace",
#	formulation => {
#		media => "CustomMedia",
#		media_workspace => "testworkspace"
#	},
#	fva => 0,
#	simulateko => 0,
#	minimizeflux => 0,
#	findminmedia => 0,
#	notes => "",
#	workspace => "testworkspace"
#});
#ok defined($fba), "FBA successfully run on gapgen model!";

##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $fba->[0],
#	workspace => "testworkspace",
#	format => "html"
#});
#ok defined($html), "Successfully exported FBA to html format!";

if (!defined($ENV{NO_TEST_MONGO})) {
	&mongo_down;
}

## check for error messages from tests
#if ($return) {
#   print $return;
#   exit(100);
#}

done_testing($test_count);

sub _processTemplateFiles {
	my $url = "http://bioseed.mcs.anl.gov/~chenry/TemplateModelFiles/";
	my ($fh2, $filename) = tempfile();
	close($fh2);
	my $status = getstore($url."CoreReactions", $filename);
	die "Unable to fetch template file\n" unless($status == 200);
	my $rxnTbl = _loadTableFile($filename);
	$status = getstore($url."CoreBiomass", $filename);
	die "Unable to fetch template file\n" unless($status == 200);
	my $bioTbl = _loadTableFile($filename);
	$status = getstore($url."CoreBiomassComps", $filename);
	die "Unable to fetch template file\n" unless($status == 200);
	my $bioCompTbl = _loadTableFile($filename);
	my $tempRxns = [];
	my $tempBioComp = [];
	my $tempBio = [];
	for (my $i=0; $i < @{$rxnTbl->{data}}; $i++) {
		my $rxnRow = [
			$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{id}],
			$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{compartment}],
			$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{direction}],
			$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{type}],
			[split(/\|/,$rxnTbl->{data}->[$i]->[$rxnTbl->{headings}->{complexes}])]
		];
		push(@{$tempRxns},$rxnRow);
	}
	my $bioNameHash;
	for (my $i=0; $i < @{$bioTbl->{data}}; $i++) {
		my $bioRow = [
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{name}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{type}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{dna}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{rna}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{protein}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{lipid}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{cellwall}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{cofactor}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{energy}],
			$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{other}]
		];
		$bioNameHash->{$bioTbl->{data}->[$i]->[$bioTbl->{headings}->{name}]} = @{$tempBio};
		push(@{$tempBio},$bioRow);
	}
	for (my $i=0; $i < @{$bioCompTbl->{data}}; $i++) {
		if (defined($bioNameHash->{$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{biomass}]})) {
			my $index = $bioNameHash->{$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{biomass}]};
			my $links = [split(/;/,$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{linked}])];
			for (my $j=0; $j < @{$links}; $j++) {
				$links->[$j] = [split(/:/,$links->[$j])];
			}
			my $bioRow = [
				$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{id}],
				$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{compartment}],
				$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{class}],
				$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{coefficientType}],
				$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{coefficient}],
				$bioCompTbl->{data}->[$i]->[$bioCompTbl->{headings}->{conditions}],
				$links
			];
			push(@{$tempBio->[$index]->[10]},$bioRow);
		}
	}
	return {
		templateReactions => $tempRxns,
		templateBiomass => $tempBio,
		name => "CoreModelTemplate",
		id => "CoreModelTemplate",
		workspace => "KBaseTemplateModels",
		domain => "Bacteria",
		modelType => "CoreModel"
	};
}

sub _loadTableFile {
	my ($filename) = @_;
	if (!-e $filename) {
		print "Could not open table file ".$filename."!\n";
		exit();
	}
	open(my $fh, "<", $filename) || return;
	my $headingline = <$fh>;
	my $tbl;
	chomp($headingline);
	my $headings = [split(/\t/,$headingline)];
	for (my $i=0; $i < @{$headings}; $i++) {
		$tbl->{headings}->{$headings->[$i]} = $i;
	}
	while (my $line = <$fh>) {
		chomp($line);
		push(@{$tbl->{data}},[split(/\t/,$line)]);
	}
	close($fh);
	return $tbl;
}

sub mongo_up {
	unless(-e "/data") {
		mkdir "/data" or die "cannot mkdir /data for mongo";
	}
	unless(-e "/mnt/db") {
		mkdir "/mnt/db" or die "cannot mkdir /mnt/db for mongo";
	}
	unless(-e "/data/db") {
		symlink("/mnt/db","/data/db") or die "cannot symlink to /data/db for mongo";
	}
	unless (system("$ENV{KB_RUNTIME}/bin/mongod", 
	        "--dbpath=/data/db",
		"--pidfilepath=/tmp/mongo.$$.pid",
		"--logpath=/tmp/mongo.$$.log",
		"--fork") == 0 ) {
		die "could not start mongod";
	} 
}

sub mongo_down {
	my $pid = `cat /tmp/mongo.$$.pid`;
	if (length($pid) > 0) {
		chomp $pid;
		unless (system("kill",  "-9", "$pid") == 0 ) {
			die "could not stop mongod with pid=$pid";
		}
		unlink "/tmp/mongo.$$.pid";
		unlink "/tmp/mongo.$$.log";
	}
}

sub workspace_up {
	if (-e $ENV{TARGET}."/services/workspaceService/service.pid") {
		system($ENV{TARGET}."/services/workspaceService/stop_service");
	}
	system($ENV{TARGET}."/services/workspaceService/start_service"); 
}

sub workspace_down {
	system($ENV{TARGET}."/services/workspaceService/stop_service");
}