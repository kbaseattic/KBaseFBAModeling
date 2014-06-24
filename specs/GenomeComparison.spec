module GenomeComparison {

	/*
		int inner_pos - position of gene name in inner genome (see dataN field in ProteomeComparison
		int score - bit score of blast alignment multiplied by 100
		int percent_of_best_score - best bit score of all hits connected to either of two genes from this hit
	*/
	typedef tuple<int inner_pos, int score, int percent_of_best_score> hit;

	/*
		string genome1ws - workspace of genome1
		string genome1id - id of genome1
		string genome2ws - workspace of genome2
		string genome2id - id of genome2
		float sub_bbh_percent - optional parameter, minimum percent of bit score compared to best bit score, default is 90
		string max_evalue -  optional parameter, maximum evalue, default is 1e-10
		list<string> proteome1names - names of genes of genome1
		mapping<string, int> proteome1map - map from genes of genome1 to their positions
		list<string> proteome2names - names of genes of genome2
		mapping<string, int> proteome2map - map from genes of genome2 to their positions
		list<list<hit>> data1 - outer list iterates over positions of genome1 gene names, inner list iterates over hits from given gene1 to genome2
		list<list<hit>> data2 - outer list iterates over positions of genome2 gene names, inner list iterates over hits from given gene2 to genome1
	*/
	typedef structure {
		string genome1ws;
		string genome1id;
		string genome2ws;
		string genome2id;
		float sub_bbh_percent;
		string max_evalue;
		list<string> proteome1names;
		mapping<string,int> proteome1map;
		list<string> proteome2names;
		mapping<string,int> proteome2map;
		list<list<hit>> data1;
		list<list<hit>> data2;
	} ProteomeComparison;

	/*
		string genome1ws - workspace of genome1
		string genome1id - id of genome1
		string genome2ws - workspace of genome2
		string genome2id - id of genome2
		float sub_bbh_percent - optional parameter, minimum percent of bit score compared to best bit score, default is 90
		string max_evalue -  optional parameter, maximum evalue, default is 1e-10
		string output_ws - workspace of output object
		string output_id - future id of output object
	*/
	typedef structure {
		string genome1ws;
		string genome1id;
		string genome2ws;
		string genome2id;
		float sub_bbh_percent;
		string max_evalue;
		string output_ws;
		string output_id;
	} blast_proteomes_params;

	funcdef blast_proteomes(blast_proteomes_params input) returns (string job_id) authentication required;

	/*
		string in_genome_ws - workspace of input genome
		string in_genome_id - id of input genome
		string out_genome_ws - workspace of output genome
		string out_genome_id - future id of output genome
		int seed_annotation_only - optional flag (default value is 0) preventing gene calling
	*/
	typedef structure {
		string in_genome_ws;
		string in_genome_id;
		string out_genome_ws;
		string out_genome_id;
		int seed_annotation_only;
	} annotate_genome_params;
	
	funcdef annotate_genome(annotate_genome_params input) returns (string job_id) authentication required;
};