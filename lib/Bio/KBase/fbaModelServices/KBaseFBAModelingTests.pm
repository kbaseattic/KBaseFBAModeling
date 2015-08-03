{
	package Bio::KBase::fbaModelServices::KBaseFBAModelingTests;
	
	use strict;
	use Bio::KBase::fbaModelServices::ScriptHelpers; 
	use Test::More;
	use Data::Dumper;
	use Config::Simple;
	
	my $serverclass = "Bio::KBase::fbaModelServices::Impl";
	my $clientclass = "Bio::KBase::fbaModelServices::Client";
	
	sub new {
	    my($class,$bin) = @_;
	    my $c = Config::Simple->new();
		$c->read($bin."test.cfg");
	    my $self = {
			testcount => 0,
			dumpoutput => $c->param("KBaseFBAModeling.dumpoutput"),
			showerrors => $c->param("KBaseFBAModeling.showerrors"),
			user => $c->param("KBaseFBAModeling.user"),
			password => $c->param("KBaseFBAModeling.password"),
			token => undef,
			url => $c->param("KBaseFBAModeling.url"),
			testoutput => {}
	    };
	    my $tokenObj = Bio::KBase::AuthToken->new(
    		user_id => $self->{user}, password => $self->{password}
		);
		$self->{token} = $tokenObj->token();
	    if (defined($c->param("KBaseFBAModeling.serverconfig"))) {
	    	$ENV{KB_DEPLOYMENT_CONFIG} = $bin.$c->param("KBaseFBAModeling.serverconfig");
	    }
	    if (!defined($self->{url}) || $self->{url} eq "impl") {
	    	print "Loading server with this config: ".$ENV{KB_DEPLOYMENT_CONFIG}."\n";
	    	my $classpath = $serverclass;
	    	$classpath =~ s/::/\//g;
	    	require $classpath.".pm";
	    	$self->{obj} = $serverclass->new();
	    } else {
	    	my $classpath = $clientclass;
	    	$classpath =~ s/::/\//g;
	    	require $classpath.".pm";
	    	$self->{obj} = $clientclass->new($self->{url},token => $self->{token});
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
		my $model_dir;
		my $model_name;
		my $model;
		my $output = $self->test_harness("ModelReconstruction",{
			genome => "/".$self->{user}."/genomes/test/.Buchnera_aphidicola/Buchnera_aphidicola.genome",
			fulldb => "0",
			output_path => $model_dir,
			output_file => $model_name
		},"Reconstruct from workspace genome test",[],0,undef,1);
		$output = $self->test_harness("ModelReconstruction",{
			genome => "PATRICSOLR:83333.84",
			fulldb => "0",
			output_path => $model_dir,
			output_file => "PubGenomeModel"
		},"Reconstruct public PATRIC genome test",[],0,undef,1);
		$output = $self->test_harness("list_gapfill_solutions",{
			model => $model
		},"List ".$model_name." gapfill solutions",[["defined(\$output->[0]) && !defined(\$output->[1])","Model should have only one gapfilling"]],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("list_fba_studies",{
			model => $model
		},"List ".$model_name." FBA studies",[],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("list_model_edits",{
			model => $model
		},"List ".$model_name." model edits",[],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("GapfillModel",{
			model => $model,
			integrate_solution => "1",
			media => "/chenry/public/modelsupport/media/Carbon-D-Glucose"
		},"Gapfill ".$model_name." in minimal media",[["length(\$output->[7]->{solutiondata}) > 0","Gapfilling should have been successful"]],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("export_model",{
			model => $model,
			format => "sbml",
			to_shock => 1
		},"Export ".$model_name." as SBML",[],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("FluxBalanceAnalysis",{
			model => $model,
		},"FBA of ".$model_name." in complete media",[["\$output->[7]->{objective} >= 0.0001","Model should grow in Complete media"]],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("FluxBalanceAnalysis",{
			model => $model,
			media => "/chenry/public/modelsupport/media/Carbon-D-Glucose"
		},"FBA of ".$model_name." in minimal media",[["\$output->[7]->{objective} >= 0.0001","Model should grow in minimal media"]],0,"Gapfill ".$model_name." in minimal media",1);
		$output = $self->test_harness("list_gapfill_solutions",{
			model => $model
		},"List ".$model_name." gapfill solutions again",[["defined(\$output->[1])","Model should have two gapfillings"]],0,"Gapfill ".$model_name." in minimal media",1);
		$output = $self->test_harness("manage_gapfill_solutions",{
			model => $model,
			commands => {
				"gf.0" => "u"
			}
		},"Unintegrating ".$model_name." gapfill solution",[],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("manage_gapfill_solutions",{
			model => $model,
			commands => {
				"gf.0" => "i"
			}
		},"Integrating ".$model_name." gapfill solution",[],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("manage_gapfill_solutions",{
			model => $model,
			commands => {
				"gf.0" => "d"
			}
		},"Deleting ".$model_name." gapfill solution",[],0,"Reconstruct from workspace genome test",1);
		$output = $self->test_harness("list_fba_studies",{
			model => $model
		},"List ".$model_name." FBA studies after running additional FBA",[["keys(%{$output}) == 3","Model should have three FBAs"]],0,"FBA of ".$model_name." in minimal media",1);
		$output = $self->test_harness("delete_fba_studies",{
			model => $model,
			fbas => ["fba.0"]
		},"Deleting ".$model_name." FBA",[],0,"Reconstruct from workspace genome test",1);
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