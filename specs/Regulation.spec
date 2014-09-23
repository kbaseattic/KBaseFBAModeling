/* 
	Module Regulation version 2.0
	
	This module describes data types to represent transcriptional regulons, in particular regulons reconstructed by comparative genomics 
	from the RegPrecise database (http://regprecise.lbl.gov). 
	
*/
module KBaseRegulation {

	/*
	The source of regulome model. The value can be one of the following:
		
		REGPRECISE_CURATED - indicates that regulome is based on the curated regulons from RegPrecise database
		REGPRECISE_PROPAGATED - indicates that regulom model was automatically built by conservation propagation of RegPrecise reference regulons 			
	*/
  	typedef string regulome_source;
  	
	/*
	Type of regulation. The value can be one of the following: 
		
		TF - for regulation by transcription factor
		RNA - for regulation by RNA regulatory element (e.g. riboswitch) 
	*/		
	typedef string regulation_type;

	/*
	The regualtory mechanism. The value of regulatory_mechanism can be: 
		
		activation - activates the transcription
		repression - represses the transcription 
	*/
	typedef string regulatory_mechanism;

	/* Represents regulatory site identifier*/
	typedef string regulatory_site_id;

	/* Represents gene identifier*/
	typedef string gene_id; 

	/* Represents transcription factor identifier*/
	typedef string transcription_factor_id;
	 
	/* Represents operon identifier*/
	typedef string operon_id;
	
	/* Represents regulator identifier*/
	typedef string regulator_id;
	
	/* Represents regulon identifier*/
	typedef string regulon_id;
	
	/* Represents regulome identifier*/
	typedef string regulome_id;
	
	/* Represents regulog identifier*/
	typedef string regulog_id;
	
	/* Represents regulog collection identifier*/
	typedef string regulog_collection_id;
	
	/* Represents effector identifier*/
	typedef string effector_id;
	
	/* Represents genome identifier*/
	typedef string genome_id;
	
	/* Represents WS reference to a genome object
		@id ws KBaseGenomes.Genome
	*/
	typedef string genome_ref;
	
	/* Represents WS reference to a genome object
		id ws Regulation.Regulon
	*/	
	typedef string regulon_ref;


	/*Type of evidence. This is going to be a controlled vocabulary descibing experimental techniques 
	   and computational methods to infer regulatory interactions.
	*/		
	typedef string evidence_type;

	/* Represents an evidence of the regulatory interaction. 
		evidence_type evidence_type - type of the evidence
		string pubmed_id - pubmed id of the paper descirbing the regulatory interaction

		@optional pubmed_id
	*/
	typedef structure {
		evidence_type evidence_type;
		string pubmed_id;
	} Evidence;


	/* Represents an effector (inducer) that can activate or deactivate regulator
		effector_id effector_id - identifier of effector
		string effector_class - effector class
		string effector_name - effector name
	*/			
	typedef structure{
		effector_id effector_id;
		string effector_class;
		string effector_name;		
	} Effector;

	/* Represents collection of effectors (curated vocabulary)
		string name - collection name
		string description - collection description
		list<Effector> effectors - list of effectors
	*/				
	typedef structure{
		string name;
		string description;
		list<Effector> effectors;
	} EffectorCollection;

	/* Represents a genome
		genome_id genome_id - genome identifier
		genome_ref genome_ref - workspace reference of a genome object 		
		string genome_name - genome name
		int ncbi_taxonomy_id - NCBI taxonomy id
		
		@optional genome_id genome_ref ncbi_taxonomy_id		
	*/				
	typedef structure {
		genome_id genome_id;
		genome_ref genome_ref;
		
		string genome_name;
		int ncbi_taxonomy_id;		
	} RGenome;	


	/* Represents a regulatory site. For instance it can be transcription factor binding site, or RNA regulatory element
		regulatory_site_id regulatory_site_id - site identifier  
		string sequence - DNA sequence of regulatory site
		int position - position of site relative to the regulated gene
		float score - strength of the site (similarity to TFBS motif, or RNA profile)	
		list<Evidence> evidesnces - evidences of the regualtory site
		
		@optional position score evidesnces regulatory_mechanism
	*/
	typedef structure {
		regulatory_site_id regulatory_site_id;
		string sequence;
		int position;
		float score;	
		regulatory_mechanism regulatory_mechanism;
		list<Evidence> evidesnces;
	} RegulatorySite;

