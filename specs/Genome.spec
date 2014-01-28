/*
@author chenry,kkeller
*/
module KBaseGenomes {
    /*
    	Reference to a ContigSet object containing the contigs for this genome in the workspace
		@id ws KBaseGenomes.ContigSet
	*/
    typedef string ContigSet_ref;
    /*
		Reference to a ProteinSet object containing the proteins for this genome in the workspace
		@id ws KBaseGenomes.ProteinSet
	*/
    typedef string ProteinSet_ref;
    /*
		Reference to a TranscriptSet object containing the transcripts for this genome in the workspace
		@id ws KBaseGenomes.TranscriptSet
	*/
    typedef string TranscriptSet_ref;
    /*
		Reference to a Feature object of a genome in the workspace
		@id subws KBaseGenomes.Genome.features.[*].id
	*/
    typedef string Feature_ref;
    /*
		Reference to a Genome object in the workspace
		@id ws KBaseGenomes.Genome
	*/
    typedef string genome_ref;
    /*
		Reference to a source_id
		@id external
	*/
    typedef string source_id;
    /*
		KBase genome ID
		@id kb
	*/
    typedef string Genome_id;
    /*
		KBase ProteinSet ID
		@id kb
	*/
    typedef string ProteinSet_id;
	/*
		ProbabilisticAnnotation ID
		@id kb
	*/
	typedef string ProbabilisticAnnotation_id;
	/*
		Genome protein ID
		@id external
	*/
    typedef string Protein_id;
	/*
		Genome feature ID
		@id external
	*/
    typedef string Feature_id;
    /*
		Reference to an individual contig in a ContigSet object
		@id subws KBase.ContigSet.contigs.[*].id
	*/
    typedef string Contig_ref;
    /*
		ContigSet contig ID
		@id external
	*/
    typedef string Contig_id;
    /*
		KBase contig set ID
		@id kb
	*/
    typedef string ContigSet_id;
    /*
		Reference to a source_id
		@id external
	*/
    typedef string source_id;
    /*
		Reference to a reads file in shock
		@id shock
	*/
    typedef string Reads_ref;
    /*
		Reference to a fasta file in shock
		@id shock
	*/
    typedef string Fasta_ref;
    
    /* Type spec for a "Contig" subobject in the "ContigSet" object

		Contig_id id - ID of contig in contigset
		string md5 - unique hash of contig sequence
		string sequence - sequence of the contig
		string description - Description of the contig (e.g. everything after the ID in a FASTA file)

		@optional length name description
		@searchable ws_subset id md5
	*/
	typedef structure {
		Contig_id id;
		int length;
		string md5;
		string sequence;
		string name;
		string description;
    } Contig;

    /* Type spec for the "ContigSet" object

		contigset_id id - unique kbase ID of the contig set
		string name - name of the contig set
		string type - type of the contig set (values are: Genome,Transcripts,Environment,Collection)
		source_id source_id - source ID of the contig set
		string source - source of the contig set
		list<Contig> contigs - list of contigs in the contig set
		reads_ref reads_ref - reference to the shocknode with the rawreads from which contigs were assembled
		fasta_ref fasta_ref - reference to fasta file from which contig set were read

		@optional name type reads_ref fasta_ref
    	@searchable ws_subset contigs.[*].(id,md5) md5 id name source_id source type
	*/
	typedef structure {
		ContigSet_id id;
		string name;
		string md5;
		source_id source_id;
		string source;
		string type;
		Reads_ref reads_ref;
		Fasta_ref fasta_ref;
		list<Contig> contigs;
    } ContigSet;
   
    /*
		Type of a genome feature with possible values peg, rna
	*/
    typedef string feature_type;
    /* A region of DNA is maintained as a tuple of four components:

		the contig
		the beginning position (from 1)
		the strand
		the length

	   We often speak of "a region".  By "location", we mean a sequence
	   of regions from the same genome (perhaps from distinct contigs).
        */
    typedef tuple<Contig_id contig_id,int begin, string strand,int length> region_of_dna;
    /*
		a "location" refers to a list of regions of DNA on contigs
    */
    typedef list<region_of_dna> location;
    
