use FindBin qw($Bin);
use lib $Bin.'/../lib';
use lib $Bin.'/../../workspace_service/lib/';
use lib $Bin.'/../../kb_seed/lib/';
use lib $Bin.'/../../idserver/lib/';
use Bio::KBase::workspaceService::Impl;
use LWP::Simple qw(getstore);
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);
use fbaModelServicesImpl;
use JSON::XS;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Temp qw(tempfile);
my $test_count = 20;
my $genomeObj;

#Initializing test workspace
my $ws = &_initializeTestWorkspace();
my $obj = fbaModelServicesImpl->new({workspace => $ws});

#Testing biochemistry retrieval method
my $biochemistry = $obj->get_biochemistry({});
ok defined($biochemistry), "Successfully printed biochemistry!";

#Testing reaction retrieval method
my $rxns = $obj->get_reactions({
	reactions => ["rxn1","rxn2"]
});
ok defined($rxns->[0]), "Successfully printed reactions!";

#Testing compound retrieval method
my $cpds = $obj->get_compounds({
	compounds => ["A","B"]
});
ok defined($cpds->[0]), "Successfully printed compounds!";

my $genome = $obj->genome_object_to_workspace({
	genomeobj => $genomeObj,
	workspace => "testworkspace"
});
ok defined($cpds->[0]), "Successfully loaded genome object to workspace!";

#Now adding media formulation to workspace
my $media = $obj->addmedia({
	media => "CustomMedia",
	workspace => "testworkspace",
	name => "CustomMedia",
	isDefined => 1,
	isMinimal => 1,
	type => "Minimal media",
	compounds => ["A name","B name","C name"],
	concentrations => [0.001,0.001,0.001],
	maxflux => [1000,1000,1000],
	minflux => [-1000,-1000,-1000]
});
ok defined($media), "Media successfully added to workspace!";

#Testing media retrieval method
my $medias = $obj->get_media({
	medias => ["Media1","CustomMedia"],
	workspaces => ["kbasecdm","testworkspace"]
});
ok defined($medias->[0]), "Successfully printed media!";

#Now test phenotype import
my $phenos = $obj->import_phenotypes({
	phenotypeSet_workspace => "testworkspace",
	genome => $genome->[0],
	genome_workspace => "testworkspace",
	phenotypes => [
		[[],"CustomMedia","testworkspace",["D name"],1],
		[[],"Media1","kbasecdm",["A name"],1],
		[["kb|g.0.peg.1","kb|g.0.peg.2"],"Media2","kbasecdm",[],1]
	],
	notes => "",
});
ok defined($phenos), "Successfully imported phenotypes!";

#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	genome => $genome->[0],
	genome_workspace => "testworkspace",
});
ok defined($model), "Model successfully constructed from input genome!";

#Now test phenotype simulation
my $phenosim = $obj->simulate_phenotypes({
	model => $model->[0],
	model_workspace => "testworkspace",
	phenotypeSet => $phenos->[0],
	phenotypeSet_workspace => "testworkspace",
	formulation => {},
	notes => "",
});
ok defined($phenosim), "Successfully simulated phenotypes!";

#Now test phenotype simulation export
my $html = $obj->export_phenotypeSimulationSet({
	phenotypeSimulationSet => $phenosim->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported phenotype simulations to html format!";
open ( my $fh, ">", "PhenotypeSim.html");
print $fh $html."\n";
close($fh);

#Testing model export to html
$html = $obj->export_fbamodel({
	model => $model->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported model to html format!";
open ( $fh, ">", "model.html");
print $fh $html."\n";
close($fh);

#Testing model retrieval method
my $mdls = $obj->get_models({
	models => [$model->[0]],
	workspaces => ["testworkspace"],
});
ok defined($mdls->[0]), "Successfully printed model data!";

#Now exporting media formulation
$html = $obj->export_media({
	media => $media->[0],
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported media to html format!";
open ( $fh, ">", "media.html");
print $fh $html."\n";
close($fh);

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
	fba_workspace => "testworkspace"
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
open ( $fh, ">", "fba.html");
print $fh $html."\n";
close($fh);

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
	fba_workspace => "testworkspace",
	donot_submit_job => 1
});
ok defined($job), "FBA successfully queued for input model!";

#Now running queued FBA job mannually to ensure that the job runs and postprocessing works
my $job = $obj->run_job({
	jobid => $job->[0],
	workspace => "testworkspace"
});
ok defined($job), "Successfully ran queued job!";

#Now exporting queued FBA
$html = $obj->export_fba({
	fba => $job->{clusterjobs}->[0]->{fbaid},
	workspace => "testworkspace",
	format => "html"
});
ok defined($html), "Successfully exported FBA to html format!";
open ( $fh, ">", "fba2.html");
print $fh $html."\n";
close($fh);

#Now test ability to retrieve annotated genome object from database
my $cdmgenome = $obj->genome_to_workspace({
	genome => "kb|g.0",
	workspace => "testworkspace"
});
ok defined($cdmgenome), "Genome successfully imported to workspace from CDM!"; 

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
	$ENV{MONGODBHOST} = "127.0.0.1";
	$ENV{MONGODBDB} = "testWorkspace";
	my $ws = Bio::KBase::workspaceService::Impl->new({testuser => "kbaseadmin"});
	$ws->_clearAllWorkspaces();
	$ws->_clearAllWorkspaceObjects();
	$ws->_clearAllWorkspaceUsers();
	$ws->_clearAllWorkspaceDataObjects();
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