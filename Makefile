TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))

DEPLOY_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

SERVER_SPEC = ReconciliationAPI.spec
SERVER_MODULE = ReconciliationAPI
SERVICE = ReconciliationAPI
SERVICE_PORT = 7036

SERVICE_DIR = $(TARGET)/services/$(SERVICE)

TPAGE = $(DEPLOY_RUNTIME)/bin/tpage
TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT)


all: bin server

echo:
	@echo $(SERVICE_PORT)
what:
	@echo $(BIN_PERL)

server: lib/$(SERVER_MODULE)Server.pm

lib/$(SERVER_MODULE)Server.pm: $(SERVER_SPEC)
	compile_typespec $(SERVER_SPEC) lib

bin: $(BIN_PERL)

$(BIN_DIR)/%: scripts/%.pl 
	$(TOOLS_DIR)/wrap_perl '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

deploy: deploy-service

deploy-service: deploy-dir deploy-scripts deploy-libs deploy-services deploy-monit deploy-doc
deploy-client: deploy-dir deploy-scripts deploy-libs  deploy-doc

deploy-dir:
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/webroot ] ; then mkdir $(SERVICE_DIR)/webroot ; fi

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		bash $(TOOLS_DIR)/wrap_perl.sh "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done 

deploy-libs:
	rsync -arv lib/. $(TARGET)/lib/.

deploy-services:
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE)/start_service
	chmod +x $(TARGET)/services/$(SERVICE)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE)/stop_service

deploy-monit:
	$(TPAGE) $(TPAGE_ARGS) service/process.$(SERVICE).tt > $(TARGET)/services/$(SERVICE)/process.$(SERVICE)

deploy-doc:
	$(DEPLOY_RUNTIME)/bin/pod2html -t "ReconciliationAPI" lib/ReconciliationAPI.pm > doc/ReconciliationAPI.html
	cp doc/*html $(SERVICE_DIR)/webroot/.
