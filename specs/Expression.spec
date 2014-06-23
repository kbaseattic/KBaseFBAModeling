/* Service for all different sorts of Expression data (microarray, RNA_seq, proteomics, qPCR */
module KBaseExpression { 

    /* 
        KBase Feature ID for a feature, typically CDS/PEG
        id ws KB.Feature 

        "ws" may change to "to" in the future 
    */
    typedef string feature_id;
    
    /* KBase list of Feature IDs , typically CDS/PEG */
    typedef list<feature_id> feature_ids;
    
    /* Measurement Value (Zero median normalized within a sample) for a given feature */
    typedef float measurement;
    
    /* KBase Sample ID for the sample */
    typedef string sample_id;
    
    /* List of KBase Sample IDs */
    typedef list<sample_id> sample_ids;

    /* List of KBase Sample IDs that this sample was averaged from */
    typedef list<sample_id> sample_ids_averaged_from;
    
    /* Sample type controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics */
    typedef string sample_type;
    
    /* Kbase Series ID */ 
    typedef string series_id; 
    
    /* list of KBase Series IDs */
    typedef list<series_id> series_ids;
    
    /* Kbase ExperimentMeta ID */ 
    typedef string experiment_meta_id; 
    
    /* list of KBase ExperimentMeta IDs */
    typedef list<experiment_meta_id> experiment_meta_ids;
    
    /* Kbase ExperimentalUnit ID */ 
    typedef string experimental_unit_id; 
    
    /* list of KBase ExperimentalUnit IDs */
    typedef list<experimental_unit_id> experimental_unit_ids;
    
    /* Mapping between sample id and corresponding value.   Used as return for get_expression_samples_(titles,descriptions,molecules,types,external_source_ids)*/
    typedef mapping<sample_id sampleID, string value> samples_string_map;

    /* Mapping between sample id and corresponding value.   Used as return for get_expression_samples_original_log2_median*/ 
    typedef mapping<sample_id sampleID, float originalLog2Median> samples_float_map;

    /* Mapping between sample id and corresponding value.   Used as return for get_series_(titles,summaries,designs,external_source_ids)*/ 
    typedef mapping<series_id seriesID, string value> series_string_map; 

    /* mapping kbase feature id as the key and measurement as the value */
    typedef mapping<feature_id featureID, measurement measurement> data_expression_levels_for_sample; 

    /*Mapping from Label (often a sample id, but free text to identify} to DataExpressionLevelsForSample */
    typedef mapping<string label, data_expression_levels_for_sample dataExpressionLevelsForSample> label_data_mapping;

    /* denominator label is the label for the denominator in a comparison.  
    This label can be a single sampleId (default or defined) or a comma separated list of sampleIds that were averaged.*/
    typedef string comparison_denominator_label;

    /* Log2Ratio Log2Level of sample over log2Level of another sample for a given feature.  
    Note if the Ratio is consumed by On Off Call function it will have 1(on), 0(unknown), -1(off) for its values */ 
    typedef float log2_ratio; 

    /* mapping kbase feature id as the key and log2Ratio as the value */ 
    typedef mapping<feature_id featureID, log2_ratio log2Ratio> data_sample_comparison; 

    /* mapping ComparisonDenominatorLabel to DataSampleComparison mapping */
    typedef mapping<comparison_denominator_label comparisonDenominatorLabel, data_sample_comparison dataSampleComparison> denominator_sample_comparison;

    /* mapping Sample Id for the numerator to a DenominatorSampleComparison.  This is the comparison data structure {NumeratorSampleId->{denominatorLabel -> {feature -> log2ratio}}} */
    typedef mapping<sample_id sampleID, denominator_sample_comparison denominatorSampleComparison> sample_comparison_mapping;

    /* Kbase SampleAnnotation ID */ 
    typedef string sample_annotation_id; 
 
    /* Kbase OntologyID  */ 
    typedef string ontology_id; 
    
