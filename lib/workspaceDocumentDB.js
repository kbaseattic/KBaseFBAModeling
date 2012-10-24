

function workspaceDocumentDB(url) {

    var _url = url;


    this.save_object = function(id, type, data, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.save_object", [id, type, data, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.save_object", [id, type, data, workspace]);
        return resp[0];
    }

    this.save_object_async = function(id, type, data, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.save_object", [id, type, data, workspace], 1, _callback, _error_callback)
    }

    this.delete_object = function(id, type, data, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.delete_object", [id, type, data, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.delete_object", [id, type, data, workspace]);
        return resp[0];
    }

    this.delete_object_async = function(id, type, data, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.delete_object", [id, type, data, workspace], 1, _callback, _error_callback)
    }

    this.get_object = function(id, type, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.get_object", [id, type, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.get_object", [id, type, workspace]);
        return resp[0];
    }

    this.get_object_async = function(id, type, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.get_object", [id, type, workspace], 1, _callback, _error_callback)
    }

    this.revert_object = function(id, type, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.revert_object", [id, type, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.revert_object", [id, type, workspace]);
        return resp[0];
    }

    this.revert_object_async = function(id, type, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.revert_object", [id, type, workspace], 1, _callback, _error_callback)
    }

    this.copy_object = function(new_id, new_workspace, source_id, type, source_workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.copy_object", [new_id, new_workspace, source_id, type, source_workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.copy_object", [new_id, new_workspace, source_id, type, source_workspace]);
        return resp[0];
    }

    this.copy_object_async = function(new_id, new_workspace, source_id, type, source_workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.copy_object", [new_id, new_workspace, source_id, type, source_workspace], 1, _callback, _error_callback)
    }

    this.move_object = function(new_id, new_workspace, source_id, type, source_workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.move_object", [new_id, new_workspace, source_id, type, source_workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.move_object", [new_id, new_workspace, source_id, type, source_workspace]);
        return resp[0];
    }

    this.move_object_async = function(new_id, new_workspace, source_id, type, source_workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.move_object", [new_id, new_workspace, source_id, type, source_workspace], 1, _callback, _error_callback)
    }

    this.has_object = function(id, type, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.has_object", [id, type, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.has_object", [id, type, workspace]);
        return resp[0];
    }

    this.has_object_async = function(id, type, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.has_object", [id, type, workspace], 1, _callback, _error_callback)
    }

    this.create_workspace = function(name, default_permission)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.create_workspace", [name, default_permission]);
//	var resp = json_call_sync("workspaceDocumentDB.create_workspace", [name, default_permission]);
        return resp[0];
    }

    this.create_workspace_async = function(name, default_permission, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.create_workspace", [name, default_permission], 1, _callback, _error_callback)
    }

    this.clone_workspace = function(new_workspace, current_workspace, default_permission)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.clone_workspace", [new_workspace, current_workspace, default_permission]);
