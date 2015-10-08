/*
@author chenry
*/
module KBaseFBA {
    typedef int bool;
    /*
		Reference to a compound object
		@id subws KBaseBiochem.Biochemistry.compounds.[*].id
	*/
    typedef string compound_ref;
    /*
		Reference to a mapping object
		@id ws KBaseOntology.Mapping
	*/
    typedef string mapping_ref;
    /*
		Reference to a classifier object
		@id ws KBaseFBA.Classifier
	*/
    typedef string Classifier_ref;
    /*
		Reference to a training set object
		@id ws KBaseFBA.ClassifierTrainingSet
	*/
    typedef string Trainingset_ref;
    /*
		Reference to a biochemistry object
		@id ws KBaseBiochem.Biochemistry
	*/
    typedef string Biochemistry_ref;
    /*
		Template biomass ID
		@id external
	*/
    typedef string templatebiomass_id;
    /*
		Template biomass compound ID
		@id external
	*/
    typedef string templatebiomasscomponent_id;
	/*
		Template reaction ID
		@id external
	*/
    typedef string templatereaction_id;
    /*
		ModelTemplate ID
		@id kb
	*/
    typedef string modeltemplate_id;
    /*
		Reference to a model template
		@id ws KBaseBiochem.Media
	*/
    typedef string media_ref;
    /*
		Reference to a model template
		@id ws KBaseGenomes.Genome
	*/
    typedef string genome_ref;
    /*
		Reference to a model template
		@id ws KBaseFBA.ModelTemplate
	*/
    typedef string template_ref;
    /*
		Reference to an OTU in a metagenome
		@id subws KBaseGenomes.MetagenomeAnnotation.otus.[*].id
	*/
    typedef string metagenome_otu_ref;
    /*
		Reference to a metagenome object
		@id ws KBaseGenomes.MetagenomeAnnotation
	*/
    typedef string metagenome_ref;
    /*
		Reference to a feature of a genome object
		@id subws KBaseGenomes.Genome.features.[*].id
	*/
    typedef string feature_ref;
	/*
		Reference to a gapgen object
		@id ws KBaseFBA.Gapgeneration
	*/
    typedef string gapgen_ref;
    /*
		Reference to a FBA object
		@id ws KBaseFBA.FBA
	*/
    typedef string fba_ref;
	/*
		Reference to a gapfilling object
		@id ws KBaseFBA.Gapfilling
	*/
    typedef string gapfill_ref;
	/*
		Reference to a complex object
		@id subws KBaseOntology.Mapping.complexes.[*].id
	*/
    typedef string complex_ref;
	/*
		Reference to a reaction object in a biochemistry
		@id subws KBaseBiochem.Biochemistry.reactions.[*].id
	*/
    typedef string reaction_ref;
    /*
		Reference to a reaction object in a model
		@id subws KBaseFBA.FBAModel.modelreactions.[*].id
	*/
    typedef string modelreaction_ref;
    /*
		Reference to a biomass object in a model
		@id subws KBaseFBA.FBAModel.biomasses.[*].id
	*/
    typedef string biomass_ref;
	/*
		Reference to a compartment object in a model
		@id subws KBaseFBA.FBAModel.modelcompartments.[*].id
	*/
    typedef string modelcompartment_ref;
	/*
		Reference to a compartment object
		@id subws KBaseBiochem.Biochemistry.compartments.[*].id
	*/
    typedef string compartment_ref;
	/*
		Reference to a compound object in a model
		@id subws KBaseFBA.FBAModel.modelcompounds.[*].id
	*/
    typedef string modelcompound_ref;
    /*
		Reference to regulatory model
		@id ws KBaseRegulation.RegModel
	*/
    typedef string regmodel_ref;
    /*
		Reference to regulome
		@id ws KBaseRegulation.Regulome
	*/
    typedef string regulome_ref;
    /*
		Reference to PROM constraints
		@id ws KBaseFBA.PromConstraint
	*/
    typedef string promconstraint_ref;
    /*
		Reference to expression data
		@id ws KBaseExpression.ExpressionSeries
	*/
    typedef string expression_series_ref;
    /*
		Reference to expression data
		@id ws KBaseFeatureValues.ExpressionMatrix
	*/
    typedef string expression_matrix_ref;
    /*
		Reference to expression data
		@id ws KBaseExpression.ExpressionSample
	*/
    typedef string expression_sample_ref;
    /*
		Reference to probabilistic annotation
		@id ws KBaseProbabilisticAnnotation.ProbAnno
	*/
    typedef string probanno_ref;
    /*
		Reference to a phenotype set object
		@id ws KBasePhenotypes.PhenotypeSet
	*/
    typedef string phenotypeset_ref;
    /*
		Reference to a phenotype simulation set object
		@id ws KBasePhenotypes.PhenotypeSimulationSet
	*/
    typedef string phenotypesimulationset_ref;
    /*
		Reference to metabolic model
		@id ws KBaseFBA.FBAModel
	*/
    typedef string fbamodel_ref;
	/*
		KBase genome ID
		@id kb
	*/
    typedef string genome_id;
    /*
		KBase FBA ID
		@id kb
	*/
    typedef string fba_id;
    /*
		Biomass reaction ID
		@id external
	*/
    typedef string biomass_id;
    /*
		Gapgeneration solution ID
		@id external
	*/
    typedef string gapgensol_id;
    /*
		Model compartment ID
		@id external
	*/
    typedef string modelcompartment_id;
    /*
		Model compound ID
		@id external
	*/
    typedef string modelcompound_id;
    /*
		Model reaction ID
		@id external
	*/
    typedef string modelreaction_id;
    /*
		Genome feature ID
		@id external
	*/
    typedef string feature_id;
    /*
		Source ID
		@id external
	*/
    typedef string source_id;
    /*
		Gapgen ID
		@id kb
	*/
    typedef string gapgen_id;
	/*
		Gapfill ID
		@id kb
	*/
    typedef string gapfill_id;
    /*
		Gapfill solution ID
		@id external
	*/
    typedef string gapfillsol_id;
    /*
		FBAModel ID
		@id kb
	*/
    typedef string fbamodel_id;
    /* 
    	BiomassCompound object
    	
		@searchable ws_subset modelcompound_ref coefficient
    */
    typedef structure {
		modelcompound_ref modelcompound_ref;
		float coefficient;
    } BiomassCompound;
    