    /* list of Kbase Ontology IDs */
    typedef list<ontology_id> ontology_ids;

    /* Kbase OntologyName */
    typedef string ontology_name;

    /* Kbase OntologyDefinition */
    typedef string ontology_definition;

    /* Data structure for top level information for sample annotation and ontology */
    typedef structure {
	sample_annotation_id sample_annotation_id;
	ontology_id ontology_id;
	ontology_name ontology_name;
	ontology_definition ontology_definition;
    } SampleAnnotation;
    
    /* list of Sample Annotations associated with the Sample */
    typedef list<SampleAnnotation> sample_annotations;

    /* externalSourceId (could be for Platform, Sample or Series)(typically maps to a GPL, GSM or GSE from GEO) */
    typedef string external_source_id;

    /* list of externalSourceIDs */
    typedef list<external_source_id> external_source_ids;

    /*
        Data structure for Person  (TEMPORARY WORKSPACE TYPED OBJECT SHOULD BE HANDLED IN THE FUTURE IN WORKSPACE COMMON)

##        @searchable ws_subset email last_name institution
    */
    typedef structure {
        string email; 
        string first_name;
        string last_name;
        string institution;
    } Person; 

    /* 
       Kbase Person ID 
    */ 
    typedef string person_id; 
    
    /* list of KBase PersonsIDs */
    typedef list<person_id> person_ids;
    
    /* KBase StrainID */
    typedef string strain_id;
    
    /* list of KBase StrainIDs */
    typedef list<strain_id> strain_ids;
    
    /* 
        KBase GenomeID 
        id ws KB.Genome

        "ws" may change to "to" in the future 
    */
    typedef string genome_id;
    
    /* list of KBase GenomeIDs */
    typedef list<genome_id> genome_ids;
    
    /* Single integer 1= WildTypeonly, 0 means all strains ok */
    typedef int wild_type_only;
    
    /* Data structure for all the top level metadata and value data for an expression sample.  Essentially a expression Sample object.*/
    typedef structure {
	sample_id sample_id;
	string source_id;
	string sample_title;
	string sample_description;
	string molecule;
	sample_type sample_type;
	string data_source;
	string external_source_id;
	string external_source_date;
	string kbase_submission_date;
	string custom;
	float original_log2_median;
	strain_id strain_id;
	string reference_strain;
	string wildtype;
	string strain_description;
	genome_id genome_id;
	string genome_scientific_name;
	string platform_id;
	string platform_title;
	string platform_technology;
	experimental_unit_id experimental_unit_id;
	experiment_meta_id experiment_meta_id;
	string experiment_title;
	string experiment_description;
	string environment_id;
	string environment_description;
	string protocol_id;
	string protocol_description;
	string protocol_name;
	sample_annotations sample_annotations;
	series_ids series_ids;
	person_ids person_ids;
	sample_ids_averaged_from sample_ids_averaged_from;
	data_expression_levels_for_sample data_expression_levels_for_sample;
	} ExpressionDataSample;
    
    /* Mapping between sampleID and ExpressionDataSample */
    typedef mapping<sample_id sampleID, ExpressionDataSample> expression_data_samples_map;

    /*mapping between seriesIDs and all Samples it contains*/
    typedef mapping<series_id seriesID, expression_data_samples_map> series_expression_data_samples_mapping;
    
    /*mapping between experimentalUnitIDs and all Samples it contains*/
    typedef mapping<experimental_unit_id experimentalUnitID, expression_data_samples_map> experimental_unit_expression_data_samples_mapping;

    /*mapping between experimentMetaIDs and ExperimentalUnitExpressionDataSamplesMapping it contains*/
    typedef mapping<experiment_meta_id experimentMetaID, experimental_unit_expression_data_samples_mapping> experiment_meta_expression_data_samples_mapping;
    
    /*mapping between strainIDs and all Samples it contains*/
    typedef mapping<strain_id strainID, expression_data_samples_map> strain_expression_data_samples_mapping;

