module fbaModelServices {
    typedef int bool;
	
	/*IMPORT FROM probabilistic_annotation/ProbabilisticAnnotation.spec*/
	typedef string md5;
    typedef list<md5> md5s;
    typedef string genome_id;
    typedef string feature_id;
    typedef string contig_id;
    typedef string feature_type;

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
	/*END IMPORT*/

	/*BIOCHEMISTRY SPEC*/
	typedef string reaction_id;
	typedef string media_id;
	typedef string compound_id;
	typedef string biochemistry_id;
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
		string name;
		list<string> aliases;
		float charge;
		string formula;
    } Compound;
	
	typedef structure {
		reaction_id id;
		string reversibility;
		float deltaG;
		float deltaGErr;
		string equation;	
    } Reaction;
	/*END BIOCHEMISTRY SPEC*/
	
	/*FBAMODEL SPEC*/
	typedef string modelcompartment_id;
	typedef structure {
		modelcompartment_id id;
		string name;
		float pH;
		float potential;
		int index;
    } ModelCompartment;
	
	typedef string compound_id;
	typedef string modelcompound_id;
	typedef structure {
		modelcompound_id id;
		compound_id compound;
		string name;
		modelcompartment_id compartment;
		float coefficient;
    } ModelCompound;
	
	typedef string feature_id;
	typedef string reaction_id;
	typedef string modelreaction_id;
	typedef structure {
		modelreaction_id id;
		reaction_id reaction;
		string name;
		string direction;
		list<feature_id> features;
		modelcompartment_id compartment;
    } ModelReaction;
	
	typedef tuple<modelcompound_id modelcompound,float coefficient> BiomassCompound;
	
	typedef string biomass_id;
	typedef structure {
		biomass_id id;
		string name;
		list<BiomassCompound> biomass_compounds;
    } ModelBiomass;
	
	typedef string media_id;
	typedef string fba_id;
	typedef tuple<fba_id id,media_id media,float objective,list<feature_id> ko> FBAMeta;
	
	typedef string gapgen_id;
	typedef tuple<gapgen_id id,media_id media,list<feature_id> ko> GapGenMeta;
	
	typedef string gapfill_id;
	typedef tuple<gapfill_id id,media_id media,list<feature_id> ko> GapFillMeta;
	
	typedef string fbamodel_id;
	typedef string genome_id;
	typedef string biochemistry_id;
	typedef string mapping_id;
	typedef structure {
		fbamodel_id id;
		genome_id genome;
		mapping_id map;
		biochemistry_id biochemistry;
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
	/*END FBAMODEL SPEC*/
	
	/*GAPFILLING FORMULATION SPEC*/
	typedef string media_id;
	typedef string probabilistic_annotation_id;
	typedef structure {
		media_id media;
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
		probabilistic_annotation_id probabilistic_annotation;
	} GapfillingFormulation;
	
	typedef tuple<reaction_id reaction,string direction> reactionAddition;
	typedef structure {
		gapfill_id id;
		GapfillingFormulation formulation;
		list<modelcompound_id> biomassRemovals;
		list<compound_id> mediaAdditions;
		list<reactionAddition> reactionAdditions;
	} GapFill;
	/*END GAPFILLING FORMULATION SPEC*/
	
	/*GAPGEN FORMULATION SPEC*/
	typedef structure {
		media_id media;
		media_id refmedia;
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
	
	typedef tuple<modelreaction_id reaction,string direction> reactionRemoval;
	typedef structure {
		gapgen_id id;
		GapgenFormulation formulation;
		list<compound_id> biomassAdditions;
		list<compound_id> mediaRemovals;
		list<reactionRemoval> reactionRemovals;
	} GapGen;
	
	/*END GAPGEN FORMULATION SPEC*/
	
	/*FBA FORMULATION SPEC*/
	typedef string feature_id;
	typedef tuple<feature_id feature,float growthFraction,float growth,bool isEssential> GeneAssertion;
	
	typedef string modelcompound_id;
	typedef tuple<modelcompound_id compound,float value,float upperBound,float lowerBound,float max,float min,string type> CompoundFlux;
	
	typedef string modelreaction_id;
	typedef tuple<modelreaction_id reaction,float value,float upperBound,float lowerBound,float max,float min,string type> ReactionFlux;
	typedef tuple<float maximumProduction,modelcompound_id modelcompound> MetaboliteProduction;
	
    typedef string compound_id;
	typedef structure {
		list<compound_id> optionalNutrients;
		list<compound_id> essentialNutrients;
    } MinimalMediaPrediction;
	
	typedef string fba_id;
	typedef string media_id;
	typedef string fbamodel_id;
	typedef string regmodel_id;
	typedef string expression_id;
	
	typedef structure {
		media_id media;
		fbamodel_id model;
		regmodel_id regmodel;
		expression_id expressionData;
		string objective;
		float objective;
		string description;
		string type;
		string uptakelimits;
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
		list<feature_id> featureKO;
		list<modelreaction_id> reactionKO;
		list<string> constraints;
		list<string> bounds;
	} FBAFormulation;
	
	typedef structure {
		fba_id id;
		FBAFormulation formulation;
		list<MinimalMediaPrediction> minimalMediaPrediction;
		list<MetaboliteProduction> metaboliteProductions;
		list<ReactionFlux> reactionFluxes;
		list<CompoundFlux> compoundFluxes;
		list<GeneAssertion> geneAssertions;
	} FBA;
	/*END FBA FORMULATION SPEC*/
	
	/*This command accepts a KBase genome ID and returns the requested genome typed object*/
	typedef structure {
        bool as_new_genome;
    } Get_GenomeObject_Opts;
    funcdef get_genomeobject (genome_id id,Get_GenomeObject_Opts options) returns (GenomeObject genome);
	
	/*This function creates a new metabolic model given an input genome id*/
	funcdef genome_to_fbamodel (genome_id in_genome) returns (fbamodel_id out_model);
	
	/*This function converts a metabolic model into an SBML file.*/
	typedef string SBML;
	funcdef fbamodel_to_sbml(fbamodel_id in_model) returns (SBML sbml_string);
	/*This function converts an input object into HTML format.*/
	typedef string HTML;
	funcdef fbamodel_to_html(fbamodel_id in_model) returns (HTML html_string);
	
    /*This function runs flux balance analysis on the input FBAModel and produces HTML as output*/
    funcdef runfba (fbamodel_id in_model,FBAFormulation formulation) returns (fba_id out_fba);
    funcdef fba_check_results (fba_id in_fba) returns (bool is_done);
    funcdef fba_results_to_html (fba_id in_fba) returns (HTML html_string);

	/*These functions run gapfilling on the input FBAModel and produce gapfill objects as output*/
    funcdef gapfill_model (fbamodel_id in_model, GapfillingFormulation formulation) returns (gapfill_id out_gapfill);
    funcdef gapfill_check_results (gapfill_id in_gapfill) returns (bool is_done);
    funcdef gapfill_to_html (gapfill_id in_gapfill) returns (HTML html_string);
    funcdef gapfill_integrate (gapfill_id in_gapfill,fbamodel_id in_model) returns ();

	/*These functions run gapgeneration on the input FBAModel and produce gapgen objects as output*/
    funcdef gapgen_model (fbamodel_id in_model, GapgenFormulation formulation) returns (gapgen_id out_gapgen);
    funcdef gapgen_check_results (gapgen_id in_gapgen) returns (bool is_done);
    funcdef gapgen_to_html (gapgen_id in_gapgen) returns (HTML html_string);
    funcdef gapgen_integrate (gapgen_id in_gapgen,fbamodel_id in_model) returns ();
		
	/*This function returns model data for input ids*/
	funcdef get_models(list<fbamodel_id> in_model_ids) returns (list<FBAModel> out_models);
	/*This function returns fba data for input ids*/
	funcdef get_fbas(list<fba_id> in_fba_ids) returns (list<FBA> out_fbas);
	/*This function returns gapfill data for input ids*/
	funcdef get_gapfills(list<gapfill_id> in_gapfill_ids) returns (list<GapFill> out_gapfills);
	/*This function returns gapgen data for input ids*/
	funcdef get_gapgens(list<gapgen_id> in_gapgen_ids) returns (list<GapGen> out_gapgens);
	/*This function returns reaction data for input ids*/
	funcdef get_reactions(list<reaction_id> in_reaction_ids,biochemistry_id biochemistry) returns (list<Reaction> out_reactions);
	/*This function returns compound data for input ids*/
	funcdef get_compounds(list<compound_id> in_compound_ids,biochemistry_id biochemistry) returns (list<Compound> out_compounds);
	/*This function returns media data for input ids*/
	funcdef get_media(list<media_id> in_media_ids,biochemistry_id biochemistry) returns (list<Media> out_media);
	/*This function returns biochemistry object */
	funcdef get_biochemistry(biochemistry_id biochemistry) returns (Biochemistry out_biochemistry);
};
