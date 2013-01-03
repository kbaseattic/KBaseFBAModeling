module fbaModelServices {
    /*********************************************************************************
    Universal simple type definitions
   	*********************************************************************************/
    /* indicates true or false values, false <= 0, true >=1 */
    typedef int bool;
    
    /* A string used as an ID for a workspace. Any string consisting of alphanumeric characters and "-" is acceptable  */
    typedef string workspace_id;
	
	/* A string indicating the "type" of an object stored in a workspace. Acceptable types are returned by the "get_types()" command in the workspace_service  */
	typedef string object_type;
	
	/* ID of an object stored in the workspace. Any string consisting of alphanumeric characters and "-" is acceptable */
	typedef string object_id;
	
	/* Login name of KBase useraccount to which permissions for workspaces are mapped */
	typedef string username;
	
	/* Exact time for workspace operations. e.g. 2012-12-17T23:24:06 */
	typedef string timestamp;
	
	/* An identifier for compounds in the KBase biochemistry database. e.g. cpd00001 */
	typedef string compound_id;
    
    /* A string used to identify a particular biochemistry database object in KBase. e.g. "default" is the ID of the standard KBase biochemistry */
    typedef string biochemistry_id;
    
    /* A string identifier for a genome in KBase. e.g. "kb|g.0" is the ID for E. coli */
    typedef string genome_id;
    
    /* A string identifier for a contiguous piece of DNA in KBase, representing a chromosome or an assembled fragment */
    typedef string contig_id;
    
    /* A string specifying the type of genome features in KBase */
    typedef string feature_type;
    
    /* A string identifier used for compartments in models in KBase. Compartments could represet organelles in a eukaryotic model, or entire cells in a community model */
    typedef string modelcompartment_id;
    
    /* A string identifier used for compounds in models in KBase. */
    typedef string modelcompound_id;
    
    /* A string identifier used for a feature in a genome. */
    typedef string feature_id;
    
    /* A string identifier used for a reaction in a KBase biochemistry. */
    typedef string reaction_id;
    
    /* A string identifier used for a reaction in a model in KBase. */
    typedef string modelreaction_id;
    
    /* A string identifier used for a biomass reaction in a KBase model. */
    typedef string biomass_id;
    
    /* A string identifier used for a media condition in the KBase database. */
    typedef string media_id;
    
    /* A string identifier used for a flux balance analysis study in KBase. */
    typedef string fba_id;
    
    /* A string identifier for a gap generation study in KBase. */
    typedef string gapgen_id;
    
    /* A string identifier for a gap filling study in KBase. */
    typedef string gapfill_id;
    
    /* A string identifier for a solution from a gap generation study in KBase. */
    typedef string gapgensolution_id;
    
    /* A string identifier for a solution from a gap filling study in KBase. */
    typedef string gapfillsolution_id;
    
    /* A string identifier for a metabolic model in KBase. */
    typedef string fbamodel_id;
    
    /* A string identifier for a Mapping object in KBase. */
    typedef string mapping_id;
    
    /* A string identifier for a regulatory model in KBase. */
    typedef string regmodel_id;
    
    /* A string identifier for a compartment in KBase. */
    typedef string compartment_id;
    
    /* A string identifier for an expression dataset in KBase. */
    typedef string expression_id;
    
    /* A string identifier used for a set of phenotype data loaded into KBase. */
    typedef string phenotypeSet_id;
    
    /* A permanent reference to an object in a workspace. */
    typedef string workspace_ref;
    
    /* A string identifier used for a probabilistic annotation in KBase. */
    typedef string probanno_id;
    
    /*********************************************************************************
    Object type definition
   	*********************************************************************************/
    /* Meta data associated with an object stored in a workspace.
	
		object_id id - ID of the object assigned by the user or retreived from the IDserver (e.g. kb|g.0)
		object_type type - type of the object (e.g. Genome)
		timestamp moddate - date when the object was modified by the user (e.g. 2012-12-17T23:24:06)
		int instance - instance of the object, which is equal to the number of times the user has overwritten the object
		timestamp date_created - time at which the alignment was built/loaded in seconds since the epoch
		string command - name of the command last used to modify or create the object
		username lastmodifier - name of the user who last modified the object
		username owner - name of the user who owns (who created) this object
		workspace_id workspace - ID of the workspace in which the object is currently stored
		workspace_ref ref - a 36 character ID that provides permanent undeniable access to this specific instance of this object
	
	*/
    typedef tuple<object_id id,object_type type,timestamp moddate,int instance,string command,username lastmodifier,username owner,workspace_id workspace,workspace_ref ref> object_metadata;
    
    /*********************************************************************************
    Probabilistic Annotation type definition
   	*********************************************************************************/
    typedef string md5;
    typedef list<md5> md5s;
    /* A region of DNA is maintained as a tuple of four components:

        the contig
        the beginning position (from 1)
        the strand
        the length

        We often speak of "a region".  By "location", we mean a sequence
        of regions from the same genome (perhaps from distinct contigs).
    */
    typedef tuple<contig_id, int begin, string strand,int length> region_of_dna;

    /*
        a "location" refers to a sequence of regions
    */
    typedef list<region_of_dna> location;
    typedef tuple<string comment, string annotator, int annotation_time> annotation;
    typedef tuple<feature_id gene, float blast_score> gene_hit;
    typedef tuple<string function, float probability, list<gene_hit> gene_hits > alt_func;

    typedef structure {
		feature_id id;
		location location;
		feature_type type;
		string function;
		list<alt_func> alternative_functions;
		string protein_translation;
		list<string> aliases;
		list<annotation> annotations;
    } feature;

    typedef structure {
		contig_id id;
		string dna;
    } contig;

    typedef structure {
		genome_id id;
		string scientific_name;
		string domain;
		int genetic_code;
		string source;
		string source_id;
		list<contig> contigs;
		list<feature> features;
    } GenomeObject;
    
    /*********************************************************************************
    Biochemistry type definition
   	*********************************************************************************/
    typedef structure {
		biochemistry_id id;
		string name;
		list<compound_id> compounds;
		list<reaction_id> reactions;
		list<media_id> media;
    } Biochemistry;
    
    typedef structure {
		media_id id;
		string name;
		list<compound_id> compounds;
		list<float> concentrations;
		float pH;
		float temperature;
    } Media;
    
    typedef structure {
		compound_id id;
		string abbrev;
		string name;
		list<string> aliases;
		float charge;
		float deltaG;
		float deltaGErr;
		string formula;
    } Compound;
    
    typedef structure {
		reaction_id id;
		string name;
		string abbrev;
		list<string> enzymes;
		string direction;
		string reversibility;
		float deltaG;
		float deltaGErr;
		string equation;
		string definition;	
    } Reaction;
    /*********************************************************************************
    FBAModel type definition
   	*********************************************************************************/
    typedef structure {
		modelcompartment_id id;
		string name;
		float pH;
		float potential;
		int index;
    } ModelCompartment;
    
    typedef structure {
		modelcompound_id id;
		compound_id compound;
		string name;
		modelcompartment_id compartment;
    } ModelCompound;
    
    typedef structure {
		modelreaction_id id;
		reaction_id reaction;
		string name;
		string direction;
		string equation;
		string definition;
		list<feature_id> features;
		modelcompartment_id compartment;
    } ModelReaction;
    
    typedef tuple<modelcompound_id modelcompound,float coefficient,string name> BiomassCompound;
    
    typedef structure {
		biomass_id id;
		string name;
		string definition;
		list<BiomassCompound> biomass_compounds;
    } ModelBiomass;
    
    typedef tuple<fba_id id,workspace_id workspace,media_id media,workspace_id media_workspace,float objective,list<feature_id> ko> FBAMeta;
    typedef tuple<gapgen_id id,workspace_id workspace,media_id media,workspace_id media_workspace,bool done,list<feature_id> ko> GapGenMeta;
    typedef tuple<gapfill_id id,workspace_id workspace,media_id media,workspace_id media_workspace,bool done,list<feature_id> ko> GapFillMeta;
    
    typedef structure {
		fbamodel_id id;
		workspace_id workspace;
		genome_id genome;
		workspace_id genome_workspace;
		mapping_id map;
		workspace_id map_workspace;
		biochemistry_id biochemistry;
		workspace_id biochemistry_workspace;
		string name;
		string type;
		string status;
		
		list<ModelBiomass> biomasses;
		list<ModelCompartment> compartments;
		list<ModelReaction> reactions;
		list<ModelCompound> compounds;
		
		list<FBAMeta> fbas;
		list<GapFillMeta> integrated_gapfillings;
		list<GapFillMeta> unintegrated_gapfillings;
		list<GapGenMeta> integrated_gapgenerations;
		list<GapGenMeta> unintegrated_gapgenerations;
    } FBAModel;
    /*********************************************************************************
    Flux Balance Analysis type definition
   	*********************************************************************************/
    typedef tuple<feature_id feature,float growthFraction,float growth,bool isEssential> GeneAssertion;
    typedef tuple<modelcompound_id compound,float value,float upperBound,float lowerBound,float max,float min,string type,string name> CompoundFlux;
    typedef tuple<modelreaction_id reaction,float value,float upperBound,float lowerBound,float max,float min,string type,string definition> ReactionFlux;
    typedef tuple<float maximumProduction,modelcompound_id modelcompound,string name> MetaboliteProduction;

    typedef string compound_id;
	    typedef structure {
		list<compound_id> optionalNutrients;
		list<compound_id> essentialNutrients;
    } MinimalMediaPrediction;
    
    typedef tuple<float min,float max,string varType,string variable> bound;
    typedef tuple<float coefficient,string varType,string variable> term;
    typedef tuple<float rhs,string sign,list<term> terms,string name> constraint;
	
	typedef structure {
		media_id media;
		list<compound_id> additionalcpds;
		workspace_id media_workspace;
		float objfraction;
		bool allreversible;
		bool maximizeObjective;
		list<term> objectiveTerms;
		list<feature_id> geneko;
		list<reaction_id> rxnko;
		list<bound> bounds;
		list<constraint> constraints;
		mapping<string,float> uptakelim;
		float defaultmaxflux;
		float defaultminuptake;
		float defaultmaxuptake;
		bool simplethermoconst;
		bool thermoconst;
		bool nothermoerror;
		bool minthermoerror;
    } FBAFormulation;
    
    typedef structure {
		fba_id id;
		workspace_id workspace;
        fbamodel_id model;
        workspace_id model_workspace;
        float objective;
        bool isComplete;
		FBAFormulation formulation;
		list<MinimalMediaPrediction> minimalMediaPredictions;
		list<MetaboliteProduction> metaboliteProductions;
		list<ReactionFlux> reactionFluxes;
		list<CompoundFlux> compoundFluxes;
		list<GeneAssertion> geneAssertions;
    } FBA;
    /*********************************************************************************
    Gapfilling type definition
   	*********************************************************************************/
    typedef structure {
		FBAFormulation formulation;
		int num_solutions;
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
		list<reaction_id> blacklistedrxns;
		list<reaction_id> gauranteedrxns;
		list<compartment_id> allowedcmps;
		probanno_id probabilisticAnnotation;
		workspace_id probabilisticAnnotation_workspace;
    } GapfillingFormulation;
    
    typedef tuple<reaction_id reaction,string direction,string compartment_id,string equation,string definition> reactionAddition;
    typedef tuple<compound_id compound,string name> biomassRemoval;
    typedef tuple<compound_id compound,string name> mediaAddition;
    
    typedef structure {
    	gapfillsolution_id id;
        float objective;
		list<biomassRemoval> biomassRemovals;
		list<mediaAddition> mediaAdditions;
		list<reactionAddition> reactionAdditions;
    } GapFillSolution;
    
    typedef structure {
		gapfill_id id;
		workspace_id workspace;
		fbamodel_id model;
        workspace_id model_workspace;
        bool isComplete;
		GapfillingFormulation formulation;
		list<GapFillSolution> solutions;
    } GapFill;
    /*********************************************************************************
    Gap Generation type definition
   	*********************************************************************************/
    typedef structure {
		FBAFormulation formulation;
		media_id refmedia;
		workspace_id refmedia_workspace;
		int num_solutions;
		bool nomediahyp;
		bool nobiomasshyp;
		bool nogprhyp;
		bool nopathwayhyp;
    } GapgenFormulation;
    
    typedef tuple<modelreaction_id reaction,string direction,string equation,string definition> reactionRemoval;
    typedef tuple<compound_id compound,string name> biomassAddition;
    typedef tuple<compound_id compound,string name> mediaRemoval;
    
    typedef structure {
        gapgensolution_id id;
        float objective;
		list<biomassAddition> biomassAdditions;
		list<mediaRemoval> mediaRemovals;
		list<reactionRemoval> reactionRemovals;
    } GapgenSolution;
    
    typedef structure {
		gapgen_id id;
		workspace_id workspace;
		fbamodel_id model;
        workspace_id model_workspace;
        bool isComplete;
		GapgenFormulation formulation;
		list<GapgenSolution> solutions;
    } GapGen;
    /*********************************************************************************
    Function definitions relating to data retrieval for Model Objects
   	*********************************************************************************/
    typedef structure {
		list<fbamodel_id> models;
		list<workspace_id> workspaces;
		string auth;
        string id_type;
    } get_models_params;
    /*
    	Returns model data for input ids
    */
    funcdef get_models(get_models_params input) returns (list<FBAModel> out_models);

    typedef structure {
		list<fba_id> fbas;
		list<workspace_id> workspaces; 
		string auth;
        string id_type;
    } get_fbas_params;
    /*
    	Returns data for the requested flux balance analysis formulations
    */
    funcdef get_fbas(get_fbas_params input) returns (list<FBA> out_fbas);

    typedef structure {
		list<gapfill_id> gapfills;
		list<workspace_id> workspaces; 
		string auth;
        string id_type;
    } get_gapfills_params;
    /*
    	Returns data for the requested gap filling simulations
    */
    funcdef get_gapfills(get_gapfills_params input) returns (list<GapFill> out_gapfills);

    typedef structure {
		list<gapgen_id> gapgens;
		list<workspace_id> workspaces;
		string auth;
        string id_type;
    } get_gapgens_params;
    /*
    	Returns data for the requested gap generation simulations
    */
    funcdef get_gapgens(get_gapgens_params input) returns (list<GapGen> out_gapgens);

    typedef structure {
		list<reaction_id> reactions;
		string auth;
        string id_type;
    } get_reactions_params;
    /*
    	Returns data for the requested reactions
    */
    funcdef get_reactions(get_reactions_params input) returns (list<Reaction> out_reactions);

    typedef structure {
		list<compound_id> compounds;
		string auth;
        string id_type;
    } get_compounds_params;
    /*
    	Returns data for the requested compounds
    */
    funcdef get_compounds(get_compounds_params input) returns (list<Compound> out_compounds);

    /*This function returns media data for input ids*/
    typedef structure {
		list<media_id> medias;
		list<workspace_id> workspaces;
		string auth;
    } get_media_params;
    /*
    	Returns data for the requested media formulations
    */
    funcdef get_media(get_media_params input) returns (list<Media> out_media);

    typedef structure {
        biochemistry_id biochemistry;
        workspace_id biochemistry_workspace;
        string id_type;
        string auth;
    } get_biochemistry_params;
    /*
    	Returns biochemistry object
    */
    funcdef get_biochemistry(get_biochemistry_params input) returns (Biochemistry out_biochemistry);
	/*********************************************************************************
    Code relating to reconstruction of metabolic models
   	*********************************************************************************/
    typedef string workspace_id;
    typedef structure {
		genome_id id;
    } genomeTO;
    typedef structure {
		genomeTO genomeobj;
		workspace_id workspace;
		string auth;
		bool overwrite;
    } genome_object_to_workspace_params;
    /*
        Loads an input genome object into the workspace.
    */
    funcdef genome_object_to_workspace(genome_object_to_workspace_params input) returns (object_metadata genomeMeta);
    
    typedef structure {
		genome_id genome;
		workspace_id workspace;
		string auth;
		bool overwrite;
    } genome_to_workspace_params;
    /*
        Retrieves a genome from the CDM and saves it as a genome object in the workspace.
    */
    funcdef genome_to_workspace(genome_to_workspace_params input) returns (object_metadata genomeMeta);
    
    typedef tuple<string foreign_id,feature_id feature> translation; 
    
    typedef structure {
		genome_id genome;
		workspace_id workspace;
		list<translation> translations;
		string id_type;
		string auth;
		bool overwrite;
    } add_feature_translation_params;
    /*
        Adds a new set of alternative feature IDs to the specified genome typed object
    */
    funcdef add_feature_translation(add_feature_translation_params input) returns (object_metadata genomeMeta);
    
    /*
        A set of paramters for the genome_to_fbamodel method. This is a mapping
        where the keys in the map are named 'in_genome', 'in_workspace', 'out_model',
        and 'out_workspace'. Values for each are described below.
    
        genome_id in_genome
        This parameter specifies the ID of the genome for which a model is to be built. This parameter is required.
    
        workspace_id in_workspace
        This parameter specifies the ID of the workspace containing the specified genome object. This parameter is also required.
    
        fbamodel_id out_model
        This parameter specifies the ID to which the generated model should be save. This is optional.
        If unspecified, a new KBase model ID will be checked out for the model.
    
        workspace_id out_workspace
        This parameter specifies the ID of the workspace where the model should be save. This is optional.
        If unspecified, this parameter will be set to the value of "in_workspace".
    */
    typedef structure {
		genome_id genome;
		workspace_id genome_workspace;
		probanno_id probanno;
		workspace_id probanno_workspace;
		float probannoThreshold;
		bool probannoOnly;
		fbamodel_id model;
		workspace_id workspace;
		string auth;
		bool overwrite;
    } genome_to_fbamodel_params;
    /*
        This function accepts a genome_to_fbamodel_params as input, building a new FBAModel for the genome specified by genome_id.
        The function returns a genome_to_fbamodel_params as output, specifying the ID of the model generated in the model_id parameter.
    */
    funcdef genome_to_fbamodel (genome_to_fbamodel_params input) returns (object_metadata modelMeta);
    
    /*
        NEED DOCUMENTATION
    */
    typedef structure {
		fbamodel_id model;
		workspace_id workspace;
		string format;
		string auth;
    } export_fbamodel_params;
    
    /*
        This function exports the specified FBAModel to a specified format (sbml,html)
    */
    funcdef export_fbamodel(export_fbamodel_params input) returns (string output);
    
    /*********************************************************************************
    Code relating to flux balance analysis
   	*********************************************************************************/
    
    typedef structure {
		media_id media;
		workspace_id workspace;
		string name;
		bool isDefined;
		bool isMinimal;
		string type;
		list<string> compounds;
		list<float> concentrations;
		list<float> maxflux;
		list<float> minflux;
		bool overwrite;
		string auth;
    } addmedia_params;
    /*
        Add media condition to workspace
    */
    funcdef addmedia(addmedia_params input) returns (object_metadata mediaMeta);
    
    typedef structure {
		media_id media;
		workspace_id workspace;
		string format;
		string auth;
    } export_media_params;
    /*
        Exports media in specified format (html,readable)
    */
    funcdef export_media(export_media_params input) returns (string output);
    
    /*
        NEED DOCUMENTATION
    */
    typedef structure {
    	fbamodel_id model;
		workspace_id model_workspace;
		FBAFormulation formulation;
		bool fva;
		bool simulateko;
		bool minimizeflux;
		bool findminmedia;
		string notes;
		fba_id fba;
		workspace_id workspace;
		string auth;
		bool overwrite;
		bool add_to_model;
    } runfba_params;
    /*
        Run flux balance analysis and return ID of FBA object with results 
    */
    funcdef runfba(runfba_params input) returns (object_metadata fbaMeta);
    
    typedef structure {
		fba_id fba;
		workspace_id workspace;
		string format;
		string auth;
    } export_fba_params;
    /*
        Export an FBA solution for viewing
    */
    funcdef export_fba(export_fba_params input) returns (string output);
    
    /*********************************************************************************
    Code relating to phenotype simulation and reconciliation
   	*********************************************************************************/
    typedef tuple< list<feature_id> geneKO,media_id baseMedia,workspace_id media_workspace,list<compound_id> additionalCpd,float normalizedGrowth> Phenotype;
    typedef structure {
		phenotypeSet_id id;
		genome_id genome;
		workspace_id genome_workspace;
		list<Phenotype> phenotypes;
		string importErrors;
    } PhenotypeSet;
    
    typedef string phenotypeSimulationSet_id;
    typedef tuple< Phenotype,float simulatedGrowth,float simulatedGrowthFraction,string class> PhenotypeSimulation;
    typedef structure {
    	phenotypeSimulationSet_id id;
		fbamodel_id model;
		workspace_id model_workspace;
		phenotypeSet_id phenotypeSet;
		list<PhenotypeSimulation> phenotypeSimulations;
    } PhenotypeSimulationSet;
    
    typedef structure {
		phenotypeSet_id phenotypeSet;
		workspace_id workspace;
		genome_id genome;
		workspace_id genome_workspace;
		list<Phenotype> phenotypes;
		bool ignore_errors;
		string auth;
    } import_phenotypes_params;
    /*
        Loads the specified phenotypes into the workspace
    */
    funcdef import_phenotypes (import_phenotypes_params input) returns (object_metadata output);
    
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		phenotypeSet_id phenotypeSet;
		workspace_id phenotypeSet_workspace;
		FBAFormulation formulation;
		string notes;
		phenotypeSimulationSet_id phenotypeSimultationSet;
		workspace_id workspace;
		bool overwrite;
		string auth;
    } simulate_phenotypes_params;
    /*
        Simulates the specified phenotype set
    */
    funcdef simulate_phenotypes (simulate_phenotypes_params input) returns (object_metadata output);
    
    typedef structure {
		phenotypeSimulationSet_id phenotypeSimulationSet;
		workspace_id workspace;
		string format;
		string auth;
    } export_phenotypeSimulationSet_params;
    /*
        Export a PhenotypeSimulationSet for viewing
    */
    funcdef export_phenotypeSimulationSet (export_phenotypeSimulationSet_params input) returns (string output);
    
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		list<gapfillsolution_id> gapfillSolutions;
		list<gapgensolution_id> gapgenSolutions;
		fbamodel_id out_model;
		workspace_id workspace;
		string auth;
		bool overwrite;
    } integrate_reconciliation_solutions_params;
    /*
        Integrates the specified gapfill and gapgen solutions into the specified model
    */
    funcdef integrate_reconciliation_solutions(integrate_reconciliation_solutions_params input) returns (object_metadata modelMeta);
    
    /*********************************************************************************
    Code relating to queuing long running jobs
   	*********************************************************************************/ 
    typedef string job_id;
    typedef structure {
		string auth;
    } CommandArguments;
    typedef structure {
		string auth;
    } clusterjob;
    typedef structure {
		job_id id;
		workspace_id workspace;
		list<clusterjob> clusterjobs;
		string postprocess_command;
		list<CommandArguments> postprocess_args;
		string queuing_command;
		float clustermem;
		int clustertime;
		string clustertoken;
		string queuetime;
		string completetime;
		bool complete;
		string owner;		
    } JobObject;
    
    typedef structure {
    	fbamodel_id model;
		workspace_id model_workspace;
		FBAFormulation formulation;
		bool fva;
		bool simulateko;
		bool minimizeflux;
		bool findminmedia;
		string notes;
		fba_id fba;
		workspace_id workspace;
		string auth;
		bool overwrite;
		bool add_to_model;
		bool donot_submit_job;
    } queue_runfba_params;
	/*
        Queues an FBA job in a single media condition
    */
	funcdef queue_runfba(queue_runfba_params input) returns (object_metadata output);
   
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		GapfillingFormulation formulation;
		phenotypeSet_id phenotypeSet;
		workspace_id phenotypeSet_workspace;
		bool integrate_solution;
		fbamodel_id out_model;
		workspace_id workspace;
		gapfill_id gapFill;
		workspace_id gapFill_workspace;
		string auth;
		bool overwrite;
		bool donot_submit_job;
    } gapfill_model_params;
    /*
        Queues an FBAModel gapfilling job in single media condition
    */
    funcdef queue_gapfill_model(gapfill_model_params input) returns (object_metadata output);
    
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		GapgenFormulation formulation;
		phenotypeSet_id phenotypeSet;
		workspace_id phenotypeSet_workspace;
		bool integrate_solution;
		fbamodel_id out_model;
		workspace_id workspace;
		gapgen_id gapGen;
		workspace_id gapGen_workspace;
		string auth;
		bool overwrite;
		bool donot_submit_job;
    } gapgen_model_params;
    /*
        Queues an FBAModel gapfilling job in single media condition
    */
    funcdef queue_gapgen_model(gapgen_model_params input) returns (object_metadata output);
    
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		FBAFormulation fba_formulation;
		GapfillingFormulation gapfill_formulation;
		GapgenFormulation gapgen_formulation;
		phenotypeSet_id phenotypeSet;
		workspace_id phenotypeSet_workspace;
		fbamodel_id out_model;
		workspace_id workspace;
		list<gapfill_id> gapFills;
		list<gapgen_id> gapGens;
		workspace_id gapFill_workspace;
		workspace_id gapGen_workspace;
		bool queueSensitivityAnalysis;
		bool queueReconciliationCombination;
		string auth;
		bool overwrite;
		bool donot_submit_job;
    } wildtype_phenotype_reconciliation_params;
    /*
        Queues an FBAModel reconciliation job
    */
    funcdef queue_wildtype_phenotype_reconciliation(wildtype_phenotype_reconciliation_params input) returns (object_metadata output);
    
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		FBAFormulation fba_formulation;
		GapfillingFormulation gapfill_formulation;
		GapgenFormulation gapgen_formulation;
		phenotypeSet_id phenotypeSet;
		workspace_id phenotypeSet_workspace;
		fbamodel_id out_model;
		workspace_id workspace;
		list<gapfill_id> gapFills;
		list<gapgen_id> gapGens;
		workspace_id gapFill_workspace;
		workspace_id gapGen_workspace;
		bool queueReconciliationCombination;
		string auth;
		bool overwrite;
		bool donot_submit_job;
    } queue_reconciliation_sensitivity_analysis_params;
    /*
        Queues an FBAModel reconciliation job
    */
    funcdef queue_reconciliation_sensitivity_analysis(wildtype_phenotype_reconciliation_params input) returns (object_metadata output);
    
    typedef structure {
		fbamodel_id model;
		workspace_id model_workspace;
		FBAFormulation fba_formulation;
		GapfillingFormulation gapfill_formulation;
		GapgenFormulation gapgen_formulation;
		phenotypeSet_id phenotypeSet;
		workspace_id phenotypeSet_workspace;
		fbamodel_id out_model;
		workspace_id workspace;
		list<gapfill_id> gapFills;
		list<gapgen_id> gapGens;
		workspace_id gapFill_workspace;
		workspace_id gapGen_workspace;
		string auth;
		bool overwrite;
		bool donot_submit_job;
    } combine_wildtype_phenotype_reconciliation_params;
    /*
        Queues an FBAModel reconciliation job
    */
    funcdef queue_combine_wildtype_phenotype_reconciliation_params(combine_wildtype_phenotype_reconciliation_params input) returns (object_metadata output);
    	
	typedef string job_id;
	typedef structure {
		job_id jobid;
		workspace_id workspace;
		string auth;
    } jobs_done_params;
	/*
        Mark specified job as complete and run postprocessing
    */
	funcdef jobs_done(jobs_done_params input) returns (JobObject output);

	typedef structure {
		job_id jobid;
		workspace_id workspace;
		string auth;
    } check_job_params;
    /*
        Retreives job data given a job ID
    */
    funcdef check_job(check_job_params input) returns (JobObject output);       
	
	typedef structure {
		job_id jobid;
		workspace_id workspace;
		int index;
		string auth;
    } run_job_params;
	/*
        Runs specified job
    */
	funcdef run_job(run_job_params input) returns (JobObject output);
};
