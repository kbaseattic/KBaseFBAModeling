

function fbaModelServices(url) {

    var _url = url;


    this.get_models = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_models", [input]);
//	var resp = json_call_sync("fbaModelServices.get_models", [input]);
        return resp[0];
    }

    this.get_models_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_models", [input], 1, _callback, _error_callback)
    }

    this.get_fbas = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_fbas", [input]);
//	var resp = json_call_sync("fbaModelServices.get_fbas", [input]);
        return resp[0];
    }

    this.get_fbas_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_fbas", [input], 1, _callback, _error_callback)
    }

    this.get_gapfills = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_gapfills", [input]);
//	var resp = json_call_sync("fbaModelServices.get_gapfills", [input]);
        return resp[0];
    }

    this.get_gapfills_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_gapfills", [input], 1, _callback, _error_callback)
    }

    this.get_gapgens = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_gapgens", [input]);
//	var resp = json_call_sync("fbaModelServices.get_gapgens", [input]);
        return resp[0];
    }

    this.get_gapgens_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_gapgens", [input], 1, _callback, _error_callback)
    }

    this.get_reactions = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_reactions", [input]);
//	var resp = json_call_sync("fbaModelServices.get_reactions", [input]);
        return resp[0];
    }

    this.get_reactions_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_reactions", [input], 1, _callback, _error_callback)
    }

    this.get_compounds = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_compounds", [input]);
//	var resp = json_call_sync("fbaModelServices.get_compounds", [input]);
        return resp[0];
    }

    this.get_compounds_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_compounds", [input], 1, _callback, _error_callback)
    }

    this.get_media = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_media", [input]);
//	var resp = json_call_sync("fbaModelServices.get_media", [input]);
        return resp[0];
    }

    this.get_media_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_media", [input], 1, _callback, _error_callback)
    }

    this.get_biochemistry = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.get_biochemistry", [input]);
//	var resp = json_call_sync("fbaModelServices.get_biochemistry", [input]);
        return resp[0];
    }

    this.get_biochemistry_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.get_biochemistry", [input], 1, _callback, _error_callback)
    }

    this.genome_to_workspace = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.genome_to_workspace", [input]);
//	var resp = json_call_sync("fbaModelServices.genome_to_workspace", [input]);
        return resp[0];
    }

    this.genome_to_workspace_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.genome_to_workspace", [input], 1, _callback, _error_callback)
    }

    this.genome_to_fbamodel = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.genome_to_fbamodel", [input]);
//	var resp = json_call_sync("fbaModelServices.genome_to_fbamodel", [input]);
        return resp[0];
    }

    this.genome_to_fbamodel_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.genome_to_fbamodel", [input], 1, _callback, _error_callback)
    }

    this.export_fbamodel = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.export_fbamodel", [input]);
//	var resp = json_call_sync("fbaModelServices.export_fbamodel", [input]);
        return resp[0];
    }

    this.export_fbamodel_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.export_fbamodel", [input], 1, _callback, _error_callback)
    }

    this.runfba = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.runfba", [input]);
//	var resp = json_call_sync("fbaModelServices.runfba", [input]);
        return resp[0];
    }

    this.runfba_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.runfba", [input], 1, _callback, _error_callback)
    }

    this.checkfba = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.checkfba", [input]);
//	var resp = json_call_sync("fbaModelServices.checkfba", [input]);
        return resp[0];
    }

    this.checkfba_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.checkfba", [input], 1, _callback, _error_callback)
    }

    this.export_fba = function(input)
    {
	var resp = json_call_ajax_sync("fbaModelServices.export_fba", [input]);
//	var resp = json_call_sync("fbaModelServices.export_fba", [input]);
        return resp[0];
    }

    this.export_fba_async = function(input, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.export_fba", [input], 1, _callback, _error_callback)
    }

    this.gapfill_model = function(in_model, formulation)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapfill_model", [in_model, formulation]);
//	var resp = json_call_sync("fbaModelServices.gapfill_model", [in_model, formulation]);
        return resp[0];
    }

    this.gapfill_model_async = function(in_model, formulation, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapfill_model", [in_model, formulation], 1, _callback, _error_callback)
    }

    this.gapfill_check_results = function(in_gapfill)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapfill_check_results", [in_gapfill]);
//	var resp = json_call_sync("fbaModelServices.gapfill_check_results", [in_gapfill]);
        return resp[0];
    }

    this.gapfill_check_results_async = function(in_gapfill, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapfill_check_results", [in_gapfill], 1, _callback, _error_callback)
    }

    this.gapfill_to_html = function(in_gapfill)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapfill_to_html", [in_gapfill]);
//	var resp = json_call_sync("fbaModelServices.gapfill_to_html", [in_gapfill]);
        return resp[0];
    }

    this.gapfill_to_html_async = function(in_gapfill, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapfill_to_html", [in_gapfill], 1, _callback, _error_callback)
    }

    this.gapfill_integrate = function(in_gapfill, in_model)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapfill_integrate", [in_gapfill, in_model]);
//	var resp = json_call_sync("fbaModelServices.gapfill_integrate", [in_gapfill, in_model]);
        return resp;
    }

    this.gapfill_integrate_async = function(in_gapfill, in_model, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapfill_integrate", [in_gapfill, in_model], 0, _callback, _error_callback)
    }

    this.gapgen_model = function(in_model, formulation)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapgen_model", [in_model, formulation]);
//	var resp = json_call_sync("fbaModelServices.gapgen_model", [in_model, formulation]);
        return resp[0];
    }

    this.gapgen_model_async = function(in_model, formulation, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapgen_model", [in_model, formulation], 1, _callback, _error_callback)
    }

    this.gapgen_check_results = function(in_gapgen)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapgen_check_results", [in_gapgen]);
//	var resp = json_call_sync("fbaModelServices.gapgen_check_results", [in_gapgen]);
        return resp[0];
    }

    this.gapgen_check_results_async = function(in_gapgen, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapgen_check_results", [in_gapgen], 1, _callback, _error_callback)
    }

    this.gapgen_to_html = function(in_gapgen)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapgen_to_html", [in_gapgen]);
//	var resp = json_call_sync("fbaModelServices.gapgen_to_html", [in_gapgen]);
        return resp[0];
    }

    this.gapgen_to_html_async = function(in_gapgen, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapgen_to_html", [in_gapgen], 1, _callback, _error_callback)
    }

    this.gapgen_integrate = function(in_gapgen, in_model)
    {
	var resp = json_call_ajax_sync("fbaModelServices.gapgen_integrate", [in_gapgen, in_model]);
//	var resp = json_call_sync("fbaModelServices.gapgen_integrate", [in_gapgen, in_model]);
        return resp;
    }

    this.gapgen_integrate_async = function(in_gapgen, in_model, _callback, _error_callback)
    {
	json_call_ajax_async("fbaModelServices.gapgen_integrate", [in_gapgen, in_model], 0, _callback, _error_callback)
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