    /* 
    	Biomass object
    */
    typedef structure {
		biomass_id id;
		string name;
		float other;
		float dna;
		float rna;
		float protein;
		float cellwall;
		float lipid;
		float cofactor;
		float energy;
		list<BiomassCompound> biomasscompounds;
    } Biomass;

    /* 
    	ModelCompartment object
    */
    typedef structure {
		modelcompartment_id id;
		compartment_ref compartment_ref;
		int compartmentIndex;
		string label;
		float pH;
		float potential;
    } ModelCompartment;
    
    /* 
    	ModelCompound object
    	
    	@optional aliases maxuptake
    */
    typedef structure {
		modelcompound_id id;
		compound_ref compound_ref;
		list<string> aliases;
		string name;
		float charge;
		float maxuptake;
		string formula;
		modelcompartment_ref modelcompartment_ref;
    } ModelCompound;
    
    /* 
    	ModelReactionReagent object
    	
		@searchable ws_subset modelcompound_ref coefficient
    */
    typedef structure {
		modelcompound_ref modelcompound_ref;
		float coefficient;
    } ModelReactionReagent;
    
    /* 
    	ModelReactionProteinSubunit object
    	
		@searchable ws_subset role triggering optionalSubunit feature_refs
    */
    typedef structure {
		string role;
		bool triggering;
		bool optionalSubunit;
		string note;
		list<feature_ref> feature_refs;
    } ModelReactionProteinSubunit;
    
    /* 
    	ModelReactionProtein object
    */
    typedef structure {
		complex_ref complex_ref;
		string note;
		list<ModelReactionProteinSubunit> modelReactionProteinSubunits;
    } ModelReactionProtein;
    
    /* 
    	ModelReaction object
    	
    	@optional name pathway reference aliases maxforflux maxrevflux
    */
    typedef structure {
		modelreaction_id id;
		reaction_ref reaction_ref;
		string name;
		list<string> aliases;
		string pathway;
		string reference;
		string direction;
		float protons;
		float maxforflux;
		float maxrevflux;
		modelcompartment_ref modelcompartment_ref;
		float probability;
		list<ModelReactionReagent> modelReactionReagents;
		list<ModelReactionProtein> modelReactionProteins;
    } ModelReaction;

    /* 
    	ModelGapfill object
    	 
    	@optional integrated_solution
    	@optional fba_ref
    	@optional gapfill_ref jobnode
    */
    typedef structure {
		gapfill_id id;
		gapfill_id gapfill_id;
		gapfill_ref gapfill_ref;
		fba_ref fba_ref;
		bool integrated;
		string integrated_solution;
		media_ref media_ref;
		string jobnode;
    } ModelGapfill;
    
    /* 
    	ModelGapgen object
    	
    	@optional integrated_solution
    	@optional fba_ref
    	@optional gapgen_ref jobnode
    */
    typedef structure {
    	gapgen_id id;
    	gapgen_id gapgen_id;
		gapgen_ref gapgen_ref;
		fba_ref fba_ref;
		bool integrated;
		string integrated_solution;
		media_ref media_ref;
		string jobnode;
    } ModelGapgen;
    
    
    typedef structure {
    	bool integrated;
    	list<tuple<string rxnid,float maxbound,bool forward>> ReactionMaxBounds;
    	list<tuple<string cpdid,float maxbound>> UptakeMaxBounds;
    	list<tuple<string bioid,string biocpd,float modifiedcoef>> BiomassChanges; 
    	float ATPSynthase;
    	float ATPMaintenance;
    } QuantOptSolution;
    
