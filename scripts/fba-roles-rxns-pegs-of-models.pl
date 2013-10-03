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
use Bio::KBase::workspaceService::Helpers qw(auth get_ws_client workspace workspaceURL parseObjectMeta parseWorkspaceMeta printObjectMeta);
use Bio::KBase::fbaModelServices::Helpers qw(get_fba_client runFBACommand universalFBAScriptCode roles_of_function );
#Defining globals describing behavior
my $primaryArgs = [];
my $script = "fba-roles-rxns-pegs-of-models";
my $translation = {};
#Defining usage and options
my $specs = [
    [ 'input=s', 'Name of file with input' ],
];
my ($opt,$params) = universalFBAScriptCode($specs,$script,$primaryArgs,$translation);

my $in_fh;
if ($opt->{input}) {
    open($in_fh, "<", $opt->{input}) or die "Cannot open $input_file: $!";
} else {
    $in_fh = \*STDIN;
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
    if (exists $roleHash{$func} ){
        my @rxnPrintArray;
           foreach my $r (@{$roleHash{$func}}){

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