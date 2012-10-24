try:
    import json
except ImportError:
    import sys
    sys.path.append('simplejson-2.3.3')
    import simplejson as json
    
import urllib



class workspaceDocumentDB:

    def __init__(self, url):
        if url != None:
            self.url = url

    def save_object(self, id, type, data, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.save_object',
                     'params': [id, type, data, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def delete_object(self, id, type, data, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.delete_object',
                     'params': [id, type, data, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def get_object(self, id, type, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.get_object',
                     'params': [id, type, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def revert_object(self, id, type, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.revert_object',
                     'params': [id, type, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def copy_object(self, new_id, new_workspace, source_id, type, source_workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.copy_object',
                     'params': [new_id, new_workspace, source_id, type, source_workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def move_object(self, new_id, new_workspace, source_id, type, source_workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.move_object',
                     'params': [new_id, new_workspace, source_id, type, source_workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def has_object(self, id, type, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.has_object',
                     'params': [id, type, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def create_workspace(self, name, default_permission):

        arg_hash = { 'method': 'workspaceDocumentDB.create_workspace',
                     'params': [name, default_permission],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def clone_workspace(self, new_workspace, current_workspace, default_permission):

        arg_hash = { 'method': 'workspaceDocumentDB.clone_workspace',
                     'params': [new_workspace, current_workspace, default_permission],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def list_workspaces(self, ):

        arg_hash = { 'method': 'workspaceDocumentDB.list_workspaces',
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

    def list_workspace_objects(self, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.list_workspace_objects',
                     'params': [workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def set_global_workspace_permissions(self, new_permission, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.set_global_workspace_permissions',
                     'params': [new_permission, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None

    def set_workspace_permissions(self, users, new_permission, workspace):

        arg_hash = { 'method': 'workspaceDocumentDB.set_workspace_permissions',
                     'params': [users, new_permission, workspace],
                     'version': '1.1'
                     }

        body = json.dumps(arg_hash)
        resp_str = urllib.urlopen(self.url, body).read()
        resp = json.loads(resp_str)

        if 'result' in resp:
            return resp['result'][0]
        else:
            return None




        