    /* 
    	ModelQuantOpt object
    */
    typedef structure {
    	string id;
		fba_ref fba_ref;
		media_ref media_ref;
		bool integrated;
		int integrated_solution;
		list<QuantOptSolution> solutions;
    } ModelQuantOpt;
    
    /* 
    	FBAModel object
    	
    	@optional metagenome_otu_ref metagenome_ref genome_ref template_refs ATPSynthaseStoichiometry ATPMaintenance quantopts
		@metadata ws source_id as Source ID
		@metadata ws source as Source
		@metadata ws name as Name
		@metadata ws type as Type
		@metadata ws genome_ref as Genome
		@metadata ws length(biomasses) as Number biomasses
		@metadata ws length(modelcompartments) as Number compartments
		@metadata ws length(modelcompounds) as Number compounds
		@metadata ws length(modelreactions) as Number reactions
		@metadata ws length(gapgens) as Number gapgens
		@metadata ws length(gapfillings) as Number gapfills
    */
    typedef structure {
		fbamodel_id id;
		string source;
		source_id source_id;
		string name;
		string type;
		genome_ref genome_ref;
		metagenome_ref metagenome_ref;
		metagenome_otu_ref metagenome_otu_ref;
		template_ref template_ref;
		float ATPSynthaseStoichiometry;
		float ATPMaintenance;
		
		list<template_ref> template_refs;
		list<ModelGapfill> gapfillings;
		list<ModelGapgen> gapgens;
		list<ModelQuantOpt> quantopts;
		
		list<Biomass> biomasses;
		list<ModelCompartment> modelcompartments;
		list<ModelCompound> modelcompounds;
		list<ModelReaction> modelreactions;
    } FBAModel;
    
    /* 
    	FBAConstraint object
    */
    typedef structure {
    	string name;
    	float rhs;
    	string sign;
    	mapping<modelcompound_id,float> compound_terms;
    	mapping<modelreaction_id,float> reaction_terms;
    	mapping<biomass_id,float> biomass_terms;
	} FBAConstraint;
    
    /* 
    	FBAReactionBound object
    */
    typedef structure {
    	modelreaction_ref modelreaction_ref;
    	string variableType;
    	float upperBound;
    	float lowerBound;
	} FBAReactionBound;
    
    /* 
    	FBACompoundBound object
    */
     typedef structure {
    	modelcompound_ref modelcompound_ref;
    	string variableType;
    	float upperBound;
    	float lowerBound;
	} FBACompoundBound;
    
    /* 
    	FBACompoundVariable object
    */
    typedef structure {
    	modelcompound_ref modelcompound_ref;
    	string variableType;
    	float upperBound;
    	float lowerBound;
    	string class;
    	float min;
    	float max;
    	float value;
	} FBACompoundVariable;
	
	/* 
    	FBAReactionVariable object
    	
    	@optional exp_state expression scaled_exp
    	
    */
	typedef structure {
    	modelreaction_ref modelreaction_ref;
    	string variableType;
    	float upperBound;
    	float lowerBound;
    	string class;
    	float min;
    	float max;
    	float value;
		string exp_state;
		float expression;
		float scaled_exp;
	} FBAReactionVariable;
	
	/* 
    	FBABiomassVariable object
    */
	typedef structure {
    	biomass_ref biomass_ref;
    	string variableType;
    	float upperBound;
    	float lowerBound;
    	string class;
    	float min;
    	float max;
    	float value;
	} FBABiomassVariable;
	
	/* 
    	FBAPromResult object
    */
	typedef structure {
    	float objectFraction;
    	float alpha;
    	float beta;
	} FBAPromResult;
    

	/*
	  Either of two values: 
	   - InactiveOn: specified as on, but turns out as inactive
	   - ActiveOff: specified as off, but turns out as active
	 */
	typedef string conflict_state;
	/*
	  FBATintleResult object	 
	*/
	typedef structure {
		float originalGrowth;
		float growth;
		float originalObjective;
		float objective;
		mapping<conflict_state,feature_id> conflicts;		    
	} FBATintleResult;

    /* 
    	FBADeletionResult object
    */
    typedef structure {
    	list<feature_ref> feature_refs;
    	float growthFraction;
	} FBADeletionResult;
	
	/* 
    	FBAMinimalMediaResult object
    */
	typedef structure {
    	list<compound_ref> essentialNutrient_refs;
    	list<compound_ref> optionalNutrient_refs;
	} FBAMinimalMediaResult;
    
    /* 
    	FBAMetaboliteProductionResult object
    */
    typedef structure {
    	modelcompound_ref modelcompound_ref;
    	float maximumProduction;
	} FBAMetaboliteProductionResult;
    
