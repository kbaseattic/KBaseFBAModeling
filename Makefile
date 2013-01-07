ROOT_DEV_MODULE_DIR := $(abspath $(dir $lastword $(MAKEFILE_LIST)))
TOP_DIR = ../..
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
 
include $(TOP_DIR)/tools/Makefile.common

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))
KB_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

# SERVER_SPEC :  fbaModelServices.spec
# SERVER_MODULE : fbaModelServices
# SERVICE       : fbaModelServices
# SERVICE_PORT  : 7036 
# PSGI_PATH     : lib/fbaModelServices.psgi

# fbaModelServices
SERV_SERVER_SPEC = fbaModelServices.spec
SERV_SERVER_MODULE = fbaModelServices
SERV_SERVICE = fbaModelServices
SERV_PSGI_PATH = lib/fbaModelServices.psgi
SERV_SERVICE_PORT = 7036
SERV_SERVICE_DIR = $(TARGET)/services/$(SERV_SERVICE)
SERV_TPAGE = $(KB_RUNTIME)/bin/perl $(KB_RUNTIME)/bin/tpage
SERV_TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(KB_RUNTIME) --define kb_service_name=$(SERV_SERVICE) \
	--define kb_service_port=$(SERV_SERVICE_PORT) --define kb_service_psgi=$(SERV_PSGI_PATH)

CLIENT_TESTS = $(wildcard t/*.t)

all: bin server

bin: $(BIN_PERL)

server:
	echo "server target does nothing"

$(BIN_DIR)/%: scripts/%.pl 
	$(TOOLS_DIR)/wrap_perl '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

test: test-client

test-client:
	for t in $(CLIENT_TESTS) ; do \
		echo $$t ; \
		$(DEPLOY_RUNTIME)/bin/perl $$t ; \
		if [ $$? -ne 0 ] ; then \
			exit 1 ; \
		fi \
	done

deploy: deploy-client deploy-service
deploy-all: deploy-client deploy-service

deploy-service: deploy-dir deploy-libs deploy-scripts deploy-services
deploy-client: deploy-dir deploy-libs deploy-scripts deploy-docs

deploy-dir:
	if [ ! -d $(SERV_SERVICE_DIR) ] ; then mkdir $(SERV_SERVICE_DIR) ; fi
	if [ ! -d $(SERV_SERVICE_DIR)/webroot ] ; then mkdir $(SERV_SERVICE_DIR)/webroot ; fi

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(KB_RUNTIME); \
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
	tpage $(SERV_TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERV_SERVICE)/start_service; \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/start_service; \
	tpage $(SERV_TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERV_SERVICE)/stop_service; \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/stop_service; \
	tpage $(SERV_TPAGE_ARGS) service/process.tt > $(TARGET)/services/$(SERV_SERVICE)/process.$(SERV_SERVICE); \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/process.$(SERV_SERVICE); 

deploy-docs:
	if [ ! -d doc ] ; then mkdir doc ; fi
	cd lib/Bio/KBase; \
	for f in fbaModel*/*.pm ; do \
		dirname=`dirname $$f`; \
		basename=`basename $$f .pm`; \
		name="$$dirname::$$basename"; \
		echo $$name; \
		$(KB_RUNTIME)/bin/pod2html -t "$$name" $$f > "../../../doc/$$name.html"; \
	done
	cp doc/*html $(SERV_SERVICE_DIR)/webroot/.

compile-typespec:
	compile_typespec \
	-impl Bio::KBase::fbaModelServices::Impl \
	-service Bio::KBase::fbaModelServices::Server \
	-psgi fbaModelServices.psgi \
	-client Bio::KBase::fbaModelServices::Client \
	-js javascript/fbaModelServices/Client \
	-py biokbase/fbaModelServices/Client \
	fbaModelServices.spec lib
