
module KBaseRegulatoryFBA {
     /*
      Genome feature
      */
    typedef string feature_id;
    /*
      Expresion sample id
    */
    typedef string expression_sample_id;
    /*
      collection of eflux expression scores for each feature in a genome,
      representing a single gene expression sample
    */
    typedef structure {
	    mapping<feature_id, float> eflux_scores;
	    string expression_sample_ref;
    } EfluxExpressionSample
    /*
      Eflux values computed for an entire gene expression series
    */
    typedef structure {
	string eflux_collection_id;
	mapping<expression_sample_id, EfluxExpressionSample> efluxExpressionSamples;
    } EfluxExpressionCollection;
};
