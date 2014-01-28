# try to do away with typeToFunction and functionToType.
# call around methods via $orig, and store class name in info hash

use strict;
use ModelSEED::MS::Metadata::Definitions;
use Bio::KBase::ObjectAPI::utilities;
use DateTime;
use Data::Dumper;

my $defaults = {
	Feature => {
		type => "peg",	
	},
	Reaction => {
		thermoReversibility => "=",
		status => "unknown"
	},
	ModelTemplate => {
		biochemistry_ref => "kbase/default"
	}
};

my $printorder = {
	Genome => {
		id => 0,
		source => 1,
		source_id => 2,
		scientific_name => 3,
		domain => 4,
		genetic_code => 5,
		dna_size => 6,
		num_contigs => 7,
		taxonomy => 8,
		gc_content => 9,
		complete => 10,
		features => 0,
		contigset_ref => 11
	},
	Feature => {
		id => 0,
		type => 1,
		function => 2,
	}
};

my $directory = $ARGV[0];
my $oldobjects = ModelSEED::MS::Metadata::Definitions::objectDefinitions();

my $objtranslation = {
	Gapfilling => "GapfillingFormulation",
	GapgenerationSolution => "GapgenSolution",
	GapfillingReaction => "GapfillingSolutionReaction",
	FBAModel => "Model",
	FBA => "FBAFormulation",
	Subsystem => "RoleSet",
	Gapgeneration => "GapgenFormulation",
	GapgenerationSolutionReaction => "GapgenSolutionReaction"
};
my $refobjtrans = {};
foreach my $key (keys(%{$objtranslation})) {
	$refobjtrans->{$objtranslation->{$key}} = $key;
}
my $baseobjects = {
	Genome => "KBaseGenomes",
	ContigSet => "KBaseGenomes",
	Media => "KBaseBiochem",
	BiochemistryStructures => "KBaseBiochem",
	Biochemistry => "KBaseBiochem",
	RegulatoryModel => "KBaseRegulation",
	PROMModel => "KBaseFBA",
	Stimuli => "KBaseRegulation",
	Mapping => "KBaseOntology",
	ModelTemplate => "KBaseFBA",
	Gapfilling => "KBaseFBA",
	Gapgeneration => "KBaseFBA",
	FBA => "KBaseFBA",
	FBAModel => "KBaseFBA",
	PhenotypeSet => "KBasePhenotypes",
	PhenotypeSimulationSet => "KBasePhenotypes",
	ProteinSet => "KBaseGenomes",
	ProbabilisticAnnotation => "KBaseGenomes"
};
my $objcorrespondence = {
	BiochemistryStructures => "BiochemistryStructures",
	Biochemistry => "Biochemistry",
	RegulatoryModel => "RegulatoryModel",
	PROMModel => "PROMModel",
	Stimuli => "Stimuli",
	Mapping => "Mapping",
	ModelTemplate => "ModelTemplate",
	GapFilling => "GapfillingFormulation",
	GapGeneration => "GapgenFormulation",
	FBA => "FBAFormulation",
	FBAModel => "Model",
};
my $revcorrespondence = {};
foreach my $obj (keys(%{$objcorrespondence})) {
	$revcorrespondence->{$objcorrespondence->{$obj}} = $obj;
}
my $subobj = {};
my $specobjects = {};
my $speclist = ["FBAModel.spec","Ontology.spec","Biochem.spec","Genome.spec","Phenotypes.spec"];
for (my $i=0; $i < @{$speclist}; $i++) {
	my $module;
	my $stringtypes = {};
	my $currref = {};
	my $inobject = 0;
	my $currentobject = {_searchable => [],_optional => []};
	open (my $specfile, "<", $directory."/".$speclist->[$i]) || die "Couldn't open ".$directory."/".$speclist->[$i]." : $!";
	while (my $line = <$specfile>) {
		chomp($line);
		if ($line =~ m/module\s(.+)\s\{/) {
			$module = $1;
		} elsif ($line =~ m/typedef\sstring\s(.+);/) {
			my $type = $1;
			$stringtypes->{$type} = $currref;
			if ($type =~ m/_ref$/) {
				$stringtypes->{$type}->{type} = "ref";
			} elsif ($type =~ m/_id$/) {
				$stringtypes->{$type}->{type} = "id";
			} else {
				$stringtypes->{$type}->{type} = "other";
			}
			$currref = {};
		} elsif ($line =~ m/\@id\s+ws\s+(.+)\.(.+)/) {
			$currref->{target} = "parent";
			$currref->{module} = $1;
			$currref->{object} = $2;
			$currref->{database} = "ws";
		} elsif ($line =~ m/\@id\s+subws\s+(.+)\.(.+)\.(.+)\.\[\*\]\.(.+)/) {
			$currref->{target} = "child";
			$currref->{module} = $1;
			$currref->{object} = $2;
			$currref->{method} = $3;
			$currref->{field} = $4;
			$currref->{database} = "ws";
		} elsif ($line =~ m/\@id\s+(.+)/) {
			$currref->{database} = $1;
		} elsif ($line =~ m/\@searchable\s+ws_subset\s+(.+)$/) {
			push(@{$currentobject->{_searchable}},split(/\s/,$1));
		} elsif ($line =~ m/\@optional\s+(.+)$/) {
			push(@{$currentobject->{_optional}},split(/\s/,$1));
		} elsif ($line =~ m/typedef\s+structure\s+\{/) {
			$inobject = 1;
		} elsif ($line =~ m/\}\s*(.+);/) {
			my $objname = $1;
			$specobjects->{$module}->{$objname} = $currentobject;
			if (!defined($baseobjects->{$objname})) {
				$subobj->{$objname} = $currentobject;
			}
			$currentobject = {_searchable => [],_optional => []};
			$inobject = 0;
		} elsif ($line =~ m/([^\s]+)\s+([^\s]+);/) {
			if ($inobject == 1) {
				$currentobject->{$2} = $1;
			} else {
				print STDERR "Declaring variable outside of object:".$line."\n\n";
			}
		}
	}
	close($specfile);
	$specobjects->{$module}->{stringtypes} = $stringtypes;
}
#Building full spec
my $typetrans = {
	string => "Str",
	"int" => "Int",
	bool => "Bool",
	float => "Num",
};
my $finalbase;
my $finalsub;
my $methods;
my $modules;
foreach my $module (keys(%{$specobjects})) {
	foreach my $objname (keys(%{$specobjects->{$module}})) {
		if ($objname ne "stringtypes") {
			$modules->{$objname} = $module;
			my $obj = $specobjects->{$module}->{$objname};
			my $newobj = {
				module => $module,
				parent => 'Ref',
				attributes => [],
				subobjects => [],
				primarykeys => ["id"],
				links => [],
				reference_id_types => ["id"],
				version => 1.0
			};
			if (defined($oldobjects->{$objname})) {
				$newobj->{analog} = $oldobjects->{$objname};
			} elsif (defined($objtranslation->{$objname})) {
				$newobj->{analog} = $oldobjects->{$objtranslation->{$objname}};
			}
			if (defined($baseobjects->{$newobj})) {
				$newobj->{class} = "indexed";
				$finalbase->{$objname} = $newobj;
			} else {
				$newobj->{class} = "child";
				$finalsub->{$objname} = $newobj;
			}
			foreach my $att (keys(%{$obj})) {
				my $type = $obj->{$att};
				if ($att ne "_searchable" && $att ne "_optional") {
					if ($type =~ m/^list\<(.+)\>/) {
						my $subtype = $1;
						if (defined($subobj->{$subtype})) {
							$methods->{$subtype} = $att;
							push(@{$newobj->{subobjects}},{
								module => $module,
								name       => $att,
								printOrder => -1,
								class      => $subtype,
								type       => "child"
							});
						} elsif ($subtype =~ m/_ref$/ && $att =~ m/(.+)_refs$/) {
							my $ref = $specobjects->{$module}->{stringtypes}->{$subtype};
							my $link = {
								module => $modules->{$ref->{object}},
								class => $ref->{object},
								name => $1."s",
								attribute => $att,
								array => 1
							};
							if ($ref->{target} eq "parent") {
								$link->{parent} = "Bio::KBase::ObjectAPI::Util::KBaseStore";
								$link->{method} = $ref->{object};
							} else {
								$link->{parent} = $ref->{object};
								$link->{method} = $ref->{method};
								$link->{field} = $ref->{field};
							}
							push(@{$newobj->{links}},$link);
							push(@{$newobj->{attributes}},{
								name       => $att,
								printOrder => -1,
								perm       => 'rw',
								type       => "ArrayRef",
								req        => 0,
								default    => "sub {return [];}"
							});		
						} else {
							push(@{$newobj->{attributes}},{
								name       => $att,
								printOrder => -1,
								perm       => 'rw',
								type       => "ArrayRef",
								req        => 0,
								default    => "sub {return [];}"
							});
						}
					} elsif ($type =~ m/^mapping\<(.+)\>$/) {
						push(@{$newobj->{attributes}},{
							name       => $att,
							printOrder => -1,
							perm       => 'rw',
							type       => "HashRef",
							req        => 0,
							default    => "sub {return {};}"
						});
					} elsif ($type =~ m/_ref$/ && $att =~ m/(.+)_ref$/) {
						my $ref = $specobjects->{$module}->{stringtypes}->{$type};
						my $link = {
							module => $modules->{$ref->{object}},
							class => $ref->{object},
							name => $1,
							attribute => $att,
						};
						if ($ref->{target} eq "parent") {
							$link->{parent} = "Bio::KBase::ObjectAPI::KBaseStore",
							$link->{method} = $ref->{object}
						} else {
							$link->{parent} = $ref->{object};
							$link->{method} = $ref->{method};
							$link->{field} = $ref->{field};
						}
						push(@{$newobj->{links}},$link);
						push(@{$newobj->{attributes}},{
							name       => $att,
							printOrder => -1,
							perm       => 'rw',
							type       => "Str",
							req        => 0,
						});
					} elsif (defined($typetrans->{$type})) {
						push(@{$newobj->{attributes}},{
							name       => $att,
							printOrder => -1,
							perm       => 'rw',
							type       => $typetrans->{$type},
							req        => 0,
						});
					} elsif ($type =~ m/tuple\<(.+)\>/) {
						push(@{$newobj->{attributes}},{
							name       => $att,
							printOrder => -1,
							perm       => 'rw',
							type       => 'ArrayRef',
							req        => 0,
							default    => "sub {return [];}"
						});
					} elsif ($type =~ m/_id$/) {
						push(@{$newobj->{attributes}},{
							name       => $att,
							printOrder => 0,
							perm       => 'rw',
							type       => 'Str',
							req        => 1
						});
					} else {
						print $objname."::".$att."\n";
						print STDERR "Unhandled type:".$type."\n";
					}
				}
			}
		}
	}
}
#Compare types and highlight missing and extra types:
my $allobjects = {};
foreach my $name (keys(%{$finalsub})) {
	$allobjects->{$name} = $finalsub->{$name};
}
foreach my $name (keys(%{$finalbase})) {
	$allobjects->{$name} = $finalbase->{$name};
}
print "Missing types:\n";
foreach my $oldobject (keys(%{$oldobjects})) {
	my $newobject = $oldobject;
	if (defined($refobjtrans->{$oldobject})) {
		$newobject = $refobjtrans->{$oldobject};
	}
	if (!defined($allobjects->{$newobject})) {
		print $oldobject."\n";
	}
}
print "\n\n";
print "Extra types:\n";
foreach my $object (keys(%{$allobjects})) {
	my $oldobject = $object;
	if (defined($objtranslation->{$object})) {
		$oldobject = $objtranslation->{$object};
	}
	if (!defined($oldobjects->{$oldobject})) {
		print $object."\n";
	} else {
		for (my $i=0; $i < @{$allobjects->{$object}->{attributes}}; $i++) {
			my $found = 0;
			for (my $j=0; $j < @{$oldobjects->{$oldobject}->{attributes}}; $j++) {
				$oldobjects->{$oldobject}->{attributes}->[$j]->{name} =~ s/_uuid/_ref/;
				if ($allobjects->{$object}->{attributes}->[$i]->{name} eq $oldobjects->{$oldobject}->{attributes}->[$j]->{name}) {
					$allobjects->{$object}->{attributes}->[$i]->{printOrder} = $oldobjects->{$oldobject}->{attributes}->[$j]->{printOrder};
					$allobjects->{$object}->{attributes}->[$i]->{"default"} = $oldobjects->{$oldobject}->{attributes}->[$j]->{"default"};
					$allobjects->{$object}->{attributes}->[$i]->{description} = $oldobjects->{$oldobject}->{attributes}->[$j]->{description};
					$allobjects->{$object}->{attributes}->[$i]->{req} = $oldobjects->{$oldobject}->{attributes}->[$j]->{req};
					$oldobjects->{$oldobject}->{attributes}->[$j]->{_found} = 1;
					$found = 1;
				}
			}
			if (defined($defaults->{$object}->{$allobjects->{$object}->{attributes}->[$i]->{name}})) {
				$allobjects->{$object}->{attributes}->[$i]->{"default"} = $defaults->{$object}->{$allobjects->{$object}->{attributes}->[$i]->{name}};
			}
			if ($found == 0) {
				$allobjects->{$object}->{extraATT}->{$allobjects->{$object}->{attributes}->[$i]->{name}} = 1;
			}
		}
		for (my $j=0; $j < @{$oldobjects->{$oldobject}->{attributes}}; $j++) {
			$oldobjects->{$oldobject}->{attributes}->[$j]->{name} =~ s/_uuid/_ref/;
			if (!defined($oldobjects->{$oldobject}->{attributes}->[$j]->{_found})) {
				$allobjects->{$object}->{missingATT}->{$oldobjects->{$oldobject}->{attributes}->[$j]->{name}} = 1;
			}
		}
		for (my $i=0; $i < @{$allobjects->{$object}->{subobjects}}; $i++) {
			my $found = 0;
			for (my $j=0; $j < @{$oldobjects->{$oldobject}->{subobjects}}; $j++) {
				if ($allobjects->{$object}->{subobjects}->[$i]->{name} eq $oldobjects->{$oldobject}->{subobjects}->[$j]->{name}) {
					$allobjects->{$object}->{subobjects}->[$i]->{printOrder} = $oldobjects->{$oldobject}->{subobjects}->[$j]->{printOrder};
					$allobjects->{$object}->{subobjects}->[$i]->{"default"} = $oldobjects->{$oldobject}->{subobjects}->[$j]->{"default"};
					$allobjects->{$object}->{subobjects}->[$i]->{description} = $oldobjects->{$oldobject}->{subobjects}->[$j]->{description};
					$allobjects->{$object}->{subobjects}->[$i]->{req} = $oldobjects->{$oldobject}->{subobjects}->[$j]->{req};
					$oldobjects->{$oldobject}->{subobjects}->[$j]->{_found} = 1;
					$found = 1;
				}
			}
			if ($found == 0) {
				$allobjects->{$object}->{extraSO}->{$allobjects->{$object}->{subobjects}->[$i]->{name}} = 1;
			}
		}
		for (my $j=0; $j < @{$oldobjects->{$oldobject}->{subobjects}}; $j++) {
			if (!defined($oldobjects->{$oldobject}->{subobjects}->[$j]->{_found})) {
				$allobjects->{$object}->{missingSO}->{$oldobjects->{$oldobject}->{subobjects}->[$j]->{name}} = 1;
			}
		}
	}
}
print "\n\n";
foreach my $object (keys(%{$allobjects})) {
	if (defined($allobjects->{$object}->{missingSO})) {
		print $object.":missingSO:".join(";",keys(%{$allobjects->{$object}->{missingSO}}))."\n";
	}
	if (defined($allobjects->{$object}->{extraSO})) {
		print $object.":extraSO:".join(";",keys(%{$allobjects->{$object}->{extraSO}}))."\n";
	}
	if (defined($allobjects->{$object}->{missingATT})) {
		print $object.":missingATT:".join(";",keys(%{$allobjects->{$object}->{missingATT}}))."\n";
	}
	if (defined($allobjects->{$object}->{extraATT})) {
		print $object.":extraATT:".join(";",keys(%{$allobjects->{$object}->{extraATT}}))."\n";
	}
}
print "\n\n";

#Creating moose objects
my $tab = "	";
foreach my $name (keys(%{$allobjects})) {
	my $object = $allobjects->{$name};
	my $module = $object->{module};
	#Creating header
    my $output = [
        "########################################################################",
        "# Bio::KBase::ObjectAPI::".$module."::DB::".$name." - This is the moose object corresponding to the ".$module.".".$name." object",
        "# Authors: Christopher Henry, Scott Devoid, Paul Frybarger",
        "# Contact email: chenry\@mcs.anl.gov",
        "# Development location: Mathematics and Computer Science Division, Argonne National Lab",
        "########################################################################"
    ];
	#Creating package statement
	push(@$output, "package Bio::KBase::ObjectAPI::".$module."::DB::" . $name . ";");
	#Creating perl use statements
	my $baseObject = "BaseObject";
	if (defined($baseobjects->{$name})) {
	   $baseObject = "IndexedObject";
	}
	push(@$output, "use Bio::KBase::ObjectAPI::" . $baseObject . ";");
	foreach my $subobject (@{$object->{subobjects}}) {
	   if ($subobject->{type} !~ /hasharray/) {
		  push(@$output, "use Bio::KBase::ObjectAPI::".$subobject->{module}."::". $subobject->{class} . ";");
	   }
	}
	push(@$output,
		"use Moose;",
		"use namespace::autoclean;"
	);
	#Determining and setting base class
	push(@$output, "extends 'Bio::KBase::ObjectAPI::" . $baseObject . "';", "", "");
	#Print version statement if we need that
	if (defined($baseobjects->{$name})) {
		push(@$output, "our \$VERSION = 1.0;");
	}
	#Printing parent
	push(@$output, "# PARENT:");
	push(@$output, "has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');");
	#Printing attributes
	push(@$output, "# ATTRIBUTES:");
	push(@$output,"has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');");
	push(@$output,"has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');");
	my $uuid = 0;
	my $modDate = 0;
	my $attrs = [];
	my $linkHash = {};
	if (defined($object->{links})) {
		foreach my $link (@{$object->{links}}) {
			my $name = $link->{name};
			my $att = $link->{attribute};
			$linkHash->{$att} = $name;
		}
	}
	foreach my $attribute (@{$object->{attributes}}) {
	   if (!defined($attribute->{printOrder})) {
	   		$attribute->{printOrder} = -1;	
	   }
	   if (defined($printorder->{$name}->{$attribute->{name}})) {
	   		$attribute->{printOrder} = $printorder->{$name}->{$attribute->{name}};
	   }
	   my $props = [
		  "is => '" . $attribute->{perm} . "'",
		  "isa => '" . $attribute->{type} . "'",
		  "printOrder => '". $attribute->{printOrder} ."'"
	   ];
	   if (defined($attribute->{req}) && $attribute->{req} == 1) {
		  push(@$props, "required => 1");
	   }
	   if (defined($attribute->{default})) {
		  if ($attribute->{default} =~ /sub\s*\{/) {
				push(@$props, "default => " . $attribute->{default} );
			} else {
				push(@$props, "default => '" . $attribute->{default} . "'");
			}
	   }
	   if ($attribute->{name} eq "id") {
		  $uuid = 1;
	   }
	   push(@$props, "type => 'attribute'", "metaclass => 'Typed'");

	   push(@$output, "has " . $attribute->{name} . " => (" . join(", ", @$props) . ");");
	   push(@$attrs, "'" . $attribute->{name} . "'");
	}
	push(@$output, "", "");
	#Printing subobjects
	my $typeToFunction;
	my $functionToType;
	if (defined($object->{subobjects}) && defined($object->{subobjects}->[0])) {
		push(@$output, "# SUBOBJECTS:");
		foreach my $subobject (@{$object->{subobjects}}) {
			if (!defined($subobject->{printOrder})) {
				$subobject->{printOrder} = -1;	
			}
			if (defined($printorder->{$name}->{$subobject->{name}})) {
				$subobject->{printOrder} = $printorder->{$name}->{$subobject->{name}};
			}
			$typeToFunction->{$subobject->{class}} = $subobject->{name};
			$functionToType->{$subobject->{name}} = $subobject->{class};

			my $soname = $subobject->{name};
			my $class = $subobject->{class};

			my $props = [ "is => 'rw'" ];
			my $type = $subobject->{type};

			push(@$props,
				"isa => 'ArrayRef[HashRef]'",
				"default => sub { return []; }",
				"type => '$type($class)'",
				"metaclass => 'Typed'",
				"reader => '_$soname'",
				"printOrder => '". $subobject->{printOrder} ."'"
			);

			push(@$output, "has $soname => (" . join(", ", @$props) . ");");
		}
		push(@$output, "", "");
	}
	#Printing object links
	if (defined($object->{links})) {
	   push(@$output, "# LINKS:");
	   foreach my $subobject (@{$object->{links}}) {
		  my $soname = $subobject->{name};
		  my $parent = $subobject->{parent};
		  my $method = $subobject->{method};
		  my $attr = $subobject->{attribute};
		  my $can_be_undef = $subobject->{can_be_undef};
			$can_be_undef = 0 unless defined $can_be_undef;
		  $subobject->{clearer} = "clear_".$soname;
		  #if (defined($functionToType->{$method})) {
		  	#$subobject->{class} = $functionToType->{$method};
		  #} else {
		  	#$subobject->{class} = $method;
		  #}
		  my $weak = (defined($subobject->{weak})) ? $subobject->{weak} : 1;
		  warn "$name $soname is notweak" if(!$weak);
		  # find link class
		  my $class;
		  foreach my $parent_so (@{$allobjects->{$parent}->{subobjects}}) {
			 if ($parent_so->{name} eq $method) {
				$class = $parent_so->{class};
				last;
			 }
		  }
		  if (!defined($class)) {
			 $class = $method;
		  }
		  my $type = 'Ref';
		  if (defined($modules->{$class})) {
		  	$type = 'Bio::KBase::ObjectAPI::'.$modules->{$class}."::".$class;
		  	$subobject->{class} = $type;
		  	$subobject->{module} = $modules->{$class};
		  }
		  if (defined($subobject->{array}) && $subobject->{array} == 1) {
		  	$weak = 0;
		  	$type = "ArrayRef";
		  }
		  my $props = [
			 "is => 'rw'",
			 "type => 'link($parent,$method,$attr)'",
			 "metaclass => 'Typed'",
			 "lazy => 1",
			 "builder => '_build_$soname'",
		  	"clearer => 'clear_$soname'",
		  ];
		  if($can_be_undef) {
			 push(@$props, "isa => 'Maybe[$type]'");
		  } else {
			 push(@$props, "isa => '$type'");
		  }
		  push(@$props, "weak_ref => 1") if($weak);
		  push(@$output, "has $soname => (" . join(", ", @$props) . ");");
	   }
	}
	push(@$output, "", "");

	#Printing builders
	push(@$output,("# BUILDERS:"));
	if ($uuid == 1) {
		if (!defined($baseobjects->{$name})) {
			push(@$output, "sub _build_reference { my (\$self) = \@_;return \$self->parent()->_reference().'/".$methods->{$name}."/id/'.\$self->id(); }");
			push(@$output, "sub _build_uuid { my (\$self) = \@_;return \$self->_reference(); }");	
		} else {
			push(@$output, "sub _build_reference { my (\$self) = \@_;return \$self->uuid(); }");
			push(@$output, "sub _build_uuid { return Data::UUID->new()->create_str(); }");
		}
	}
	foreach my $subobject (@{$object->{links}}) {
	   if (defined($subobject->{array}) && $subobject->{array} == 1) {
		   push(@$output,
			  "sub _build_".$subobject->{name}." {",
			  "$tab my (\$self) = \@_;",
			  "$tab return \$self->getLinkedObjectArray(\$self->" . $subobject->{attribute} . "());",
			  "}"
		   );
	   } else {
	   	push(@$output,
			  "sub _build_".$subobject->{name}." {",
			  "$tab my (\$self) = \@_;",
			  "$tab return \$self->getLinkedObject(\$self->" . $subobject->{attribute} . "());",
			  "}"
		   );
	   }
	}
	push(@$output, "", "");

	#Printing constants
	push(@$output, "# CONSTANTS:");
	if (defined($baseobjects->{$name})) {
		push(@$output, "sub __version__ { return \$VERSION; }");
	}
	push(@$output, "sub _type { return '" . $module.".".$name . "'; }");
	push(@$output, "sub _module { return '" . $module . "'; }");
	push(@$output, "sub _class { return '" . $name . "'; }");
	if (defined($baseobjects->{$name})) {
		push(@$output, "sub _top { return 1; }");
	} else {
		push(@$output, "sub _top { return 0; }");
	}
	
	# add _attributes, links, and _subobjects

	my $attr_map = [];
	my $num = 0;
	map {push(@$attr_map, $_->{name} . " => " . $num++)} @{$object->{attributes}};

	my $attributes = Dumper($object->{attributes});
	$attributes =~ s/\$VAR1/my \$attributes/;

	push(@$output, "",
		$attributes,
		"my \$attribute_map = {" . join(", ", @$attr_map) . "};",
		"sub _attributes {",
		"$tab my (\$self, \$key) = \@_;",
		"$tab if (defined(\$key)) {",
		"$tab $tab my \$ind = \$attribute_map->{\$key};",
		"$tab $tab if (defined(\$ind)) {",
		"$tab $tab $tab return \$attributes->[\$ind];",
		"$tab $tab } else {",
		"$tab $tab $tab return;",
		"$tab $tab }",
		"$tab } else {",
		"$tab $tab return \$attributes;",
		"$tab }",
		"}"
	);

	my $link_map = [];
	$num = 0;
	map {push(@$link_map, $_->{name} . " => " . $num++)} @{$object->{links}};

	my $links = Dumper($object->{links});
	$links =~ s/\$VAR1/my \$links/;

	push(@$output, "",
		$links,
		"my \$link_map = {" . join(", ", @$link_map) . "};",
		"sub _links {",
		"$tab my (\$self, \$key) = \@_;",
		"$tab if (defined(\$key)) {",
		"$tab $tab my \$ind = \$link_map->{\$key};",
		"$tab $tab if (defined(\$ind)) {",
		"$tab $tab $tab return \$links->[\$ind];",
		"$tab $tab } else {",
		"$tab $tab $tab return;",
		"$tab $tab }",
		"$tab } else {",
		"$tab $tab return \$links;",
		"$tab }",
		"}"
	);

	my $so_map = [];
	$num = 0;
	map {push(@$so_map, $_->{name} . " => " . $num++)} @{$object->{subobjects}};

	my $subobjects = Dumper($object->{subobjects});
	$subobjects =~ s/\$VAR1/my \$subobjects/;

	push(@$output, "",
		$subobjects,
		"my \$subobject_map = {" . join(", ", @$so_map) . "};",
		"sub _subobjects {",
		"$tab my (\$self, \$key) = \@_;",
		"$tab if (defined(\$key)) {",
		"$tab $tab my \$ind = \$subobject_map->{\$key};",
		"$tab $tab if (defined(\$ind)) {",
		"$tab $tab $tab return \$subobjects->[\$ind];",
		"$tab $tab } else {",
		"$tab $tab $tab return;",
		"$tab $tab }",
		"$tab } else {",
		"$tab $tab return \$subobjects;",
		"$tab }",
		"}"
	);
	
	# print subobject readers
	if (defined($object->{subobjects}) && defined($object->{subobjects}->[0])) {
	   push(@$output, "# SUBOBJECT READERS:");
	   foreach my $subobject (@{$object->{subobjects}}) {
		  push(@$output,
			  "around '" . $subobject->{name} . "' => sub {",
			  "$tab my (\$orig, \$self) = \@_;",
			  "$tab return \$self->_build_all_objects('" . $subobject->{name} . "');",
			  "};"
		  );
	   }
	   push(@$output, "", "");
	}

	#Finalizing
	push(@$output, "__PACKAGE__->meta->make_immutable;", "1;");
	if (!-d "/Users/chenry/code/KBaseFBAModeling/lib/Bio/KBase/ObjectAPI/".$module."/DB/") {
		File::Path::mkpath ("/Users/chenry/code/KBaseFBAModeling/lib/Bio/KBase/ObjectAPI/".$module."/DB/");
	}
	Bio::KBase::ObjectAPI::utilities::PRINTFILE("/Users/chenry/code/KBaseFBAModeling/lib/Bio/KBase/ObjectAPI/".$module."/DB/".$name.".pm",$output);
	if (!-e "/Users/chenry/code/KBaseFBAModeling/lib/Bio/KBase/ObjectAPI/".$module."/".$name.".pm") {
		my $oldobject = $name;
		if (defined($objtranslation->{$name})) {
			$oldobject = $objtranslation->{$name};
		}
		if (-e "/Users/chenry/code/ModelSEED/lib/ModelSEED/MS/".$oldobject.".pm") {
	   		$output = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/code/ModelSEED/lib/ModelSEED/MS/".$oldobject.".pm");
	   		for(my $i=0; $i < @{$output}; $i++) {
	   			$output->[$i] =~ s/ModelSEED::utilities/Bio::KBase::ObjectAPI::utilities/g;
	   			my $replace = "Bio::KBase::ObjectAPI::".$module."::DB";
	   			$output->[$i] =~ s/ModelSEED::MS::DB/$replace/g;
	   			if ($output->[$i] =~ m/::DB::(\w+)/) {
	   				my $oldobj = $1;
	   				if (defined($refobjtrans->{$oldobj})) {
	   					my $newobj = $refobjtrans->{$oldobj};
	   					$output->[$i] =~ s/$oldobj/$newobj/;
	   				}
	   			}
	   			if ($output->[$i] =~ m/use\sModelSEED::Configuration;/) {
	   				$output->[$i] = "";
	   			}
	   			if ($output->[$i] =~ m/ModelSEED::MS::(\w+)/) {
	   				my $oldobj = $1;
	   				my $newobj = $oldobj;
	   				if (defined($refobjtrans->{$oldobj})) {
	   					$newobj = $refobjtrans->{$oldobj};
	   				}
	   				if (defined($modules->{$newobj})) {
	   					my $mentionedmodule = $modules->{$newobj};
	   					$replace = "Bio::KBase::ObjectAPI::".$mentionedmodule."::".$newobj;
	   					$output->[$i] =~ s/ModelSEED::MS::\w+/$replace/g;
	   				} else {
	   					$output->[$i] =~ s/ModelSEED::MS::/Bio::KBase::ObjectAPI::/g;
	   				}
	   			}
	   		}
		} else {
	   		$output = [
			  "########################################################################",
			  "# Bio::KBase::ObjectAPI::".$module."::".$name." - This is the moose object corresponding to the ".$module.".".$name." object",
			  "# Authors: Christopher Henry, Scott Devoid, Paul Frybarger",
			  "# Contact email: chenry\@mcs.anl.gov",
			  "# Development location: Mathematics and Computer Science Division, Argonne National Lab",
			  "# Date of module creation: ".DateTime->now()->datetime(),
			  "########################################################################",
			  "use strict;",
			  "use Bio::KBase::ObjectAPI::".$module."::DB::".$name.";",
			  "package Bio::KBase::ObjectAPI::".$module."::".$name.";",
			  "use Moose;",
				"use namespace::autoclean;",
				"extends 'Bio::KBase::ObjectAPI::".$module."::DB::".$name."';",
				"#***********************************************************************************************************",
				"# ADDITIONAL ATTRIBUTES:",
				"#***********************************************************************************************************",
				"",
				"",
				"#***********************************************************************************************************",
				"# BUILDERS:",
				"#***********************************************************************************************************",
				"",
				"",
				"",
				"#***********************************************************************************************************",
				"# CONSTANTS:",
				"#***********************************************************************************************************",
				"",
				"#***********************************************************************************************************",
				"# FUNCTIONS:",
				"#***********************************************************************************************************",
				"",
				"",
				"__PACKAGE__->meta->make_immutable;",
				"1;"
			];
		}
		#Bio::KBase::ObjectAPI::utilities::PRINTFILE("/Users/chenry/code/KBaseFBAModeling/lib/Bio/KBase/ObjectAPI/".$module."/".$name.".pm",$output);
	}
}