	/* 
    	FBAMinimalReactionsResult object
    */
    typedef structure {
    	string id;
    	bool suboptimal;
    	float totalcost;
    	list<modelreaction_ref> reaction_refs;
    	list<string> reaction_directions;
	} FBAMinimalReactionsResult;  
    

    typedef float probability;
    /*
      collection of tintle probability scores for each feature in a genome,
      representing a single gene probability sample
    */
    typedef structure {
	    mapping<feature_id,probability> tintle_probability;
	    string expression_sample_ref;	    
    } TintleProbabilitySample;

	
	typedef structure {
		string biomass_component;
		float mod_coefficient;
	} QuantOptBiomassMod;
	
	typedef structure {
		modelreaction_ref modelreaction_ref;
		modelcompound_ref modelcompound_ref;
		bool reaction;
		float mod_upperbound;
	} QuantOptBoundMod;
	
	typedef structure {
		float atp_synthase;
		float atp_maintenance;
		list<QuantOptBiomassMod> QuantOptBiomassMods;
		list<QuantOptBoundMod> QuantOptBoundMods;
	} QuantitativeOptimizationSolution;

	/* 
    	GapFillingReaction object holds data on a reaction added by gapfilling analysis
    	
    	@optional compartmentIndex round
    */
    typedef structure {
    	int round;
    	reaction_ref reaction_ref;
    	compartment_ref compartment_ref;
    	string direction;
    	int compartmentIndex;
    	list<feature_ref> candidateFeature_refs;
    } GapfillingReaction;
    
    /* 
    	ActivatedReaction object holds data on a reaction activated by gapfilling analysis
    	
    	@optional round
    */
    typedef structure {
    	int round;
    	modelreaction_ref modelreaction_ref;
    } ActivatedReaction;
    
    /*
    	GapFillingSolution object holds data on a solution generated by gapfilling analysis
    	
    	@optional objective gfscore actscore rejscore candscore rejectedCandidates activatedReactions failedReaction_refs
    	
    	@searchable ws_subset id suboptimal integrated solutionCost koRestore_refs biomassRemoval_refs mediaSupplement_refs
    */
    typedef structure {
    	gapfillsol_id id;
    	float solutionCost;
    	
    	list<modelcompound_ref> biomassRemoval_refs;
    	list<modelcompound_ref> mediaSupplement_refs;
    	list<modelreaction_ref> koRestore_refs;
    	bool integrated;
    	bool suboptimal;
    	
    	float objective;
    	float gfscore;
    	float actscore;
    	float rejscore;
    	float candscore;
    	
    	list<GapfillingReaction> rejectedCandidates;
    	list<modelreaction_ref> failedReaction_refs;
    	list<ActivatedReaction> activatedReactions;
    	list<GapfillingReaction> gapfillingSolutionReactions;
    } GapfillingSolution;