    /*
	Structure for a publication (from ER API)
	also want to capture authors, journal name (not in ER)
    */
    typedef tuple<int id, string source_db, string article_title, string link, string pubdate, string authors, string journal_name> publication;

    /*
	Structure for subsystem data (from CDMI API)

    */
    typedef tuple<string subsystem, string variant, string role> subsystem_data;

    /*
	Structure for regulon data (from CDMI API)

    */
    typedef tuple<string regulon_id, list<Feature_id> regulon_set, list<Feature_id> tfs> regulon_data;

    /*
	Structure for an atomic regulon (from CDMI API)

    */
    typedef tuple<string atomic_regulon_id, int atomic_regulon_size> atomic_regulon;

    /*
	Structure for co-occurring fids (from CDMI API)

    */
    typedef tuple<Feature_id scored_fid, float score> co_occurring_fid;

    /*
	Structure for coexpressed fids (from CDMI API)

    */
    typedef tuple<Feature_id scored_fid, float score> coexpressed_fid;
    
   	/*
	Structure for a protein family
		@optional query_begin query_end subject_begin subject_end score evalue subject_description release_version
    */
    typedef structure {
		string id;
		string subject_db;
		string release_version;
		string subject_description;
		int query_begin;
		int query_end;
		int subject_begin;
		int subject_end;
		float score;
		float evalue;
    } ProteinFamily;

	/*
		a notation by a curator of the genome object
    */
    typedef tuple<string comment, string annotator, int annotation_time> annotation;
	
	/*
    	Structure for a single feature of a Feature
	Should genome_id contain the genome_id in the Genome object,
	the workspace id of the Genome object, a genomeref,
	something else?
	Should sequence be in separate objects too?
	We may want to add additional fields for other CDM functions
	(e.g., atomic regulons, coexpressed fids, co_occurring fids,...)

		@optional md5 location function protein_translation protein_families subsystems publications subsystems subsystem_data aliases annotations regulon_data atomic_regulons coexpressed_fids co_occurring_fids dna_sequence protein_translation_length dna_sequence_length
		@searchable ws_subset id type function aliases md5
    */
    typedef structure {
		Feature_id id;
		list<tuple<Contig_id,int,string,int>> location;
		string type;
		string function;
		string md5;
		string protein_translation;
		string dna_sequence;
		int protein_translation_length;
		int dna_sequence_length;
		list<publication> publications;
		list<string> subsystems;
		list<ProteinFamily> protein_families;
		list<string> aliases;
		list<annotation> annotations;
		list<subsystem_data> subsystem_data;
		list<regulon_data> regulon_data;
		list<atomic_regulon> atomic_regulons;
		list<coexpressed_fid> coexpressed_fids;
		list<co_occurring_fid> co_occurring_fids;
    } Feature;

    /*
    	Genome object holds much of the data relevant for a genome in KBase
	Genome publications should be papers about the genome, not
	papers about certain features of the genome (which go into the
	Feature object)
	Should the Genome object have a list of feature ids? (in
	addition to having a list of feature_refs)
	Should the Genome object contain a list of contig_ids too?

    	@optional contig_ids publications md5 taxonomy gc_content complete dna_size num_contigs contig_lengths contigset_ref proteinset_ref transcriptset_ref
    	@searchable ws_subset features.[*].(md5,id,type,function,aliases) taxonomy num_contigs source_id source genetic_code id scientific_name domain contigset_ref proteinset_ref transcriptset_ref
    */
    typedef structure {
		Genome_id id;
		string scientific_name;
		string domain;
		int genetic_code;
		int dna_size;
		int num_contigs;
		list<int> contig_lengths;
		list<Contig_id> contig_ids;
		string source;
		source_id source_id;
		string md5;
		string taxonomy;
		float gc_content;
		int complete;
		list<publication> publications;
		list<Feature> features;
		ContigSet_ref contigset_ref;
		ProteinSet_ref proteinset_ref;
		TranscriptSet_ref transcriptset_ref;
    } Genome;
    