	/* Represents a regulated gene
		gene_id gene_id - gene identifier 
		string locus_tag - locus tag of a gene
		string name - gene name
		
		@optional locus_tag name
	*/
	typedef structure {
		gene_id gene_id;
		string locus_tag;
		string name;	
	} Gene;

	
	/* Represents a transcription factor controlling genes
		transcription_factor_id transcription_factor_id - transcription factor identifier
		string locus_tag - locus tag of a transcription factor
		string name - transcription factor name
		
		@optional locus_tag name
	*/	
	typedef structure {
		transcription_factor_id transcription_factor_id;
		string locus_tag;
		string name;
	} TranscriptionFactor;
		
	/* Represents a regulated operon
		operon_id operon_id - identifier of operons
		list<Gene> genes  - list of regulated genes
		list<RegulatorySite> sites - list of regulatory sites
	*/		
	typedef structure {
		operon_id operon_id;
		list<Gene> genes;
		list<RegulatorySite> sites;	
	} RegulatedOperon;
	
	/* Represents orthologous group of regulators. Can be either transcription factor or RNA regulatory element.
		regulator_id regulator_id - identifier of regulator
		regulation_type regulation_type - type of regulation
		string regulator_name - name of regulator
		string taxonomy - the same regulator name happens to be used by scientific community to reference non-orthologous regulators in different taxonomic groups.
						  Thus taxonomy is required to uniquely identify orthologous regulators.
						   
		string tf_family - the name of TF family
		string rfam_id - identifier of RNA regulatory element in RFAM database.
		
		@optional taxonomy tf_family rfam_id
	*/		
	typedef structure{
		regulator_id regulator_id;
		regulation_type regulation_type;
		string regulator_name;
		string taxonomy;	
		string tf_family;
		string rfam_id;
	} Regulator;
	
	
	/* Represents regulon
		regulon_id regulon_id - identifier of regulon
		Regulator regulator - provides general information about orthologous group of transcription factor or RNA regualtory element controlling genes of this regulon 
		list<Effector> effectors - list of effectors		
		list<TranscriptionFactor> tfs - transcription factors controlling genes of this regulon
		list<RegulatedOperon> operons - list of regulated operons
		list<Evidence> evidesnces - list of evidences for the regulon

		
		@optional tfs regulator effectors evidesnces
	*/	
	typedef structure {
		regulon_id regulon_id;
		Regulator regulator;
		list<Effector> effectors;
		list<TranscriptionFactor> tfs;
		list<RegulatedOperon> operons;
		list<Evidence> evidesnces;
	} Regulon;


	/* Represents regulome - collection of regulons for a given genome
		regulome_id regulome_id - identifier of a regulome
		regulome_source regulome_source - source of a regulome
		string regulome_name -  name of a regulome
		Genome genome - source genome		
		list<Regulon> regulons - list of regulons comprising this regulome
		list<Evidence> evidesnces - list of evidences for the regulome

		@optional evidesnces
	*/	
	typedef structure {
		regulome_id regulome_id;
		regulome_source regulome_source;
		string regulome_name;
		RGenome genome;
		
		list<Regulon> regulons;	
		list<Evidence> evidesnces;
	} Regulome;


	/* Represents regulog - collection of regulons controlled by orthologous regulators, typically in a tight taxonomic group
		regulog_id regulog_id - identifier of a regulog
		Regulator regulator - provides general information about orthologous group of transcription factor or RNA regualtory element controlling genes of regulons comprising this regulog
		list<regulon_ref> regulon_refs - workspace references to regulons
	*/		
	typedef structure {
		regulog_id regulog_id;
		Regulator regulator;
		list<regulon_ref> regulon_refs;		
	} Regulog;
	
	
	/* Represents collection of regulogs
		regulog_collection_id regulog_collection_id - identifier of a regulog collection
		string name - collection name
		string description - collection description
		list<Regulog> regulogs - list of regulogs comprising this collection
		list<Genome> genomes - list genomes represented by this collection			
	*/			
	typedef structure {
		regulog_collection_id regulog_collection_id;
		string name;
		string description;
		list<Regulog> regulogs;
		list<RGenome> genomes;	
	} RegulogCollection;
		
		
};