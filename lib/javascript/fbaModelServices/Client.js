

function fbaModelServices(url, auth, auth_cb) {

    var _url = url;

    var _auth = auth ? auth : { 'token' : '',
                                'user_id' : ''};
    var _auth_cb = auth_cb;


    this.get_models = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_models", [input]);

        return resp[0];
    }

    this.get_models_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_models", [input], 1, _callback, _error_callback)
    }

    this.get_fbas = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_fbas", [input]);

        return resp[0];
    }

    this.get_fbas_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_fbas", [input], 1, _callback, _error_callback)
    }

    this.get_gapfills = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_gapfills", [input]);

        return resp[0];
    }

    this.get_gapfills_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_gapfills", [input], 1, _callback, _error_callback)
    }

    this.get_gapgens = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_gapgens", [input]);

        return resp[0];
    }

    this.get_gapgens_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_gapgens", [input], 1, _callback, _error_callback)
    }

    this.get_reactions = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_reactions", [input]);

        return resp[0];
    }

    this.get_reactions_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_reactions", [input], 1, _callback, _error_callback)
    }

    this.get_compounds = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_compounds", [input]);

        return resp[0];
    }

    this.get_compounds_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_compounds", [input], 1, _callback, _error_callback)
    }

    this.get_alias = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_alias", [input]);

        return resp[0];
    }

    this.get_alias_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_alias", [input], 1, _callback, _error_callback)
    }

    this.get_aliassets = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_aliassets", [input]);

        return resp[0];
    }

    this.get_aliassets_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_aliassets", [input], 1, _callback, _error_callback)
    }

    this.get_media = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_media", [input]);

        return resp[0];
    }

    this.get_media_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_media", [input], 1, _callback, _error_callback)
    }

    this.get_biochemistry = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_biochemistry", [input]);

        return resp[0];
    }

    this.get_biochemistry_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_biochemistry", [input], 1, _callback, _error_callback)
    }

    this.get_ETCDiagram = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.get_ETCDiagram", [input]);

        return resp[0];
    }

    this.get_ETCDiagram_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.get_ETCDiagram", [input], 1, _callback, _error_callback)
    }

    this.import_probanno = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.import_probanno", [input]);

        return resp[0];
    }

    this.import_probanno_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.import_probanno", [input], 1, _callback, _error_callback)
    }

    this.genome_object_to_workspace = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.genome_object_to_workspace", [input]);

        return resp[0];
    }

    this.genome_object_to_workspace_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.genome_object_to_workspace", [input], 1, _callback, _error_callback)
    }

    this.genome_to_workspace = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.genome_to_workspace", [input]);

        return resp[0];
    }

    this.genome_to_workspace_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.genome_to_workspace", [input], 1, _callback, _error_callback)
    }

    this.add_feature_translation = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.add_feature_translation", [input]);

        return resp[0];
    }

    this.add_feature_translation_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.add_feature_translation", [input], 1, _callback, _error_callback)
    }

    this.genome_to_fbamodel = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.genome_to_fbamodel", [input]);

        return resp[0];
    }

    this.genome_to_fbamodel_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.genome_to_fbamodel", [input], 1, _callback, _error_callback)
    }

    this.import_fbamodel = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.import_fbamodel", [input]);

        return resp[0];
    }

    this.import_fbamodel_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.import_fbamodel", [input], 1, _callback, _error_callback)
    }

    this.import_template_fbamodel = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.import_template_fbamodel", [input]);

        return resp[0];
    }

    this.import_template_fbamodel_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.import_template_fbamodel", [input], 1, _callback, _error_callback)
    }

    this.export_fbamodel = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.export_fbamodel", [input]);

        return resp[0];
    }

    this.export_fbamodel_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.export_fbamodel", [input], 1, _callback, _error_callback)
    }

    this.export_object = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.export_object", [input]);

        return resp[0];
    }

    this.export_object_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.export_object", [input], 1, _callback, _error_callback)
    }

    this.export_genome = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.export_genome", [input]);

        return resp[0];
    }

    this.export_genome_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.export_genome", [input], 1, _callback, _error_callback)
    }

    this.adjust_model_reaction = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.adjust_model_reaction", [input]);

        return resp[0];
    }

    this.adjust_model_reaction_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.adjust_model_reaction", [input], 1, _callback, _error_callback)
    }

    this.adjust_biomass_reaction = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.adjust_biomass_reaction", [input]);

        return resp[0];
    }

    this.adjust_biomass_reaction_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.adjust_biomass_reaction", [input], 1, _callback, _error_callback)
    }

    this.addmedia = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.addmedia", [input]);

        return resp[0];
    }

    this.addmedia_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.addmedia", [input], 1, _callback, _error_callback)
    }

    this.export_media = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.export_media", [input]);

        return resp[0];
    }

    this.export_media_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.export_media", [input], 1, _callback, _error_callback)
    }

    this.runfba = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.runfba", [input]);

        return resp[0];
    }

    this.runfba_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.runfba", [input], 1, _callback, _error_callback)
    }

    this.export_fba = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.export_fba", [input]);

        return resp[0];
    }

    this.export_fba_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.export_fba", [input], 1, _callback, _error_callback)
    }

    this.import_phenotypes = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.import_phenotypes", [input]);

        return resp[0];
    }

    this.import_phenotypes_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.import_phenotypes", [input], 1, _callback, _error_callback)
    }

    this.simulate_phenotypes = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.simulate_phenotypes", [input]);

        return resp[0];
    }

    this.simulate_phenotypes_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.simulate_phenotypes", [input], 1, _callback, _error_callback)
    }

    this.export_phenotypeSimulationSet = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.export_phenotypeSimulationSet", [input]);

        return resp[0];
    }

    this.export_phenotypeSimulationSet_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.export_phenotypeSimulationSet", [input], 1, _callback, _error_callback)
    }

    this.integrate_reconciliation_solutions = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.integrate_reconciliation_solutions", [input]);

        return resp[0];
    }

    this.integrate_reconciliation_solutions_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.integrate_reconciliation_solutions", [input], 1, _callback, _error_callback)
    }

    this.queue_runfba = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.queue_runfba", [input]);

        return resp[0];
    }

    this.queue_runfba_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.queue_runfba", [input], 1, _callback, _error_callback)
    }

    this.queue_gapfill_model = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.queue_gapfill_model", [input]);

        return resp[0];
    }

    this.queue_gapfill_model_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.queue_gapfill_model", [input], 1, _callback, _error_callback)
    }

    this.queue_gapgen_model = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.queue_gapgen_model", [input]);

        return resp[0];
    }

    this.queue_gapgen_model_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.queue_gapgen_model", [input], 1, _callback, _error_callback)
    }

    this.queue_wildtype_phenotype_reconciliation = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.queue_wildtype_phenotype_reconciliation", [input]);

        return resp[0];
    }

    this.queue_wildtype_phenotype_reconciliation_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.queue_wildtype_phenotype_reconciliation", [input], 1, _callback, _error_callback)
    }

    this.queue_reconciliation_sensitivity_analysis = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.queue_reconciliation_sensitivity_analysis", [input]);

        return resp[0];
    }

    this.queue_reconciliation_sensitivity_analysis_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.queue_reconciliation_sensitivity_analysis", [input], 1, _callback, _error_callback)
    }

    this.queue_combine_wildtype_phenotype_reconciliation = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.queue_combine_wildtype_phenotype_reconciliation", [input]);

        return resp[0];
    }

    this.queue_combine_wildtype_phenotype_reconciliation_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.queue_combine_wildtype_phenotype_reconciliation", [input], 1, _callback, _error_callback)
    }

    this.jobs_done = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.jobs_done", [input]);

        return resp[0];
    }

    this.jobs_done_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.jobs_done", [input], 1, _callback, _error_callback)
    }

    this.run_job = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.run_job", [input]);

        return resp[0];
    }

    this.run_job_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.run_job", [input], 1, _callback, _error_callback)
    }

    this.set_cofactors = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.set_cofactors", [input]);

        return resp[0];
    }

    this.set_cofactors_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.set_cofactors", [input], 1, _callback, _error_callback)
    }

    this.find_reaction_synonyms = function(input)
    {
        var resp = json_call_ajax_sync("fbaModelServices.find_reaction_synonyms", [input]);

        return resp[0];
    }

    this.find_reaction_synonyms_async = function(input, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.find_reaction_synonyms", [input], 1, _callback, _error_callback)
    }

    this.role_to_reactions = function(params)
    {
        var resp = json_call_ajax_sync("fbaModelServices.role_to_reactions", [params]);

        return resp[0];
    }

    this.role_to_reactions_async = function(params, _callback, _error_callback)
    {
        json_call_ajax_async("fbaModelServices.role_to_reactions", [params], 1, _callback, _error_callback)
    }

    /*
     * JSON call using jQuery method.
     */

    function json_call_ajax_sync(method, params)
    {
        var rpc = { 'params' : params,
                    'method' : method,
                    'version': "1.1",
                    'id': String(Math.random()).slice(2),
        };
        
        var body = JSON.stringify(rpc);
        var resp_txt;
        var code;

	var token = _auth.token;
	if (_auth_cb)
	{
	    token = _auth_cb();
	}

        var x = jQuery.ajax({
		"async": false,
		dataType: "text",
		url: _url,
		beforeSend: function (xhr){
		    if (token)
		    {
			xhr.setRequestHeader('Authorization', _auth.token);
		    }
		},
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
                    'id': String(Math.random()).slice(2),
        };
        
        var body = JSON.stringify(rpc);
        var resp_txt;
        var code;
        
	var token = _auth.token;
	if (_auth_cb)
	{
	    token = _auth_cb();
	}

        var x = jQuery.ajax({
		"async": true,
		dataType: "text",
		url: _url,
		beforeSend: function (xhr){
		    if (token)
		    {
			xhr.setRequestHeader('Authorization', token);
		    }
		},
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
}


