#!/usr/bin/perl -w

use strict;
use Config::Simple;
use Bio::KBase::workspaceService::Client;
use Bio::KBase::workspace::Client;
use ModelSEED::KBaseStore;
use JSON::XS;
use Bio::KBase::ObjectAPI::KBaseStore;
$|=1;

my $config = $ARGV[0];
my $object = $ARGV[1];
if (!defined($config)) {
	print STDERR "No config file provided!\n";
	exit(-1);
}
if (!-e $config) {
	print STDERR "Config file ".$config." not found!\n";
	exit(-1);
}

my $c = Config::Simple->new();
$c->read($config);

my $wserv = Bio::KBase::workspaceService::Client->new($c->param("kbclientconfig.wsurl"));
#my $wserv = Bio::KBase::workspaceService::Impl->new({
#	"mongodb-database" => "workspace_service",
#	"mssserver-url" => "http://biologin-4.mcs.anl.gov:7050",
#	"idserver-url" => "http://kbase.us/service/idserver",
#	"mongodb-host" => "mongodb.kbase.us"
#});
my $wsderv = Bio::KBase::workspace::Client->new($c->param("kbclientconfig.wsdurl"),$c->param("kbclientconfig.auth"));
my $idserv = Bio::KBase::IDServer::Client->new($c->param("kbclientconfig.idurl"));

my $oldstore = ModelSEED::KBaseStore->new({
	auth => $c->param("kbclientconfig.auth"),
	workspace => $wserv
});
my $newstore = Bio::KBase::ObjectAPI::KBaseStore->new({
	workspace => $wsderv
});

