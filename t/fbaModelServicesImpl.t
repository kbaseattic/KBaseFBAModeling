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
my $test_count = 2;

#Initializing test workspace
my $ws = &_initializeTestWorkspace();
my $obj = fbaModelServicesImpl->new({workspace => $ws});

#Now test ability to retrieve annotated genome object from database
my $genome = $obj->genome_to_workspace({
	in_genome => "kb|g.0",
	out_workspace => "testworkspace",
	as_new_genome => 0
});
ok defined($genome), "Genome successfully imported to workspace from CDM!"; 

#Now test ability to produce a metabolic model
my $model = $obj->genome_to_fbamodel({
	in_genome => "kb|g.0",
	in_workspace => "testworkspace",
	out_workspace => "testworkspace"
});
ok defined($genome), "Model successfully constructed from input genome!";

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
	$ws->save_object({
		id => "default",
		type => "Mapping",
		data => $data,
		workspace => "kbase",
		command => "_loadBiochemToDB"
	});
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
	&_loadBiochemToDB($ws);
	$ws = Bio::KBase::workspaceService::Impl->new({testuser => "testuser"});
	return $ws;
}