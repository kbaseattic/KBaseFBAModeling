try:
    import json
except ImportError:
    import sys
    sys.path.append('simplejson-2.3.3')
    import simplejson as json
    
import urllib



class fbaModelCLI:

    def __init__(self, url):
        if url != None:
            self.url = url

    def execute_command(self, args, stdin):

        arg_hash = { 'method': 'fbaModelCLI.execute_command',
                     'params': [args, stdin],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result']
        else:
            return None




        