    /*mapping between genomeIDs and all StrainExpressionDataSamplesMapping it contains*/
    typedef mapping<genome_id genomeID, strain_expression_data_samples_mapping> genome_expression_data_samples_mapping;

    /*mapping between ontologyIDs (concatenated if searched for with the and operator) and all the Samples that match that term(s)*/
    typedef mapping<ontology_id ontology_id, expression_data_samples_map> ontology_expression_data_sample_mapping;

    /* mapping kbase sample id as the key and a single measurement (for a specified feature id, one mapping higher) as the value */
    typedef mapping<sample_id sampleID, measurement measurement> sample_measurement_mapping; 
    
    /*mapping between FeatureIds and the mappings between samples and log2level mapping*/
    typedef mapping<feature_id featureID, sample_measurement_mapping sample_measurement_mapping> feature_sample_measurement_mapping;

    /*DATA STRUCTURES FOR GEO PARSING*/

    /*Data structure for a GEO Platform */
    typedef structure { 
        string gpl_id;
	string gpl_title;
        string gpl_technology; 
	string gpl_tax_id;
	string gpl_organism;
    } GPL; 
     
    /*Email for the GSM contact person*/
    typedef string contact_email;
 
    /*First Name of GSM contact person*/
    typedef string contact_first_name;

    /*Last Name of GSM contact person*/
    typedef string contact_last_name;

    /*Institution of GSM contact person*/
    typedef string contact_institution;

    /*Data structure for GSM ContactPerson*/
    typedef structure {
	contact_first_name contact_first_name;
	contact_last_name contact_last_name;
	contact_institution contact_institution;
    } ContactPerson;

    /*Mapping between key : ContactEmail and value : ContactPerson Data Structure*/
    typedef mapping<contact_email contact_email, ContactPerson contact_person> contact_people;

    /*Measurement data structure */
    typedef structure { 
        float value;
        float n;
        float stddev;
	float z_score;
	float p_value;
	float median;
	float mean;
    } FullMeasurement;
    
    /* mapping kbase feature id as the key and FullMeasurement Structure as the value */ 
    typedef mapping<feature_id feature_id, FullMeasurement full_measurement> gsm_data_set; 
    
    /* List of GSM Data level warnings */ 
    typedef list<string> gsm_data_warnings; 

    /* List of GSM level warnings */ 
    typedef list<string> gsm_warnings;

    /* List of GSE level warnings */
    typedef list<string> gse_warnings;

    /* List of GSM Data level errors */
    typedef list<string> gsm_data_errors;

    /* List of GSM level errors */
    typedef list<string> gsm_errors;

    /* List of GSE level errors */
    typedef list<string> gse_errors;

    /* List of GSM Sample Characteristics from ch1 */
    typedef list<string> gsm_sample_characteristics;

    /* Data structure that has the GSM data, warnings, errors and originalLog2Median for that GSM and Genome ID combination */    
    typedef structure {
        gsm_data_warnings warnings;
        gsm_data_errors errors;
        gsm_data_set features;
	float originalLog2Median;
    } GenomeDataGSM;

    /* mapping kbase feature id as the key and FullMeasurement Structure as the value */ 
    typedef mapping<genome_id genome_id, GenomeDataGSM genome_data_gsm> gsm_data; 

    /* GSM OBJECT */
    typedef structure {
	string gsm_id;
	string gsm_title;
	string gsm_description;
	string gsm_molecule;
	string gsm_submission_date;
	string gsm_tax_id;
	string gsm_sample_organism;
        gsm_sample_characteristics gsm_sample_characteristics;
	string gsm_protocol;
	string gsm_value_type;
	GPL gsm_platform;
	contact_people gsm_contact_people;
	gsm_data gsm_data;
	string gsm_feature_mapping_approach;
        ontology_ids ontology_ids;
	gsm_warnings gsm_warning;
	gsm_errors gsm_errors;
    } GsmObject;

