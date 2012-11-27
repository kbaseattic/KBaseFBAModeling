try:
    import json
except ImportError:
    import sys
    sys.path.append('simplejson-2.3.3')
    import simplejson as json
    
import urllib



class fbaModelServices:

    def __init__(self, url):
        if url != None:
            self.url = url

    def get_models(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_models',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_fbas(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_fbas',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_gapfills(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_gapfills',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_gapgens(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_gapgens',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_reactions(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_reactions',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_compounds(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_compounds',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_media(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_media',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_biochemistry(self, input):

        arg_hash = { 'method': 'fbaModelServices.get_biochemistry',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def genome_object_to_workspace(self, input):

        arg_hash = { 'method': 'fbaModelServices.genome_object_to_workspace',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def genome_to_workspace(self, input):

        arg_hash = { 'method': 'fbaModelServices.genome_to_workspace',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def genome_to_fbamodel(self, input):

        arg_hash = { 'method': 'fbaModelServices.genome_to_fbamodel',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def export_fbamodel(self, input):

        arg_hash = { 'method': 'fbaModelServices.export_fbamodel',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def addmedia(self, input):

        arg_hash = { 'method': 'fbaModelServices.addmedia',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def export_media(self, input):

        arg_hash = { 'method': 'fbaModelServices.export_media',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def runfba(self, input):

        arg_hash = { 'method': 'fbaModelServices.runfba',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def export_fba(self, input):

        arg_hash = { 'method': 'fbaModelServices.export_fba',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def import_phenotypes(self, input):

        arg_hash = { 'method': 'fbaModelServices.import_phenotypes',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def simulate_phenotypes(self, input):

        arg_hash = { 'method': 'fbaModelServices.simulate_phenotypes',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def export_phenotypeSimulationSet(self, input):

        arg_hash = { 'method': 'fbaModelServices.export_phenotypeSimulationSet',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def queue_runfba(self, input):

        arg_hash = { 'method': 'fbaModelServices.queue_runfba',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def queue_gapfill_model(self, input):

        arg_hash = { 'method': 'fbaModelServices.queue_gapfill_model',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def queue_gapgen_model(self, input):

        arg_hash = { 'method': 'fbaModelServices.queue_gapgen_model',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def queue_wildtype_phenotype_reconciliation(self, input):

        arg_hash = { 'method': 'fbaModelServices.queue_wildtype_phenotype_reconciliation',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def queue_combine_wildtype_phenotype_reconciliation_params(self, input):

        arg_hash = { 'method': 'fbaModelServices.queue_combine_wildtype_phenotype_reconciliation_params',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def jobs_done(self, input):

        arg_hash = { 'method': 'fbaModelServices.jobs_done',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def check_job(self, input):

        arg_hash = { 'method': 'fbaModelServices.check_job',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def run_job(self, input):

        arg_hash = { 'method': 'fbaModelServices.run_job',
                     'params': [input],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None




        
