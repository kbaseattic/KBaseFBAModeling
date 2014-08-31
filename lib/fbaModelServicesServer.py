#!/usr/bin/env python
from wsgiref.simple_server import make_server
import sys
import json
import traceback
from multiprocessing import Process
from getopt import getopt, GetoptError
from jsonrpcbase import JSONRPCService, InvalidParamsError, KeywordError,\
  JSONRPCError, ServerError, ParseError, InvalidRequestError
from os import environ
from ConfigParser import ConfigParser
from biokbase import log
import biokbase.nexus

DEPLOY = 'KB_DEPLOYMENT_CONFIG'
SERVICE = 'KB_SERVICE_NAME'

# Note that the error fields do not match the 2.0 JSONRPC spec


def get_config_file():
    return environ.get(DEPLOY, None)


def get_service_name():
    return environ.get(SERVICE, None)


def get_config():
    if not get_config_file() or not get_service_name():
        return None
    retconfig = {}
    config = ConfigParser()
    config.read(get_config_file())
    for nameval in config.items(get_service_name()):
        retconfig[nameval[0]] = nameval[1]
    return retconfig

config = get_config()

from fbaModelServicesImpl import fbaModelServices
impl_fbaModelServices = fbaModelServices(config)


class JSONObjectEncoder(json.JSONEncoder):

    def default(self, obj):
        if isinstance(obj, set):
            return list(obj)
        if isinstance(obj, frozenset):
            return list(obj)
        if hasattr(obj, 'toJSONable'):
            return obj.toJSONable()
        return json.JSONEncoder.default(self, obj)


class JSONRPCServiceCustom(JSONRPCService):

    def call(self, jsondata):
        """
        Calls jsonrpc service's method and returns its return value in a JSON
        string or None if there is none.

        Arguments:
        jsondata -- remote method call in jsonrpc format
        """
        result = self.call_py(jsondata)
        if result != None:
            return json.dumps(result, cls=JSONObjectEncoder)

        return None

    def _call_method(self, request):
        """Calls given method with given params and returns it value."""
        method = self.method_data[request['method']]['method']
        params = request['params']
        result = None
        try:
            if isinstance(params, list):
                # Does it have enough arguments?
                if len(params) < self._man_args(method):
                    raise InvalidParamsError('not enough arguments')
                # Does it have too many arguments?
                if(not self._vargs(method) and len(params) >
                    self._max_args(method)):
                    raise InvalidParamsError('too many arguments')

                result = method(*params)
            elif isinstance(params, dict):
                # Do not accept keyword arguments if the jsonrpc version is
                # not >=1.1.
                if request['jsonrpc'] < 11:
                    raise KeywordError

                result = method(**params)
            else:  # No params
                result = method()
        except JSONRPCError:
            raise
        except Exception as e:
#            log.exception('method %s threw an exception' % request['method'])
            # Exception was raised inside the method.
            newerr = ServerError()
            newerr.trace = traceback.format_exc()
            newerr.data = e.message
            raise newerr
        return result

    def call_py(self, jsondata):
        """
        Calls jsonrpc service's method and returns its return value in python
        object format or None if there is none.

        This method is same as call() except the return value is a python
        object instead of JSON string. This method is mainly only useful for
        debugging purposes.
        """
        try:
            rdata = json.loads(jsondata)
        except ValueError:
            raise ParseError

        # set some default values for error handling
        request = self._get_default_vals()

        if isinstance(rdata, dict) and rdata:
            # It's a single request.
            self._fill_request(request, rdata)
            respond = self._handle_request(request)

            # Don't respond to notifications
            if respond is None:
                return None

            return respond
        elif isinstance(rdata, list) and rdata:
            # It's a batch.
            requests = []
            responds = []

            for rdata_ in rdata:
                # set some default values for error handling
                request_ = self._get_default_vals()
                self._fill_request(request_, rdata_)
                requests.append(request_)

            for request_ in requests:
                respond = self._handle_request(request_)
                # Don't respond to notifications
                if respond is not None:
                    responds.append(respond)

            if responds:
                return responds

            # Nothing to respond.
            return None
        else:
            # empty dict, list or wrong type
            raise InvalidRequestError