    /* Mapping of Key GSMID to GSM Object */
    typedef mapping<string gsm_key_id, GsmObject gsmObject> gse_samples;

    /* GSE OBJECT */
    typedef structure {
	string gse_id;
	string gse_title;
	string gse_summary;
	string gse_design;
	string gse_submission_date;
	string pub_med_id;
	gse_samples gse_samples;
	gse_warnings gse_warnings;
	gse_errors gse_errors;
    } GseObject;

    /* Single integer 1= metaDataOnly, 0 means returns data */
    typedef int meta_data_only; 


    /*FUNCTIONS*/
    
    /* core function used by many others.  Given a list of KBase SampleIds returns mapping of SampleId to expressionSampleDataStructure (essentially the core Expression Sample Object) : 
    {sample_id -> expressionSampleDataStructure}*/
    funcdef get_expression_samples_data(sample_ids sample_ids) returns (expression_data_samples_map expression_data_samples_map);

    /* given a list of sample ids and feature ids it returns a LabelDataMapping {sampleID}->{featureId => value}}.  
If feature list is an empty array [], all features with measurment values will be returned. */
    funcdef get_expression_data_by_samples_and_features(sample_ids sample_ids, feature_ids feature_ids) returns (label_data_mapping label_data_mapping);

    /* given a list of SeriesIDs returns mapping of SeriesID to expressionDataSamples : {series_id -> {sample_id -> expressionSampleDataStructure}}*/
    funcdef get_expression_samples_data_by_series_ids(series_ids series_ids) returns (series_expression_data_samples_mapping series_expression_data_samples_mapping);

    /* given a list of SeriesIDs returns a list of Sample IDs */
    funcdef get_expression_sample_ids_by_series_ids(series_ids series_ids) returns (sample_ids sample_ids);
    
    /* given a list of ExperimentalUnitIDs returns mapping of ExperimentalUnitID to expressionDataSamples : {experimental_unit_id -> {sample_id -> expressionSampleDataStructure}}*/
    funcdef get_expression_samples_data_by_experimental_unit_ids(experimental_unit_ids experimental_unit_ids) returns (experimental_unit_expression_data_samples_mapping experimental_unit_expression_data_samples_mapping);

    /* given a list of ExperimentalUnitIDs returns a list of Sample IDs */
    funcdef get_expression_sample_ids_by_experimental_unit_ids(experimental_unit_ids experimental_unit_ids) returns (sample_ids sample_ids); 
    
    /* given a list of ExperimentMetaIDs returns mapping of {experimentMetaID -> {experimentalUnitId -> {sample_id -> expressionSampleDataStructure}}} */ 
    funcdef get_expression_samples_data_by_experiment_meta_ids(experiment_meta_ids experiment_meta_ids) returns (experiment_meta_expression_data_samples_mapping experiment_meta_expression_data_samples_mapping); 

    /* given a list of ExperimentMetaIDs returns a list of Sample IDs */ 
    funcdef get_expression_sample_ids_by_experiment_meta_ids(experiment_meta_ids experiment_meta_ids) returns (sample_ids sample_ids); 
    
    /* given a list of Strains, and a SampleType (controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics) , it returns a StrainExpressionDataSamplesMapping,  
    StrainId -> ExpressionSampleDataStructure {strain_id -> {sample_id -> expressionSampleDataStructure}}*/
    funcdef get_expression_samples_data_by_strain_ids(strain_ids strain_ids, sample_type sample_type) returns (strain_expression_data_samples_mapping strain_expression_data_samples_mapping);

    /* given a list of Strains, and a SampleType, it returns a list of Sample IDs*/
    funcdef get_expression_sample_ids_by_strain_ids(strain_ids strain_ids, sample_type sample_type) returns (sample_ids sample_ids); 

