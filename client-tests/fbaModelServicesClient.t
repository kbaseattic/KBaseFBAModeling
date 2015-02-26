use strict;
use warnings;
use Bio::KBase::AuthToken;
use Bio::KBase::fbaModelServices::Client;
use JSON::XS;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
use LWP::Simple qw(getstore);
my $test_count = 33;
my $genomeObj;
my $token;

#Logging in
my $tokenObj = Bio::KBase::AuthToken->new(
    user_id => 'kbasetest', password => '@Suite525'
);
$token = $tokenObj->token();

#Instantiating client workspace
my $wsurl = "http://140.221.84.209:7058";
#Instantiating client object
my $obj = Bio::KBase::fbaModelServices::Client->new("http://localhost:7036",$token);
my $obj = Bio::KBase::fbaModelServices::Client->new("http://140.221.85.73:4043",$token);
#Testing biochemistry retrieval method
my $biochemistry = $obj->get_biochemistry({
	wsurl => $wsurl
});
ok defined($biochemistry), "Successfully printed biochemistry!";
#Testing reaction retrieval method
my $rxns = $obj->get_reactions({
	reactions => ["rxn00001","rxn00002"],
	wsurl => $wsurl
});
ok defined($rxns->[0]), "Successfully printed reactions!";
#Testing compound retrieval method
my $cpds = $obj->get_compounds({
	compounds => ["cpd00001","cpd00002"],
	wsurl => $wsurl
});
ok defined($cpds->[0]), "Successfully printed compounds!";
#Creating workspace for tests
eval {
	my ($meta) = $ws->create_workspace({
		workspace => "fbaservicestest",
		globalread => "n"
	});
};
#Now test ability to retrieve annotated genome object from database
my $cdmgenome;
eval {
	$cdmgenome = $obj->genome_to_workspace({
		genome => "kb|g.0",
		workspace => "fbaservicestest",
		wsurl => $wsurl
	});
};
ok defined($cdmgenome), "Genome successfully imported to workspace from CDM!"; 
#Now adding media formulation to workspace
my $media = $obj->addmedia({
	media => "CustomMedia",
	workspace => "fbaservicestest",
	name => "CustomMedia",
	isDefined => 1,
	isMinimal => 1,
	type => "Minimal media",
	compounds => ["H2O","ADP","ATP"],
	concentrations => [0.001,0.001,0.001],
	maxflux => [1000,1000,1000],
	minflux => [-1000,-1000,-1000],
	wsurl => $wsurl
});
ok defined($media), "Media successfully added to workspace!";
$media = $obj->addmedia({
	media => "Complete",
	workspace => "fbaservicestest",
	name => "Complete",
	isDefined => 0,
	isMinimal => 1,
	type => "Rich media",
	compounds => [],
	concentrations => [],
	maxflux => [],
	minflux => [],
	wsurl => $wsurl
});
#Testing media retrieval method
my $medias = $obj->get_media({
	medias => ["CustomMedia"],
	workspaces => ["fbaservicestest"],
	wsurl => $wsurl
});
ok defined($medias->[0]), "Successfully printed media!";
#Now test phenotype import
my $phenos = $obj->import_phenotypes({
	workspace => "fbaservicestest",
	genome => "kb|g.0",
	genome_workspace => "fbaservicestest",
	phenotypes => [
		[[],"CustomMedia","fbaservicestest",["ADP"],1],
		[[],"Complete","fbaservicestest",["ATP"],1],
		[["kb|g.0.peg.1","kb|g.0.peg.2"],"CustomMedia","fbaservicestest",[],1]
	],
	notes => "",
	wsurl => $wsurl
});
ok defined($phenos), "Successfully imported phenotypes!";
#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	genome => "kb|g.0",
	workspace => "fbaservicestest",
	wsurl => $wsurl
});
ok defined($model), "Model successfully constructed from input genome!";
#Now test phenotype simulation
my $phenosim = $obj->simulate_phenotypes({
	model => $model->[0],
	workspace => "fbaservicestest",
	phenotypeSet => $phenos->[0],
	phenotypeSet_workspace => "fbaservicestest",
	formulation => {},
	notes => "",
	wsurl => $wsurl
});
ok defined($phenosim), "Successfully simulated phenotypes!";
#Now test phenotype simulation export
my $html = $obj->export_phenotypeSimulationSet({
	phenotypeSimulationSet => $phenosim->[0],
	workspace => "fbaservicestest",
	format => "html",
	wsurl => $wsurl
});
ok defined($html), "Successfully exported phenotype simulations to html format!";
#Testing model export
#my $cytoseed = $obj->export_fbamodel({
#	model => $model->[0],
#	workspace => "fbaservicestest",
#	format => "cytoseed",
#	wsurl => $wsurl
#});
#ok defined($cytoseed), "Successfully exported model to cytoseed format!";
$html = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "html",
	wsurl => $wsurl
});
ok defined($html), "Successfully exported model to html format!";
my $sbml = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "sbml",
	wsurl => $wsurl
});
ok defined($sbml), "Successfully exported model to sml format!";
#Testing model retrieval method
my $mdls = $obj->get_models({
	models => [$model->[0]],
	workspaces => ["fbaservicestest"],
	wsurl => $wsurl
});
ok defined($mdls->[0]), "Successfully printed model data!";
#Now exporting media formulation
$html = $obj->export_media({
	media => $media->[0],
	workspace => "fbaservicestest",
	format => "html",
	wsurl => $wsurl
});
ok defined($html), "Successfully exported media to html format!";
#Now test flux balance analysis
my $fba = $obj->runfba({
	model => $model->[0],
	model_workspace => "fbaservicestest",
	formulation => {
		media => "CustomMedia",
		media_workspace => "fbaservicestest"
	},
	fva => 0,
	simulateko => 0,
	minimizeflux => 0,
	findminmedia => 0,
	notes => "",
	workspace => "fbaservicestest",
	wsurl => $wsurl
});
ok defined($fba), "FBA successfully run on input model!";
#Testing fba retrieval method
my $fbas = $obj->get_fbas({
	fbas => [$fba->[0]],
	workspaces => ["fbaservicestest"],
	wsurl => $wsurl
});
ok defined($fbas->[0]), "Successfully printed fba data!";
#Now test flux balance analysis export
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "fbaservicestest",
	format => "html",
	wsurl => $wsurl
});
ok defined($html), "Successfully exported FBA to html format!";