class MethodContext(dict):

    def __init__(self, logger):
        self['client_ip'] = None
        self['user_id'] = None
        self['authenticated'] = None
        self['token'] = None
        self['module'] = None
        self['method'] = None
        self['call_id'] = None
        self._debug_levels = set([7, 8, 9, 'DEBUG', 'DEBUG2', 'DEBUG3'])
        self._logger = logger

    def log_err(self, message):
        self._log(log.ERR, message)

    def log_info(self, message):
        self._log(log.INFO, message)

    def log_debug(self, message, level=1):
        if level in self._debug_levels:
            pass
        else:
            level = int(level)
            if level < 1 or level > 3:
                raise ValueError("Illegal log level: " + str(level))
            level = level + 6
        self._log(level, message)

    def set_log_level(self, level):
        self._logger.set_log_level(level)

    def get_log_level(self):
        return self._logger.get_log_level()

    def clear_log_level(self):
        self._logger.clear_user_log_level()

    def _log(self, level, message):
        self._logger.log_message(level, message, self['client_ip'],
                                 self['user_id'], self['module'],
                                 self['method'], self['call_id'])


class Application(object):
    # Wrap the wsgi handler in a class definition so that we can
    # do some initialization and avoid regenerating stuff over
    # and over

    def logcallback(self):
        self.serverlog.set_log_file(self.userlog.get_log_file())

    def log(self, level, context, message):
        self.serverlog.log_message(level, message, context['client_ip'],
                             context['user_id'], context['module'],
                             context['method'], context['call_id'])

    def __init__(self):
        submod = get_service_name() or 'fbaModelServices'
        self.userlog = log.log(
            submod, ip_address=True, authuser=True, module=True, method=True,
            call_id=True, changecallback=self.logcallback,
            config=get_config_file())
        self.serverlog = log.log(
            submod, ip_address=True, authuser=True, module=True, method=True,
            call_id=True, logfile=self.userlog.get_log_file())
        self.serverlog.set_log_level(6)
        self.rpc_service = JSONRPCServiceCustom()
        self.method_authentication = dict()
        self.rpc_service.add(impl_fbaModelServices.get_models,
                             name='fbaModelServices.get_models',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_models'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_fbas,
                             name='fbaModelServices.get_fbas',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_fbas'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_gapfills,
                             name='fbaModelServices.get_gapfills',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_gapfills'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_gapgens,
                             name='fbaModelServices.get_gapgens',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_gapgens'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_reactions,
                             name='fbaModelServices.get_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_reactions'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_compounds,
                             name='fbaModelServices.get_compounds',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_compounds'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_alias,
                             name='fbaModelServices.get_alias',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_alias'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_aliassets,
                             name='fbaModelServices.get_aliassets',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_aliassets'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_media,
                             name='fbaModelServices.get_media',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_media'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.get_biochemistry,
                             name='fbaModelServices.get_biochemistry',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_biochemistry'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.import_probanno,
                             name='fbaModelServices.import_probanno',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_probanno'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.genome_object_to_workspace,
                             name='fbaModelServices.genome_object_to_workspace',
                             types=[dict])
        self.method_authentication['fbaModelServices.genome_object_to_workspace'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.genome_to_workspace,
                             name='fbaModelServices.genome_to_workspace',
                             types=[dict])
        self.method_authentication['fbaModelServices.genome_to_workspace'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.domains_to_workspace,
                             name='fbaModelServices.domains_to_workspace',
                             types=[dict])
        self.method_authentication['fbaModelServices.domains_to_workspace'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.compute_domains,
                             name='fbaModelServices.compute_domains',
                             types=[dict])
        self.method_authentication['fbaModelServices.compute_domains'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.add_feature_translation,
                             name='fbaModelServices.add_feature_translation',
                             types=[dict])
        self.method_authentication['fbaModelServices.add_feature_translation'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.genome_to_fbamodel,
                             name='fbaModelServices.genome_to_fbamodel',
                             types=[dict])
        self.method_authentication['fbaModelServices.genome_to_fbamodel'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.translate_fbamodel,
                             name='fbaModelServices.translate_fbamodel',
                             types=[dict])
        self.method_authentication['fbaModelServices.translate_fbamodel'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.build_pangenome,
                             name='fbaModelServices.build_pangenome',
                             types=[dict])
        self.method_authentication['fbaModelServices.build_pangenome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.genome_heatmap_from_pangenome,
                             name='fbaModelServices.genome_heatmap_from_pangenome',
                             types=[dict])
        self.method_authentication['fbaModelServices.genome_heatmap_from_pangenome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.ortholog_family_from_pangenome,
                             name='fbaModelServices.ortholog_family_from_pangenome',
                             types=[dict])
        self.method_authentication['fbaModelServices.ortholog_family_from_pangenome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.pangenome_to_proteome_comparison,
                             name='fbaModelServices.pangenome_to_proteome_comparison',
                             types=[dict])
        self.method_authentication['fbaModelServices.pangenome_to_proteome_comparison'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.import_fbamodel,
                             name='fbaModelServices.import_fbamodel',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_fbamodel'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.export_fbamodel,
                             name='fbaModelServices.export_fbamodel',
                             types=[dict])
        self.method_authentication['fbaModelServices.export_fbamodel'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.export_object,
                             name='fbaModelServices.export_object',
                             types=[dict])
        self.method_authentication['fbaModelServices.export_object'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.export_genome,
                             name='fbaModelServices.export_genome',
                             types=[dict])
        self.method_authentication['fbaModelServices.export_genome'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.adjust_model_reaction,
                             name='fbaModelServices.adjust_model_reaction',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_model_reaction'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.adjust_biomass_reaction,
                             name='fbaModelServices.adjust_biomass_reaction',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_biomass_reaction'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.addmedia,
                             name='fbaModelServices.addmedia',
                             types=[dict])
        self.method_authentication['fbaModelServices.addmedia'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.export_media,
                             name='fbaModelServices.export_media',
                             types=[dict])
        self.method_authentication['fbaModelServices.export_media'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.runfba,
                             name='fbaModelServices.runfba',
                             types=[dict])
        self.method_authentication['fbaModelServices.runfba'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.generate_model_stats,
                             name='fbaModelServices.generate_model_stats',
                             types=[dict])
        self.method_authentication['fbaModelServices.generate_model_stats'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.minimize_reactions,
                             name='fbaModelServices.minimize_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.minimize_reactions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.export_fba,
                             name='fbaModelServices.export_fba',
                             types=[dict])
        self.method_authentication['fbaModelServices.export_fba'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.import_phenotypes,
                             name='fbaModelServices.import_phenotypes',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_phenotypes'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.simulate_phenotypes,
                             name='fbaModelServices.simulate_phenotypes',
                             types=[dict])
        self.method_authentication['fbaModelServices.simulate_phenotypes'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.add_media_transporters,
                             name='fbaModelServices.add_media_transporters',
                             types=[dict])
        self.method_authentication['fbaModelServices.add_media_transporters'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.export_phenotypeSimulationSet,
                             name='fbaModelServices.export_phenotypeSimulationSet',
                             types=[dict])
        self.method_authentication['fbaModelServices.export_phenotypeSimulationSet'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.integrate_reconciliation_solutions,
                             name='fbaModelServices.integrate_reconciliation_solutions',
                             types=[dict])
        self.method_authentication['fbaModelServices.integrate_reconciliation_solutions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_runfba,
                             name='fbaModelServices.queue_runfba',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_runfba'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_gapfill_model,
                             name='fbaModelServices.queue_gapfill_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_gapfill_model'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.gapfill_model,
                             name='fbaModelServices.gapfill_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.gapfill_model'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_gapgen_model,
                             name='fbaModelServices.queue_gapgen_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_gapgen_model'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.gapgen_model,
                             name='fbaModelServices.gapgen_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.gapgen_model'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_wildtype_phenotype_reconciliation,
                             name='fbaModelServices.queue_wildtype_phenotype_reconciliation',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_wildtype_phenotype_reconciliation'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_reconciliation_sensitivity_analysis,
                             name='fbaModelServices.queue_reconciliation_sensitivity_analysis',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_reconciliation_sensitivity_analysis'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_combine_wildtype_phenotype_reconciliation,
                             name='fbaModelServices.queue_combine_wildtype_phenotype_reconciliation',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_combine_wildtype_phenotype_reconciliation'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.run_job,
                             name='fbaModelServices.run_job',
                             types=[dict])
        self.method_authentication['fbaModelServices.run_job'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.queue_job,
                             name='fbaModelServices.queue_job',
                             types=[dict])
        self.method_authentication['fbaModelServices.queue_job'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.set_cofactors,
                             name='fbaModelServices.set_cofactors',
                             types=[dict])
        self.method_authentication['fbaModelServices.set_cofactors'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.find_reaction_synonyms,
                             name='fbaModelServices.find_reaction_synonyms',
                             types=[dict])
        self.method_authentication['fbaModelServices.find_reaction_synonyms'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.role_to_reactions,
                             name='fbaModelServices.role_to_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.role_to_reactions'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.reaction_sensitivity_analysis,
                             name='fbaModelServices.reaction_sensitivity_analysis',
                             types=[dict])
        self.method_authentication['fbaModelServices.reaction_sensitivity_analysis'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.filter_iterative_solutions,
                             name='fbaModelServices.filter_iterative_solutions',
                             types=[dict])
        self.method_authentication['fbaModelServices.filter_iterative_solutions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.delete_noncontributing_reactions,
                             name='fbaModelServices.delete_noncontributing_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.delete_noncontributing_reactions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.annotate_workspace_Genome,
                             name='fbaModelServices.annotate_workspace_Genome',
                             types=[dict])
        self.method_authentication['fbaModelServices.annotate_workspace_Genome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.gtf_to_genome,
                             name='fbaModelServices.gtf_to_genome',
                             types=[dict])
        self.method_authentication['fbaModelServices.gtf_to_genome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.fasta_to_ProteinSet,
                             name='fbaModelServices.fasta_to_ProteinSet',
                             types=[dict])
        self.method_authentication['fbaModelServices.fasta_to_ProteinSet'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.ProteinSet_to_Genome,
                             name='fbaModelServices.ProteinSet_to_Genome',
                             types=[dict])
        self.method_authentication['fbaModelServices.ProteinSet_to_Genome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.fasta_to_ContigSet,
                             name='fbaModelServices.fasta_to_ContigSet',
                             types=[dict])
        self.method_authentication['fbaModelServices.fasta_to_ContigSet'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.ContigSet_to_Genome,
                             name='fbaModelServices.ContigSet_to_Genome',
                             types=[dict])
        self.method_authentication['fbaModelServices.ContigSet_to_Genome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.probanno_to_genome,
                             name='fbaModelServices.probanno_to_genome',
                             types=[dict])
        self.method_authentication['fbaModelServices.probanno_to_genome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.get_mapping,
                             name='fbaModelServices.get_mapping',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_mapping'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.subsystem_of_roles,
                             name='fbaModelServices.subsystem_of_roles',
                             types=[dict])
        self.method_authentication['fbaModelServices.subsystem_of_roles'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.adjust_mapping_role,
                             name='fbaModelServices.adjust_mapping_role',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_mapping_role'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.adjust_mapping_complex,
                             name='fbaModelServices.adjust_mapping_complex',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_mapping_complex'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.adjust_mapping_subsystem,
                             name='fbaModelServices.adjust_mapping_subsystem',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_mapping_subsystem'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.get_template_model,
                             name='fbaModelServices.get_template_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.get_template_model'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.import_template_fbamodel,
                             name='fbaModelServices.import_template_fbamodel',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_template_fbamodel'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.adjust_template_reaction,
                             name='fbaModelServices.adjust_template_reaction',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_template_reaction'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.adjust_template_biomass,
                             name='fbaModelServices.adjust_template_biomass',
                             types=[dict])
        self.method_authentication['fbaModelServices.adjust_template_biomass'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.add_stimuli,
                             name='fbaModelServices.add_stimuli',
                             types=[dict])
        self.method_authentication['fbaModelServices.add_stimuli'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.import_regulatory_model,
                             name='fbaModelServices.import_regulatory_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_regulatory_model'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.compare_models,
                             name='fbaModelServices.compare_models',
                             types=[dict])
        self.method_authentication['fbaModelServices.compare_models'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.compare_genomes,
                             name='fbaModelServices.compare_genomes',
                             types=[dict])
        self.method_authentication['fbaModelServices.compare_genomes'] = 'optional'
        self.rpc_service.add(impl_fbaModelServices.import_metagenome_annotation,
                             name='fbaModelServices.import_metagenome_annotation',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_metagenome_annotation'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.models_to_community_model,
                             name='fbaModelServices.models_to_community_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.models_to_community_model'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.metagenome_to_fbamodels,
                             name='fbaModelServices.metagenome_to_fbamodels',
                             types=[dict])
        self.method_authentication['fbaModelServices.metagenome_to_fbamodels'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.import_expression,
                             name='fbaModelServices.import_expression',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_expression'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.import_regulome,
                             name='fbaModelServices.import_regulome',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_regulome'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.create_promconstraint,
                             name='fbaModelServices.create_promconstraint',
                             types=[dict])
        self.method_authentication['fbaModelServices.create_promconstraint'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.add_biochemistry_compounds,
                             name='fbaModelServices.add_biochemistry_compounds',
                             types=[dict])
        self.method_authentication['fbaModelServices.add_biochemistry_compounds'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.update_object_references,
                             name='fbaModelServices.update_object_references',
                             types=[dict])
        self.method_authentication['fbaModelServices.update_object_references'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.add_reactions,
                             name='fbaModelServices.add_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.add_reactions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.remove_reactions,
                             name='fbaModelServices.remove_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.remove_reactions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.modify_reactions,
                             name='fbaModelServices.modify_reactions',
                             types=[dict])
        self.method_authentication['fbaModelServices.modify_reactions'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.add_features,
                             name='fbaModelServices.add_features',
                             types=[dict])
        self.method_authentication['fbaModelServices.add_features'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.remove_features,
                             name='fbaModelServices.remove_features',
                             types=[dict])
        self.method_authentication['fbaModelServices.remove_features'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.modify_features,
                             name='fbaModelServices.modify_features',
                             types=[dict])
        self.method_authentication['fbaModelServices.modify_features'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.import_trainingset,
                             name='fbaModelServices.import_trainingset',
                             types=[dict])
        self.method_authentication['fbaModelServices.import_trainingset'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.preload_trainingset,
                             name='fbaModelServices.preload_trainingset',
                             types=[dict])
        self.method_authentication['fbaModelServices.preload_trainingset'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.build_classifier,
                             name='fbaModelServices.build_classifier',
                             types=[dict])
        self.method_authentication['fbaModelServices.build_classifier'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.classify_genomes,
                             name='fbaModelServices.classify_genomes',
                             types=[dict])
        self.method_authentication['fbaModelServices.classify_genomes'] = 'required'
        self.rpc_service.add(impl_fbaModelServices.build_tissue_model,
                             name='fbaModelServices.build_tissue_model',
                             types=[dict])
        self.method_authentication['fbaModelServices.build_tissue_model'] = 'required'
        self.auth_client = biokbase.nexus.Client(
            config={'server': 'nexus.api.globusonline.org',
                    'verify_ssl': False,
                    'client': None,
                    'client_secret': None})

    def __call__(self, environ, start_response):
        # Context object, equivalent to the perl impl CallContext
        ctx = MethodContext(self.userlog)
        ctx['client_ip'] = environ.get('REMOTE_ADDR')

        status = '500 Internal Server Error'

        try:
            body_size = int(environ.get('CONTENT_LENGTH', 0))
        except (ValueError):
            body_size = 0
        if environ['REQUEST_METHOD'] == 'OPTIONS':
            # we basically do nothing and just return headers
            status = '200 OK'
            rpc_result = ""
        else:
            request_body = environ['wsgi.input'].read(body_size)
            try:
                req = json.loads(request_body)
            except ValueError as ve:
                err = {'error': {'code': -32700,
                                 'name': "Parse error",
                                 'message': str(ve),
                                 }
                       }
                rpc_result = self.process_error(err, ctx, {'version': '1.1'})
            else:
                ctx['module'], ctx['method'] = req['method'].split('.')
                ctx['call_id'] = req['id']
                try:
                    token = environ.get('HTTP_AUTHORIZATION')
                    # parse out the method being requested and check if it
                    # has an authentication requirement
                    auth_req = self.method_authentication.get(req['method'],
                                                              "none")
                    if auth_req != "none":
                        if token is None and auth_req == 'required':
                            err = ServerError()
                            err.data = "Authentication required for " + \
                                "fbaModelServices but no authentication header was passed"
                            raise err
                        elif token is None and auth_req == 'optional':
                            pass
                        else:
                            try:
                                user, _, _ = \
                                    self.auth_client.validate_token(token)
                                ctx['user_id'] = user
                                ctx['authenticated'] = 1
                                ctx['token'] = token
                            except Exception, e:
                                if auth_req == 'required':
                                    err = ServerError()
                                    err.data = \
                                        "Token validation failed: %s" % e
                                    raise err
                    # push the context object into the implementation
                    # instance's namespace
                    impl_fbaModelServices.ctx = ctx
                    self.log(log.INFO, ctx, 'start method')
                    rpc_result = self.rpc_service.call(request_body)
                    self.log(log.INFO, ctx, 'end method')
                except JSONRPCError as jre:
                    err = {'error': {'code': jre.code,
                                     'name': jre.message,
                                     'message': jre.data
                                     }
                           }
                    trace = jre.trace if hasattr(jre, 'trace') else None
                    rpc_result = self.process_error(err, ctx, req, trace)
                except Exception, e:
                    err = {'error': {'code': 0,
                                     'name': 'Unexpected Server Error',
                                     'message': 'An unexpected server error ' +
                                        'occurred',
                                     }
                           }
                    rpc_result = self.process_error(err, ctx, req,
                                                    traceback.format_exc())
                else:
                    status = '200 OK'

        #print 'The request method was %s\n' % environ['REQUEST_METHOD']
        #print 'The environment dictionary is:\n%s\n' % pprint.pformat(environ)
        #print 'The request body was: %s' % request_body
        #print 'The result from the method call is:\n%s\n' % \
        #    pprint.pformat(rpc_result)

        if rpc_result:
            response_body = rpc_result
        else:
            response_body = ''

        response_headers = [
            ('Access-Control-Allow-Origin', '*'),
            ('Access-Control-Allow-Headers', environ.get(
                 'HTTP_ACCESS_CONTROL_REQUEST_HEADERS', 'authorization')),
            ('content-type', 'application/json'),
            ('content-length', str(len(response_body)))]
        start_response(status, response_headers)
        return [response_body]

    def process_error(self, error, context, request, trace=None):
        if trace:
            self.log(log.ERR, context, trace.split('\n')[0:-1])
        if 'id' in request:
            error['id'] = request['id']
        if 'version' in request:
            error['version'] = request['version']
            error['error']['error'] = trace
        elif 'jsonrpc' in request:
            error['jsonrpc'] = request['jsonrpc']
            error['error']['data'] = trace
        else:
            error['version'] = '1.0'
            error['error']['error'] = trace
        return json.dumps(error)