    /* given a list of Genomes, a SampleType ( controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics) 
    and a int indicating WildTypeOnly (1 = true, 0 = false) , it returns a GenomeExpressionDataSamplesMapping   ,  
    GenomeId -> StrainId -> ExpressionDataSample.  StrainId -> ExpressionSampleDataStructure {genome_id -> {strain_id -> {sample_id -> expressionSampleDataStructure}}}*/
    funcdef get_expression_samples_data_by_genome_ids(genome_ids genome_ids, sample_type sample_type, wild_type_only wild_type_only) returns (genome_expression_data_samples_mapping genome_expression_data_samples_mapping);

    /* given a list of GenomeIDs, a SampleType ( controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics) 
    and a int indicating WildType Only (1 = true, 0 = false) , it returns a list of Sample IDs*/ 
    funcdef get_expression_sample_ids_by_genome_ids(genome_ids genome_ids, sample_type sample_type, wild_type_only wild_type_only) returns (sample_ids sample_ids); 

    /* given a list of ontologyIDs, AndOr operator (and requires sample to have all ontology IDs, or sample has to have any of the terms), GenomeId, 
    SampleType ( controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics), wildTypeOnly returns OntologyID(concatenated if Anded) -> ExpressionDataSample  */
    funcdef get_expression_samples_data_by_ontology_ids(ontology_ids ontology_ids, string and_or, genome_id genome_id, sample_type sample_type, wild_type_only wild_type_only) 
        returns (ontology_expression_data_sample_mapping ontology_expression_data_sample_mapping);

    /* given a list of ontologyIDs, AndOr operator (and requires sample to have all ontology IDs, or sample has to have any of the terms), GenomeId, 
    SampleType ( controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics), wildTypeOnly returns a list of SampleIDs  */ 
    funcdef get_expression_sample_ids_by_ontology_ids(ontology_ids ontology_ids, string and_or, genome_id genome_id, sample_type sample_type, wild_type_only wild_type_only) 
        returns (sample_ids sample_ids); 

    /* given a list of FeatureIDs, a SampleType ( controlled vocabulary : microarray, RNA-Seq, qPCR, or proteomics) 
    and an int indicating WildType Only (1 = true, 0 = false) returns a FeatureSampleMeasurementMapping: {featureID->{sample_id->measurement}}*/
    funcdef get_expression_data_by_feature_ids(feature_ids feature_ids, sample_type sample_type, wild_type_only wild_type_only) 
        returns (feature_sample_measurement_mapping feature_sample_measurement_mapping);

    /* Compare samples takes two data structures labelDataMapping  {sampleID or label}->{featureId or label => value}}, 
    the first labelDataMapping is the numerator, the 2nd is the denominator in the comparison. returns a 
    SampleComparisonMapping {numerator_sample_id(or label)->{denominator_sample_id(or label)->{feature_id(or label) -> log2Ratio}}} */
    funcdef compare_samples(label_data_mapping numerators_data_mapping, label_data_mapping denominators_data_mapping) returns (sample_comparison_mapping sample_comparison_mapping);

    /* Compares each sample vs its defined default control.  If the Default control is not specified for a sample, then nothing is returned for that sample .
    Takes a list of sampleIDs returns SampleComparisonMapping {sample_id ->{denominator_default_control sample_id ->{feature_id -> log2Ratio}}} */
    funcdef compare_samples_vs_default_controls(sample_ids numerator_sample_ids) returns (sample_comparison_mapping sample_comparison_mapping);

    /* Compares each numerator sample vs the average of all the denominator sampleIds.  Take a list of numerator sample IDs and a list of samples Ids to average for the denominator.
    returns SampleComparisonMapping {numerator_sample_id->{denominator_sample_id ->{feature_id -> log2Ratio}}} */
    funcdef compare_samples_vs_the_average(sample_ids numerator_sample_ids, sample_ids denominator_sample_ids) returns (sample_comparison_mapping sample_comparison_mapping);

