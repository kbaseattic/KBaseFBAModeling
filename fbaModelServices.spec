module fbaModelServices {
	typedef int bool;
	typedef string md5;
    typedef list<md5> md5s;
    typedef string genome_id;
    typedef string feature_id;
    typedef string contig_id;
    typedef string feature_type;
    typedef tuple<contig_id, int begin, string strand,int length> region_of_dna;
    typedef list<region_of_dna> location;
    
    typedef tuple<string comment, string annotator, int annotation_time> annotation;

    typedef structure {
		feature_id id;
		location location;
		feature_type type;
		string function;
		string protein_translation;
		list<string> aliases;
		list<annotation> annotations;
    } Feature;

    typedef structure {
		contig_id id;
		string dna;
    } Contig;

    typedef structure {
		genome_id id;
		string scientific_name;
		string domain;
		int genetic_code;
		string source;
		string source_id;		
		list<Contig> contigs;
		list<Feature> features;
    } GenomeTO;

	typedef string modelcompound_id;
	typedef string compound_id;
	typedef string modelcompartment_id;
	
	typedef structure {
		modelcompound_id id;
		string name;
		compound_id compound_id;
		modelcompartment_id modelcompartment_id;
		float charge;
		string formula;
    } ModelCompoundTO;
		
	typedef string modelreaction_id;
	typedef string reaction_id;
	
	typedef structure {
		bool isCustomGPR;
		string rawGPR;
    } ModelReactionRawGPRTO;
	
	typedef structure {
		modelcompound_id modelcompound_id;
		float coefficient;
    } ModelReactionReagentTO;
	
	typedef structure {
		modelreaction_id id;
		reaction_id reaction_id;
		modelcompartment_id modelcompartment_id;
		string direction;
		string protons;
		string equation;
		list<ModelReactionRawGPRTO> gpr;
		list<ModelReactionReagentTO> modelReactionReagents;
    } ModelReactionTO;
	
	typedef structure {
		modelcompound_id modelcompound_id;
		float coefficient;
    } BiomassCompoundTO;
	
	typedef string biomass_id;
	
	typedef structure {
		biomass_id id;
		string name;
		list<BiomassCompoundTO> biomassCompounds;
    } BiomassTO;
	
	typedef string compartment_id;
	
	typedef structure {
		modelcompartment_id id;
		compartment_id compartment_id;
		string name;
		float pH;
		float potential;
		int index;
    } ModelCompartmentTO;

	typedef string model_id;
	typedef string genome_id;
	typedef string mapping_id;
	typedef string biochemistry_id;
	
	typedef string media_id;
	typedef string feature_id;
	typedef string reactionset_id;
	typedef string genome_id;
	typedef string FBAModelEX;
	typedef string SBML;
	typedef string HTMLFile;
	typedef string fbaformulation_id;
	
	typedef structure {
		string entityID;
		string variableType;
		float lowerBound;
		float upperBound;
		float min;
		float max;
		float value;
    } FBAVariable;
	
	typedef structure {
		string simultatedPhenotype;
		float simulatedGrowthFraction;
		float simulatedGrowth;
		string class;
		list<string> noGrowthCompounds;
		list<string> dependantReactions;
		list<string> dependantGenes;
		list<string> fluxes;	
    } FBAPhenotypeSimulationResult;
    
    typedef structure {
		list<string> geneKO;
		float simulatedGrowth;
		float simulatedGrowthFraction;
    } FBADeletionResult;
	
	typedef structure {
		list<string> optionalNutrients;
		list<string> essentialNutrients;
    } FBAMinimalMediaResult;
	
	typedef structure {
		float maximumProduction;
		string compound;
    } FBAMetaboliteProductionResult;
	
	typedef structure {
		string notes;
		float objectiveValue;
		list<FBAVariable>  variables;
		list<FBAPhenotypeSimulationResult>  fbaPhenotypeSimultationResults;
		list<FBADeletionResult>  fbaDeletionResults;
		list<FBAMinimalMediaResult>  minimalMediaResults;
		list<FBAMetaboliteProductionResult>  fbaMetaboliteProductionResults;
	} FBAResult;
    
	typedef structure {
		string model;
		string regulatoryModel;
		string expressionData;
		string media;
		list<string> rxnKO;
        list<string> geneKO;
		string objective;
		list<string> constraints;
		list<string> bounds;
		list<string> phenotypes;
		string uptakelimits;
		list<FBAResult> fbaResults;
		string notes;
		float objectiveConstraintFraction;
		bool allReversible;
		float defaultMaxFlux;
		float defaultMaxDrainFlux;
        float defaultMinDrainFlux;
		int numberOfSolutions;
		bool fva;
        int comboDeletions;
        bool fluxMinimization;
        bool findMinimalMedia;
        bool simpleThermoConstraints;
        bool thermodynamicConstraints;
        bool noErrorThermodynamicConstraints;
        bool minimizeErrorThermodynamicConstraints;        
    } FBAFormulation;
	
	typedef structure {
		reactionset_id reactionset;
		string reactionsetType;
		string multiplierType;
		string description;
		float multiplier;
	} ReactionSetMultiplier;
		
	typedef structure {
		string role;
		genome_id orthologGenome;
		feature_id ortholog;
		feature_id feature;
		float similarityScore;
		float distanceScore;
	} GeneCandidate;
	
	typedef structure {
		string media;
		string notes;
		string objective;
		float objfraction;
		string rxnko;
		string geneko;
		string uptakelim;
		float defaultmaxflux;
		float defaultmaxuptake;
		float defaultminuptake;
		bool nomediahyp;
		bool nobiomasshyp;
		bool nogprhyp;
		bool nopathwayhyp;
		bool allowunbalanced;
		float activitybonus;
		float drainpen;
		float directionpen;
		float nostructpen;
		float unfavorablepen;
		float nodeltagpen;
		float biomasstranspen;
		float singletranspen;
		float transpen;
		string blacklistedrxns;
		string gauranteedrxns;
		string allowedcmps;
	} GapfillingFormulation;
	
	typedef structure {
		string media;
		string refmedia;
		string notes;
		string objective;
		float objfraction;
		string rxnko;
		string geneko;
		string uptakelim;
		float defaultmaxflux;
		float defaultmaxuptake;
		float defaultminuptake;
		bool nomediahyp;
		bool nobiomasshyp;
		bool nogprhyp;
		bool nopathwayhyp;
	} GapgenFormulation;
	
	typedef structure {
        model_id ancestor;
        model_id id;
		string name;
		int version;
		string type;
		string status;
		int current;
		float growth;
		genome_id genome;
		mapping_id map;
		biochemistry_id biochemistry;
		list<BiomassTO> biomasses;
		list<ModelCompartmentTO> modelcompartments;
		list<ModelCompoundTO> modelcompounds;
		list<ModelReactionTO> modelreactions;
    } FBAModel;
    
    typedef structure {
        string objectType;
        string parentUUID;
        string uuid;
    } ObjectSpec;
	
	/*
		This function creates a metabolic model object from the annotated genome object.
	*/
    funcdef genome_snapshot (GenomeId id) returns (GenomeSnapshotId snapshot_id);
    funcdef genome_get_snapshot (GenomeSnapshotId id) returns (Genome genome);

    funcdef model_build (GenomeSnapshotId id) returns (ModelId model_id);
    funcdef model_get (ModelId id) returns (Model model);
    funcdef model_to_sbml (ModelId id) returns (SBML sbml_string);
    funcdef model_to_html (ModelId id) returns (HTML html_string);

    funcdef fba_default_formulation (ModelId id) returns (FBAFormulation formulation);
    funcdef fba_run (ModelId id, FBAFormulation formulation) returns (FbaResultsId results_id);
    funcdef fba_check_results (FbaResultsId id) returns (Bool is_done);
    funcdef fba_get_results (FbaResultsId id) returns (FBAResults fba_results);
    funcdef fba_results_to_html (FbaResultsId id) returns (HTML html_string);

    funcdef gapfill_default_formulation (ModelId id) returns (GapfillFormulation formulation);
    funcdef gapfill_model (ModelId id, GapfillFormulation formulation) returns (GapfillResultsId results_id);
    funcdef gapfill_check_results (GapfillResultsId id) returns (Bool is_done);
    funcdef gapfill_get_results (GapfillResultsId id) returns (GapfillResults results);
    funcdef gapfill_results_to_html (GapfillResultsId id) returns (HTML html_string);

    funcdef gapfill_integrate_results (GapfillResultsId id, ModelId id) returns (ModelId new_model_id);

    funcdef gapgen_default_formulation (ModelId id) returns (GapgenFormulation formulation);
    funcdef gapgen_model (ModelId id, GapgenFormulation formulation) returns (GapgenResultsId results_id);
    funcdef gapgen_check_results (GapgenResultsId id) returns (Bool is_done);
    funcdef gapgen_get_results (GapgenResultsId id) returns (GapgenResults results);
    funcdef gapgen_results_to_html (GapgenResultsId id) returns (HTML html_string);

    funcdef gapgen_integrate_results (GapgenResultsId id, ModelId id) returns (ModelId new_model_id);
};
