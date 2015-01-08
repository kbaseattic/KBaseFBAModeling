function KBase_FBAModel(modeltabs) {
    var self = this;
	this.modeltabs = modeltabs;
	
	this.set_metadata = function (indata) {
		this.meta = indata;
		this.overview.wsid = indata[7]."/".indata[1];
		this.overview.objecttype = indata[2];
		this.overview.owner = indata[5];
		this.overview.instance = indata[4];
		this.overview.moddate = indata[3];
		this.overview.name = indata[10]["Name"];
		this.overview.source = indata[10]["Source"]+"/"+indata[10]["Source ID"];		
		this.overview.genome = indata[10]["Genome"];
		this.overview.modeltype = indata[10]["Type"];		
		this.overview.numreactions = indata[10]["Number reactions"];
		this.overview.numcompounds = indata[10]["Number compounds"];
		this.overview.numcompartments = indata[10]["Number compartments"];
		this.overview.numbiomass = indata[10]["Number biomasses"];
		this.overview.numgapfills = indata[10]["Number gapfills"];
	};
	
	this.set_data = function (indata) {
		this.data = indata;
		this.modelreactions = this.data.modelreactions;
		this.modelcompounds = this.data.modelcompounds;
		this.modelgenes = [];
		this.modelcompartments = this.data.modelcompartments;
		this.biomasses = this.data.biomasses;
		this.gapfillings = this.data.gapfillings;
		this.cpdhash = {};
		this.rxnhash = {};
		this.cmphash = {};
		this.genehash = {};
		for (var i=0; i< this.modelcompartments.length; i++) {
			var cmp = this.modelcompartments[i];
			this.cmphash[cmp.id] = cmp;
		}
		for (var i=0; i< this.modelcompounds.length; i++) {
			var cpd = this.modelcompounds[i];
			cpd.cmpkbid = cpd.modelcompartment_ref.split("/").pop();
			cpd.cpdkbid = cpd.compound_ref.split("/").pop();
			if (cpd.name === undefined) {
				cpd.name = cpd.id;
			}
			cpd.name = cpd.name.replace(/_[a-zA-z]\d+$/, '');
			this.cpdhash[cpd.id] = cpd;
			if (cpd.cpdkbid != "cpd00000") {
				this.cpdhash[cpd.cpdkbid+"_"+cpd.cmpkbid] = cpd;
			}
		}
		for (var i=0; i< this.modelreactions.length; i++) {
			var rxn = this.modelreactions[i];
			rxn.rxnkbid = rxn.reaction_ref.split("/").pop();
			rxn.cmpkbid = rxn.modelcompartment_ref.split("/").pop();
			rxn.dispid = rxn.id.replace(/_[a-zA-z]\d+$/, '')+"["+rxn.cmpkbid+"]";
			rxn.name = rxn.name.replace(/_[a-zA-z]\d+$/, '');
			if (rxn.name == "CustomReaction") {
				rxn.name = rxn.id.replace(/_[a-zA-z]\d+$/, '');
			}
			this.rxnhash[rxn.id] = rxn;
			if (rxn.rxnkbid != "rxn00000") {
				this.rxnhash[rxn.rxnkbid+"_"+rxn.cmpkbid] = rxn;
				if (rxn.rxnkbid+"_"+rxn.cmpkbid != rxn.id) {
					rxn.dispid += "<br>("+rxn.rxnkbid+")";
				}
			}
			var reactants = "";
			var products = "";
			var sign = "<=>";
			if (rxn.direction == ">") {
				sign = "=>";
			} else if (rxn.direction == "<") {
				sign = "<=";
			}
			for (var j=0; j< rxn.modelReactionReagents.length; j++) {
				var rgt = rxn.modelReactionReagents[j];
				rgt.cpdkbid = rgt.modelcompound_ref.split("/").pop();
				if (rgt.coefficient < 0) {
					if (reactants.length > 0) {
						reactants += " + ";
					}
					if (rgt.coefficient != -1) {
						var abscoef = Math.round(-1*100*rgt.coefficient)/100;
						reactants += "("+abscoef+") ";
					}
					reactants += this.cpdhash[rgt.cpdkbid].name+"["+this.cpdhash[rgt.cpdkbid].cmpkbid+"]";
				} else {
					if (products.length > 0) {
						products += " + ";
					}
					if (rgt.coefficient != 1) {
						var abscoef = Math.round(100*rgt.coefficient)/100;
						products += "("+abscoef+") ";
					}
					products += this.cpdhash[rgt.cpdkbid].name+"["+this.cpdhash[rgt.cpdkbid].cmpkbid+"]";
				}
			}
			rxn.ftrhash = {};
			for (var j=0; j< rxn.modelReactionProteins.length; j++) {
				var prot = rxn.modelReactionProteins[j];
				for (var k=0; k< prot.modelReactionProteinSubunits.length; k++) {
					var subunit = prot.modelReactionProteinSubunits[k];
					for (var m=0; m< subunit.feature_refs.length; m++) {
						rxn.ftrhash[subunit.feature_refs[m].split("/").pop()] = 1;
					}
				}
			}
			rxn.dispfeatures = "";
			rxn.genes = [];
			for (var gene in rxn.ftrhash) {
				if (rxn.dispfeatures.length > 0) {
					rxn.dispfeatures += "<br>";
				}
				rxn.genes.push(gene);
			}
			rxn.equation = reactants+" "+sign+" "+products;
		}
	};
	
	this.ReactionTab = function (id) {
		var rxn = this.rxnhash[id];
		return [{
				"label": "ID",
				"data": rxn.id
			},{
				"label": "Name",
				"data": rxn.name
			},{
				"label": "Equation",
				"data": rxn.equation
			},{
				"label": "Genes",
				"data": rxn.genes,
				"type": "tabLinkArray"
		}];
	}
	
	this.GeneTab = function (id) {
		var gene = this.genehash[id];
		return [{
				"label": "ID",
				"data": gene.id
			},{
				"label": "Reactions",
				"data": rxn.reactions,
				"type": "tabLinkArray"
		}];
	}
	
	this.CompoundTab = function (id) {
		var cpd = this.genehash[id];
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
			"label": "Compartment",
			"key": "compartment",
			"type": "tabLink",
			"function": "CompartmentTab"
		}];
	}
	
	this.CompartmentTab = function (id) {
		return [[]];
	}
	
	this.BiomassTab = function (id) {
		return [[]];
	}
	
	this.GapfillTab = function (id) {
		return [[]];
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
			"label": "Genome",
			"key": "genome",
			"type": "wslink"
		},{
			"label": "Model type",
			"key": "modeltype"
		},{
			"label": "Number reactions",
			"key": "numreactions"
		},{
			"label": "Number compounds",
			"key": "numcompounds"
		},{
			"label": "Number compartments",
			"key": "numcompartments"
		},{
			"label": "Number biomass",
			"key": "numbiomass"
		},{
			"label": "Number gapfills",
			"key": "numgapfills"
		}]   		
	}, {
		"key": "modelreactions",
		"name": "Reactions",
		"columns": [{
			"label": "Reaction",
			"key": "dispid",
			"type": "tabLink",
			"tabLinkKey": "id"
			"function": "ReactionTab",
			"width": "15%"
		}, {
			"label": "Name",
			"key": "name"
		}, {
			"label": "Equation",
			"key": "equation"
		}, {
			"label": "Genes",
			"key": "genes",
			"type": "tabLinkArray",
			"function": "GeneTab",
		}]
	}, {
		"key": "modelcompounds",
		"name": "Compounds",
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
		"key": "modelgenes",
		"name": "Genes",
		"columns": [{
			"label": "Gene",
			"key": "id",
			"type": "tabLink",
			"function": "GeneTab"
		}, {
			"label": "Reactions",
			"key": "reactions",
			"type": "tabLinkArray",
			"function": "ReactionTab",
		}]
	}, {
		"key": "modelcompartments",
		"name": "Compartments",
		"columns": [{
			"label": "Compartment",
			"key": "id",
			"type": "tabLink",
			"function": "CompartmentTab"
		}, {
			"label": "Name",
			"key": "label"
		}, {
			"label": "pH",
			"key": "pH"
		}, {
			"label": "Potential",
			"key": "potential"
		}]
	}, {
		"key": "biomasscpds",
		"name": "Biomass",
		"columns": [{
			"label": "Biomass",
			"key": "biomass",
			"type": "tabLink",
			"function": "BiomassTab"
		}, {
			"label": "Compound",
			"key": "id",
			"type": "tabLink",
			"function": "CompoundTab"
		}, {
			"label": "Name",
			"key": "name"
		}, {
			"label": "Coefficient",
			"key": "coefficient"
		}, {
			"label": "Compartment",
			"key": "compartment",
			"type": "tabLink",
			"function": "CompartmentTab"
		}]
	}, {
		"key": "gapfillings",
		"name": "Gapfilling",
		"columns": [{
			"label": "Gapfill",
			"key": "id",
			"type": "tabLink",
			"function": "GapfillTab"
		}, {
			"label": "Integrated",
			"key": "integrated"
		}, {
			"label": "Media",
			"key": "media_ref",
			"type": "wslink"
		}, {
			"label": "FBA",
			"key": "fba_ref",
			"type": "wslink"
		}]
	}];
}