ROOT_DEV_MODULE_DIR := $(abspath $(dir $lastword $(MAKEFILE_LIST)))
TOP_DIR = ../..
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
 
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

deploy-service: deploy-dir deploy-libs deploy-scripts deploy-services deploy-cfg
deploy-client: deploy-dir deploy-libs deploy-fba-scripts deploy-docs

deploy-fba-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-addaliases.pl" $(TARGET)/bin/kbfba-addaliases ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-addmedia.pl" $(TARGET)/bin/kbfba-addmedia ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjustbiomass.pl" $(TARGET)/bin/kbfba-adjustbiomass ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjustmapcomplex.pl" $(TARGET)/bin/kbfba-adjustmapcomplex ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjustmaprole.pl" $(TARGET)/bin/kbfba-adjustmaprole ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjustmapsubsystem.pl" $(TARGET)/bin/kbfba-adjustmapsubsystem ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjustmodel.pl" $(TARGET)/bin/kbfba-adjustmodel ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjusttempbiocpd.pl" $(TARGET)/bin/kbfba-adjusttempbiocpd ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjusttempbiomass.pl" $(TARGET)/bin/kbfba-adjusttempbiomass ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-adjusttemprxn.pl" $(TARGET)/bin/kbfba-adjusttemprxn ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-buildfbamodel.pl" $(TARGET)/bin/kbfba-buildfbamodel ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-exportfba.pl" $(TARGET)/bin/kbfba-exportfba ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-exportfbamodel.pl" $(TARGET)/bin/kbfba-exportfbamodel ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-exportgenome.pl" $(TARGET)/bin/kbfba-exportgenome ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-exportmedia.pl" $(TARGET)/bin/kbfba-exportmedia ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-exportobject.pl" $(TARGET)/bin/kbfba-exportobject ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-exportphenosim.pl" $(TARGET)/bin/kbfba-exportphenosim ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-gapfill.pl" $(TARGET)/bin/kbfba-gapfill ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-gapgen.pl" $(TARGET)/bin/kbfba-gapgen ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getbio.pl" $(TARGET)/bin/kbfba-getbio ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getcompounds.pl" $(TARGET)/bin/kbfba-getcompounds ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getfbas.pl" $(TARGET)/bin/kbfba-getfbas ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getgapfills.pl" $(TARGET)/bin/kbfba-getgapfills ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getgapgens.pl" $(TARGET)/bin/kbfba-getgapgens ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getmap.pl" $(TARGET)/bin/kbfba-getmap ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getmedia.pl" $(TARGET)/bin/kbfba-getmedia ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getmodels.pl" $(TARGET)/bin/kbfba-getmodels ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-getreactions.pl" $(TARGET)/bin/kbfba-getreactions ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-gettemplate.pl" $(TARGET)/bin/kbfba-gettemplate ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-importfbamodel.pl" $(TARGET)/bin/kbfba-importfbamodel ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-importpheno.pl" $(TARGET)/bin/kbfba-importpheno ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-importprobanno.pl" $(TARGET)/bin/kbfba-importprobanno ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-importtemplate.pl" $(TARGET)/bin/kbfba-importtemplate ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-importtranslation.pl" $(TARGET)/bin/kbfba-importtranslation ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-integratesolution.pl" $(TARGET)/bin/kbfba-integratesolution ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-jobdone.pl" $(TARGET)/bin/kbfba-jobdone ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-loadgenome.pl" $(TARGET)/bin/kbfba-loadgenome ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-queuefba.pl" $(TARGET)/bin/kbfba-queuefba ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-runfba.pl" $(TARGET)/bin/kbfba-runfba ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-runjob.pl" $(TARGET)/bin/kbfba-runjob ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-simpheno.pl" $(TARGET)/bin/kbfba-simpheno ; \
	$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/fba-url.pl" $(TARGET)/bin/kbfba-url ; \


kbfba-addaliases	modeling
kbfba-addmedia	modeling
kbfba-adjustbiomass	modeling
kbfba-adjustmapcomplex	modeling
kbfba-adjustmaprole	modeling
kbfba-adjustmapsubsystem	modeling
kbfba-adjustmodel	modeling
kbfba-adjusttempbiocpd	modeling
kbfba-adjusttempbiomass	modeling
kbfba-adjusttemprxn	modeling
kbfba-buildfbamodel	modeling
kbfba-exportfba	modeling
kbfba-exportfbamodel	modeling
kbfba-exportgenome	modeling
kbfba-exportmedia	modeling
kbfba-exportobject	modeling
kbfba-exportphenosim	modeling
kbfba-gapfill	modeling
kbfba-gapgen	modeling
kbfba-getbio	modeling
kbfba-getcompounds	modeling
kbfba-getfbas	modeling
kbfba-getgapfills	modeling
kbfba-getgapgens	modeling
kbfba-getmap	modeling
kbfba-getmedia	modeling
kbfba-getmodels	modeling
kbfba-getreactions	modeling
kbfba-gettemplate	modeling
kbfba-importfbamodel	modeling
kbfba-importpheno	modeling
kbfba-importprobanno	modeling
kbfba-importtemplate	modeling
kbfba-importtranslation	modeling
kbfba-integratesolution	modeling
kbfba-jobdone	modeling
kbfba-loadgenome	modeling
kbfba-queuefba	modeling
kbfba-runfba	modeling
kbfba-runjob	modeling
kbfba-simpheno	modeling
kbfba-url	modeling

deploy-dir:
	if [ ! -d $(SERV_SERVICE_DIR) ] ; then mkdir $(SERV_SERVICE_DIR) ; fi
	if [ ! -d $(SERV_SERVICE_DIR)/webroot ] ; then mkdir $(SERV_SERVICE_DIR)/webroot ; fi

#deploy-scripts:
#	export KB_TOP=$(TARGET); \
#	export KB_RUNTIME=$(KB_RUNTIME); \
#	export KB_PERL_PATH=$(TARGET)/lib bash ; \
#	for src in $(SRC_PERL) ; do \
#		basefile=`basename $$src`; \
#		base=`basename $$src .pl`; \
#		echo install $$src $$base ; \
#		cp $$src $(TARGET)/plbin ; \
#		bash $(TOOLS_DIR)/wrap_perl.sh "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
#	done 

deploy-libs:
	rsync -arv lib/. $(TARGET)/lib/.

deploy-services:
	tpage $(SERV_TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERV_SERVICE)/start_service; \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/start_service; \
	tpage $(SERV_TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERV_SERVICE)/stop_service; \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/stop_service; \
	tpage $(SERV_TPAGE_ARGS) service/process.tt > $(TARGET)/services/$(SERV_SERVICE)/process.$(SERV_SERVICE); \
	chmod +x $(TARGET)/services/$(SERV_SERVICE)/process.$(SERV_SERVICE); \
	cp configs/KBaseMSConfig.json ${HOME}/.modelseed2
	echo "{\"user_options\":{\"MFATK_BIN\":\"$(TARGET)/bin/mfatoolkit\",\"MFATK_CACHE\":\"/tmp\"}}" > $(TARGET)/services/$(SERV_SERVICE)/config.json;

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

include $(TOP_DIR)/tools/Makefile.common.rules