//	var resp = json_call_sync("workspaceDocumentDB.clone_workspace", [new_workspace, current_workspace, default_permission]);
        return resp[0];
    }

    this.clone_workspace_async = function(new_workspace, current_workspace, default_permission, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.clone_workspace", [new_workspace, current_workspace, default_permission], 1, _callback, _error_callback)
    }

    this.list_workspaces = function()
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.list_workspaces", []);
//	var resp = json_call_sync("workspaceDocumentDB.list_workspaces", []);
        return resp[0];
    }

    this.list_workspaces_async = function(_callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.list_workspaces", [], 1, _callback, _error_callback)
    }

    this.list_workspace_objects = function(workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.list_workspace_objects", [workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.list_workspace_objects", [workspace]);
        return resp[0];
    }

    this.list_workspace_objects_async = function(workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.list_workspace_objects", [workspace], 1, _callback, _error_callback)
    }

    this.set_global_workspace_permissions = function(new_permission, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.set_global_workspace_permissions", [new_permission, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.set_global_workspace_permissions", [new_permission, workspace]);
        return resp[0];
    }

    this.set_global_workspace_permissions_async = function(new_permission, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.set_global_workspace_permissions", [new_permission, workspace], 1, _callback, _error_callback)
    }

    this.set_workspace_permissions = function(users, new_permission, workspace)
    {
	var resp = json_call_ajax_sync("workspaceDocumentDB.set_workspace_permissions", [users, new_permission, workspace]);
//	var resp = json_call_sync("workspaceDocumentDB.set_workspace_permissions", [users, new_permission, workspace]);
        return resp[0];
    }

    this.set_workspace_permissions_async = function(users, new_permission, workspace, _callback, _error_callback)
    {
	json_call_ajax_async("workspaceDocumentDB.set_workspace_permissions", [users, new_permission, workspace], 1, _callback, _error_callback)
    }

    function _json_call_prepare(url, method, params, async_flag)
    {
	var rpc = { 'params' : params,
		    'method' : method,
		    'version': "1.1",
	};
	
	var body = JSON.stringify(rpc);
	
	var http = new XMLHttpRequest();
	
	http.open("POST", url, async_flag);
	
	//Send the proper header information along with the request
	http.setRequestHeader("Content-type", "application/json");
	//http.setRequestHeader("Content-length", body.length);
	//http.setRequestHeader("Connection", "close");
	return [http, body];
    }

    /*
     * JSON call using jQuery method.
     */

    function json_call_ajax_sync(method, params)
    {
        var rpc = { 'params' : params,
                    'method' : method,
                    'version': "1.1",
        };
        
        var body = JSON.stringify(rpc);
        var resp_txt;
	var code;
        
        var x = jQuery.ajax({       "async": false,
                                    dataType: "text",
                                    url: _url,
                                    success: function (data, status, xhr) { resp_txt = data; code = xhr.status },
				    error: function(xhr, textStatus, errorThrown) { resp_txt = xhr.responseText, code = xhr.status },
                                    data: body,
                                    processData: false,
                                    type: 'POST',
				    });

        var result;

        if (resp_txt)
        {
	    var resp = JSON.parse(resp_txt);
	    
	    if (code >= 500)
	    {
		throw resp.error;
	    }
	    else
	    {
		return resp.result;
	    }
        }
	else
	{
	    return null;
	}
    }

    function json_call_ajax_async(method, params, num_rets, callback, error_callback)
    {
        var rpc = { 'params' : params,
                    'method' : method,
                    'version': "1.1",
        };
        
        var body = JSON.stringify(rpc);
        var resp_txt;
	var code;
        
        var x = jQuery.ajax({       "async": true,
                                    dataType: "text",
                                    url: _url,
                                    success: function (data, status, xhr)
				{
				    resp = JSON.parse(data);
				    var result = resp["result"];
				    if (num_rets == 1)
				    {
					callback(result[0]);
				    }
				    else
				    {
					callback(result);
				    }
				    
				},
				    error: function(xhr, textStatus, errorThrown)
				{
				    if (xhr.responseText)
				    {
					resp = JSON.parse(xhr.responseText);
					if (error_callback)
					{
					    error_callback(resp.error);
					}
					else
					{
					    throw resp.error;
					}
				    }
				},
                                    data: body,
                                    processData: false,
                                    type: 'POST',
				    });

    }

    function json_call_async(method, params, num_rets, callback)
    {
	var tup = _json_call_prepare(_url, method, params, true);
	var http = tup[0];
	var body = tup[1];
	
	http.onreadystatechange = function() {
	    if (http.readyState == 4 && http.status == 200) {
		var resp_txt = http.responseText;
		var resp = JSON.parse(resp_txt);
		var result = resp["result"];
		if (num_rets == 1)
		{
		    callback(result[0]);
		}
		else
		{
		    callback(result);
		}
	    }
	}
	
	http.send(body);
	
    }
    
    function json_call_sync(method, params)
    {
	var tup = _json_call_prepare(url, method, params, false);
	var http = tup[0];
	var body = tup[1];
	
	http.send(body);
	
	var resp_txt = http.responseText;
	
	var resp = JSON.parse(resp_txt);
	var result = resp["result"];
	    
	return result;
    }
}