$Bio::KBase::workspaceService::Server::CallContext = {_override => {_authentication => ""}};
my $array = [split(/[\t;]/,$object)];
my $obj = $oldstore->get_object($array->[0],$array->[1]."/".$array->[2]);
my $provenance = [{
	"time" => $array->[5]."+0000",
	service_ver => 0,
	service => "KBaseFBAModeling",
	method => $array->[4],
	method_params => [],
	input_ws_objects => [],
	resolved_ws_objects => [],
	intermediate_incoming => [],
	intermediate_outgoing => []
}];
if ($array->[4] =~ m/Bio::KBase::([^:]+)::(.+)/) {
	$provenance->{service} = $1;
	$provenance->{method} = $2;
}
$newstore->provenance($provenance);
$newstore->user_override($array->[3]);
if ($array->[0] eq "PhenotypeSimulationSet") {
	my $modobj = $newstore->get_object("FBAModel",$obj->{model_workspace}."/".$obj->{model});
	my $phenoobj = $newstore->get_object("PhenotypeSet",$obj->{phenotypeSet});
	my $data = {
		id => $obj->{id},
		phenotypeSimulations => [],
		fbamodel_ref => $modobj->_reference(),
		phenotypeset_ref => $phenoobj->_reference()
	};
	my $i=1;
	foreach my $phenosim (@{$obj->{phenotypeSimulations}}) {
		my $newpheno = {
			id => $data->{id}.".phenosim.".$i,
			phenotype_ref => $phenoobj->_reference()."/phenotypes/id/".$phenoobj->id().".pheno.".$i,
			simulatedGrowth => $phenosim->[1],
			simulatedGrowthFraction => $phenosim->[2],
			phenoclass => $phenosim->[3]
		};
		push(@{$data->{phenotypeSimulations}},$newpheno);
		$i++;
	}
	my $NewPhenoSimSet = Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSimulationSet->new($data);
	eval {
		$NewPhenoSimSet->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "FBAModel") {
	my $genomehash;
	my $kbid;
	if (defined($obj->kbid())) {
		$kbid = $obj->kbid();
	} else {
		$kbid = "kb|fbamdl.".$idserv->allocate_id_range("kb|fbamdl",1);
	}
	my $data = {
		id => $kbid,
		gapfillings => [],
		gapgens => [],
		biomasses => [],
		compartments => [],
		modelcompounds => [],
		modelreactions => []
	};
	if (defined($obj->annotation_uuid())) {
		my $class = $obj->annotation()->classifyGenomeFromAnnotation();
    	my $template;
    	if ($class eq "Gram positive") {
    		$template = $newstore->get_object("KBaseTemplateModels/GramPosModelTemplate");
       	} elsif ($class eq "Plant") {
       		$template = $newstore->get_object("KBaseTemplateModels/PlantModelTemplate");
    	} else {
    		$template = $newstore->get_object("KBaseTemplateModels/GramNegModelTemplate");
    	}
    	if (defined($genomehash->{$obj->annotation_uuid()})) {;
			my $genome = $newstore->get_object($genomehash->{$obj->annotation_uuid()});
			$data->{genome_ref} = $genome->_reference();
    	}
		$data->{template_ref} = $template->_reference();
	}
	if (defined($obj->id()) && !defined($obj->source_id())) {
		$obj->source_id($obj->id());
	}
	if (!defined($obj->source_id())) {
		$obj->source_id($kbid);
		$obj->source("KBase");
	}
	my $list = [qw(source_id source name type)];
	foreach my $item (@{$list}) {
		if (defined($obj->$item())) {
			$data->{$item} = $obj->$item();
		}
	}
	my $gfs = $obj->integratedGapfillings();
	for (my $i=0; $i < @{$gfs}; $i++) {
		my $gf = TranslateGapfilling($gfs->[$i]);
		push(@{$data->{gapfillings}},{
			gapfill_id => $gf->id(),
			gapfill_ref => $gf->_reference(),
			integrated => 1,
			integrated_solution => $obj->integratedGapfillingSolutions()->{$gfs->[$i]->uuid()},
			media_ref => $gf->media_ref(),
		});
	}
	$gfs = $obj->unintegratedGapfillings();
	for (my $i=0; $i < @{$gfs}; $i++) {
		my $gf = TranslateGapfilling($gfs->[$i]);
		push(@{$data->{gapfillings}},{
			gapfill_id => $gf->id(),
			gapfill_ref => $gf->_reference(),
			integrated => 0,
			integrated_solution => 0,
			media_ref => $gf->media_ref(),
		});
	}
	my $ggs = $obj->integratedGapgens();
	for (my $i=0; $i < @{$ggs}; $i++) {
		my $gg = TranslateGapgen($ggs->[$i]);
		push(@{$data->{gapgens}},{
			gapgen_id => $gg->id(),
			gapgen_ref => $gg->_reference(),
			integrated => 1,
			integrated_solution => $obj->integratedGapgenSolutions()->{$ggs->[$i]->uuid()},
			media_ref => $gg->media_ref(),
		});
	}
	$ggs = $obj->unintegratedGapgens();
	for (my $i=0; $i < @{$ggs}; $i++) {
		my $gg = TranslateGapgen($ggs->[$i]);
		push(@{$data->{gapgens}},{
			gapgen_id => $gg->id(),
			gapgen_ref => $gg->_reference(),
			integrated => 0,
			integrated_solution => 0,
			media_ref => $gg->media_ref(),
		});
	}
} elsif ($array->[0] eq "FBA") {
	my $model = $newstore->get_object("FBAModel",$obj->model_uuid());
	my $data = {
		id => "kb|fba.".$idserv->allocate_id_range("kb|fba",1),
		compoundflux_objterms => {},
		reactionflux_objterms => {},
		biomassflux_objterms => {},
		FBAConstraints => [],
		FBAReactionBounds => [],
		FBACompoundBounds => [],
		FBACompoundVariables => [],
		FBAReactionVariables => [],
		FBABiomassVariables => [],
		FBAPromResults => [],
		FBADeletionResults => [],
		FBAMinimalMediaResults => [],
		FBAMetaboliteProductionResults => [],
	};
	my $list = [qw(uptakeLimits inputfiles parameters drainfluxUseVariables fluxUseVariables decomposeReversibleDrainFlux decomposeReversibleFlux PROMKappa defaultMinDrainFlux defaultMaxDrainFlux defaultMaxFlux objectiveConstraintFraction comboDeletions numberOfSolutions maximizeObjective minimizeErrorThermodynamicConstraints noErrorThermodynamicConstraints thermodynamicConstraints fva fluxMinimization findMinimalMedia allReversible simpleThermoConstraints)];
	foreach my $item (@{$list}) {
		if (defined($obj->$item())) {
			$data->{$item} = $obj->$item();
		}
	}
	if (defined($obj->fbaResults()->[0])) {
		$data->{objectiveValue} = $obj->fbaResults()->[0]->objectiveValue();
		$data->{outputfiles} = $obj->fbaResults()->[0]->outputfiles();
	}		
	#regmodel_ref regmodel_ref;
	#fbamodel_ref fbamodel_ref;
	#prommodel_ref prommodel_ref;
	#media_ref media_ref;
	#phenotypeset_ref phenotypeset_ref;
	#list<feature_ref> geneKO_refs;
	#list<modelreaction_ref> reactionKO_refs;
	#list<compound_ref> additionalCpd_refs;
	#phenotypesimulationset_ref phenotypesimulationset_ref;
	my $NewFBA = Bio::KBase::ObjectAPI::KBaseFBA::FBA->new($data);
	eval {
		$NewFBA->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "ModelTemplate") {
	my $mapping = $newstore->get_object("kbase/default-mapping");
	my $biochem = $newstore->get_object("kbase/default");
	my $data = {
		id => "kb|mdltmp.".$idserv->allocate_id_range("kb|mdltmp",1),
		domain => $obj->domain(),
		name => $obj->name(),
		modelType => $obj->modelType(),
		mapping_ref => $mapping->_reference(),
		templateReactions => [],
		templateBiomasses => []
	};
	my $temprxns = $obj->templateReactions();
	my $rxncount = 1;
	foreach my $temprxn (@{$temprxns}) {
		my $newrxn = {
			id => $data->{id}.".temprxn.".$rxncount,
			type => $temprxn->type(),
			direction => $temprxn->direction(),
			reaction_ref => $biochem->_reference()."/reactions/id/".$temprxn->reaction()->id(),
			compartment_ref => $biochem->_reference()."/compartments/id/".$temprxn->compartment()->id(),
			complex_refs => []
		};
		$rxncount++;
		my $complexes = $temprxn->complexes();
		foreach my $complex (@{$complexes}) {
			push(@{$newrxn->{complex_refs}},$mapping->_reference()."/complexes/id/".$complex->id());
		}
		push(@{$data->{templateReactions}},$newrxn);
	}
	my $tempbios = $obj->templateBiomasses();
	my $biocount = 1;
	foreach my $tempbio (@{$tempbios}) {
		my $newtempbio = {
			id => $data->{id}.".tempbio.".$biocount,
			templateBiomassComponents => []
		};
		my $list = [qw(name type other dna rna protein lipid cellwall cofactor energy)];
		foreach my $item (@{$list}) {
			if (defined($tempbio->$item())) {
				if ($item eq "name" || $item eq "type") {
					$newtempbio->{$item} = $tempbio->$item();
				} else {
					$newtempbio->{$item} = $tempbio->$item()+0;
				}
			}
		}
		$biocount++;
		my $tempbiocomps = $tempbio->templateBiomassComponents();
		my $count = 1;
		foreach my $tempbiocomp (@{$tempbiocomps}) {
			my $newtempbiocomp = {
				id => $newtempbio->{id}.".tempbiocomp.".$count,
    			class => $tempbiocomp->class(),
    			compound_ref => $biochem->_reference()."/compounds/id/".$tempbiocomp->compound()->id(),
    			compartment_ref => $biochem->_reference()."/compartments/id/".$tempbiocomp->compartment()->id(),
    			coefficientType => $tempbiocomp->coefficientType(),
    			coefficient => $tempbiocomp->coefficient()+0,
    			linked_compound_refs => [],
    			link_coefficients => $tempbiocomp->linkCoefficients()
			};
			for (my $i=0; $i < @{$newtempbiocomp->{link_coefficients}}; $i++) {
				$newtempbiocomp->{link_coefficients}->[$i] = $newtempbiocomp->{link_coefficients}->[$i]+0;
			}
			$count++;
			my $linkedcpds = $tempbiocomp->linkedCompounds();
			foreach my $linkcpd (@{$linkedcpds}) {
				push(@{$newtempbiocomp->{linked_compound_refs}},$biochem->_reference()."/compounds/id/".$linkcpd->id());
			}
			push(@{$newtempbio->{templateBiomassComponents}},$newtempbiocomp);
		}
		push(@{$data->{templateBiomasses}},$newtempbio);
	}
	my $NewModelTemplate = Bio::KBase::ObjectAPI::KBaseFBA::ModelTemplate->new($data);
	$NewModelTemplate->parent($newstore);
	eval {
		$NewModelTemplate->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "PhenotypeSet") {
	my $data = {phenotypes => []};
	my $list = [qw(id name source source_id importErrors)];
	foreach my $item (@{$list}) {
		if (defined($obj->$item())) {
			$data->{$item} = $obj->$item();
		}
	}
	my $genobj = $newstore->get_object("Genome",$obj->{genome_workspace}."/".$obj->{genome});
	$data->{genome_ref} = $genobj->_reference();
	my $i=1;
	my $biochem = $newstore->get_object("Biochemistry","kbase/default");
	foreach my $pheno (@{$obj->{phenotypes}}) {
		my $media = $newstore->get_object("Media",$pheno->[2]."/".$pheno->[1]);
		my $newpheno = {
			id => $data->{id}.".pheno.".$i,
			name => $pheno->[5],
			normalizedGrowth => $pheno->[4],
			media_ref => $media->_reference()
		};
		foreach my $gene (@{$pheno->[0]}) {
			push(@{$newpheno->{geneko_refs}},$data->{genome_ref}."/features/id/".$gene);
		}
		foreach my $cpd (@{$pheno->[3]}) {
			push(@{$newpheno->{additionalcompound_refs}},$biochem->_reference()."/compounds/id/".$cpd);
		}
		push(@{$data->{phenotypes}},$newpheno);
		$i++;	
	}
	my $NewPhenoSet = Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSet->new($data);
	eval {
		$NewPhenoSet->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "Mapping") {
	my $data = {
		id => "kb|mapping.".$idserv->allocate_id_range("kb|mapping",1),
		name => $obj->name(),
		subsystems => [],
		complexes => [],
		roles => [],
		role_aliases => {},
		complex_aliases => {},
		subsystem_aliases => {}
	};
	my $roles = $obj->roles();
	foreach my $role (@{$roles}) {
		my $newrole = {};
		my $list = [qw(id name seedfeature)];
		foreach my $item (@{$list}) {
			if (defined($role->$item())) {
				$newrole->{$item} = $role->$item();
			}
		}
		push(@{$data->{roles}},$newrole);
	}
	my $rolesets = $obj->rolesets();
	foreach my $roleset (@{$rolesets}) {
		my $newss = {role_refs => []};
		my $list = [qw(id name class subclass type)];
		foreach my $item (@{$list}) {
			if (defined($roleset->$item())) {
				$newss->{$item} = $roleset->$item();
			}
		}
		my $roles = $roleset->roles();
		foreach my $role (@{$roles}) {
			push(@{$newss->{role_refs}},"~/roles/id/".$role->id());
		}
		push(@{$data->{subsystems}},$newss);
	}
	my $complexes = $obj->complexes();
	foreach my $complex (@{$complexes}) {
		my $newcpx = {complexroles => []};
		my $list = [qw(id name)];
		foreach my $item (@{$list}) {
			if (defined($complex->$item())) {
				$newcpx->{$item} = $complex->$item();
			}
		}
		my $cpxroles = $complex->complexroles();
		foreach my $cpxrole (@{$cpxroles}) {
			my $newcpxrole = {};
			my $list = [qw(optional type triggering)];
			foreach my $item (@{$list}) {
				if (defined($cpxrole->$item())) {
					if ($item eq "optional") {
						$newcpxrole->{optionalRole} = $cpxrole->optional()+0;
					} elsif ($item eq "triggering") {
						$newcpxrole->{$item} = $cpxrole->triggering()+0;
					} else {
						$newcpxrole->{$item} = $cpxrole->$item();
					}
				}
			}
			$newcpxrole->{role_ref} = "~/roles/id/".$cpxrole->role()->id();
			push(@{$newcpx->{complexroles}},$newcpxrole);
		}
		push(@{$data->{complexes}},$newcpx);
	}
	my $aliassets = $obj->aliasSets();
	for (my $i=0; $i < @{$aliassets}; $i++) {
		my $set = $aliassets->[$i];
		my $aliases = $set->aliases();
		foreach my $alias (keys(%{$aliases})) {
			my $uuids = $aliases->{$alias};
			foreach my $uuid (@{$uuids}) {
				my $function;
				if ($set->attribute() eq "complexes") {
					$function = "complex_aliases";
				} elsif ($set->attribute() eq "subsystems") {
					$function = "subsystem_aliases";
				} elsif ($set->attribute() eq "roles") {
					$function = "role_aliases";
				}
				if (defined($function)) {
					push(@{$data->{$function}->{$obj->getObject($set->attribute(),$uuid)->id()}->{$set->name()}},$alias);
				}
			}
		}
	}
	my $NewMapping = Bio::KBase::ObjectAPI::KBaseOntology::Mapping->new($data);
	$NewMapping->parent($newstore);
	eval {
		$NewMapping->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "Media") {
	my $bioobj = $newstore->get_object("kbase/default");
	print "Retrieved new biochemistry!\n";
	my $origbio = $oldstore->get_object("Biochemistry","kbase/default");
	print "Retrieved old biochemistry!\n";
	$obj->parent($origbio);
	my $data = {id => "kb|media.".$idserv->allocate_id_range("kb|media",1),mediacompounds => []};
	my $list = [qw(isDefined isMinimal name type)];
	foreach my $item (@{$list}) {
		if (defined($obj->$item())) {
			$data->{$item} = $obj->$item();
		}
	}
	$data->{source_id} = $obj->{id};
	my $mediacompounds = $obj->mediacompounds();
	foreach my $mediacomp (@{$mediacompounds}) {
		my $newcomp = {};
		$newcomp->{compound_ref} = $bioobj->_reference()."/compounds/id/".$mediacomp->compound()->id();
		$newcomp->{concentration} = $mediacomp->concentration()+0;
		$newcomp->{maxFlux} = $mediacomp->maxFlux()+0;
		$newcomp->{minFlux} = $mediacomp->minFlux()+0;
		push(@{$data->{mediacompounds}},$newcomp);
	}
	my $NewMedia = Bio::KBase::ObjectAPI::KBaseBiochem::Media->new($data);
	$NewMedia->parent($newstore);
	eval {
		$NewMedia->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "Biochemistry") {
	my $biochemstruct;
	eval {
		$biochemstruct = $obj->biochemistrystructures();
	};
	my $NewBiochemStruct;
	if (defined($biochemstruct)) {
		my $bsid = "kb|biochemstruct.".$idserv->allocate_id_range("kb|biochemstruct",1);
		$NewBiochemStruct = Bio::KBase::ObjectAPI::KBaseBiochem::BiochemistryStructures->new({
			id => $bsid,
			name => $bsid,
			description => "",
			structures => []
		});
		my $structs = $biochemstruct->structures();
		my $index = 1;
		foreach my $struct (@{$structs}) {
			$NewBiochemStruct->add("structures",{
				id => $bsid.".".$index,
				data => $struct->data(),
				type => $struct->type()
			});
			$index++;
		}
		$NewBiochemStruct->parent($newstore);
		eval {
			$NewBiochemStruct->save($array->[1]."/".$array->[2].".biochemstruct");
			print "Success:".$array->[1]."/".$array->[2].".biochemstruct\n";
		};
		if ($@) {
			print "Failed:".$array->[1]."/".$array->[2].".biochemstruct\n";
			print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
		}
	}
	my $data = {
		id => "kb|biochem.".$idserv->allocate_id_range("kb|biochem",1),
		name => $obj->name(),
		description => "",
		compartments => [],
		compounds => [],
		reactions => [],
		reactionSets => [],
		compoundSets => [],
		cues => [],
		compound_aliases => {},
		reaction_aliases => {}
	};
	my $NewBiochem = Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry->new($data);
	my $cues = $obj->cues();
	for (my $i=0;$i < @{$cues}; $i++) {
		my $data = {};
		my $list = [qw(name abbreviation formula mass defaultCharge deltaG deltaGErr smallMolecule priority)];
		foreach my $item (@{$list}) {
			if (defined($cues->[$i]->$item())) {
				$data->{$item} = $cues->[$i]->$item();
			}
		}
		$data->{id} = $cues->[$i]->name();
		if (defined($biochemstruct)) {
			if (defined($cues->[$i]->structure())) {
				$data->{structure_key} = Digest::MD5::md5_hex($cues->[$i]->structure()->data());
				$data->{structure_data} = $cues->[$i]->structure()->data();
				$data->{structure_type} = $cues->[$i]->structure()->type();
			}
		}
		$NewBiochem->add("cues",$data);
	}
	my $compartments = $obj->compartments();
	for (my $i=0;$i < @{$compartments}; $i++) {
		my $data = {};
		my $list = [qw(id name hierarchy)];
		foreach my $item (@{$list}) {
			if (defined($compartments->[$i]->$item())) {
				$data->{$item} = $compartments->[$i]->$item();
			}
		}
		$NewBiochem->add("compartments",$data);
	}
	my $compounds = $obj->compounds();
	for (my $i=0;$i < @{$compounds}; $i++) {
		my $data = {};
		my $list = [qw(id isCofactor name abbreviation formula unchargedFormula mass defaultCharge deltaG deltaGErr)];
		foreach my $item (@{$list}) {
			if (defined($compounds->[$i]->$item())) {
				$data->{$item} = $compounds->[$i]->$item();
			}
		}
		foreach my $pk (keys(%{$compounds->[$i]->pkas()})) {
			my $array = $compounds->[$i]->pkas()->{$pk};
			foreach my $atom (@{$array}) {
				$atom = $atom+0;
				$pk = $pk+0;
				push(@{$data->{pkas}->{$atom}},$pk);
			}
		}
		foreach my $pk (keys(%{$compounds->[$i]->pkbs()})) {
			my $array = $compounds->[$i]->pkbs()->{$pk};
			foreach my $atom (@{$array}) {
				$atom = $atom+0;
				$pk = $pk+0;
				push(@{$data->{pkbs}->{$atom}},$pk);
			}
		}
		if (defined($compounds->[$i]->cues())) {
			my $cues = $compounds->[$i]->cues();
			foreach my $cue (keys(%{$cues})) {
				my $cueobj = $obj->getObject("cues",$cue);
				$data->{cues}->{"~/cues/id/".$cueobj->name()} = $cues->{$cue};
			}
		}
		if (defined($compounds->[$i]->abstractCompound_uuid())) {
			$data->{abstractCompound_ref} = "~/compounds/id/".$compounds->[$i]->abstractCompound()->id();
		}
		foreach my $compcpd (@{$compounds->[$i]->comprisedOfCompounds()}) {
			push(@{$data->{comprisedOfCompound_refs}},"~/compounds/id/".$compcpd->id());
		};
		if (defined($biochemstruct)) {
			foreach my $struct (@{$compounds->[$i]->structures()}) {
				if ($struct->type() eq "inchi") {
					$data->structure_ref() = $NewBiochemStruct->_reference()."/structures/id/".$NewBiochem->queryObject("structures",{data => $struct->data()})->id();
				}
			}
		}
		$NewBiochem->add("compounds",$data);
	}
	my $reactions = $obj->reactions();
	for (my $i=0;$i < @{$reactions}; $i++) {
		my $data = {reagents => []};
		my $list = [qw(id deltaGErr deltaG defaultProtons name abbreviation direction thermoReversibility status)];
		foreach my $item (@{$list}) {
			if (defined($reactions->[$i]->$item())) {
				$data->{$item} = $reactions->[$i]->$item();
			}
		}
		if (defined($reactions->[$i]->cues())) {
			my $cues = $reactions->[$i]->cues();
			foreach my $cue (keys(%{$cues})) {
				my $cueobj = $obj->getObject("cues",$cue);
				$data->{cues}->{"~/cues/id/".$cueobj->name()} = $cues->{$cue};
			}
		}
		if (defined($reactions->[$i]->reagents())) {
			my $reagents = $reactions->[$i]->reagents();
			foreach my $reagent (@{$reagents}) {
				my $newreagent = {};
				$newreagent->{compound_ref} = "~/compounds/id/".$reagent->compound()->id();
				$newreagent->{compartment_ref} = "~/compartments/id/".$reagent->compartment()->id();
				$newreagent->{coefficient} = $reagent->coefficient();
				$newreagent->{isCofactor} = $reagent->isCofactor()+0;
				push(@{$data->{reagents}},$newreagent);
			}
		}
		if (defined($reactions->[$i]->abstractReaction_uuid())) {
			$data->{abstractReaction_ref} = "~/reactions/id/".$reactions->[$i]->abstractReaction()->id();
		}
		$NewBiochem->add("reactions",$data);
	}
	my $reactionSets = $obj->reactionSets();
	for (my $i=0;$i < @{$reactionSets}; $i++) {
		my $data = {
			id => $reactionSets->[$i]->id(),
			name => $reactionSets->[$i]->name(),
			class => $reactionSets->[$i]->class(),
			type => $reactionSets->[$i]->type(),
			reaction_refs => []
		};
		my $rxns = $reactionSets->[$i]->reactions();
		for (my $j=0; $j < @{$rxns}; $j++) {
			push(@{$data->{reaction_refs}},"~/reactions/id/".$rxns->[$j]->id());
		}
		$NewBiochem->add("reactionSets",$data);
	}
	my $compoundSets = $obj->compoundSets();
	for (my $i=0;$i < @{$compoundSets}; $i++) {
		my $data = {
			id => $compoundSets->[$i]->id(),
			name => $compoundSets->[$i]->name(),
			class => $compoundSets->[$i]->class(),
			type => $compoundSets->[$i]->type(),
			compound_refs => []
		};
		my $cpds = $compoundSets->[$i]->compounds();
		for (my $j=0; $j < @{$cpds}; $j++) {
			push(@{$data->{compound_refs}},"~/compounds/id/".$cpds->[$j]->id());
		}
		$NewBiochem->add("compoundSets",$data);
	}
	my $aliassets = $obj->aliasSets();
	for (my $i=0; $i < @{$aliassets}; $i++) {
		my $set = $aliassets->[$i];
		my $aliases = $set->aliases();
		foreach my $alias (keys(%{$aliases})) {
			my $uuids = $aliases->{$alias};
			foreach my $uuid (@{$uuids}) {
				my $function;
				if ($set->attribute() eq "reactions") {
					$function = "reaction_aliases";
				} elsif ($set->attribute() eq "compounds") {
					$function = "compound_aliases";
				}
				if (defined($function)) {
					push(@{$NewBiochem->$function()->{$obj->getObject($set->attribute(),$uuid)->id()}->{$set->name()}},$alias);
				}
			}
		}
	}
	$NewBiochem->parent($newstore);
	eval {
		$NewBiochem->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
} elsif ($array->[0] eq "Genome") {
	if ($obj->{id} !~ m/kb\|/) {
		$obj->{id} = "kb|g.".$idserv->allocate_id_range("kb|g",1);
	}
	my $genomedata = {
		id => $obj->{id},
		scientific_name => "Unknown",
		domain => "Bacteria",
		genetic_code => 11,
		source => "KBase",
		source_id => $obj->{id},
		taxonomy => "Unknown",
		gc_content => 0.5,
		features => [],
	};
	my $items = ["publications","source","source_id","scientific_name","taxonomy","gc_content","domain","genetic_code"];
	foreach my $item (@{$items}) {
		if (defined($obj->{$item})) {
			$genomedata->{$item} = $obj->{$item};
		}
	}
	if (defined($obj->{gc})) {
		$genomedata->{gc_content} = $obj->{gc};
	}
	if (defined($obj->{features})) {
		for (my $i=0; $i < @{$obj->{features}}; $i++) {
			my $ftr = $obj->{features}->[$i];
			my $newftr = {
				id => $ftr->{id}
			};
			$items = ["location","protein_families","subsystems","publications","co_occurring_fids","coexpressed_fids","atomic_regulons","regulon_data","subsystem_data","function","protein_translation","dna_sequence","type","function","aliases","annotations"];
			foreach my $item (@{$items}) {
				if (defined($ftr->{$item})) {
					$newftr->{$item} = $ftr->{$item};
				}
			}
			if (!defined($newftr->{type}) && $newftr->{id} =~ m/(\w+)\.\d+$/) {
				$newftr->{type} = $1;
			}
			if (defined($newftr->{protein_translation})) {
				$newftr->{protein_translation_length} = length($newftr->{protein_translation});
				$newftr->{md5} = Digest::MD5::md5_hex($newftr->{protein_translation});
			}
			if (defined($newftr->{dna_sequence})) {
				$newftr->{dna_sequence_length} = length($newftr->{dna_sequence});
			}
			push(@{$genomedata->{features}},$newftr);
		}
	}
	if (!defined($genomedata->{scientific_name})) {
		$genomedata->{scientific_name} = $obj->{id};
	}
	if (defined($obj->{contigs_uuid})) {
		my $oldcontigs = $oldstore->get_object("GenomeContigs",$obj->{contigs_uuid});
		my $label = "dna";
		if (defined($oldcontigs->{contigs}->[0]->{seq})) {
			$label = "seq";
		}
		$genomedata->{num_contigs} = @{$oldcontigs->{contigs}};
		my $sortedcontigs = [sort { $a->{$label} cmp $b->{$label} } @{$oldcontigs->{contigs}}];
		my $str = "";
		for (my $i=0; $i < @{$sortedcontigs}; $i++) {
			if (length($str) > 0) {
				$str .= ";";
			}
			$str .= $sortedcontigs->[$i]->{$label};
			
		}
		$genomedata->{dna_size} = length($str);
		my $newdata = {
			name => $genomedata->{scientific_name},
			md5 => Digest::MD5::md5_hex($str),
			source_id => $genomedata->{source_id},
			source => $genomedata->{source},
			type => "Organism",
			contigs => []
		};
		$genomedata->{md5} = $newdata->{md5};
		my $output = $idserv->register_ids("kb|contigset","md5hash",[$newdata->{md5}]);
		$newdata->{id} = $output->{$newdata->{md5}};
		for (my $i=0; $i < @{$oldcontigs->{contigs}}; $i++) {
			push(@{$genomedata->{contig_ids}},$oldcontigs->{contigs}->[$i]->{id});
			push(@{$genomedata->{contig_lengths}},length($oldcontigs->{contigs}->[$i]->{$label}));
			my $md5 = Digest::MD5::md5_hex($oldcontigs->{contigs}->[$i]->{$label});
			push(@{$newdata->{contigs}},{
				id => $oldcontigs->{contigs}->[$i]->{id},
				"length" => length($oldcontigs->{contigs}->[$i]->{$label}),
				md5 => $md5,
				sequence => $oldcontigs->{contigs}->[$i]->{$label},
				name => $oldcontigs->{contigs}->[$i]->{id}
			});
		}
		my $ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($newdata);
		$ContigObj->parent($newstore);
		eval {
			$ContigObj->save($array->[1]."/".$array->[2].".contigset");
			print "Success:".$array->[1]."/".$array->[2].".contigset\n";
		};
		if ($@) {
			print "Failed:".$array->[1]."/".$array->[2].".contigset\n" ;
			print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
		}
		$genomedata->{contigset_ref} = $ContigObj->_reference();
	}
	my $GenomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomedata);
	my $features = $GenomeObj->features();
	$GenomeObj->parent($newstore);
	eval {
		$GenomeObj->save($array->[1]."/".$array->[2]);
		print "Success:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n";
	};
	if ($@) {
		print "Failed:".$array->[1]."/".$array->[2]."/".$obj->{"_kbaseWSMeta"}->{wsinst}."\n" ;
		print "ERROR_MESSAGE".$@."END_ERROR_MESSAGE\n";
	}
}

1;
