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
my $test_count = 33;

################################################################################
#Test intiailization: setting test config, instantiating Impl, getting auth token
################################################################################
$ENV{KB_SERVICE_NAME}="workspaceService";
$ENV{KB_DEPLOYMENT_CONFIG}=$Bin."/../configs/test.cfg";
my $ws = Bio::KBase::workspaceService::Impl->new();
$ws->_clearAllWorkspaces();
$ws->_clearAllWorkspaceObjects();
$ws->_clearAllWorkspaceUsers();
$ws->_clearAllWorkspaceDataObjects();
$ws->_initializeWorkspace();
$ws->create_workspace({
	workspace => "testworkspace",
	default_permission => "n"
});
$ENV{KB_SERVICE_NAME}="fbaModelServices";
$ENV{KB_DEPLOYMENT_CONFIG}=$Bin."/../configs/test.cfg";
my $obj = Bio::KBase::fbaModelServices::Impl->new({workspace => $ws});
################################################################################
#Tests 1-3: retrieving a biochemistry object and reaction and compound data
################################################################################
#Testing biochemistry retrieval method
my $biochemistry = $obj->get_biochemistry({});
ok defined($biochemistry), "Successfully printed biochemistry!";

#Testing reaction retrieval method
my $rxns = $obj->get_reactions({
	reactions => ["rxn1","rxn2"],
	biochemistry => "testdefault"
});
ok defined($rxns->[0]), "Successfully printed reactions!";

#Testing compound retrieval method
my $cpds = $obj->get_compounds({
	compounds => ["A","B"],
	biochemistry => "testdefault"
});
ok defined($cpds->[0]), "Successfully printed compounds!";

################################################################################
#Tests 4: adding a genome object to the database
################################################################################
my $url = "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/genome.test.json";
my ($fh, $uncompressed_filename) = tempfile();
my $status = getstore($url, $uncompressed_filename);
open($fh, "<", $uncompressed_filename) || die "$!: $@";
my @strings = <$fh>;
my $genomeObj = JSON::XS->new->utf8->decode(join("",@strings));
my $genome = $obj->genome_object_to_workspace({
	genomeobj => $genomeObj,
	workspace => "testworkspace",
	mapping => "testdefault",
	mapping_workspace => "kbase"
});
ok defined($cpds->[0]), "Successfully loaded genome object to workspace!";
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
	compounds => ["C name","D name","B name"],
	concentrations => [0.001,0.001,0.001],
	maxflux => [1000,1000,1000],
	minflux => [-1000,-1000,-1000],
	biochemistry => "testdefault"
});
ok defined($media), "Media successfully added to workspace!";

#Now exporting media formulation
my $html = $obj->export_media({
	media => $media->[0],
	workspace => "testworkspace",
	format => "html",
	biochemistry => "testdefault"
});
ok defined($html), "Successfully exported media to html format!";
#open ( $fh, ">", "media.html");
#print $fh $html."\n";
#close($fh);

#Testing media retrieval method
my $medias = $obj->get_media({
	medias => ["Media1","CustomMedia"],
	workspaces => ["kbasecdm","testworkspace"],
	biochemistry => "testdefault"
});
ok defined($medias->[0]), "Successfully printed media!";
################################################################################
#Test 8-12: building and exporting an metabolic model
################################################################################
#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	genome => $genome->[0],
	workspace => "testworkspace",
});
ok defined($model), "Model successfully constructed from input genome!";
#Testing model export
my $cytoseed = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "cytoseed"
});
ok defined($cytoseed), "Successfully exported model to cytoseed format!";
#open ( $fh, ">", "model.cytoseed");
#print $fh $cytoseed."\n";
#close($fh);

$html = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported model to html format!";
#open ( $fh, ">", "model.html");
#print $fh $html."\n";
#close($fh);

my $sbml = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "sbml"
});
ok defined($sbml), "Successfully exported model to sml format!";
#open ( $fh, ">", "model.sbml");
#print $fh $sbml."\n";
#close($fh);

