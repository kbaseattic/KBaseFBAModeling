try:
    import json
except ImportError:
    import sys
    sys.path.append('simplejson-2.3.3')
    import simplejson as json
    
import urllib



class fbaModelData:

    def __init__(self, url):
        if url != None:
            self.url = url

    def has_data(self, ref):

        arg_hash = { 'method': 'fbaModelData.has_data',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_data(self, ref):

        arg_hash = { 'method': 'fbaModelData.get_data',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def save_data(self, ref, data, config):

        arg_hash = { 'method': 'fbaModelData.save_data',
                     'params': [ref, data, config],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_aliases(self, query):

        arg_hash = { 'method': 'fbaModelData.get_aliases',
                     'params': [query],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def update_alias(self, ref, uuid):

        arg_hash = { 'method': 'fbaModelData.update_alias',
                     'params': [ref, uuid],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def add_viewer(self, ref, viewer):

        arg_hash = { 'method': 'fbaModelData.add_viewer',
                     'params': [ref, viewer],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def remove_viewer(self, ref, viewer):

        arg_hash = { 'method': 'fbaModelData.remove_viewer',
                     'params': [ref, viewer],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def set_public(self, ref, public):

        arg_hash = { 'method': 'fbaModelData.set_public',
                     'params': [ref, public],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def alias_owner(self, ref):

        arg_hash = { 'method': 'fbaModelData.alias_owner',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def alias_public(self, ref):

        arg_hash = { 'method': 'fbaModelData.alias_public',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def alias_viewers(self, ref):

        arg_hash = { 'method': 'fbaModelData.alias_viewers',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def ancestors(self, ref):

        arg_hash = { 'method': 'fbaModelData.ancestors',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def ancestor_graph(self, ref):

        arg_hash = { 'method': 'fbaModelData.ancestor_graph',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def descendants(self, ref):

        arg_hash = { 'method': 'fbaModelData.descendants',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def descendant_graph(self, ref):

        arg_hash = { 'method': 'fbaModelData.descendant_graph',
                     'params': [ref],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def init_database(self, ):

        arg_hash = { 'method': 'fbaModelData.init_database',
                     'params': [],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def delete_database(self, config):

        arg_hash = { 'method': 'fbaModelData.delete_database',
                     'params': [config],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None




        
