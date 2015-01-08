/* 
Service for Metabolomics data
@author seaver
*/
module KBaseMetabolome { 

    /* 
        KBase Compound ID for a compound
        id ws KB.Compound

        "ws" may change to "to" in the future 
    */
    typedef string compound_id;
    
    /* KBase list of Compound IDs */
    typedef list<compound_id> compound_ids;
    
    /* 
        KBase GenomeID 
        id ws KB.Genome

        "ws" may change to "to" in the future 
    */
    typedef string genome_id;

    /* 
        KBase BiochemistryID 
        id ws KB.Biochmistry

        "ws" may change to "to" in the future 
    */
    typedef string biochemistry_id;

    /* mapping kbase compound id as the key and measurement as the value */
    typedef mapping<compound_id compoundID, measurement measurement> data_metabolome_levels_for_sample; 

    /* Sample type controlled vocabulary : GC-MS, MS-MS, LP-MS etc.
    typedef string sample_type;

    /*
        Temporary workspace typed object for ontology.  Should be replaced by a ontology workspace typed object.
        Currently supports EO, PO and ENVO ontology terms.
    */
    typedef structure {
        string metabolome_ontology_term_id; 
        string metabolome_ontology_term_name; 
        string metabolome_ontology_term_definition;         
    } MetabolomeOntologyTerm;

    /* list of MetabolomesOntologies */ 
    typedef list<MetabolomeOntologyTerm> metabolome_ontology_terms; 

    /*
        Data structure for Strain
    */
    typedef structure {
        genome_id genome_id; 
        string reference_strain;
        string wild_type;
        string description;
        string name;
    } Strain; 

    /*
        Data structure for Protocol
    */
    typedef structure {
        string name; 
        string description;
    } Protocol; 

    /*
       id for the metabolome sample

       @id ws KBaseMetabolome.MetabolomeSample

       "ws" may go to "to" in the future
    */
    typedef string metabolome_sample_id;

    /* list of metabolome sample ids */ 
    typedef list<metabolome_sample_id> metabolome_sample_ids;

    /* list of metabolome series ids that the sample belongs to : note this can not be a ws_reference because ws does not support bidirectional references */
    typedef list<string> metabolome_series_ids;

    /* map between biochemistry ids and a list of samples from that biochemistry in this sample */
    typedef mapping<biochemistry_id biochemistry_id, metabolome_sample_ids> biochemistry_metabolome_sample_ids_map; 

    /* list of Persons */ 
    typedef list<Person> persons;

    /* 
       Data structure for the workspace metabolome sample.  The Metabolome Sample typed object.

       @optional description title data_quality_level original_median default_control_sample characteristics
       @optional averaged_from_samples protocol strain persons data_source shock_url processing_comments metabolome_series_ids 
       
       @searchable ws_subset id source_id type data_quality_level biochemistry_id description title data_source characteristics
       @searchable ws_subset persons.[*].email persons.[*].last_name persons.[*].institution  
       @searchable ws_subset strain.genome_id strain.reference_strain strain.wild_type          
       @searchable ws_subset protocol.name protocol.description 
       @searchable ws_subset metabolome_ontology_terms.[*].metabolome_ontology_term_id metabolome_ontology_terms.[*].metabolome_ontology_term_name
    */
    typedef structure {
        string id;
        string source_id;
        sample_type type;
        string numerical_interpretation;
        string description;
        string title;
        int data_quality_level;
        float original_median;
	string external_source_date;
        data_metabolome_levels_for_sample metabolome_levels; 
	biochemistry_id biochemistry_id; 
        metabolome_ontology_terms metabolome_ontology_terms;
        metabolome_sample_id default_control_sample; 
        metabolome_sample_ids averaged_from_samples; 
        Protocol protocol; 
        Strain strain; 
        persons persons;
        string data_source; 
        string shock_url;
        string processing_comments;
        metabolome_series_ids metabolome_series_ids;
        string characteristics;
    } MetabolomeSample;

    /*
        Data structure for the workspace metabolome series.  The MetabolomeSeries typed object.
        publication should need to eventually have ws objects, will not include it for now.

        @optional title summary design publication_id 

        @searchable ws_subset id source_id publication_id title summary design biochemistry_metabolome_sample_ids_map
    */
    typedef structure { 
        string id; 
        string source_id;
        biochemistry_metabolome_sample_ids_map biochemistry_metabolome_sample_ids_map;
        string title; 
        string summary;
        string design; 
        string publication_id; 
	string external_source_date;
    } MetabolomeSeries; 

    /*
        Simple Grouping of Samples that belong to the same replicate group.  MetabolomeReplicateGroup typed object.
        @searchable ws_subset id metabolome_sample_ids
    */
    typedef structure {
        string id;
        metabolome_sample_ids metabolome_sample_ids;
    } MetabolomeReplicateGroup;
}; 