    /* 
    	FBA object holds the formulation and results of a flux balance analysis study
    	
    	@optional ExpressionKappa ExpressionOmega ExpressionAlpha expression_matrix_ref expression_matrix_column jobnode gapfillingSolutions QuantitativeOptimizationSolutions quantitativeOptimization minimize_reactions minimize_reaction_costs FBATintleResults FBAMinimalReactionsResults PROMKappa phenotypesimulationset_ref objectiveValue phenotypeset_ref promconstraint_ref regulome_ref tintlesample_ref tintleW tintleKappa
    	@metadata ws maximizeObjective as Maximized
		@metadata ws comboDeletions as Combination deletions
		@metadata ws minimize_reactions as Minimize reactions
		@metadata ws regulome_ref as Regulome
		@metadata ws fbamodel_ref as Model
		@metadata ws promconstraint_ref as PromConstraint
		@metadata ws media_ref as Media
		@metadata ws objectiveValue as Objective
		@metadata ws expression_matrix_ref as ExpressionMatrix
		@metadata ws expression_matrix_column as ExpressionMatrixColumn
		@metadata ws length(biomassflux_objterms) as Number biomass objectives
		@metadata ws length(geneKO_refs) as Number gene KO
		@metadata ws length(reactionKO_refs) as Number reaction KO
		@metadata ws length(additionalCpd_refs) as Number additional compounds
		@metadata ws length(FBAConstraints) as Number constraints
		@metadata ws length(FBAReactionBounds) as Number reaction bounds
		@metadata ws length(FBACompoundBounds) as Number compound bounds
		@metadata ws length(FBACompoundVariables) as Number compound variables
		@metadata ws length(FBAReactionVariables) as Number reaction variables
		
    */
    typedef structure {
		fba_id id;
		bool fva;
		bool fluxMinimization;
		bool findMinimalMedia;
		bool allReversible;
		bool simpleThermoConstraints;
		bool thermodynamicConstraints;
		bool noErrorThermodynamicConstraints;
		bool minimizeErrorThermodynamicConstraints;
		bool quantitativeOptimization;
		
		bool maximizeObjective;
		mapping<modelcompound_id,float> compoundflux_objterms;
    	mapping<modelreaction_id,float> reactionflux_objterms;
		mapping<biomass_id,float> biomassflux_objterms;
		
		int comboDeletions;
		int numberOfSolutions;
		
		float objectiveConstraintFraction;
		float defaultMaxFlux;
		float defaultMaxDrainFlux;
		float defaultMinDrainFlux;
		float PROMKappa;
		float tintleW;
		float tintleKappa;
		float ExpressionAlpha;
		float ExpressionOmega;
		float ExpressionKappa;
		
		bool decomposeReversibleFlux;
		bool decomposeReversibleDrainFlux;
		bool fluxUseVariables;
		bool drainfluxUseVariables;
		bool minimize_reactions;
		
		string jobnode;
		regulome_ref regulome_ref;
		fbamodel_ref fbamodel_ref;
		promconstraint_ref promconstraint_ref;
		expression_matrix_ref expression_matrix_ref;
		string expression_matrix_column;
		expression_sample_ref tintlesample_ref;
		media_ref media_ref;
		phenotypeset_ref phenotypeset_ref;
		list<feature_ref> geneKO_refs;
		list<modelreaction_ref> reactionKO_refs;
		list<modelcompound_ref> additionalCpd_refs;
		mapping<string,float> uptakeLimits;
		mapping<modelreaction_id,float> minimize_reaction_costs;
		
		mapping<string,string> parameters;
		mapping<string,list<string>> inputfiles;
		
		list<FBAConstraint> FBAConstraints;
		list<FBAReactionBound> FBAReactionBounds;
		list<FBACompoundBound> FBACompoundBounds;
			
		float objectiveValue;
		mapping<string,list<string>> outputfiles;
		phenotypesimulationset_ref phenotypesimulationset_ref;

		list<FBACompoundVariable> FBACompoundVariables;
		list<FBAReactionVariable> FBAReactionVariables;
		list<FBABiomassVariable> FBABiomassVariables;
		list<FBAPromResult> FBAPromResults;
		list<FBATintleResult> FBATintleResults;
		list<FBADeletionResult> FBADeletionResults;
		list<FBAMinimalMediaResult> FBAMinimalMediaResults;
		list<FBAMetaboliteProductionResult> FBAMetaboliteProductionResults;
		list<FBAMinimalReactionsResult> FBAMinimalReactionsResults;
		list<QuantitativeOptimizationSolution> QuantitativeOptimizationSolutions;
		list<GapfillingSolution> gapfillingSolutions;
    } FBA;
    
    /* 
    	GapGenerationSolutionReaction object holds data a reaction proposed to be removed from the model
    */
    typedef structure {
    	modelreaction_ref modelreaction_ref;
    	string direction;
    } GapgenerationSolutionReaction;
    
    /* 
    	GapGenerationSolution object holds data on a solution proposed by the gapgeneration command
    */
    typedef structure {
    	gapgensol_id id;
    	float solutionCost;
    	list<modelcompound_ref> biomassSuppplement_refs;
    	list<modelcompound_ref> mediaRemoval_refs;
    	list<modelreaction_ref> additionalKO_refs;
    	bool integrated;
    	bool suboptimal;
    	list<GapgenerationSolutionReaction> gapgenSolutionReactions;
    } GapgenerationSolution;
    
    /* 
    	GapGeneration object holds data on formulation and solutions from gapgen analysis
    	
    	@optional fba_ref totalTimeLimit timePerSolution media_ref referenceMedia_ref gprHypothesis reactionRemovalHypothesis biomassHypothesis mediaHypothesis
		@metadata ws fba_ref as FBA
		@metadata ws fbamodel_ref as Model
		@metadata ws length(gapgenSolutions) as Number solutions
    */
    typedef structure {
    	gapgen_id id;
    	fba_ref fba_ref;
    	fbamodel_ref fbamodel_ref;
    	
    	bool mediaHypothesis;
    	bool biomassHypothesis;
    	bool gprHypothesis;
    	bool reactionRemovalHypothesis;
    	
    	media_ref media_ref;
    	media_ref referenceMedia_ref;
    	
    	int timePerSolution;
    	int totalTimeLimit;
    	
    	list<GapgenerationSolution> gapgenSolutions;
    } Gapgeneration;
    
