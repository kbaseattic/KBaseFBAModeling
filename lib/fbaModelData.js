

function fbaModelData(url) {

    var _url = url;


    this.has_data = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.has_data", [ref]);
//	var resp = json_call_sync("fbaModelData.has_data", [ref]);
        return resp[0];
    }

    this.has_data_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.has_data", [ref], 1, _callback, _error_callback)
    }

    this.get_data = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.get_data", [ref]);
//	var resp = json_call_sync("fbaModelData.get_data", [ref]);
        return resp[0];
    }

    this.get_data_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.get_data", [ref], 1, _callback, _error_callback)
    }

    this.save_data = function(ref, data, config)
    {
	var resp = json_call_ajax_sync("fbaModelData.save_data", [ref, data, config]);
//	var resp = json_call_sync("fbaModelData.save_data", [ref, data, config]);
        return resp[0];
    }

    this.save_data_async = function(ref, data, config, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.save_data", [ref, data, config], 1, _callback, _error_callback)
    }

    this.get_aliases = function(query)
    {
	var resp = json_call_ajax_sync("fbaModelData.get_aliases", [query]);
//	var resp = json_call_sync("fbaModelData.get_aliases", [query]);
        return resp[0];
    }

    this.get_aliases_async = function(query, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.get_aliases", [query], 1, _callback, _error_callback)
    }

    this.update_alias = function(ref, uuid)
    {
	var resp = json_call_ajax_sync("fbaModelData.update_alias", [ref, uuid]);
//	var resp = json_call_sync("fbaModelData.update_alias", [ref, uuid]);
        return resp[0];
    }

    this.update_alias_async = function(ref, uuid, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.update_alias", [ref, uuid], 1, _callback, _error_callback)
    }

    this.add_viewer = function(ref, viewer)
    {
	var resp = json_call_ajax_sync("fbaModelData.add_viewer", [ref, viewer]);
//	var resp = json_call_sync("fbaModelData.add_viewer", [ref, viewer]);
        return resp[0];
    }

    this.add_viewer_async = function(ref, viewer, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.add_viewer", [ref, viewer], 1, _callback, _error_callback)
    }

    this.remove_viewer = function(ref, viewer)
    {
	var resp = json_call_ajax_sync("fbaModelData.remove_viewer", [ref, viewer]);
//	var resp = json_call_sync("fbaModelData.remove_viewer", [ref, viewer]);
        return resp[0];
    }

    this.remove_viewer_async = function(ref, viewer, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.remove_viewer", [ref, viewer], 1, _callback, _error_callback)
    }

    this.set_public = function(ref, public)
    {
	var resp = json_call_ajax_sync("fbaModelData.set_public", [ref, public]);
//	var resp = json_call_sync("fbaModelData.set_public", [ref, public]);
        return resp[0];
    }

    this.set_public_async = function(ref, public, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.set_public", [ref, public], 1, _callback, _error_callback)
    }

    this.alias_owner = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.alias_owner", [ref]);
//	var resp = json_call_sync("fbaModelData.alias_owner", [ref]);
        return resp[0];
    }

    this.alias_owner_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.alias_owner", [ref], 1, _callback, _error_callback)
    }

    this.alias_public = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.alias_public", [ref]);
//	var resp = json_call_sync("fbaModelData.alias_public", [ref]);
        return resp[0];
    }

    this.alias_public_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.alias_public", [ref], 1, _callback, _error_callback)
    }

    this.alias_viewers = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.alias_viewers", [ref]);
//	var resp = json_call_sync("fbaModelData.alias_viewers", [ref]);
        return resp[0];
    }

    this.alias_viewers_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.alias_viewers", [ref], 1, _callback, _error_callback)
    }

    this.ancestors = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.ancestors", [ref]);
//	var resp = json_call_sync("fbaModelData.ancestors", [ref]);
        return resp[0];
    }

    this.ancestors_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.ancestors", [ref], 1, _callback, _error_callback)
    }

    this.ancestor_graph = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.ancestor_graph", [ref]);
//	var resp = json_call_sync("fbaModelData.ancestor_graph", [ref]);
        return resp[0];
    }

    this.ancestor_graph_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.ancestor_graph", [ref], 1, _callback, _error_callback)
    }

    this.descendants = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.descendants", [ref]);
//	var resp = json_call_sync("fbaModelData.descendants", [ref]);
        return resp[0];
    }

    this.descendants_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.descendants", [ref], 1, _callback, _error_callback)
    }

    this.descendant_graph = function(ref)
    {
	var resp = json_call_ajax_sync("fbaModelData.descendant_graph", [ref]);
//	var resp = json_call_sync("fbaModelData.descendant_graph", [ref]);
        return resp[0];
    }

    this.descendant_graph_async = function(ref, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.descendant_graph", [ref], 1, _callback, _error_callback)
    }

    this.init_database = function()
    {
	var resp = json_call_ajax_sync("fbaModelData.init_database", []);
//	var resp = json_call_sync("fbaModelData.init_database", []);
        return resp[0];
    }

    this.init_database_async = function(_callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.init_database", [], 1, _callback, _error_callback)
    }

    this.delete_database = function(config)
    {
	var resp = json_call_ajax_sync("fbaModelData.delete_database", [config]);
//	var resp = json_call_sync("fbaModelData.delete_database", [config]);
        return resp[0];
    }

    this.delete_database_async = function(config, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelData.delete_database", [config], 1, _callback, _error_callback)
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