#Testing model retrieval method
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
		[[],"CustomMedia","testworkspace",["D name"],1],
		[[],"Media1","kbasecdm",["A name"],1],
		[["kb|g.0.peg.1","kb|g.0.peg.2"],"Media2","kbasecdm",[],1]
	],
	notes => "",
	biochemistry => "testdefault"
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
#open ( my $fh, ">", "PhenotypeSim.html");
#print $fh $html."\n";
#close($fh);

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
#open ( $fh, ">", "fba.html");
#print $fh $html."\n";
#close($fh);

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
	donot_submit_job => 1
});
ok defined($job), "FBA successfully queued for input model!";

#Now running queued FBA job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "testworkspace"
});
ok defined($job), "Successfully ran queued FBA job!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $job->{clusterjobs}->[0]->{fbaid},
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported FBA to html format!";
#open ( $fh, ">", "fba2.html");
#print $fh $html."\n";
#close($fh);

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
	donot_submit_job => 1
});
ok defined($html), "Successfully queued gapfill job!";

#Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "testworkspace"
});
ok defined($job), "Successfully ran queued gapfill job!";

#Now queuing gapfilling in custom media
$job = $obj->queue_gapfill_model({
	model => $model->[0].".gf",
	workspace => "testworkspace",
	formulation => {
		formulation => {
			media => "Complete",
			media_workspace => "kbasecdm"
		},
		num_solutions => 1
	},
	integrate_solution => 1,
	out_model => $model->[0].".gf2",
	donot_submit_job => 1
});
ok defined($html), "Successfully queued gapfill job!";

#Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "testworkspace"
});
ok defined($job), "Successfully ran queued gapfill job!";

#Now test flux balance analysis
$fba = $obj->runfba({
	model => $model->[0].".gf2",
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
ok defined($fba), "FBA successfully run on gapfilled model!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported FBA to html format!";
#open ( $fh, ">", "fba-GapFill.html");
#print $fh $html."\n";
#close($fh);

#Now exporting queued FBA
$job = $obj->queue_gapgen_model({
	model => $model->[0].".gf2",
	workspace => "testworkspace",
	formulation => {
		formulation => {
			media => "CustomMedia",
			media_workspace => "testworkspace"
		},
		refmedia => "Complete",
		refmedia_workspace => "kbasecdm",
		num_solutions => 1
	},
	integrate_solution => 1,
	out_model => $model->[0].".gg",
	donot_submit_job => 1
});
ok defined($html), "Successfully queued gapgen job!";

#Now checking job retreival
my $jobs = $obj->_workspaceServices()->get_jobs({status => "done"});
ok @{$jobs} >= 3,"Correct number of done jobs in the job queue!";
$jobs = $obj->_workspaceServices()->get_jobs({status => "queued"});
ok @{$jobs} >= 1,"Correct number of queued jobs in the job queue!";

#Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "testworkspace"
});
ok defined($job), "Successfully ran queued gapgen job!";

