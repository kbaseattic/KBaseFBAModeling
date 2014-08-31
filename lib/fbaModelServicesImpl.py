#BEGIN_HEADER
#END_HEADER


class fbaModelServices:
    '''
    Module Name:
    fbaModelServices

    Module Description:
    =head1 fbaModelServices

=head2 SYNOPSIS

The FBA Model Services include support related to the reconstruction, curation,
reconciliation, and analysis of metabolic models. This includes commands to:

1.) Load genome typed objects into a workspace

2.) Build a model from a genome typed object and curate the model

3.) Analyze a model with flux balance analysis

4.) Simulate and reconcile a model to an imported set of growth phenotype data

=head2 EXAMPLE OF API USE IN PERL

To use the API, first you need to instantiate a fbaModelServices client object:

my $client = Bio::KBase::fbaModelServices::Client->new;
   
Next, you can run API commands on the client object:
   
my $objmeta = $client->genome_to_workspace({
        genome => "kb|g.0",
        workspace => "myWorkspace"
});
my $objmeta = $client->genome_to_fbamodel({
        model => "myModel"
        workspace => "myWorkspace"
});

=head2 AUTHENTICATION

Each and every function in this service takes a hash reference as
its single argument. This hash reference may contain a key
C<auth> whose value is a bearer token for the user making
the request. If this is not provided a default user "public" is assumed.

=head2 WORKSPACE

A workspace is a named collection of objects owned by a specific
user, that may be viewable or editable by other users.Functions that operate
on workspaces take a C<workspace_id>, which is an alphanumeric string that
uniquely identifies a workspace among all workspaces.
    '''

    ######## WARNING FOR GEVENT USERS #######
    # Since asynchronous IO can lead to methods - even the same method -
    # interrupting each other, you must be *very* careful when using global
    # state. A method could easily clobber the state set by another while
    # the latter method is running.
    #########################################
    #BEGIN_CLASS_HEADER
    #END_CLASS_HEADER

    # config contains contents of config file in a hash or None if it couldn't
    # be found
    def __init__(self, config):
        #BEGIN_CONSTRUCTOR
        #END_CONSTRUCTOR
        pass

    def get_models(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_models
        #BEGIN get_models
        #END get_models

        #At some point might do deeper type checking...
        if not isinstance(out_models, list):
            raise ValueError('Method get_models return value ' +
                             'out_models is not type list as required.')
        # return the results
        return [out_models]

    def get_fbas(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_fbas
        #BEGIN get_fbas
        #END get_fbas

        #At some point might do deeper type checking...
        if not isinstance(out_fbas, list):
            raise ValueError('Method get_fbas return value ' +
                             'out_fbas is not type list as required.')
        # return the results
        return [out_fbas]

    def get_gapfills(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_gapfills
        #BEGIN get_gapfills
        #END get_gapfills

        #At some point might do deeper type checking...
        if not isinstance(out_gapfills, list):
            raise ValueError('Method get_gapfills return value ' +
                             'out_gapfills is not type list as required.')
        # return the results
        return [out_gapfills]

    def get_gapgens(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_gapgens
        #BEGIN get_gapgens
        #END get_gapgens

        #At some point might do deeper type checking...
        if not isinstance(out_gapgens, list):
            raise ValueError('Method get_gapgens return value ' +
                             'out_gapgens is not type list as required.')
        # return the results
        return [out_gapgens]

    def get_reactions(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_reactions
        #BEGIN get_reactions
        #END get_reactions

        #At some point might do deeper type checking...
        if not isinstance(out_reactions, list):
            raise ValueError('Method get_reactions return value ' +
                             'out_reactions is not type list as required.')
        # return the results
        return [out_reactions]

    def get_compounds(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_compounds
        #BEGIN get_compounds
        #END get_compounds

        #At some point might do deeper type checking...
        if not isinstance(out_compounds, list):
            raise ValueError('Method get_compounds return value ' +
                             'out_compounds is not type list as required.')
        # return the results
        return [out_compounds]

    def get_alias(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN get_alias
        #END get_alias

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method get_alias return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def get_aliassets(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: aliassets
        #BEGIN get_aliassets
        #END get_aliassets

        #At some point might do deeper type checking...
        if not isinstance(aliassets, list):
            raise ValueError('Method get_aliassets return value ' +
                             'aliassets is not type list as required.')
        # return the results
        return [aliassets]

    def get_media(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_media
        #BEGIN get_media
        #END get_media

        #At some point might do deeper type checking...
        if not isinstance(out_media, list):
            raise ValueError('Method get_media return value ' +
                             'out_media is not type list as required.')
        # return the results
        return [out_media]

    def get_biochemistry(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: out_biochemistry
        #BEGIN get_biochemistry
        #END get_biochemistry

        #At some point might do deeper type checking...
        if not isinstance(out_biochemistry, dict):
            raise ValueError('Method get_biochemistry return value ' +
                             'out_biochemistry is not type dict as required.')
        # return the results
        return [out_biochemistry]

    def import_probanno(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: probannoMeta
        #BEGIN import_probanno
        #END import_probanno

        #At some point might do deeper type checking...
        if not isinstance(probannoMeta, list):
            raise ValueError('Method import_probanno return value ' +
                             'probannoMeta is not type list as required.')
        # return the results
        return [probannoMeta]

    def genome_object_to_workspace(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: genomeMeta
        #BEGIN genome_object_to_workspace
        #END genome_object_to_workspace

        #At some point might do deeper type checking...
        if not isinstance(genomeMeta, list):
            raise ValueError('Method genome_object_to_workspace return value ' +
                             'genomeMeta is not type list as required.')
        # return the results
        return [genomeMeta]

    def genome_to_workspace(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: genomeMeta
        #BEGIN genome_to_workspace
        #END genome_to_workspace

        #At some point might do deeper type checking...
        if not isinstance(genomeMeta, list):
            raise ValueError('Method genome_to_workspace return value ' +
                             'genomeMeta is not type list as required.')
        # return the results
        return [genomeMeta]

    def domains_to_workspace(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: GenomeDomainMeta
        #BEGIN domains_to_workspace
        #END domains_to_workspace

        #At some point might do deeper type checking...
        if not isinstance(GenomeDomainMeta, list):
            raise ValueError('Method domains_to_workspace return value ' +
                             'GenomeDomainMeta is not type list as required.')
        # return the results
        return [GenomeDomainMeta]

    def compute_domains(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN compute_domains
        #END compute_domains

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method compute_domains return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def add_feature_translation(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: genomeMeta
        #BEGIN add_feature_translation
        #END add_feature_translation

        #At some point might do deeper type checking...
        if not isinstance(genomeMeta, list):
            raise ValueError('Method add_feature_translation return value ' +
                             'genomeMeta is not type list as required.')
        # return the results
        return [genomeMeta]

    def genome_to_fbamodel(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN genome_to_fbamodel
        #END genome_to_fbamodel

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method genome_to_fbamodel return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def translate_fbamodel(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN translate_fbamodel
        #END translate_fbamodel

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method translate_fbamodel return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def build_pangenome(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN build_pangenome
        #END build_pangenome

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method build_pangenome return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def genome_heatmap_from_pangenome(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN genome_heatmap_from_pangenome
        #END genome_heatmap_from_pangenome

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method genome_heatmap_from_pangenome return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def ortholog_family_from_pangenome(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN ortholog_family_from_pangenome
        #END ortholog_family_from_pangenome

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method ortholog_family_from_pangenome return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def pangenome_to_proteome_comparison(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN pangenome_to_proteome_comparison
        #END pangenome_to_proteome_comparison

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method pangenome_to_proteome_comparison return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def import_fbamodel(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN import_fbamodel
        #END import_fbamodel

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method import_fbamodel return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def export_fbamodel(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN export_fbamodel
        #END export_fbamodel

        #At some point might do deeper type checking...
        if not isinstance(output, basestring):
            raise ValueError('Method export_fbamodel return value ' +
                             'output is not type basestring as required.')
        # return the results
        return [output]

    def export_object(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN export_object
        #END export_object

        #At some point might do deeper type checking...
        if not isinstance(output, basestring):
            raise ValueError('Method export_object return value ' +
                             'output is not type basestring as required.')
        # return the results
        return [output]

    def export_genome(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN export_genome
        #END export_genome

        #At some point might do deeper type checking...
        if not isinstance(output, basestring):
            raise ValueError('Method export_genome return value ' +
                             'output is not type basestring as required.')
        # return the results
        return [output]

    def adjust_model_reaction(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN adjust_model_reaction
        #END adjust_model_reaction

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method adjust_model_reaction return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def adjust_biomass_reaction(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN adjust_biomass_reaction
        #END adjust_biomass_reaction

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method adjust_biomass_reaction return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def addmedia(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: mediaMeta
        #BEGIN addmedia
        #END addmedia

        #At some point might do deeper type checking...
        if not isinstance(mediaMeta, list):
            raise ValueError('Method addmedia return value ' +
                             'mediaMeta is not type list as required.')
        # return the results
        return [mediaMeta]

    def export_media(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN export_media
        #END export_media

        #At some point might do deeper type checking...
        if not isinstance(output, basestring):
            raise ValueError('Method export_media return value ' +
                             'output is not type basestring as required.')
        # return the results
        return [output]

    def runfba(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: fbaMeta
        #BEGIN runfba
        #END runfba

        #At some point might do deeper type checking...
        if not isinstance(fbaMeta, list):
            raise ValueError('Method runfba return value ' +
                             'fbaMeta is not type list as required.')
        # return the results
        return [fbaMeta]

    def generate_model_stats(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN generate_model_stats
        #END generate_model_stats

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method generate_model_stats return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def minimize_reactions(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: fbaMeta
        #BEGIN minimize_reactions
        #END minimize_reactions

        #At some point might do deeper type checking...
        if not isinstance(fbaMeta, list):
            raise ValueError('Method minimize_reactions return value ' +
                             'fbaMeta is not type list as required.')
        # return the results
        return [fbaMeta]

    def export_fba(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN export_fba
        #END export_fba

        #At some point might do deeper type checking...
        if not isinstance(output, basestring):
            raise ValueError('Method export_fba return value ' +
                             'output is not type basestring as required.')
        # return the results
        return [output]

    def import_phenotypes(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN import_phenotypes
        #END import_phenotypes

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method import_phenotypes return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def simulate_phenotypes(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN simulate_phenotypes
        #END simulate_phenotypes

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method simulate_phenotypes return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def add_media_transporters(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN add_media_transporters
        #END add_media_transporters

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method add_media_transporters return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def export_phenotypeSimulationSet(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN export_phenotypeSimulationSet
        #END export_phenotypeSimulationSet

        #At some point might do deeper type checking...
        if not isinstance(output, basestring):
            raise ValueError('Method export_phenotypeSimulationSet return value ' +
                             'output is not type basestring as required.')
        # return the results
        return [output]

    def integrate_reconciliation_solutions(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN integrate_reconciliation_solutions
        #END integrate_reconciliation_solutions

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method integrate_reconciliation_solutions return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def queue_runfba(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_runfba
        #END queue_runfba

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_runfba return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def queue_gapfill_model(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_gapfill_model
        #END queue_gapfill_model

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_gapfill_model return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def gapfill_model(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN gapfill_model
        #END gapfill_model

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method gapfill_model return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def queue_gapgen_model(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_gapgen_model
        #END queue_gapgen_model

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_gapgen_model return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def gapgen_model(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN gapgen_model
        #END gapgen_model

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method gapgen_model return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def queue_wildtype_phenotype_reconciliation(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_wildtype_phenotype_reconciliation
        #END queue_wildtype_phenotype_reconciliation

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_wildtype_phenotype_reconciliation return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def queue_reconciliation_sensitivity_analysis(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_reconciliation_sensitivity_analysis
        #END queue_reconciliation_sensitivity_analysis

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_reconciliation_sensitivity_analysis return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def queue_combine_wildtype_phenotype_reconciliation(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_combine_wildtype_phenotype_reconciliation
        #END queue_combine_wildtype_phenotype_reconciliation

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_combine_wildtype_phenotype_reconciliation return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def run_job(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN run_job
        #END run_job

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method run_job return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def queue_job(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: job
        #BEGIN queue_job
        #END queue_job

        #At some point might do deeper type checking...
        if not isinstance(job, dict):
            raise ValueError('Method queue_job return value ' +
                             'job is not type dict as required.')
        # return the results
        return [job]

    def set_cofactors(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN set_cofactors
        #END set_cofactors

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method set_cofactors return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def find_reaction_synonyms(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN find_reaction_synonyms
        #END find_reaction_synonyms

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method find_reaction_synonyms return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def role_to_reactions(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN role_to_reactions
        #END role_to_reactions

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method role_to_reactions return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def reaction_sensitivity_analysis(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN reaction_sensitivity_analysis
        #END reaction_sensitivity_analysis

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method reaction_sensitivity_analysis return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def filter_iterative_solutions(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN filter_iterative_solutions
        #END filter_iterative_solutions

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method filter_iterative_solutions return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def delete_noncontributing_reactions(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN delete_noncontributing_reactions
        #END delete_noncontributing_reactions

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method delete_noncontributing_reactions return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def annotate_workspace_Genome(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN annotate_workspace_Genome
        #END annotate_workspace_Genome

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method annotate_workspace_Genome return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def gtf_to_genome(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN gtf_to_genome
        #END gtf_to_genome

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method gtf_to_genome return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def fasta_to_ProteinSet(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN fasta_to_ProteinSet
        #END fasta_to_ProteinSet

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method fasta_to_ProteinSet return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def ProteinSet_to_Genome(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN ProteinSet_to_Genome
        #END ProteinSet_to_Genome

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method ProteinSet_to_Genome return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def fasta_to_ContigSet(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN fasta_to_ContigSet
        #END fasta_to_ContigSet

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method fasta_to_ContigSet return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def ContigSet_to_Genome(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN ContigSet_to_Genome
        #END ContigSet_to_Genome

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method ContigSet_to_Genome return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def probanno_to_genome(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN probanno_to_genome
        #END probanno_to_genome

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method probanno_to_genome return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def get_mapping(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN get_mapping
        #END get_mapping

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method get_mapping return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def subsystem_of_roles(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN subsystem_of_roles
        #END subsystem_of_roles

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method subsystem_of_roles return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def adjust_mapping_role(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN adjust_mapping_role
        #END adjust_mapping_role

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method adjust_mapping_role return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def adjust_mapping_complex(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN adjust_mapping_complex
        #END adjust_mapping_complex

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method adjust_mapping_complex return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def adjust_mapping_subsystem(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN adjust_mapping_subsystem
        #END adjust_mapping_subsystem

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method adjust_mapping_subsystem return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def get_template_model(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN get_template_model
        #END get_template_model

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method get_template_model return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def import_template_fbamodel(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN import_template_fbamodel
        #END import_template_fbamodel

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method import_template_fbamodel return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def adjust_template_reaction(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN adjust_template_reaction
        #END adjust_template_reaction

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method adjust_template_reaction return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def adjust_template_biomass(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: modelMeta
        #BEGIN adjust_template_biomass
        #END adjust_template_biomass

        #At some point might do deeper type checking...
        if not isinstance(modelMeta, list):
            raise ValueError('Method adjust_template_biomass return value ' +
                             'modelMeta is not type list as required.')
        # return the results
        return [modelMeta]

    def add_stimuli(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN add_stimuli
        #END add_stimuli

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method add_stimuli return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def import_regulatory_model(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN import_regulatory_model
        #END import_regulatory_model

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method import_regulatory_model return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def compare_models(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN compare_models
        #END compare_models

        #At some point might do deeper type checking...
        if not isinstance(output, dict):
            raise ValueError('Method compare_models return value ' +
                             'output is not type dict as required.')
        # return the results
        return [output]

    def compare_genomes(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN compare_genomes
        #END compare_genomes

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method compare_genomes return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def import_metagenome_annotation(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN import_metagenome_annotation
        #END import_metagenome_annotation

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method import_metagenome_annotation return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def models_to_community_model(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN models_to_community_model
        #END models_to_community_model

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method models_to_community_model return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def metagenome_to_fbamodels(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: outputs
        #BEGIN metagenome_to_fbamodels
        #END metagenome_to_fbamodels

        #At some point might do deeper type checking...
        if not isinstance(outputs, list):
            raise ValueError('Method metagenome_to_fbamodels return value ' +
                             'outputs is not type list as required.')
        # return the results
        return [outputs]

    def import_expression(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: expression_meta
        #BEGIN import_expression
        #END import_expression

        #At some point might do deeper type checking...
        if not isinstance(expression_meta, list):
            raise ValueError('Method import_expression return value ' +
                             'expression_meta is not type list as required.')
        # return the results
        return [expression_meta]

    def import_regulome(self, input):
        # self.ctx is set by the wsgi application class
        # return variables are: regulome_meta
        #BEGIN import_regulome
        #END import_regulome

        #At some point might do deeper type checking...
        if not isinstance(regulome_meta, list):
            raise ValueError('Method import_regulome return value ' +
                             'regulome_meta is not type list as required.')
        # return the results
        return [regulome_meta]

    def create_promconstraint(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: promconstraint_meta
        #BEGIN create_promconstraint
        #END create_promconstraint

        #At some point might do deeper type checking...
        if not isinstance(promconstraint_meta, list):
            raise ValueError('Method create_promconstraint return value ' +
                             'promconstraint_meta is not type list as required.')
        # return the results
        return [promconstraint_meta]

    def add_biochemistry_compounds(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN add_biochemistry_compounds
        #END add_biochemistry_compounds

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method add_biochemistry_compounds return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def update_object_references(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN update_object_references
        #END update_object_references

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method update_object_references return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def add_reactions(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN add_reactions
        #END add_reactions

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method add_reactions return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def remove_reactions(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN remove_reactions
        #END remove_reactions

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method remove_reactions return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def modify_reactions(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN modify_reactions
        #END modify_reactions

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method modify_reactions return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def add_features(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN add_features
        #END add_features

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method add_features return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def remove_features(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN remove_features
        #END remove_features

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method remove_features return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def modify_features(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN modify_features
        #END modify_features

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method modify_features return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def import_trainingset(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN import_trainingset
        #END import_trainingset

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method import_trainingset return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def preload_trainingset(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN preload_trainingset
        #END preload_trainingset

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method preload_trainingset return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def build_classifier(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN build_classifier
        #END build_classifier

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method build_classifier return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def classify_genomes(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN classify_genomes
        #END classify_genomes

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method classify_genomes return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]

    def build_tissue_model(self, params):
        # self.ctx is set by the wsgi application class
        # return variables are: output
        #BEGIN build_tissue_model
        #END build_tissue_model

        #At some point might do deeper type checking...
        if not isinstance(output, list):
            raise ValueError('Method build_tissue_model return value ' +
                             'output is not type list as required.')
        # return the results
        return [output]
