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

    def genome_to_fbamodel(self, in_genome):

        arg_hash = { 'method': 'fbaModelServices.genome_to_fbamodel',
                     'params': [in_genome],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def fbamodel_to_exchangeFormat(self, in_model):

        arg_hash = { 'method': 'fbaModelServices.fbamodel_to_exchangeFormat',
                     'params': [in_model],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def exchangeFormat_to_fbamodel(self, in_model):

        arg_hash = { 'method': 'fbaModelServices.exchangeFormat_to_fbamodel',
                     'params': [in_model],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def fbamodel_to_sbml(self, in_model):

        arg_hash = { 'method': 'fbaModelServices.fbamodel_to_sbml',
                     'params': [in_model],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def sbml_to_fbamodel(self, in_model):

        arg_hash = { 'method': 'fbaModelServices.sbml_to_fbamodel',
                     'params': [in_model],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def gapfill_fbamodel(self, in_model, in_formulation, overwrite, save):

        arg_hash = { 'method': 'fbaModelServices.gapfill_fbamodel',
                     'params': [in_model, in_formulation, overwrite, save],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def runfba(self, in_model, in_formulation, overwrite, save):

        arg_hash = { 'method': 'fbaModelServices.runfba',
                     'params': [in_model, in_formulation, overwrite, save],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def object_to_html(self, inObject):

        arg_hash = { 'method': 'fbaModelServices.object_to_html',
                     'params': [inObject],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None




        