#Now test flux balance analysis
$fba = $obj->runfba({
	model => $model->[0].".gg",
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
ok defined($fba), "FBA successfully run on gapgen model!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported FBA to html format!";
#open ( $fh, ">", "fba-Gapgen.html");
#print $fh $html."\n";
#close($fh);

##Now test ability to retrieve annotated genome object from database
#my $cdmgenome = $obj->genome_to_workspace({
#	genome => "kb|g.1",
#	workspace => "testworkspace"
#});
#ok defined($cdmgenome), "Genome successfully imported to workspace from CDM!"; 

done_testing($test_count);

sub _loadBiochemToDB {
	my ($ws) = @_;
	my $url = "http://bioseed.mcs.anl.gov/~chenry/exampleObjects/defaultBiochem.json.gz";
	my ($fh1, $compressed_filename) = tempfile();
	my ($fh2, $uncompressed_filename) = tempfile();
	close($fh1);
	close($fh2);
	my $status = getstore($url, $compressed_filename);
	die "Unable to fetch from model_seed\n" unless($status == 200);
	gunzip $compressed_filename => $uncompressed_filename;
	local $/;
	open(my $fh, "<", $uncompressed_filename) || die "$!: $@";
	my $string = <$fh>;
	my $data = JSON::XS->new->utf8->decode($string);
	$data->{uuid} = "kbase/default";
	$ws->save_object({
		id => "default",
		type => "Biochemistry",
		data => $data,
		workspace => "kbase",
		command => "_loadBiochemToDB"
	});
	$url = "http://bioseed.mcs.anl.gov/~chenry/exampleObjects/defaultMap.json.gz";
	$status = getstore($url, $compressed_filename);
	die "Unable to fetch from model_seed\n" unless($status == 200);
	gunzip $compressed_filename => $uncompressed_filename;
	open($fh, "<", $uncompressed_filename) || die "$!: $@";
	$string = <$fh>;
	$data = JSON::XS->new->utf8->decode($string);
	$data->{biochemistry_uuid} = "kbase/default";
	$data->{uuid} = "kbase/default";
	$ws->save_object({
		id => "default",
		type => "Mapping",
		data => $data,
		workspace => "kbase",
		command => "_loadBiochemToDB"
	});
}

sub _loadTestBiochemToDB {
	my ($ws) = @_;
	my $url = "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/biochemistry.test.json";
	my ($fh2, $uncompressed_filename) = tempfile();
	close($fh2);
	my $status = getstore($url, $uncompressed_filename);
	die "Unable to fetch from model_seed\n" unless($status == 200);
	local $/;
	open(my $fh, "<", $uncompressed_filename) || die "$!: $@";
	my $string = <$fh>;
	my $data = JSON::XS->new->utf8->decode($string);
	$data->{uuid} = "kbase/default";
	$ws->save_object({
		id => "default",
		type => "Biochemistry",
		data => $data,
		workspace => "kbase",
		command => "_loadBiochemToDB"
	});
	$url = "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/mapping.test.json";
	$status = getstore($url, $uncompressed_filename);
	open($fh, "<", $uncompressed_filename) || die "$!: $@";
	$string = <$fh>;
	$data = JSON::XS->new->utf8->decode($string);
	$data->{biochemistry_uuid} = "kbase/default";
	$data->{uuid} = "kbase/default";
	$ws->save_object({
		id => "default",
		type => "Mapping",
		data => $data,
		workspace => "kbase",
		command => "_loadBiochemToDB"
	});
	$url = "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/mapping.test.json";
	$status = getstore($url, $uncompressed_filename);
	open($fh, "<", $uncompressed_filename) || die "$!: $@";
	$string = <$fh>;
	$data = JSON::XS->new->utf8->decode($string);
	$data->{biochemistry_uuid} = "kbase/default";
	$data->{uuid} = "kbase/default";
	$ws->save_object({
		id => "default",
		type => "Mapping",
		data => $data,
		workspace => "kbase",
		command => "_loadBiochemToDB"
	});
	$url = "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/genome.test.json";
	$status = getstore($url, $uncompressed_filename);
	open($fh, "<", $uncompressed_filename) || die "$!: $@";
	$string = <$fh>;
	$genomeObj = JSON::XS->new->utf8->decode($string);
}

sub _initializeTestWorkspace {
	my $ws = Bio::KBase::workspaceService::Impl->new({testuser => "kbasetest"});
	$ws->_clearAllWorkspaces();
	$ws->_clearAllWorkspaceObjects();
	$ws->_clearAllWorkspaceUsers();
	$ws->_clearAllWorkspaceDataObjects();
	$ws->_clearAllJobs();
	$ws->create_workspace({
		workspace => "kbase",
		default_permission => "r"
	});
	&_loadTestBiochemToDB($ws);
	$ws = Bio::KBase::workspaceService::Impl->new({testuser => "testuser"});
	$ws->create_workspace({
		workspace => "testworkspace",
		default_permission => "r"
	});
	return $ws;
}

sub prettyPrintKBaseGenome {
	my ($wss,$id,$ws) = @_;
	my $output = $wss->get_object({
		type => "Genome",
		workspace => $ws,
		id => $id
	});
	my $JSON = JSON::XS->new->utf8(1);
	$JSON->pretty(1);
	open ( my $fh, ">", "genome.json");
	print $fh $JSON->encode($output->{data})."\n";
	close($fh);
}

#Old 'real' test media formulation
#compounds => [qw(
#	Oxaloacetate Co2+ Cl- H+ Ca2+ Cu2+ Sulfate Zn2+ Mn2+ NH3
#	Phosphate H2O O2 K+ Mg Na+ Fe2+ fe3 Molybdate Ni2+ D-Glucose
#)],
#concentrations => [
#	0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,
#	0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001
#],
#maxflux => [
#	1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,
#	1000,1000,1000,1000,1000,1000,1000,1000,1000,1000
#],
#minflux => [
#	-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
#	-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000
#]
