use strict;
use warnings;
use Bio::KBase::workspaceService::Client;
use Bio::KBase::AuthToken;
use Bio::KBase::fbaModelServices::Client;
#use Bio::KBase::fbaModelServices::Impl;
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
my $ws = Bio::KBase::workspaceService::Client->new("http://kbase.us/services/workspace/");
#Instantiating client object
my $obj = Bio::KBase::fbaModelServices::Client->new("http://kbase.us/services/fbaServices/");
#my $obj = Bio::KBase::fbaModelServices::Impl->new({workspace => $ws});
#Checking for standard and default biochemistry
&_prepareWorkspace($ws);

#Testing biochemistry retrieval method
my $biochemistry = $obj->get_biochemistry({});
ok defined($biochemistry), "Successfully printed biochemistry!";
$biochemistry = $obj->get_biochemistry({biochemistry => "testdefault"});
ok defined($biochemistry), "Successfully printed biochemistry!";
#Testing reaction retrieval method
my $rxns = $obj->get_reactions({
	reactions => ["rxn00001","rxn00002"],
	biochemistry => "default",
	mapping => "default"
});
ok defined($rxns->[0]), "Successfully printed reactions!";
#Testing compound retrieval method
my $cpds = $obj->get_compounds({
	compounds => ["cpd00001","cpd00002"],
	biochemistry => "default",
	mapping => "default"
});
ok defined($cpds->[0]), "Successfully printed compounds!";
eval {
	my ($meta) = $ws->create_workspace({
	        workspace => "fbaservicestest",
	        default_permission => "n",
	        auth => $token,
	});
};
#Testing loading of genome object to workspace
my ($fh, $uncompressed_filename,$genome);
{
	($fh, $uncompressed_filename) = tempfile();
	close($fh);
	local $/;
	my $status = getstore("http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/genome.test.json", $uncompressed_filename);
	open($fh, "<", $uncompressed_filename) || die "$!: $@";
	my $string = <$fh>;
	$genomeObj = JSON::XS->new->utf8->decode($string);
	$genome = $obj->genome_object_to_workspace({
		genomeobj => $genomeObj,
		workspace => "fbaservicestest",
		auth => $token
	});
	ok defined($genome), "Successfully loaded genome object to workspace!";
}

