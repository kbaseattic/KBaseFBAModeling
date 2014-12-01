/*
@author chenry
*/
module KBasePhenotypes {
    /*
		Model compound ID
		@id external
	*/
    typedef string compound_id;
    /*
		Model reaction ID
		@id external
	*/
    typedef string reaction_id;
    /*
		Source ID
		@id external
	*/
    typedef string source_id;
    /*
		Reference to a compound object
		@id subws KBaseBiochem.Biochemistry.compounds.[*].id
	*/
    typedef string compound_ref;
    /*
		Reference to a feature of a genome object
		@id subws KBaseGenomes.Genome.features.[*].id
	*/
    typedef string feature_ref;
    /*
		Reference to a feature of a genome object
		@id ws KBaseGenomes.Genome
	*/
    typedef string genome_ref;
    /*
		Reference to a mapping object
		@id ws KBaseBiochem.Media
	*/
    typedef string media_ref;
    /*
		Reference to a model object
		@id ws KBaseFBA.FBAModel
	*/
    typedef string fbamodel_ref;
    /*
		Reference to a PhenotypeSet object
		@id ws KBasePhenotypes.PhenotypeSet
	*/
    typedef string phenotypeset_ref;
    /*
		Reference to a PhenotypeSet object
		@id subws KBasePhenotypes.PhenotypeSet.phenotypes.[*].id
	*/
    typedef string phenotype_ref;
    /*
		Phenotype ID
		@id external
	*/
    typedef string phenotype_id;
    /*
		Phenotype simulation ID
		@id external
	*/
    typedef string phenosim_id;
    /*
		PhenotypeSet ID
		@id kb
	*/
    typedef string phenotypeset_id;
	/*
		PhenotypeSimulationSet ID
		@id kb
	*/
    typedef string phenosimset_id;
    
    /* 
    	Phenotype subobject holds data on a single phenotype
    	    	
    	@optional name
    	@searchable ws_subset id media_ref geneko_refs additionalcompound_refs normalizedGrowth name
    */
    typedef structure {
		phenotype_id id;
		media_ref media_ref;
		list<feature_ref> geneko_refs;
		list<compound_ref> additionalcompound_refs;
		float normalizedGrowth;
		string name;
    } Phenotype;
    
    /* 
    	PhenotypeSet object contains a set of phenotype objects
    	    	
    	@optional name
		@metadata ws source_id as Source ID
		@metadata ws source as Source
		@metadata ws name as Name
		@metadata ws length(phenotypes) as Number phenotypes
		@metadata ws type as Type
		
    */
    typedef structure {
		phenotypeset_id id;
		source_id source_id;
		string source;
		string name;
		genome_ref genome_ref;
		list<Phenotype> phenotypes;
		string importErrors;
		string type;
    } PhenotypeSet;
    
    /* 
    	PhenotypeSimulation subobject holds data on a single phenotype simulation

    	@optional numGapfilledReactions
    	@optional gapfilledReactions
    */
    typedef structure {
		phenosim_id id;
		phenotype_ref phenotype_ref;
		float simulatedGrowth;
		float simulatedGrowthFraction;
		int numGapfilledReactions;
		list<string> gapfilledReactions;
		string phenoclass;
    } PhenotypeSimulation;
    
    /* 
    	PhenotypeSimulationSet object holds data on simulations of many phenotypes
    	
		@metadata ws length(phenotypeSimulations) as Number phenotypes
    */
    typedef structure {
    	phenosimset_id id;
		fbamodel_ref fbamodel_ref;
		phenotypeset_ref phenotypeset_ref;
		list<PhenotypeSimulation> phenotypeSimulations;
    } PhenotypeSimulationSet;
};