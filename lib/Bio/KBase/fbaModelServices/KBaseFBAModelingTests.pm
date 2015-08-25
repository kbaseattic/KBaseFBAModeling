{
	package Bio::KBase::fbaModelServices::KBaseFBAModelingTests;
	
	use strict;
	use Bio::KBase::fbaModelServices::ScriptHelpers;
	use Bio::KBase::workspace::Client;
	use Test::More;
	use Data::Dumper;
	use Config::Simple;
	use JSON::XS;
	
	my $serverclass = "Bio::KBase::fbaModelServices::Impl";
	my $clientclass = "Bio::KBase::fbaModelServices::Client";
	
	sub new {
	    my($class,$bin,$config) = @_;
	    if (!defined($config)) {
	    	$config = $bin."/test.cfg";
	    }
	    my $c = Config::Simple->new();
		$c->read($config);
	    my $self = {
			dir => $bin,
			testcount => 0,
			dumpoutput => $c->param("KBaseFBAModelingTest.dumpoutput"),
			showerrors => $c->param("KBaseFBAModelingTest.showerrors"),
			user => $c->param("KBaseFBAModelingTest.user"),
			password => $c->param("KBaseFBAModelingTest.password"),
			workspace_url => $c->param("KBaseFBAModelingTest.workspace_url"),
			token => undef,
			url => $c->param("KBaseFBAModelingTest.url"),
			testoutput => {}
	    };
	    my $tokenObj = Bio::KBase::AuthToken->new(
    		user_id => $self->{user}, password => $self->{password}
		);
		$self->{token} = $tokenObj->token();
	    if (defined($c->param("KBaseFBAModelingTest.serverconfig"))) {
	    	$ENV{KB_DEPLOYMENT_CONFIG} = $c->param("KBaseFBAModelingTest.serverconfig");
	    }
	    if (!defined($self->{url}) || $self->{url} eq "impl") {
	    	print "Loading server with this config: ".$ENV{KB_DEPLOYMENT_CONFIG}."\n";
	    	$Bio::KBase::fbaModelServices::Server::CallContext = {token => $self->{token}};
	    	my $classpath = $serverclass;
	    	$classpath =~ s/::/\//g;
	    	require $classpath.".pm";
	    	$self->{obj} = $serverclass->new({"workspace-url" => $self->{workspace_url}});
	    	$self->{workspace_service} = $self->{obj}->_workspaceServices();
	    } else {
	    	my $classpath = $clientclass;
	    	$classpath =~ s/::/\//g;
	    	require $classpath.".pm";
	    	$self->{obj} = $clientclass->new($self->{url},token => $self->{token});
	    	$self->{workspace_service} = Bio::KBase::workspace::Client->new($self->{workspace_url},,token => $self->{token});
	    }
	    return bless $self, $class;
	}
	
	sub test_harness {
		my($self,$function,$parameters,$name,$tests,$fail_to_pass,$dependency) = @_;
		$self->{testoutput}->{$name} = {
			output => undef,
			"index" => $self->{testcount},
			tests => $tests,
			command => $function,
			parameters => $parameters,
			dependency => $dependency,
			fail_to_pass => $fail_to_pass,
			pass => 1,
			function => 1,
			status => "Failed initial function test!"
		};
		$self->{testcount}++;
		if (defined($dependency) && $self->{testoutput}->{$dependency}->{function} != 1) {
			$self->{testoutput}->{$name}->{pass} = -1;
			$self->{testoutput}->{$name}->{function} = -1;
			$self->{testoutput}->{$name}->{status} = "Test skipped due to failed dependency!";
			return;
		}
		my $output;
		eval {
			if (defined($parameters)) {
				$parameters->{wsurl} = $self->{workspace_url};
				$output = $self->{obj}->$function($parameters);
			} else {
				$output = $self->{obj}->$function();
			}
		};
		my $errors;
		if ($@) {
			$errors = $@;
		}
		$self->{completetestcount}++;
		if (defined($output)) {
			$self->{testoutput}->{$name}->{output} = $output;
			$self->{testoutput}->{$name}->{function} = 1;
			if (defined($fail_to_pass) && $fail_to_pass == 1) {
				$self->{testoutput}->{$name}->{pass} = 0;
				$self->{testoutput}->{$name}->{status} = $name." worked, but should have failed!"; 
				ok $self->{testoutput}->{$name}->{pass} == 1, $self->{testoutput}->{$name}->{status};
			} else {
				ok 1, $name." worked as expected!";
				for (my $i=0; $i < @{$tests}; $i++) {
					$self->{completetestcount}++;
					$tests->[$i]->[2] = eval $tests->[$i]->[0];
					if ($tests->[$i]->[2] == 0) {
						$self->{testoutput}->{$name}->{pass} = 0;
						$self->{testoutput}->{$name}->{status} = $name." worked, but sub-tests failed!"; 
					}
					ok $tests->[$i]->[2] == 1, $tests->[$i]->[1];
				}
			}
		} else {
			$self->{testoutput}->{$name}->{function} = 0;
			if (defined($fail_to_pass) && $fail_to_pass == 1) {
				$self->{testoutput}->{$name}->{pass} = 1;
				$self->{testoutput}->{$name}->{status} = $name." failed as expected!";
			} else {
				$self->{testoutput}->{$name}->{pass} = 0;
				$self->{testoutput}->{$name}->{status} = $name." failed to function at all!";
			}
			ok $self->{testoutput}->{$name}->{pass} == 1, $self->{testoutput}->{$name}->{status};
			if ($self->{showerrors} && $self->{testoutput}->{$name}->{pass} == 0 && defined($errors)) {
				print "Errors:\n".$errors."\n";
			}
		}
		if ($self->{dumpoutput}) {
			print "$function output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
		return $output;
	}
	
	sub run_tests {
		my($self) = @_;
		my $user = $self->{user};
		my $workspace = $user.":TestWorkspace";
		#Create the workspace for all test data, done in eval in case workspace already exists
		eval {
			$self->{workspace_service}->create_workspace({
				workspace => $workspace,
				globalread => "n",
				description => "Workspace used to store input and output from test operations"
			});
		};
		#Testing genome import commands for SEED, KBase, and RAST
		my $output = $self->test_harness("genome_to_workspace",{
#			"genome" => "315750.3",
#			"workspace" => $workspace,
#			"source" => "rast",
#			"sourceLogin" => "reviewer",
#			"sourcePassword" => "reviewer"
#		},"genome_to_workspace: import rast genome",[],0,undef,1);
#		$output = $self->test_harness("genome_to_workspace",{
#			"genome" => "224308.1",
#			"workspace" => $workspace,
#			"source" => "seed"
#		},"genome_to_workspace: import seed genome",[],0,undef,1);
#		$output = $self->test_harness("genome_to_workspace",{
			"genome" => "kb|g.2403",
			"workspace" => $workspace,
			"source" => "kbase"
		},"genome_to_workspace: import kbase genome",[],0,undef,1);
		#Loading test genome object for manual object load
		open (my $fh, "<", $self->{dir}."/../test-data/genome.json") || "Couldn't open ".$self->{dir}."/../test-data/genome.json: $!";
		my $genomeobj = "";
		while (my $line = <$fh>) {
			$genomeobj .= $line;
		};
    	close($fh);
		$genomeobj = decode_json $genomeobj;
#		$output = $self->test_harness("genome_object_to_workspace",{
#			"uid" => "carsonella",
#			"workspace" => $workspace,
#			"genomeobj" => $genomeobj
#		},"genome_object_to_workspace: import genome object",[],0,undef,1);
		#Now testing model reconstruction pipeline
		$output = $self->test_harness("addmedia",{
			"media" => "TestMedia",
			"workspace" => $workspace,
			"compounds" => ["Co2+","Cl-","H+","Ca2+","Cu2+","Sulfate","Zn2+","Mn2+","NH3","Phosphate","H2O","O2","K+","Mg","Na+","Fe2+","fe3","Molybdate","Ni2+","D-Glucose"],
			"name" => "TestMedia",
			"isDefined" => 0,
			"isMinimal" => 0,
			"type" => "custom",
			"concentrations" => [0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001],
			"maxflux" => [100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100],
			"minflux" => [-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100,-100]
		},"addmedia: import media object",[],0,undef,1);
		$output = $self->test_harness("get_media",{
			"medias" => ["TestMedia"],
			"workspaces" => [$workspace]
		},"get_media: retrieving a media object",[],0,undef,1);
		$output = $self->test_harness("export_media",{
			"media" => "TestMedia",
			"workspace" => $workspace,
			"format" => "readable"
		},"export_media: exporting a media object",[],0,undef,1);
		$output = $self->test_harness("genome_to_fbamodel",{
			"genome" => "kb|g.2403",
			"workspace" => $workspace,
			"genome_workspace" => $workspace,
			"model" => "TestModel"
		},"genome_to_fbamodel: building a metabolic model",[],0,"genome_to_workspace: import kbase genome",1);
		$output = $self->test_harness("gapfill_model",{
			"model"=>"TestModel",
			"workspace"=>$workspace,
			"model_workspace"=>$workspace,
			"formulation"=> {
				"media"=>"TestMedia",
				"media_workspace"=>$workspace
			},
			"out_model"=>"TestModelGF",
			"integrate_solution"=>1
		},"gapfill_model: gapfilling model in TestMedia",[],0,"genome_to_fbamodel: building a metabolic model",1);
		$output = $self->test_harness("export_fbamodel",{
			"model"=>"TestModelGF",
			"workspace"=>$workspace,
			"format"=>"SBML"
		},"export_fbamodel: exporting a model in SBML format",[],0,"gapfill_model: gapfilling model in TestMedia",1);
		$output = $self->test_harness("get_models",{
			"models"=>["TestModelGF"],
			"workspaces"=>[$workspace]
		},"get_models: retreiving a model",[],0,"gapfill_model: gapfilling model in TestMedia",1);
		$output = $self->test_harness("runfba",{
			"workspace"=>$workspace,
			"model"=>"TestModelGF",
			"formulation"=> {
				"media"=>"TestMedia",
				"media_workspace"=>$workspace
			},
			"fba"=>"TestModelGFFBA"
		},"runfba: running flux balance analysis",[],0,"gapfill_model: gapfilling model in TestMedia",1);
		$output = $self->test_harness("get_fbas",{
			"fbas"=>["TestModelGFFBA"],
			"workspaces"=>[$workspace]
		},"get_fbas: retreiving an FBA",[],0,"runfba: running flux balance analysis",1);
		$output = $self->test_harness("export_fba",{
			"fba"=>"TestModelGFFBA",
			"workspace"=>$workspace,
			"format"=>"readable"
		},"export_fba: exporting an FBA",[],0,"runfba: running flux balance analysis",1);
		$output = $self->test_harness("add_reactions",{
			"model"=>"TestModelGF",
			"workspace"=>$workspace,
			"reactions"=>[["rxn10029","c",">","","","rxn10029","","2.3.1.41"]],
			"model_workspace"=>$workspace,
			"output_id"=>"TestModelGFAddRxn"
		},"add_reactions: adding a reaction",[],0,"gapfill_model: gapfilling model in TestMedia",1);				
		$output = $self->test_harness("modify_reactions",{
			"model"=>"TestModelGFAddRxn",
			"workspace"=>$workspace,
			"reactions"=>[["rxn10029_c0","c","=","","","rxn10029","","2.3.1.41"]],
			"model_workspace"=>$workspace,
			"output_id"=>"TestModelGFModRxn"
		},"modify_reactions: modifying a reaction",[],0,"add_reactions: adding a reaction",1);
		$output = $self->test_harness("remove_reactions",{
			"model"=>"TestModelGFAddRxn",
			"workspace"=>$workspace,
			"reactions"=>["rxn10029_c0"],
			"model_workspace"=>$workspace,
			"output_id"=>"TestModelGFRemRxn"
		},"remove_reactions: removing a reaction",[],0,"add_reactions: adding a reaction",1);
		$output = $self->test_harness("import_phenotypes",{
			"phenotypes" => [
				[[],"Carbon-D-Glucose","KBaseMedia",[],1],
				[[],"ArgonneLBMedia","KBaseMedia",[],1],
				[[],"ArgonneNMSMedia","KBaseMedia",[],1]
			],
			"genome"=>"kb|g.2403",
			"workspace"=>$workspace,
			"genome_workspace"=>$workspace,
			"phenotypeSet"=>"TestPhenotypeSet"
		},"import_phenotypes: importing phenotype data",[],0,"genome_to_workspace: import kbase genome",1);
		$output = $self->test_harness("add_media_transporters",{
			"model"=>"TestModelGF",
			"outmodel"=>"TestModelGFAddTransport",
			"workspace"=>$workspace,
			"phenotypeSet_workspace"=>$workspace,
			"model_workspace"=>$workspace,
			"phenotypeSet"=>"TestPhenotypeSet",
			"all_transporters"=>1
		},"add_media_transporters: adding media transporters",[],0,"import_phenotypes: importing phenotype data",1);
		$output = $self->test_harness("simulate_phenotypes",{
			"phenotypeSet"=>"TestPhenotypeSet",
			"workspace"=>$workspace,
			"model"=>"TestModelGFAddTransport",
			"phenotypeSet_workspace"=>$workspace,
			"model_workspace"=>$workspace,
			"phenotypeSimultationSet"=>"TestPhenotypeSetSimulation",			
			"outmodel"=>"TestModelGFAddTransport"
		},"simulate_phenotypes: simulating phenotype data",[],0,"import_phenotypes: importing phenotype data",1);
		$output = $self->test_harness("export_phenotypeSimulationSet",{
			"workspace"=>$workspace,
			"phenotypeSimulationSet"=>"TestPhenotypeSetSimulation"
		},"export_phenotypeSimulationSet: exporting phenotype data",[],0,"simulate_phenotypes: simulating phenotype data",1);
		done_testing($self->{completetestcount});
	}
}	

{
	package CallContext;
	
	use strict;
	
	sub new {
	    my($class,$token,$method,$user) = @_;
	    my $self = {
	        token => $token,
	        method => $method,
	        user_id => $user
	    };
	    return bless $self, $class;
	}
	sub user_id {
		my($self) = @_;
		return $self->{user_id};
	}
	sub token {
		my($self) = @_;
		return $self->{token};
	}
	sub method {
		my($self) = @_;
		return $self->{method};
	}
	sub log_debug {
		my($self,$msg) = @_;
		print STDERR $msg."\n";
	}
	sub log_info {
		my($self,$msg) = @_;
		print STDERR $msg."\n";
	}
}

1;