    /* Takes in comparison results.  If the value is >= on_threshold it is deemed on (1), if <= off_threshold it is off(-1), meets none then 0.  Thresholds normally set to zero.
    returns SampleComparisonMapping {numerator_sample_id(or label)->{denominator_sample_id(or label)->{feature_id(or label) -> on_off_call (possible values 0,-1,1)}}} */
    funcdef get_on_off_calls(sample_comparison_mapping sample_comparison_mapping, float off_threshold, float on_threshold) returns (sample_comparison_mapping on_off_mappings);

    /* Takes in comparison results. Direction must equal 'up', 'down', or 'both'.  Count is the number of changers returned in each direction.
    returns SampleComparisonMapping {numerator_sample_id(or label)->{denominator_sample_id(or label)->{feature_id(or label) -> log2Ratio (note that the features listed will be limited to the top changers)}}} */
    funcdef get_top_changers(sample_comparison_mapping sample_comparison_mapping, string direction, int count) returns (sample_comparison_mapping top_changers_mappings);

    /* given a List of SampleIDs, returns a Hash (key : SampleID, value: Title of Sample) */
    funcdef get_expression_samples_titles(sample_ids sample_ids) returns (samples_string_map samples_titles_map);

    /* given a List of SampleIDs, returns a Hash (key : SampleID, value: Description of Sample) */
    funcdef get_expression_samples_descriptions(sample_ids sample_ids) returns (samples_string_map samples_descriptions_map);

    /* given a List of SampleIDs, returns a Hash (key : SampleID, value: Molecule of Sample) */
    funcdef get_expression_samples_molecules(sample_ids sample_ids) returns (samples_string_map samples_molecules_map);

    /* given a List of SampleIDs, returns a Hash (key : SampleID, value: Type of Sample) */
    funcdef get_expression_samples_types(sample_ids sample_ids) returns (samples_string_map samples_types_map);

    /* given a List of SampleIDs, returns a Hash (key : SampleID, value: External_Source_ID of Sample (typically GSM)) */
    funcdef get_expression_samples_external_source_ids(sample_ids sample_ids) returns (samples_string_map samples_external_source_id_map);

    /* given a List of SampleIDs, returns a Hash (key : SampleID, value: OriginalLog2Median of Sample) */ 
    funcdef get_expression_samples_original_log2_medians(sample_ids sample_ids) returns (samples_float_map samples_float_map);

    /* given a List of SeriesIDs, returns a Hash (key : SeriesID, value: Title of Series) */
    funcdef get_expression_series_titles(series_ids series_ids) returns (series_string_map series_string_map);
 
    /* given a List of SeriesIDs, returns a Hash (key : SeriesID, value: Summary of Series) */
    funcdef get_expression_series_summaries(series_ids series_ids) returns (series_string_map series_string_map);

    /* given a List of SeriesIDs, returns a Hash (key : SeriesID, value: Design of Series) */
    funcdef get_expression_series_designs(series_ids series_ids) returns (series_string_map series_string_map);

    /* given a List of SeriesIDs, returns a Hash (key : SeriesID, value: External_Source_ID of Series (typically GSE)) */
    funcdef get_expression_series_external_source_ids(series_ids series_ids) returns (series_string_map series_string_map);

    /* get sample ids by the sample's external source id : Takes a list of sample external source ids, and returns a list of sample ids  */
    funcdef get_expression_sample_ids_by_sample_external_source_ids(external_source_ids external_source_ids) returns (sample_ids sample_ids);

    /* get sample ids by the platform's external source id : Takes a list of platform external source ids, and returns a list of sample ids  */   
    funcdef get_expression_sample_ids_by_platform_external_source_ids(external_source_ids external_source_ids) returns (sample_ids sample_ids);   
 
    /* get series ids by the series's external source id : Takes a list of series external source ids, and returns a list of series ids  */          
    funcdef get_expression_series_ids_by_series_external_source_ids(external_source_ids external_source_ids) returns (series_ids series_ids);  