done_testing(17);

##Now running queued FBA job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($job), "Successfully ran queued FBA job!";
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $job->{clusterjobs}->[0]->{fbaid},
#	workspace => "fbaservicestest",
#	format => "html",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($html), "Successfully exported FBA to html format!";
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($job), "Successfully ran queued gapfill job!";
##Now queuing gapfilling in custom media
#$job = $obj->queue_gapfill_model({
#	model => $model->[0].".gf",
#	workspace => "fbaservicestest",
#	formulation => {
#		formulation => {
#			media => "Complete",
#			media_workspace => "NO_WORKSPACE"
#		},
#		num_solutions => 1
#	},
#	integrate_solution => 1,
#	out_model => $model->[0].".gf2",
#	donot_submit_job => 1,
#	biochemistry => "testdefault",
#	mapping => "testdefault",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($html), "Successfully queued gapfill job!";
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($job), "Successfully ran queued gapfill job!";
##Now test flux balance analysis
#$fba = $obj->runfba({
#	model => $model->[0].".gf2",
#	model_workspace => "fbaservicestest",
#	formulation => {
#		media => "CustomMedia",
#		media_workspace => "fbaservicestest"
#	},
#	fva => 0,
#	simulateko => 0,
#	minimizeflux => 0,
#	findminmedia => 0,
#	notes => "",
#	workspace => "fbaservicestest",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($fba), "FBA successfully run on gapfilled model!";
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $fba->[0],
#	workspace => "fbaservicestest",
#	format => "html",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($html), "Successfully exported FBA to html format!";
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($job), "Successfully ran queued gapgen job!";
##Now test flux balance analysis
#$fba = $obj->runfba({
#	model => $model->[0].".gg",
#	model_workspace => "fbaservicestest",
#	formulation => {
#		media => "CustomMedia",
#		media_workspace => "fbaservicestest"
#	},
#	fva => 0,
#	simulateko => 0,
#	minimizeflux => 0,
#	findminmedia => 0,
#	notes => "",
#	workspace => "fbaservicestest",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($fba), "FBA successfully run on gapgen model!";
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $fba->[0],
#	workspace => "fbaservicestest",
#	format => "html",
#	auth => $token,
#	wsurl => $wsurl
#});
#ok defined($html), "Successfully exported FBA to html format!";