#Now test ability to retrieve annotated genome object from database
my $cdmgenome;
eval {
	$cdmgenome = $obj->genome_to_workspace({
		genome => "kb|g.2",
		workspace => "fbaservicestest",
		auth => $token
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
	compounds => ["C name","D name","B name"],
	concentrations => [0.001,0.001,0.001],
	maxflux => [1000,1000,1000],
	minflux => [-1000,-1000,-1000],
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($media), "Media successfully added to workspace!";

#Testing media retrieval method
my $medias = $obj->get_media({
	medias => ["Media1","CustomMedia"],
	workspaces => ["kbasecdm","fbaservicestest"],
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($medias->[0]), "Successfully printed media!";

#Now test phenotype import
my $phenos = $obj->import_phenotypes({
	workspace => "fbaservicestest",
	genome => $genome->[0],
	genome_workspace => "fbaservicestest",
	phenotypes => [
		[[],"CustomMedia","fbaservicestest",["D name"],1],
		[[],"Media1","kbasecdm",["A name"],1],
		[["kb|g.0.peg.1","kb|g.0.peg.2"],"Media2","kbasecdm",[],1]
	],
	notes => "",
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($phenos), "Successfully imported phenotypes!";

#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	genome => $genome->[0],
	workspace => "fbaservicestest",
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
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
	auth => $token
});
ok defined($phenosim), "Successfully simulated phenotypes!";

#Now test phenotype simulation export
my $html = $obj->export_phenotypeSimulationSet({
	phenotypeSimulationSet => $phenosim->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported phenotype simulations to html format!";
open ($fh, ">", "PhenotypeSim.html");
print $fh $html."\n";
close($fh);

#Testing model export
my $cytoseed = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "cytoseed",
	auth => $token
});
ok defined($cytoseed), "Successfully exported model to cytoseed format!";
open ( $fh, ">", "model.cytoseed");
print $fh $cytoseed."\n";
close($fh);

$html = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported model to html format!";
open ( $fh, ">", "model.html");
print $fh $html."\n";
close($fh);

my $sbml = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "sbml",
	auth => $token
});
ok defined($sbml), "Successfully exported model to sml format!";
open ( $fh, ">", "model.sbml");
print $fh $sbml."\n";
close($fh);

#Testing model retrieval method
my $mdls = $obj->get_models({
	models => [$model->[0]],
	workspaces => ["fbaservicestest"],
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($mdls->[0]), "Successfully printed model data!";

#Now exporting media formulation
$html = $obj->export_media({
	media => $media->[0],
	workspace => "fbaservicestest",
	format => "html",
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($html), "Successfully exported media to html format!";
open ( $fh, ">", "media.html");
print $fh $html."\n";
close($fh);

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
	auth => $token
});
ok defined($fba), "FBA successfully run on input model!";

#Testing fba retrieval method
my $fbas = $obj->get_fbas({
	fbas => [$fba->[0]],
	workspaces => ["fbaservicestest"],
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($fbas->[0]), "Successfully printed fba data!";

#Now test flux balance analysis export
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported FBA to html format!";
open ( $fh, ">", "fba.html");
print $fh $html."\n";
close($fh);

#Now test the queue fba function, without submitting the job to the cluster
my $job = $obj->queue_runfba({
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
	donot_submit_job => 1,
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($job), "FBA successfully queued for input model!";

#Now running queued FBA job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "fbaservicestest",
	auth => $token
});
ok defined($job), "Successfully ran queued FBA job!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $job->{clusterjobs}->[0]->{fbaid},
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported FBA to html format!";
open ( $fh, ">", "fba2.html");
print $fh $html."\n";
close($fh);

#Now queuing gapfilling in complete media
$job = $obj->queue_gapfill_model({
	model => $model->[0],
	workspace => "fbaservicestest",
	formulation => {
		formulation => {
			media => "CustomMedia",
			media_workspace => "fbaservicestest"
		},
		num_solutions => 1
	},
	integrate_solution => 1,
	out_model => $model->[0].".gf",
	donot_submit_job => 1,
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($html), "Successfully queued gapfill job!";

#Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "fbaservicestest",
	auth => $token
});
ok defined($job), "Successfully ran queued gapfill job!";

#Now queuing gapfilling in custom media
$job = $obj->queue_gapfill_model({
	model => $model->[0].".gf",
	workspace => "fbaservicestest",
	formulation => {
		formulation => {
			media => "Complete",
			media_workspace => "kbasecdm"
		},
		num_solutions => 1
	},
	integrate_solution => 1,
	out_model => $model->[0].".gf2",
	donot_submit_job => 1,
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($html), "Successfully queued gapfill job!";

#Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "fbaservicestest",
	auth => $token
});
ok defined($job), "Successfully ran queued gapfill job!";

#Now test flux balance analysis
$fba = $obj->runfba({
	model => $model->[0].".gf2",
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
	auth => $token
});
ok defined($fba), "FBA successfully run on gapfilled model!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported FBA to html format!";
open ( $fh, ">", "fba-GapFill.html");
print $fh $html."\n";
close($fh);

#Now exporting queued FBA
$job = $obj->queue_gapgen_model({
	model => $model->[0].".gf2",
	workspace => "fbaservicestest",
	formulation => {
		formulation => {
			media => "CustomMedia",
			media_workspace => "fbaservicestest"
		},
		refmedia => "Complete",
		refmedia_workspace => "kbasecdm",
		num_solutions => 1
	},
	integrate_solution => 1,
	out_model => $model->[0].".gg",
	donot_submit_job => 1,
	biochemistry => "testdefault",
	mapping => "testdefault",
	auth => $token
});
ok defined($html), "Successfully queued gapgen job!";

#Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
$job = $obj->run_job({
	jobid => $job->[0],
	workspace => "fbaservicestest",
	auth => $token
});
ok defined($job), "Successfully ran queued gapgen job!";

#Now test flux balance analysis
$fba = $obj->runfba({
	model => $model->[0].".gg",
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
	auth => $token
});
ok defined($fba), "FBA successfully run on gapgen model!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $fba->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported FBA to html format!";
open ( $fh, ">", "fba-Gapgen.html");
print $fh $html."\n";
close($fh);

done_testing($test_count);

sub _prepareWorkspace {
	my ($ws) = @_;
	#Making sure the kbase workspace exists
	eval {
		$ws->create_workspace({
			workspace => "kbase",
			default_permission => "r",
			auth => $token
		});
	};
	#Is the default biochemistry present?
	if ($ws->has_object({
		id => "default",
		type => "Biochemistry",
		workspace => "kbase",
		auth => $token
	}) == 0) {
		print "Adding full biochemistry!\n";
		$ws->save_object({
			id => "default",
			type => "Biochemistry",
			data => "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/defaultKBaseBiochem.json.gz",
			workspace => "kbase",
			command => "_prepareWorkspace",
			auth => $token,
			json => 1,
			compressed => 1,
			retrieveFromURL => 1
		});
	}
	#Is the default mapping present?
	if ($ws->has_object({
		id => "default",
		type => "Mapping",
		workspace => "kbase",
		auth => $token
	}) == 0) {
		#Add default mapping
		print "Adding full mapping!\n";
		$ws->save_object({
			id => "default",
			type => "Mapping",
			data => "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/defaultKBaseMapping.json.gz",
			workspace => "kbase",
			command => "_prepareWorkspace",
			auth => $token,
			json => 1,
			compressed => 1,
			retrieveFromURL => 1
		});
	}
	#Is the test default biochemistry present?
	if ($ws->has_object({
		id => "testdefault",
		type => "Biochemistry",
		workspace => "kbase",
		auth => $token
	}) == 0) {
		#Add test biochemistry
		print "Adding test biochemistry!\n";
		$ws->save_object({
			id => "testdefault",
			type => "Biochemistry",
			data => "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/testKBaseBiochem.json",
			workspace => "kbase",
			command => "_prepareWorkspace",
			auth => $token,
			json => 1,
			compressed => 1,
			retrieveFromURL => 1
		});
	}
	#Is the test default mapping present?
	if ($ws->has_object({
		id => "testdefault",
		type => "Mapping",
		workspace => "kbase",
		auth => $token
	}) == 0) {
		#Add default mapping
		print "Adding test mapping!\n";
		$ws->save_object({
			id => "testdefault",
			type => "Mapping",
			data => "http://bioseed.mcs.anl.gov/~chenry/KbaseFiles/testKBaseMapping.json",
			workspace => "kbase",
			command => "_prepareWorkspace",
			auth => $token,
			json => 1,
			compressed => 1,
			retrieveFromURL => 1
		});
	}
}