function KBase_Media(tabwidget) {
    var self = this;
	this.tabwidget = tabwidget;
	
	this.set_metadata = function (indata) {
		this.meta = indata;
		this.overview.wsid = indata[7]."/".indata[1];
		this.overview.objecttype = indata[2];
		this.overview.owner = indata[5];
		this.overview.instance = indata[4];
		this.overview.moddate = indata[3];
		this.overview.name = indata[10]["Name"];
		this.overview.source = indata[10]["Source ID"];		
		this.overview.minimal = indata[10]["Is Minimal"];
		this.overview.defined = indata[10]["Is Defined"];		
		this.overview.numcompounds = indata[10]["Number compounds"];
	};
	
	this.set_data = function (indata) {
		this.data = indata;
		this.mediacompounds = this.data.mediacompounds;
		this.reagents = this.data.reagents;
		this.cpdhash = {};
		var cpdarray = [];
		for (var i=0; i< this.modelcompounds.length; i++) {
			var cpd = this.modelcompounds[i];
			cpd.id = cpd.compound_ref.split("/").pop();
			this.cpdhash[cpd.id] = cpd;
			cpdarray.push(cpd.id);
		}
		var cpddata = this.tabwidget.get_compound_data(cpdarray);
		for (var i=0; i< this.modelcompounds.length; i++) {
			var cpd = this.modelcompounds[i];
			cpd.name = cpddata[i].name;
			cpd.formula = cpddata[i].formula;
			cpd.charge = cpddata[i].charge;
			cpd.deltaG = cpddata[i].deltaG;
			cpd.deltaGErr = cpddata[i].deltaGErr;
			cpd.abbrev = cpddata[i].abbrev;
		}
	};
	
	this.CompoundTab = function (id) {
		var cpd = this.cpdhash[id];
		return [{
			"label": "Compound",
			"data": cpd.id,
		}, {
			"label": "Name",
			"key": "name"
		}, {
			"label": "Formula",
			"key": "formula"
		}, {
			"label": "Charge",
			"key": "charge"
		}, {
			"label": "deltaG",
			"key": "deltaG"
		}, {
			"label": "Max flux",
			"key": "maxFlux"
		}, {
			"label": "Min flux",
			"key": "minFlux"
		}, {
			"label": "Concentration",
			"key": "concentration"
		}];
	}
	
    this.tabList = [{
		"key": "overview",
		"name": "Overview",
		"type": "verticaltbl",
		"rows": [{
			"label": "ID",
			"key": "wsid"
		},{
			"label": "Object type",
			"key": "objecttype",
			"type": "typelink"
		},{
			"label": "Owner",
			"key": "owner"
		},{
			"label": "Version",
			"key": "instance"
		},{
			"label": "Mod-date",
			"key": "moddate"
		},{
			"label": "Name",
			"key": "name"
		},{
			"label": "Source",
			"key": "source"
		},{
			"label": "Is minimal",
			"key": "minimal",
		},{
			"label": "Is defined",
			"key": "defined"
		},{
			"label": "Number compounds",
			"key": "numcompounds"
		}]   		
	}, {
		"key": "mediacompounds",
		"name": "Media compounds",
		"columns": [{
			"label": "Compound",
			"key": "id",
			"type": "tabLink",
			"function": "CompoundTab",
		}, {
			"label": "Name",
			"key": "name"
		}, {
			"label": "Formula",
			"key": "formula"
		}, {
			"label": "Charge",
			"key": "charge"
		}, {
			"label": "Compartment",
			"key": "compartment",
			"type": "tabLink",
			"function": "CompartmentTab"
		}]
	}, {
		"key": "reagents",
		"name": "Reagents",
		"columns": [{
			"label": "Reagent",
			"key": "id",
		}, {
			"label": "Name",
			"key": "name",
		}, {
			"label": "Concentration",
			"key": "concentration",
		}]
	}];
}