    /* given a GEO GSE ID, it will return a complex data structure to be put int the upload tab files*/
    funcdef get_GEO_GSE(string gse_input_id) returns (GseObject gseObject);




    /*WORKSPACE OBJECTS*/ 

    /*
      NOTE THE PROTOCOL, PERSON, PUBLICATION CREATED HERE SHOULD ALL BE HANDLED BY SOME COMMON TYPED OBJECTS SERVICE IN THE FUTURE.
      FOR NOW I ONLY HAVE STRING IDS TO REPRESENT THE OBJECT.
      ALSO ONTOLOGY SHOULD BE HANDLED BY SOME SORT OF ONTOLOGY SERVICE IN THE FUTURE.  I NEED TO CREATE ONE NOW FOR USE.
    */

    /*
        Temporary workspace typed object for ontology.  Should be replaced by a ontology workspace typed object.
        Currently supports EO, PO and ENVO ontology terms.
    */
    typedef structure {
        string expression_ontology_term_id; 
        string expression_ontology_term_name; 
        string expression_ontology_term_definition;         
    } ExpressionOntologyTerm;

    /* list of ExpressionsOntologies */ 
    typedef list<ExpressionOntologyTerm> expression_ontology_terms; 

    /*
        Data structure for Strain  (TEMPORARY WORKSPACE TYPED OBJECT SHOULD BE HANDLED IN THE FUTURE IN WORKSPACE COMMON)
    */
    typedef structure {
        genome_id genome_id; 
        string reference_strain;
        string wild_type;
        string description;
        string name;
    } Strain; 

    /*
        Data structure for the workspace expression platform.  The ExpressionPlatform typed object.
        source_id defaults to id if not set, but typically referes to a GPL if the data is from GEO.

        @optional strain

        @searchable ws_subset source_id id genome_id title technology
        @searchable ws_subset strain.genome_id  strain.reference_strain strain.wild_type          
    */
    typedef structure { 
        string id; 
        string source_id;
        genome_id genome_id;
        Strain strain; 
        string technology; 
        string title; 
    } ExpressionPlatform; 

    /*
       id for the expression platform

       @id ws KBaseExpression.ExpressionPlatform

       "ws" may go to "to" in the future
    */
    typedef string expression_platform_id;

    /*
        Data structure for Protocol  (TEMPORARY WORKSPACE TYPED OBJECT SHOULD BE HANDLED IN THE FUTURE IN WORKSPACE COMMON)
    */
    typedef structure {
        string name; 
        string description;
    } Protocol; 

    /*
       id for the expression sample

       @id ws KBaseExpression.ExpressionSample

       "ws" may go to "to" in the future
    */
    typedef string expression_sample_id;

    /* list of expression sample ids */ 
    typedef list<expression_sample_id> expression_sample_ids;

    /* list of expression series ids that the sample belongs to : note this can not be a ws_reference because ws does not support bidirectional references */
    typedef list<string> expression_series_ids;

    /* map between genome ids and a list of samples from that genome in this sample */
    typedef mapping<genome_id genome_id, expression_sample_ids> genome_expression_sample_ids_map; 
    

    /* list of Persons */ 
    typedef list<Person> persons;

