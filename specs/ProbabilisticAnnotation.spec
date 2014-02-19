/*
The purpose of the Probabilistic Annotation service is to provide users with
alternative annotations for genes, each attached to a likelihood score, and to
translate these likelihood scores into likelihood scores for the existence of
reactions in metabolic models.  With the Probabilistic Annotation service:

- Users can quickly assess the quality of an annotation.

- Reaction likelihood computations allow users to estimate the quality of
  metabolic networks generated using the automated reconstruction tools in
  other services.

- Combining reaction likelihoods with gapfilling both directly incorporates
  available genetic evidence into the gapfilling process and provides putative
  gene annotations automatically, reducing the effort needed to search for
  evidence for gapfilled reactions.

*/

module ProbabilisticAnnotation {

	/* ************************************************************************************* */
	/* SIMPLE ID AND STRING TYPES */
	/* ************************************************************************************* */

    typedef int bool;

	/* A string identifier for a probabilistic annotation object. */
    typedef string probanno_id;
    
    /* A string identifier for a job object. */
    typedef string job_id;
    
    /* A string identifier for a template model object. */
    typedef string template_id;

	/* A string identifier for a reaction probabilities object. */
	typedef string rxnprobs_id;
	
	/* A string identifier for a genome. */    
    typedef string genome_id;
    
    /* A string identifier for a feature. */
    typedef string feature_id;
    
	/* A string identifier for a workspace. Any string consisting of alphanumeric characters and "-" is acceptable. */
	typedef string workspace_id;
	
	/* A string indicating the type of an object stored in a workspace. */
	typedef string object_type;
	
	/* A string identifier for a reaction object. */
	typedef string reaction_id;
	
	/* ID of an object stored in the workspace. */
	typedef string object_id;
	
	/* Login name of KBase user account to which permissions for workspaces are mapped */
	typedef string username;
	
	/* Exact time for workspace operations. e.g. 2012-12-17T23:24:06 */
	typedef string timestamp;
	
    /* A permanent reference to an object in a workspace. */
    typedef string workspace_ref;
    
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
		string chsum - checksum of the associated data object
		mapping<string,string> metadata - custom metadata entered for data object during save operation 
	
	*/
	typedef tuple<object_id id, object_type type, timestamp moddate, int instance, string command, username lastmodifier, username owner, workspace_id workspace, workspace_ref ref, string chsum, mapping<string,string> metadata> object_metadata;

	/* ************************************************************************************* */
	/* PROBABILISTIC ANNOTATION DATA TYPES */
	/* ************************************************************************************* */

    
    /*
       A function_probability is a (annotation, probability) pair associated with a gene
       An annotation is a "///"-delimited list of roles that could be associated with that gene.
    */
    typedef tuple<string annotation, float probability> function_probability;

    /* Object to carry alternative functions and probabilities for genes in a genome    

        probanno_id id - ID of the probabilistic annotation object    
        genome_id genome - ID of the genome the probabilistic annotation was built for
        workspace_id genome_workspace - ID of the workspace containing genome
        mapping<feature_id, list<function_probability>> roleset_probabilities - mapping of features to list of alternative function_probability objects
        list<feature_id> skipped_features - list of features in genome with no probability
    */
    typedef structure {
		probanno_id id;
		genome_id genome;
		workspace_id genome_workspace;
		mapping<feature_id, list<function_probability>> roleset_probabilities;
		list<feature_id> skipped_features;
    } ProbAnno;
    
    /* Data structure to hold probability of a reaction
    
    	reaction_id reaction - ID of the reaction
    	float probability - Probability of the reaction
    	string type - Type of complexes ("HASCOMPLEXES" or "NOCOMPLEXES")
    	string complex_info - Detailed information on complexes
    	string gene_list - List of genes most likely to be attached to reaction
    	
    */
    typedef tuple<reaction_id reaction, float probability, string type, string complex_info, string gene_list> reaction_probability;
    
    /* Object to hold reaction probabilities for a genome.
    
    	genome_id genome - ID of the genome the reaction probabilities was built for
    	list<reaction_probability> reaction_probabilities - list of reaction probabilities
    	
    */
    typedef structure {
        rxnprobs_id id;
        template_id template_model;
        workspace_id template_workspace;
    	genome_id genome;
        workspace_id genome_workspace;
        probanno_id probanno;
        workspace_id probanno_workspace;
    	list<reaction_probability> reaction_probabilities;
    } RxnProbs;
};