    /* 
    	GapFilling object holds data on the formulations and solutions of a gapfilling analysis
    	
    	@optional simultaneousGapfill totalTimeLimit timePerSolution transporterMultiplier singleTransporterMultiplier biomassTransporterMultiplier noDeltaGMultiplier noStructureMultiplier deltaGMultiplier directionalityMultiplier drainFluxMultiplier reactionActivationBonus allowableCompartment_refs blacklistedReaction_refs targetedreaction_refs guaranteedReaction_refs completeGapfill balancedReactionsOnly reactionAdditionHypothesis gprHypothesis biomassHypothesis mediaHypothesis fba_ref media_ref probanno_ref
    	@metadata ws fba_ref as FBA
		@metadata ws fbamodel_ref as Model
		@metadata ws media_ref as Media
		@metadata ws length(gapfillingSolutions) as Number solutions
    
    */
    typedef structure {
    	gapfill_id id;
    	fba_ref fba_ref;
    	media_ref media_ref;
    	fbamodel_ref fbamodel_ref;
    	probanno_ref probanno_ref;
    	
    	bool mediaHypothesis;
    	bool biomassHypothesis;
    	bool gprHypothesis;
    	bool reactionAdditionHypothesis;
    	bool balancedReactionsOnly;
    	bool completeGapfill;
    	bool simultaneousGapfill;
    	
    	list<reaction_ref> guaranteedReaction_refs;
    	list<reaction_ref> targetedreaction_refs;
    	list<reaction_ref> blacklistedReaction_refs;
    	list<compartment_ref> allowableCompartment_refs;
    	
    	float reactionActivationBonus;
    	float drainFluxMultiplier;
    	float directionalityMultiplier;
    	float deltaGMultiplier;
    	float noStructureMultiplier;
    	float noDeltaGMultiplier;
    	float biomassTransporterMultiplier;
    	float singleTransporterMultiplier;
    	float transporterMultiplier;
    	
    	int timePerSolution;
    	int totalTimeLimit;
    	
    	mapping<reaction_ref,float> reactionMultipliers;
    	list<GapfillingSolution> gapfillingSolutions;
    } Gapfilling;
	
    /* 
    	TemplateBiomassComponent object holds data on a compound of biomass in template
    */
	typedef structure {
    	templatebiomasscomponent_id id;
    	string class;
    	compound_ref compound_ref;
    	compartment_ref compartment_ref;
    	
    	string coefficientType;
    	float coefficient;
    	
    	list<compound_ref> linked_compound_refs;
    	list<float> link_coefficients;
    } TemplateBiomassComponent;
    
    /* 
    	TemplateBiomass object holds data on biomass in template
    	
    	@searchable ws_subset id name type other dna rna protein lipid cellwall cofactor energy
    */
	typedef structure {
    	templatebiomass_id id;
    	string name;
    	string type;
    	float other;
    	float dna;
    	float rna;
    	float protein;
    	float lipid;
    	float cellwall;
    	float cofactor;
    	float energy;
    	list<TemplateBiomassComponent> templateBiomassComponents;
    } TemplateBiomass;
    
    /* 
    	TemplateReaction object holds data on reaction in template
    	
    	@optional base_cost forward_penalty reverse_penalty GapfillDirection
    */
	typedef structure {
    	templatereaction_id id;
    	reaction_ref reaction_ref;
    	compartment_ref compartment_ref;
    	list<complex_ref> complex_refs;
    	string direction;
    	string GapfillDirection;
    	string type;
    	float base_cost;
    	float forward_penalty;
    	float reverse_penalty;
    } TemplateReaction;
    
    /* 
    	ModelTemplate object holds data on how a model is constructed from an annotation
    	    	
    	@optional name
    	@searchable ws_subset id name modelType domain mapping_ref
    */
	typedef structure {
    	modeltemplate_id id;
    	string name;
    	string modelType;
    	string domain;
    	mapping_ref mapping_ref;
    	Biochemistry_ref biochemistry_ref;
    	
    	list<TemplateReaction> templateReactions;
    	list<TemplateBiomass> templateBiomasses;
    } ModelTemplate;
    
    /* ReactionSensitivityAnalysisCorrectedReaction object
		
		kb_sub_id kbid - KBase ID for reaction knockout corrected reaction
		ws_sub_id model_reaction_wsid - ID of model reaction
		float normalized_required_reaction_count - Normalized count of reactions required for this reaction to function
		list<ws_sub_id> required_reactions - list of reactions required for this reaction to function
		
		@optional
		
	*/
	typedef structure {
		modelreaction_ref modelreaction_ref;
		float normalized_required_reaction_count;
		list<modelreaction_id> required_reactions;
    } ReactionSensitivityAnalysisCorrectedReaction;
	
	/* Object for holding reaction knockout sensitivity reaction data
		
		kb_sub_id kbid - KBase ID for reaction knockout sensitivity reaction
		ws_sub_id model_reaction_wsid - ID of model reaction
		bool delete - indicates if reaction is to be deleted
		bool deleted - indicates if the reaction has been deleted
		float growth_fraction - Fraction of wild-type growth after knockout
		float normalized_activated_reaction_count - Normalized number of activated reactions
		list<ws_sub_id> biomass_compounds  - List of biomass compounds that depend on the reaction
		list<ws_sub_id> new_inactive_rxns - List of new reactions dependant upon reaction KO
		list<ws_sub_id> new_essentials - List of new essential genes with reaction knockout
	
		@optional direction
	*/
	typedef structure {
		string id;
		modelreaction_ref modelreaction_ref;
		float growth_fraction;
		bool delete;
		bool deleted;
		string direction;
		float normalized_activated_reaction_count;
		list<modelcompound_id> biomass_compounds;
		list<modelreaction_id> new_inactive_rxns;
		list<feature_id> new_essentials;
    } ReactionSensitivityAnalysisReaction;
	
