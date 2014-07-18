/*
@author chenry
*/
module KBaseOntology {
    /*
		ID of map object
		@id kb
	*/
    typedef string map_id;
    /*
		ID of subsystem object
		@id external
	*/
    typedef string subsystem_id;
    /*
		ID of role object
		@id external
	*/
    typedef string role_id;
    /*
		ID of complex object
		@id external
	*/
    typedef string complex_id;
    /*
		Reference to a role
		@id subws KBaseOntology.Mapping.roles.[*].id
	*/
    typedef string role_ref;

    /* 
    	Role object containing data relating to functional role
    	    	
    	@optional name seedfeature
    	@searchable ws_subset id seedfeature name
    */
    typedef structure {
    	role_id id;
    	string name;
    	string seedfeature;
    } Role;
    
    /* 
    	Subsystem object with data on functionally related groups of roles
    	    	
    	@optional name
    	@searchable ws_subset id name class subclass type role_refs
    */
    typedef structure {
    	subsystem_id id;
    	string name;
    	string class;
    	string subclass;
    	string type;
    	list<role_ref> role_refs;
    } Subsystem;
    
    /* 
    	ComplexRole object containing data relating to role in complex
    	
    	@searchable ws_subset role_ref optionalRole type triggering
    */
    typedef structure {
    	role_ref role_ref;
    	int optionalRole;
    	string type;
    	int triggering;
    } ComplexRole;
    
    /* 
    	Complex object combines multiple subunit roles in a single biological function
    	    	
    	@optional name
    	@searchable ws_subset id name
    	@searchable ws_subset complexroles.[*].(role_ref,type,optionalRole,triggering)
    */
    typedef structure {
    	complex_id id;
    	string name;
    	list<ComplexRole> complexroles;
    } Complex;
    
    /* 
    	Mapping object holds data on subsystems and complexes
    	    	
    	@optional name
    	@searchable ws_subset id name role_aliases complex_aliases subsystem_aliases
    	@searchable ws_subset roles.[*].(id,name,seedfeature) 
    	@searchable ws_subset subsystems.[*].(id,name,class,subclass,type,role_refs) 
    	@searchable ws_subset complexes.[*].(id,name,complexroles.[*].(role_ref,type,optionalRole,triggering))
    */
    typedef structure {
    	map_id id;
    	string name;
    	
    	list<Role> roles;
    	list<Subsystem> subsystems;
    	list<Complex> complexes;
    	
    	mapping<role_id,mapping<string,list<string>>> role_aliases;
		mapping<complex_id,mapping<string,list<string>>> complex_aliases;
		mapping<subsystem_id,mapping<string,list<string>>> subsystem_aliases;
    } Mapping;
    
    /*
		A genome_id is a string (usually kb|g.NNNN, but can be free-form)
	*/
	typedef string genome_id;
	/*
		A code for evidence
	*/
	typedef string evidence_code;

	/*
		A gene_id is a string (usually kb.g.NNNN.CCC.NNNN, but can be free-form)
	*/
	typedef string gene_id;

	/*
		A ontology id is a string (usually GO:NNNN)
	*/
	typedef string ontology_acc;

	/*
	A gene list is a list of gene_ids
	*/
	typedef list<gene_id> gene_list;

	/*
		Structure for Ontology object

		@optional evidence_codes gene_list
	*/
	typedef structure {
		ontology_acc acc;
		string type;
		string name;
		list<evidence_code> evidence_codes;
		mapping<genome_id,gene_list> gene_list;
	} Ontology;

	/*
		Structure for OntologyTermAnnotation object
		@optional ontology_type ontology_description
	*/ 
	typedef structure {
		string ontology_type;
		string ontology_description;
                list<evidence_code> evidence_codes;
	} OntologyTermAnnotation;

	typedef mapping<ontology_acc, OntologyTermAnnotation> ontology_term_annotation_map;

	typedef	mapping<gene_id, ontology_term_annotation_map> gene_annotation_map;

	/*
		Structure for GeneOntologyAnnotations
		@optional source
	*/
	typedef structure {
		gene_annotation_map ga;
		string source;
	} GeneOntologyAnnotation;


	typedef structure{
		int rel_type_id;
		int id;
	} ParentTerm;

	/*
		Structure for OntologyTerm
		type is ontology type and it can be a domain_name for GO or it could be a relation type 
		name is short description of a term
		id is an internal unique id for efficient processing
		To compress more, it might be changed to list later
		@optional parent_list
	*/
	typedef structure{
		string type;
		string name;
		int    id;
		list<ParentTerm> parent_list;
	} OntologyTerm;

	typedef structure{
		mapping<ontology_acc, OntologyTerm> ontology_acc_term_map;
	} OntologyAccMap;

};