    /* 
       Data structure for the workspace expression sample.  The Expression Sample typed object.
       
       protocol, persons and strain should need to eventually have common ws objects.  I will make expression ones for now.
       
       we may need a link to experimentMetaID later.

       @optional description title data_quality_level original_median expression_ontology_terms platform_id default_control_sample characteristics
       @optional averaged_from_samples protocol strain persons molecule data_source shock_url processing_comments expression_series_ids 
       
       @searchable ws_subset id source_id type data_quality_level genome_id platform_id description title data_source characteristics keys_of(expression_levels) 
       @searchable ws_subset persons.[*].email persons.[*].last_name persons.[*].institution  
       @searchable ws_subset strain.genome_id strain.reference_strain strain.wild_type          
       @searchable ws_subset protocol.name protocol.description 
       @searchable ws_subset expression_ontology_terms.[*].expression_ontology_term_id expression_ontology_terms.[*].expression_ontology_term_name
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
        data_expression_levels_for_sample expression_levels; 
genome_id genome_id; 
        expression_ontology_terms expression_ontology_terms;
        expression_platform_id platform_id; 
        expression_sample_id default_control_sample; 
        expression_sample_ids averaged_from_samples; 
        Protocol protocol; 
        Strain strain; 
        persons persons;
        string molecule;
        string data_source; 
        string shock_url;
        string processing_comments;
        expression_series_ids expression_series_ids;
        string characteristics;
    } ExpressionSample;

    /*
        Data structure for the workspace expression series.  The ExpressionSeries typed object.
        publication should need to eventually have ws objects, will not include it for now.

        @optional title summary design publication_id 

        @searchable ws_subset id source_id publication_id title summary design genome_expression_sample_ids_map
    */
    typedef structure { 
        string id; 
        string source_id;
        genome_expression_sample_ids_map genome_expression_sample_ids_map;
        string title; 
        string summary;
        string design; 
        string publication_id; 
string external_source_date;
    } ExpressionSeries; 

    /*
        Simple Grouping of Samples that belong to the same replicate group.  ExpressionReplicateGroup typed object.
        @searchable ws_subset id expression_sample_ids
    */
    typedef structure {
        string id;
        expression_sample_ids expression_sample_ids;
    } ExpressionReplicateGroup;

    /*
       Specification for the RNASeqFastq Metadata
    */

    /*
       reference genome id for mapping the RNA-Seq fastq file
    */

    typedef string genome_id;
    /*
     Object for the RNASeq Metadata
     @optional platform source tissue condition po_id eo_id
    */
    typedef structure {
        string paired;
        string platform;
        string sample_id;
        string title;
        string source;
        string source_id;
        string ext_source_date;
        string domain;
        genome_id ref_genome;
        list<string> tissue;
        list<string> condition;
        list<string> po_id;
        list<string> eo_id;
     }RNASeqSampleMetaData;

     /*
       Complete List of RNASeq MetaData
     */
     typedef list<RNASeqSampleMetaData> RNASeqSamplesMetaData;
 
    /*
       A reference to RNASeq fastq  object on shock         
    */
 
    typedef string shock_url;
    /*   
       A reference to RNASeq fastq  object on shock       
    */

  typedef string shock_id;
  
 
  /*   
       A reference to RNASeq fastq  object
  */
  typedef structure{
      shock_id shock_id;
      shock_url shock_url;
  }shock_ref;
 
  /*
      RNASeq fastq  object
  */

  typedef structure {
      string name;
      string type;
      string created;
      shock_ref  shock_ref;
      RNASeqSampleMetaData metadata;  
  }RNASeqSample;

   /*
       list of RNASeqSamples
   */

  typedef list<RNASeqSample> RNASeqSamplesSet;
  /*
     Object for the RNASeq Alignment bam file
  */
  typedef structure {
      string  name;
      string  paired;
      string created;
      shock_ref shock_ref;
      RNASeqSampleMetaData metadata; 
  }RNASeqSampleAlignment;

/*
       list of RNASeqSampleAlignment
*/

  typedef list<RNASeqSampleAlignment> RNASeqSampleAlignmentSet;

/*
       RNASeqDifferentialExpression file structure
*/
   typedef structure {
       string name;
       shock_ref shock_ref;
   }RNASeqDifferentialExpressionFile;

/*
       list of RNASeqDifferentialExpression files 
*/

   typedef list<RNASeqDifferentialExpressionFile> RNASeqDifferentialExpressionSet;

/*
     Object for the RNASeq Differential Expression
*/

  typedef structure {
       string  name;
       string  title;
       string created;
       RNASeqDifferentialExpressionSet diff_expression;
  }RNASeqDifferentialExpression;
}; 