	/* Object for holding reaction knockout sensitivity results
	
		kb_id kbid - KBase ID of reaction sensitivity object
		ws_id model_wsid - Workspace reference to associated model
		string type - type of reaction KO sensitivity object
		bool deleted_noncontributing_reactions - boolean indicating if noncontributing reactions were deleted
		bool integrated_deletions_in_model - boolean indicating if deleted reactions were implemented in the model
		list<ReactionSensitivityAnalysisReaction> reactions - list of sensitivity data for tested reactions
		list<ReactionSensitivityAnalysisCorrectedReaction> corrected_reactions - list of reactions dependant upon tested reactions
		
		@searchable ws_subset id fbamodel_ref type deleted_noncontributing_reactions integrated_deletions_in_model
		@optional	
	*/
    typedef structure {
		string id;
		fbamodel_ref fbamodel_ref;
		string type;
		bool deleted_noncontributing_reactions;
		bool integrated_deletions_in_model;
		list<ReactionSensitivityAnalysisReaction> reactions;
		list<ReactionSensitivityAnalysisCorrectedReaction> corrected_reactions;
    } ReactionSensitivityAnalysis;


    /* 
        ETCStep object
    */

    typedef structure {
        list<string> reactions;
    } ETCStep;

    /* 
        ETCPathwayObj object
    */

    typedef structure {
        string electron_acceptor;
        list<ETCStep> steps;
    } ETCPathwayObj;

    /* 
        ElectronTransportChains (ETC) object
    */
    typedef structure {
        list<ETCPathwayObj> pathways;
    } ETC;

    /*
    Object required by the prom_constraints object which defines the computed probabilities for a target gene.  The
    TF regulating this target can be deduced based on the TFtoTGmap object.
    
        string target_gene_ref           - reference to the target gene
        float probTGonGivenTFoff    - PROB(target=ON|TF=OFF)
                                    the probability that the target gene is ON, given that the
                                    transcription factor is not expressed.  Set to null or empty if
                                    this probability has not been calculated yet.
        float probTGonGivenTFon   - PROB(target=ON|TF=ON)
                                    the probability that the transcriptional target is ON, given that the
                                    transcription factor is expressed.    Set to null or empty if
                                    this probability has not been calculated yet.
    */
    typedef structure {
        string target_gene_ref;
        float probTGonGivenTFoff;
        float probTGonGivenTFon;
    } TargetGeneProbabilities;

	/*
    Object required by the prom_constraints object, this maps a transcription factor 
     to a group of regulatory target genes.
    
        string transcriptionFactor_ref                       - reference to the transcription factor
        list<TargetGeneProbabilities> targetGeneProbs        - collection of target genes for the TF
                                                                along with associated joint probabilities for each
                                                                target to be on given that the TF is on or off.
    
    */
    typedef structure {
        string transcriptionFactor_ref;
        list<TargetGeneProbabilities> targetGeneProbs;
    } TFtoTGmap;
    
    /*
    An object that encapsulates the information necessary to apply PROM-based constraints to an FBA model. This
    includes a regulatory network consisting of a set of regulatory interactions (implied by the set of TFtoTGmap
    objects) and interaction probabilities as defined in each TargetGeneProbabilities object.  A link the the annotation
    object is required in order to properly link to an FBA model object.  A reference to the expression_data_collection
    used to compute the interaction probabilities is provided for future reference.
    
        string id                                         - the id of this prom_constraints object in a
                                                                        workspace
        genome_ref									
                                                                        which specfies how TFs and targets are named
        list<TFtoTGmap> transcriptionFactorMaps                                     - the list of TFMaps which specifies both the
                                                                        regulatory network and interaction probabilities
                                                                        between TF and target genes
        expression_series_ref expression_series_ref   - the id of the expresion_data_collection object in
                                                                        the workspace which was used to compute the
                                                                        regulatory interaction probabilities
    
    */
    typedef structure {
        string id;
        genome_ref genome_ref;
        list<TFtoTGmap> transcriptionFactorMaps;
        expression_series_ref expression_series_ref;
		regulome_ref regulome_ref;
    } PromConstraint;
    
    /*
        
    */
    typedef structure {
        string id;
        string description;
        float tp_rate;
        float fb_rate;
        float precision;
        float recall;
        float f_measure;
        float ROC_area;
        mapping<string,int> missclassifications;
    } ClassifierClasses;
    
    /*
        
    */
    typedef structure {
        string id;
        string attribute_type;
        string classifier_type;
        Trainingset_ref trainingset_ref;
        string data;
        string readable;
        int correctly_classified_instances;
        int incorrectly_classified_instances;
        int total_instances;
        float kappa;
        float mean_absolute_error;
        float root_mean_squared_error;
        float relative_absolute_error;
        float relative_squared_error;
        list<ClassifierClasses> classes;
    } Classifier;
    
