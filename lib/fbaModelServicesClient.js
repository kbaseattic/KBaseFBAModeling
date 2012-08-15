

function fbaModelServices(url) {

    var _url = url;


    this.genome_to_fbamodel = function(in_genome)
    {
	var resp = json_call_ajax_sync("fbaModelServices.genome_to_fbamodel", [in_genome]);
//	var resp = json_call_sync("fbaModelServices.genome_to_fbamodel", [in_genome]);
        return resp[0];
    }

    this.genome_to_fbamodel_async = function(in_genome, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.genome_to_fbamodel", [in_genome], 1, _callback, _error_callback)
    }

    this.fbamodel_to_sbml = function(in_model)
    {
	var resp = json_call_ajax_sync("fbaModelServices.fbamodel_to_sbml", [in_model]);
//	var resp = json_call_sync("fbaModelServices.fbamodel_to_sbml", [in_model]);
        return resp[0];
    }

    this.fbamodel_to_sbml_async = function(in_model, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.fbamodel_to_sbml", [in_model], 1, _callback, _error_callback)
    }

    this.gapfill_fbamodel = function(in_model, in_formulation, overwrite, save)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapfill_fbamodel", [in_model, in_formulation, overwrite, save]);
//	var resp = json_call_sync("fbaModelServices.gapfill_fbamodel", [in_model, in_formulation, overwrite, save]);
        return resp[0];
    }

    this.gapfill_fbamodel_async = function(in_model, in_formulation, overwrite, save, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapfill_fbamodel", [in_model, in_formulation, overwrite, save], 1, _callback, _error_callback)
    }

    this.runfba = function(in_model, in_formulation, overwrite, save)
    {
	var resp = json_call_ajax_sync("fbaModelServices.runfba", [in_model, in_formulation, overwrite, save]);
//	var resp = json_call_sync("fbaModelServices.runfba", [in_model, in_formulation, overwrite, save]);
        return resp[0];
    }

    this.runfba_async = function(in_model, in_formulation, overwrite, save, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.runfba", [in_model, in_formulation, overwrite, save], 1, _callback, _error_callback)
    }

    this.object_to_html = function(inObject)
    {
	var resp = json_call_ajax_sync("fbaModelServices.object_to_html", [inObject]);
//	var resp = json_call_sync("fbaModelServices.object_to_html", [inObject]);
        return resp[0];
    }

    this.object_to_html_async = function(inObject, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.object_to_html", [inObject], 1, _callback, _error_callback)
    }

    this.gapgen_fbamodel = function(in_model, in_formulation, overwrite, save)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapgen_fbamodel", [in_model, in_formulation, overwrite, save]);
//	var resp = json_call_sync("fbaModelServices.gapgen_fbamodel", [in_model, in_formulation, overwrite, save]);
        return resp[0];
    }

    this.gapgen_fbamodel_async = function(in_model, in_formulation, overwrite, save, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapgen_fbamodel", [in_model, in_formulation, overwrite, save], 1, _callback, _error_callback)
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