application = Application()

# This is the uwsgi application dictionary. On startup uwsgi will look
# for this dict and pull its configuration from here.
# This simply lists where to "mount" the application in the URL path
#
# This uwsgi module "magically" appears when running the app within
# uwsgi and is not available otherwise, so wrap an exception handler
# around it
#
# To run this server in uwsgi with 4 workers listening on port 9999 use:
# uwsgi -M -p 4 --http :9999 --wsgi-file _this_file_
# To run a using the single threaded python BaseHTTP service
# listening on port 9999 by default execute this file
#
try:
    import uwsgi
# Before we do anything with the application, see if the
# configs specify patching all std routines to be asynch
# *ONLY* use this if you are going to wrap the service in
# a wsgi container that has enabled gevent, such as
# uwsgi with the --gevent option
    if config is not None and config.get('gevent_monkeypatch_all', False):
        print "Monkeypatching std libraries for async"
        from gevent import monkey
        monkey.patch_all()
    uwsgi.applications = {
        '': application
        }
except ImportError:
    # Not available outside of wsgi, ignore
    pass

_proc = None


def start_server(host='localhost', port=0, newprocess=False):
    '''
    By default, will start the server on localhost on a system assigned port
    in the main thread. Excecution of the main thread will stay in the server
    main loop until interrupted. To run the server in a separate process, and
    thus allow the stop_server method to be called, set newprocess = True. This
    will also allow returning of the port number.'''

    global _proc
    if _proc:
        raise RuntimeError('server is already running')
    httpd = make_server(host, port, application)
    port = httpd.server_address[1]
    print "Listening on port %s" % port
    if newprocess:
        _proc = Process(target=httpd.serve_forever)
        _proc.daemon = True
        _proc.start()
    else:
        httpd.serve_forever()
    return port


def stop_server():
    global _proc
    _proc.terminate()
    _proc = None

if __name__ == "__main__":
    try:
        opts, args = getopt(sys.argv[1:], "", ["port=", "host="])
    except GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        sys.exit(2)
    port = 9999
    host = 'localhost'
    for o, a in opts:
        if o == '--port':
            port = int(a)
        elif o == '--host':
            host = a
            print "Host set to %s" % host
        else:
            assert False, "unhandled option"

    start_server(host=host, port=port)
#    print "Listening on port %s" % port
#    httpd = make_server( host, port, application)
#
#    httpd.serve_forever()