    typedef tuple<genome_ref genome,string class,list<string> attributes> WorkspaceGenomeClassData;
    typedef tuple<string database,string genome_id,string class,list<string> attributes> ExternalGenomeClassData;
	typedef tuple<string,string> ClassData;
    typedef tuple<genome_ref genome,string class,float probability> WorkspaceGenomeClassPrediction;
    typedef tuple<string database,string genome,string class,float probability> ExternalGenomeClassPrediction;

	    
    /*
        @optional attribute_type source description
    */
    typedef structure {
        string id;
        string description;
        string source;
        string attribute_type;
        list<WorkspaceGenomeClassData> workspace_training_set; 
		list<ExternalGenomeClassData> external_training_set;
		list<ClassData> class_data;
    } ClassifierTrainingSet;
    
    /*
    */
    typedef structure {
        string id;
        Classifier_ref classifier_ref;
        list<WorkspaceGenomeClassPrediction> workspace_genomes; 
		list<ExternalGenomeClassPrediction> external_genomes;
    } ClassifierResult;
    
    /*
	This type represents an element of a FBAModelSet.
	@optional metadata
	*/
	typedef structure {
	  mapping<string, string> metadata;
	  fbamodel_ref ref;
	} FBAModelSetElement;

	/*
		A type describing a set of FBAModels, where each element of the set 
		is an FBAModel object reference.
	*/
	typedef structure {
	  string description;
	  mapping<string, FBAModelSetElement> elements;
	} FBAModelSet;
	
	/*
		Conserved state - indicates a possible state of reaction/compound in FBA with values:
			<NOT_IN_MODEL,INACTIVE,FORWARD,REVERSE,UPTAKE,EXCRETION>
	*/
    typedef string Conserved_state; 
	
	/*
		FBAComparisonFBA object: this object holds information about an FBA in a FBA comparison
	*/
	typedef structure {
		string id;
		fba_ref fba_ref;
		fbamodel_ref fbamodel_ref;
		mapping<string fba_id,tuple<int common_reactions,int common_forward,int common_reverse,int common_inactive,int common_exchange_compounds,int common_uptake,int common_excretion,int common_inactive> > fba_similarity;
		float objective;
		media_ref media_ref;
		int reactions;
		int compounds;
		int forward_reactions;
		int reverse_reactions;
		int uptake_compounds;
		int excretion_compounds;
	} FBAComparisonFBA;

	/*
		FBAComparisonReaction object: this object holds information about a reaction across all compared models
	*/
	typedef structure {
		string id;
		string name;
		list<tuple<float coefficient,string name,string compound>> stoichiometry;
		string direction;
		mapping<Conserved_state,tuple<int count,float fraction,float flux_mean, float flux_stddev>> state_conservation;
		Conserved_state most_common_state;
		mapping<string fba_id,tuple<Conserved_state,float UpperBound,float LowerBound,float Max,float Min,float flux,float expression_score,string expression_class,string ModelReactionID>> reaction_fluxes;
	} FBAComparisonReaction;

	/*
		FBAComparisonCompound object: this object holds information about a compound across a set of FBA simulations
	*/
	typedef structure {
		string id;
		string name;
		float charge;
		string formula;
		mapping<Conserved_state,tuple<int count,float fraction,float flux_mean,float stddev>> state_conservation;
		Conserved_state most_common_state;
		mapping<string fba_id,tuple<Conserved_state,float UpperBound,float LowerBound,float Max,float Min,float Flux,string class>> exchanges;
	} FBAComparisonCompound;

	/*
		FBAComparison object: this object holds information about a comparison of multiple FBA simulations

		@metadata ws id as ID
		@metadata ws common_reactions as Common reactions
		@metadata ws common_compounds as Common compounds
		@metadata ws length(fbas) as Number FBAs
		@metadata ws length(reactions) as Number reactions
		@metadata ws length(compounds) as Number compounds
	*/
	typedef structure {
		string id;
		int common_reactions;
		int common_compounds;
		list<FBAComparisonFBA> fbas;
		list<FBAComparisonReaction> reactions;
		list<FBAComparisonCompound> compounds;
	} FBAComparison;

	/*
		SubsystemReaction object: this object holds information about individual reactions in a subsystems
	*/
	typedef structure {
		string id;
		string reaction_ref;
		list <string> roles;
		string tooltip;
	} SubsystemReaction;

	/*
		SubsystemAnnotation object: this object holds all reactions in subsystems
	*/
	typedef structure {
		string id;
		Biochemistry_ref biochemistry_ref;
		mapping_ref mapping_ref;
		mapping < string subsystem_id, list < tuple < string reaction_id, SubsystemReaction reaction_info > > > subsystems;
	} SubsystemAnnotation;
};