	/* Type spec for the "Protein" object
	
		Protein_id id - unique external ID of protein
		string function - annotated function for protein
		string md5 - md5 hash of protein sequence
		string sequence - amino acid sequence of protein
		int length - length of protein
		list<ProteinFamily> protein_families - families to which the protein belongs
		list<string> aliases - aliases for the protein
		list<annotation> annotations - curator annotations on protein
		list<subsystem_data> subsystem_data;
		
		@optional function
    	@searchable ws_subset id md5 function length aliases
	*/
	typedef structure {
		Protein_id id;
		string function;
		string md5;
		string sequence;
		int length;
		list<ProteinFamily> protein_families;
		list<string> aliases;
		list<annotation> annotations;
    } Protein;
   
   /* Type spec for the "ProteinSet" object

		proteinset_id id - unique kbase ID of the protein set
		string name - name of the protein set
		string type - type of the protein set (values are: Organism,Environment,Collection)
		source_id source_id - source ID of the protein set
		string source - source of the protein set
		list<Protein> proteins - list of proteins in the protein set
		fasta_ref fasta_ref - reference to fasta file from which contig set were read

		@optional name type fasta_ref
    	@searchable ws_subset proteins.[*].(id,md5,function,length,aliases) md5 id name source_id source type
	*/
	typedef structure {
		ProteinSet_id id;
		string name;
		string md5;
		source_id source_id;
		string source;
		string type;
		Fasta_ref fasta_ref;
		list<Protein> proteins;
    } ProteinSet;
    
    /*
       A function_probability is a (annotation, probability) pair associated with a gene
       An annotation is a "///"-delimited list of roles that could be associated with that gene.
    */
    typedef tuple<string annotation, float probability> function_probability;

    /* Object to carry alternative functions and probabilities for genes in a genome    

        probanno_id id - ID of the probabilistic annotation object    
        genome_ref genome_ref - reference to genome probabilistic annotation was built for
        mapping<feature_id, list<function_probability>> roleset_probabilities - mapping of features to list of alternative function_probability objects
        list<feature_id> skipped_features - list of features in genome with no probability
        
    	@searchable ws_subset id genome_ref skipped_features
        
    */
    typedef structure {
		ProbabilisticAnnotation_id id;
		genome_ref genome_ref;
		mapping<Feature_id,list<function_probability>> roleset_probabilities;
		list<Feature_id> skipped_features;
    } ProbabilisticAnnotation;
    
    /* Structure for the "MetagenomeAnnotationOTUFunction" object
		
		list<string> reference_genes - list of genes associated with hit
		string functional_role - annotated function
		string kbid - kbase ID of OTU function in metagenome
		int abundance - number of hits with associated role and OTU
		float confidence - confidence of functional role hit
		string confidence_type - type of functional role hit
		
    	@searchable ws_subset id abundance confidence functional_role
	*/
    typedef structure {
		string id;
		list<string> reference_genes;
		string functional_role;
		int abundance;
		float confidence;
    } MetagenomeAnnotationOTUFunction;
     
    /* Structure for the "MetagenomeAnnotationOTU" object
	
		string name - name of metagenome OTU
		string kbid - KBase ID of OTU of metagenome object
		string source_id - ID used for OTU in metagenome source
		string source - source OTU ID
		list<MetagenomeAnnotationOTUFunction> functions - list of functions in OTU
		
    	@searchable ws_subset id name source_id source functions.[*].(id,abundance,confidence,functional_role) 

	*/
    typedef structure {
    	float ave_confidence;
		float ave_coverage;
		string id;
		string name;
		string source_id;
		string source;
		list<MetagenomeAnnotationOTUFunction> functions;
    } MetagenomeAnnotationOTU;
    
    /* Structure for the "MetagenomeAnnotation" object
	
		string type - type of metagenome object
		string name - name of metagenome object
		string kbid - KBase ID of metagenome object
		string source_id - ID used in metagenome source
		string source - source of metagenome data
		string confidence_type - type of confidence score
		list<MetagenomeAnnotationOTU> otus - list of otus in metagenome
		
    	@searchable ws_subset type name id source_id source confidence_type otus.[*].(id,name,source_id,source,functions.[*].(id,abundance,confidence,functional_role))
	*/
    typedef structure {
		string type;
		string name;
		string id;
		string source_id;
		string source;
		string confidence_type;
		list<MetagenomeAnnotationOTU> otus;
    } MetagenomeAnnotation;
};