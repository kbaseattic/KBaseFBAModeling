ROOT_DEV_MODULE_DIR := $(abspath $(dir $lastword $(MAKEFILE_LIST)))
TOP_DIR = $(shell python -c "import os.path as p; print p.abspath('../..')")
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
DEFAULT_FBA_URL ?= https://kbase.us/services/KBaseFBAModeling
DEFAULT_OLDWS_URL ?= http://kbase.us/services/workspace
DEV_FBA_URL ?= http://140.221.85.73:4043

include $(TOP_DIR)/tools/Makefile.common

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))
SRC_PYTHON = $(wildcard scripts/*.py)
BIN_PYTHON = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PYTHON))))
# KB_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

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

all: bin server

bin: $(BIN_PERL) $(BIN_PYTHON)

server:
	echo "server target does nothing"

$(BIN_DIR)/%: scripts/%.pl 
	$(TOOLS_DIR)/wrap_perl '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

$(BIN_DIR)/%: scripts/%.py
	$(TOOLS_DIR)/wrap_python '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

CLIENT_TESTS = $(wildcard client-tests/*.t)
SCRIPT_TESTS = $(wildcard script-tests/*.sh)
SERVER_TESTS = $(wildcard server-tests/*.t)

test: test-service test-scripts test-client
	@echo "running server, script and client tests"

test-service:
	for t in $(SERVER_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/prove $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

test-scripts:
	for t in $(SCRIPT_TESTS) ; do \
		if [ -f $$t ] ; then \
			/bin/sh $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

test-client:
	for t in $(CLIENT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/prove $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

deploy: deploy-client deploy-service
deploy-all: deploy-client deploy-service

deploy-service: deploy-dir deploy-libs deploy-scripts deploy-services deploy-cfg deploy-kbscripts
deploy-client: deploy-dir deploy-libs deploy-scripts deploy-docs deploy-kbscripts

deploy-dir:
	if [ ! -d $(SERV_SERVICE_DIR) ] ; then mkdir $(SERV_SERVICE_DIR) ; fi
	if [ ! -d $(SERV_SERVICE_DIR)/webroot ] ; then mkdir $(SERV_SERVICE_DIR)/webroot ; fi

deploy-libs: configure-scripts
	rsync -arv lib/. $(TARGET)/lib/.

deploy-kbscripts:
	cp $(TARGET)/bin/fba-addaliases $(TARGET)/bin/kbfba-addaliases
	cp $(TARGET)/bin/fba-addmedia $(TARGET)/bin/kbfba-addmedia
	cp $(TARGET)/bin/fba-adjustbiomass $(TARGET)/bin/kbfba-adjustbiomass
	cp $(TARGET)/bin/fba-adjustmapcomplex $(TARGET)/bin/kbfba-adjustmapcomplex
	cp $(TARGET)/bin/fba-adjustmaprole $(TARGET)/bin/kbfba-adjustmaprole
	cp $(TARGET)/bin/fba-adjustmapsubsystem $(TARGET)/bin/kbfba-adjustmapsubsystem
	cp $(TARGET)/bin/fba-adjustmodel $(TARGET)/bin/kbfba-adjustmodel
	cp $(TARGET)/bin/fba-adjusttempbiocpd $(TARGET)/bin/kbfba-adjusttempbiocpd
	cp $(TARGET)/bin/fba-adjusttempbiomass $(TARGET)/bin/kbfba-adjusttempbiomass
	cp $(TARGET)/bin/fba-adjusttemprxn $(TARGET)/bin/kbfba-adjusttemprxn
	cp $(TARGET)/bin/fba-buildfbamodel $(TARGET)/bin/kbfba-buildfbamodel
	cp $(TARGET)/bin/fba-exportfba $(TARGET)/bin/kbfba-exportfba
	cp $(TARGET)/bin/fba-exportfbamodel $(TARGET)/bin/kbfba-exportfbamodel
	cp $(TARGET)/bin/fba-exportgenome $(TARGET)/bin/kbfba-exportgenome
	cp $(TARGET)/bin/fba-exportmedia $(TARGET)/bin/kbfba-exportmedia
	cp $(TARGET)/bin/fba-exportobject $(TARGET)/bin/kbfba-exportobject
	cp $(TARGET)/bin/fba-exportphenosim $(TARGET)/bin/kbfba-exportphenosim
	cp $(TARGET)/bin/fba-gapfill $(TARGET)/bin/kbfba-gapfill
	cp $(TARGET)/bin/fba-gapgen $(TARGET)/bin/kbfba-gapgen
	cp $(TARGET)/bin/fba-getbio $(TARGET)/bin/kbfba-getbio
	cp $(TARGET)/bin/fba-getcompounds $(TARGET)/bin/kbfba-getcompounds
	cp $(TARGET)/bin/fba-getfbas $(TARGET)/bin/kbfba-getfbas
	cp $(TARGET)/bin/fba-getgapfills $(TARGET)/bin/kbfba-getgapfills
	cp $(TARGET)/bin/fba-getgapgens $(TARGET)/bin/kbfba-getgapgens
	cp $(TARGET)/bin/fba-getmap $(TARGET)/bin/kbfba-getmap
	cp $(TARGET)/bin/fba-getmedia $(TARGET)/bin/kbfba-getmedia
	cp $(TARGET)/bin/fba-getmodels $(TARGET)/bin/kbfba-getmodels
	cp $(TARGET)/bin/fba-getreactions $(TARGET)/bin/kbfba-getreactions
	cp $(TARGET)/bin/fba-gettemplate $(TARGET)/bin/kbfba-gettemplate
	cp $(TARGET)/bin/fba-importfbamodel $(TARGET)/bin/kbfba-importfbamodel
	cp $(TARGET)/bin/fba-importpheno $(TARGET)/bin/kbfba-importpheno
	cp $(TARGET)/bin/fba-importprobanno $(TARGET)/bin/kbfba-importprobanno
	cp $(TARGET)/bin/fba-importtemplate $(TARGET)/bin/kbfba-importtemplate
	cp $(TARGET)/bin/fba-importtranslation $(TARGET)/bin/kbfba-importtranslation
	cp $(TARGET)/bin/fba-integratesolution $(TARGET)/bin/kbfba-integratesolution
	cp $(TARGET)/bin/fba-loadgenome $(TARGET)/bin/kbfba-loadgenome
	cp $(TARGET)/bin/fba-queuefba $(TARGET)/bin/kbfba-queuefba
	cp $(TARGET)/bin/fba-runfba $(TARGET)/bin/kbfba-runfba
	cp $(TARGET)/bin/fba-runjob $(TARGET)/bin/kbfba-runjob
	cp $(TARGET)/bin/fba-simpheno $(TARGET)/bin/kbfba-simpheno
	cp $(TARGET)/bin/fba-url $(TARGET)/bin/kbfba-url
	cp $(TARGET)/bin/ws-getjob $(TARGET)/bin/kbws-getjob
	cp $(TARGET)/bin/ws-jobs $(TARGET)/bin/kbws-jobs
	cp $(TARGET)/bin/ws-resetjob $(TARGET)/bin/kbws-resetjob
	cp $(TARGET)/bin/ws-checkjob $(TARGET)/bin/kbws-checkjob

deploy-services:
	tpage $(SERV_TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERV_SERVICE)/start_service; \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/start_service; \
	tpage $(SERV_TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERV_SERVICE)/stop_service; \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/stop_service; \
	tpage $(SERV_TPAGE_ARGS) service/process.tt > $(TARGET)/services/$(SERV_SERVICE)/process.$(SERV_SERVICE); \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/process.$(SERV_SERVICE); \

deploy-docs:
	if [ ! -d docs ] ; then mkdir -p docs ; fi
	$(KB_RUNTIME)/bin/pod2html -t "fbaModelServices" lib/Bio/KBase/fbaModelServices/Client.pm > docs/fbaModelServices.html
	cp docs/*html $(SERV_SERVICE_DIR)/webroot/.

compile-typespec:
	mkdir -p lib/biokbase/fbaModelServices
	touch lib/biokbase/__init__.py
	touch lib/biokbase/fbaModelServices/__init__.py
	compile_typespec \
	-impl Bio::KBase::fbaModelServices::Impl \
	-service Bio::KBase::fbaModelServices::Server \
	-psgi fbaModelServices.psgi \
	-client Bio::KBase::fbaModelServices::Client \
	-js javascript/fbaModelServices/Client \
	-py biokbase/fbaModelServices/Client \
	fbaModelServices.spec lib

# configure endpoints used by scripts, and possibly other script runtime options in the future
configure-scripts:
	$(DEPLOY_RUNTIME)/bin/tpage \
		--define defaultFBAURL=$(DEFAULT_FBA_URL) \
		--define defaultOldWSURL=$(DEFAULT_OLDWS_URL) \
		--define FBAprodURL=$(DEFAULT_FBA_URL) \
		--define FBAlocalURL=http://127.0.0.1:$(SERV_SERVICE_PORT) \
		--define FBAdevURL=$(DEV_FBA_URL) \
		lib/Bio/KBase/$(SERV_SERVICE)/ScriptConfig.tt > lib/Bio/KBase/$(SERV_SERVICE)/ScriptConfig.pm

include $(TOP_DIR)/tools/Makefile.common.rules
