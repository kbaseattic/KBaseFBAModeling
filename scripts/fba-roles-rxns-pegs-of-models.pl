#!/usr/bin/env perl
########################################################################
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use warnings;
use JSON;
use Try::Tiny;
use Bio::KBase::workspace::ScriptHelpers qw( get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::ScriptHelpers qw(fbaws get_fba_client runFBACommand universalFBAScriptCode roles_of_function );
#Defining globals describing behavior
my $primaryArgs = ["Input File"];
my $script = "fba-roles-rxns-pegs-of-models";

my $translation = {
};

#Defining usage and options
my $specs = [
    [  'File Name with the input format (Genome  Model  workspace)' ],
];

my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

my $in_fh;
if ($opt->{"Input File"}) {
    open($in_fh, "<", $opt->{"Input File"}) or die "Cannot open input file: $!";
} 


while (defined($_ = <$in_fh>)){
	chop;
	my($g_id,$m_id, $w_id) = split(/\s+/,$_);
	my %modelHash = (
	    models => [$m_id],
	    workspaces => [$w_id],
	    auth => auth()
	);


	my %genomeHash = (
    	id => $g_id,
    	type => 'Genome',
    	workspace => $w_id,
	    auth => auth()
	);


my $comp;
$comp->{workspace} = 'KBaseTemplateModels';
$comp->{templateModel} = 'GramPosModelTemplate';

my $biochem = get_fba_client()->role_to_reactions($comp);


my %hash1;
my %hash2;
for(my $i =0; $i< @{$biochem}; $i++){

  my $comp = $biochem->[$i]->{complexes};
  my $role = $biochem->[$i]->{name};

    for (my $j =0; $j< @{$comp}; $j++){

     my $comp_id = $comp->[$j]->{complex};
     my $rxns = $comp->[$j]->{reactions};
       #print "%$comp_id%\t";
        for (my $k =0; $k< @{$rxns}; $k++){

           my $rxn_id = $rxns->[$k]->{reaction};
            #print "$comp_id\t*$rxn_id*\n";

              #my @roles = &SeedUtils::roles_of_function($role);
                 #foreach my $r (@roles){

                   #$hash1{$rxn_id}->{$role} = 1;
                   #push(@{$hash2{$rxn_id}},$role);
                   $hash1{$role}->{$rxn_id} = 1;

                   push(@{$hash2{$role}},$rxn_id);

        }

    }

}



my $model = get_fba_client()->get_models(\%modelHash);
my $modelOne = $model->[0]->{reactions};

my %modelrxnHash;
for(my $i =0; $i< @{$modelOne}; $i++){

    my $rxn_co = $modelOne->[$i]->{id};
    my $rname = $modelOne->[$i]->{name};
    my @rxn = split /_/, $rxn_co;
    $rxn[0] =~ s/^\s+//;
    $rxn[0] =~ s/\s+$//;    
    $modelrxnHash{$rxn[0]} = $rname;

    #print "**$rxn[0]**\t$rname\n";

}

my $genome = get_ws_client()->get_object(\%genomeHash);
my $genomeData = $genome->{data}->{features};

for(my $i =0; $i< @{$genomeData}; $i++){
try{
    my $func = $genomeData->[$i]->{function};
    my $name = $genomeData->[$i]->{id};
    #my @rxnArray = split /\s+/, @{$roleHash{$func}};
    #print "@{$roleHash{$func}}\n";
    if (exists $hash2{$func} ){
        my @rxnPrintArray;
           foreach my $r (@{$hash2{$func}}){

              if (exists $modelrxnHash{$r}){
                 push (@rxnPrintArray, $r);
        
               }
            } 
       my $rxns = join(";",@rxnPrintArray);    
       print "$func\t$name\t$rxns\n";
    
    }    
  }
}

 
}
