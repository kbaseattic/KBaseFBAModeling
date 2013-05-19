use strict;
use warnings;
use Bio::KBase::workspaceService::Client;
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
my $ws = Bio::KBase::workspaceService::Client->new("http://localhost:7058");
#Instantiating client object
my $obj = Bio::KBase::fbaModelServices::Client->new("http://localhost:7036");
#Checking for standard and default biochemistry
&_prepareWorkspace($ws);
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
	compounds => ["H2O","ADP"],
});
ok defined($cpds->[0]), "Successfully printed compounds!";
#Creating workspace for tests
eval {
	my ($meta) = $ws->create_workspace({
		workspace => "fbaservicestest",
		default_permission => "n",
		auth => $token,
	});
};
#Now test ability to retrieve annotated genome object from database
my $cdmgenome;
eval {
	$cdmgenome = $obj->genome_to_workspace({
		genome => "kb|g.0",
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
	compounds => ["H2O","ADP","ATP"],
	concentrations => [0.001,0.001,0.001],
	maxflux => [1000,1000,1000],
	minflux => [-1000,-1000,-1000],
	auth => $token
});
ok defined($media), "Media successfully added to workspace!";
#Testing media retrieval method
my $medias = $obj->get_media({
	medias => ["Carbon-D-Glucose","CustomMedia"],
	workspaces => ["NO_WORKSPACE","fbaservicestest"],
	auth => $token
});
ok defined($medias->[0]), "Successfully printed media!";
#Now test phenotype import
my $phenos = $obj->import_phenotypes({
	workspace => "fbaservicestest",
	genome => "kb|g.0",
	genome_workspace => "fbaservicestest",
	phenotypes => [
		[[],"CustomMedia","fbaservicestest",["D name"],1],
		[[],"Carbon-D-Glucose","NO_WORKSPACE",["A name"],1],
		[["kb|g.0.peg.1","kb|g.0.peg.2"],"Carbon-Glycerol","NO_WORKSPACE",[],1]
	],
	notes => "",
	auth => $token
});
ok defined($phenos), "Successfully imported phenotypes!";
#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	genome => "kb|g.0",
	workspace => "fbaservicestest",
	coremodel => 1,
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
#Testing model export
my $cytoseed = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "cytoseed",
	auth => $token
});
ok defined($cytoseed), "Successfully exported model to cytoseed format!";
$html = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
});
ok defined($html), "Successfully exported model to html format!";
my $sbml = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "fbaservicestest",
	format => "sbml",
	auth => $token
});
ok defined($sbml), "Successfully exported model to sml format!";
#Testing model retrieval method
my $mdls = $obj->get_models({
	models => [$model->[0]],
	workspaces => ["fbaservicestest"],
	auth => $token
});
ok defined($mdls->[0]), "Successfully printed model data!";
#Now exporting media formulation
$html = $obj->export_media({
	media => $media->[0],
	workspace => "fbaservicestest",
	format => "html",
	auth => $token
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
	auth => $token
});
ok defined($fba), "FBA successfully run on input model!";
#Testing fba retrieval method
my $fbas = $obj->get_fbas({
	fbas => [$fba->[0]],
	workspaces => ["fbaservicestest"],
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
	auth => $token
});
ok defined($job), "FBA successfully queued for input model!";
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
	auth => $token
});
ok defined($html), "Successfully queued gapfill job!";
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
	auth => $token
});
ok defined($html), "Successfully queued gapgen job!";

done_testing(21);

##Now running queued FBA job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token
#});
#ok defined($job), "Successfully ran queued FBA job!";
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $job->{clusterjobs}->[0]->{fbaid},
#	workspace => "fbaservicestest",
#	format => "html",
#	auth => $token
#});
#ok defined($html), "Successfully exported FBA to html format!";
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token
#});
#ok defined($job), "Successfully ran queued gapfill job!";
##Now queuing gapfilling in custom media
#$job = $obj->queue_gapfill_model({
#	model => $model->[0].".gf",
#	workspace => "fbaservicestest",
#	formulation => {
#		formulation => {
#			media => "Complete",
#			media_workspace => "kbasecdm"
#		},
#		num_solutions => 1
#	},
#	integrate_solution => 1,
#	out_model => $model->[0].".gf2",
#	donot_submit_job => 1,
#	biochemistry => "testdefault",
#	mapping => "testdefault",
#	auth => $token
#});
#ok defined($html), "Successfully queued gapfill job!";
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token
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
#	auth => $token
#});
#ok defined($fba), "FBA successfully run on gapfilled model!";
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $fba->[0],
#	workspace => "fbaservicestest",
#	format => "html",
#	auth => $token
#});
#ok defined($html), "Successfully exported FBA to html format!";
##Now running queued gapfill job mannually to ensure that the job runs and postprocessing works
#$job = $obj->run_job({
#	jobid => $job->[0],
#	workspace => "fbaservicestest",
#	auth => $token
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
#	auth => $token
#});
#ok defined($fba), "FBA successfully run on gapgen model!";
##Now exporting queued FBA
#$html = $obj->export_fba({
#	fba => $fba->[0],
#	workspace => "fbaservicestest",
#	format => "html",
#	auth => $token
#});
#ok defined($html), "Successfully exported FBA to html format!";

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
	my $meta;
	eval {
		$meta = $ws->get_object({
			id => "default",
			type => "Biochemistry",
			workspace => "kbase",
			auth => $token
		});
	};
	if (!defined($meta)) {
		$ws->import_bio({overwrite => 1});
	}
	eval {
		$meta = $ws->get_object({
			id => "default",
			type => "Mapping",
			workspace => "kbase",
			auth => $token
		});
	};
	if (!defined($meta)) {
		$ws->import_map({overwrite => 1});
	}
	eval {
		$ws->create_workspace({
			workspace => "KBaseTemplateModels",
			default_permission => "r",
			auth => $token
		});
	};
	eval {
		$meta = $ws->get_object({
			id => "CoreModelTemplate",
			type => "ModelTemplate",
			workspace => "KBaseTemplateModels",
			auth => $token
		});
	};
	if (!defined($meta)) {
		$obj->import_template_fbamodel(_processTemplateFiles());
	}
}

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
		modelType => "CoreModel",
		auth => $token
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
