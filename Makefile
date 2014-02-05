ROOT_DEV_MODULE_DIR := $(abspath $(dir $lastword $(MAKEFILE_LIST)))
TARGET = $(KB_TOP)/../
TOOLS_DIR = $(KB_TOP)/tools
 
include $(KB_TOP)/tools/Makefile.common

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
	$(KB_TOP)/tools/wrap_perl '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

$(BIN_DIR)/%: scripts/%.py
	$(KB_TOP)/tools/wrap_python '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

CLIENT_TESTS = $(wildcard client-tests/*.t)
SCRIPT_TESTS = $(wildcard script-tests/*.sh)
SERVER_TESTS = $(wildcard server-tests/*.t)

test: test-service test-scripts test-client
	@echo "running server, script and client tests"

test-service:
	for t in $(SERVER_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(KB_RUNTIME)/bin/prove $$t ; \
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
			$(KB_RUNTIME)/bin/prove $$t ; \
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
	export KB_PERL_PATH=$(TARGET)/lib ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-addaliases.pl" $(TARGET)/bin/kbfba-addaliases ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-addmedia.pl" $(TARGET)/bin/kbfba-addmedia ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjustbiomass.pl" $(TARGET)/bin/kbfba-adjustbiomass ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjustmapcomplex.pl" $(TARGET)/bin/kbfba-adjustmapcomplex ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjustmaprole.pl" $(TARGET)/bin/kbfba-adjustmaprole ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjustmapsubsystem.pl" $(TARGET)/bin/kbfba-adjustmapsubsystem ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjustmodel.pl" $(TARGET)/bin/kbfba-adjustmodel ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjusttempbiocpd.pl" $(TARGET)/bin/kbfba-adjusttempbiocpd ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjusttempbiomass.pl" $(TARGET)/bin/kbfba-adjusttempbiomass ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-adjusttemprxn.pl" $(TARGET)/bin/kbfba-adjusttemprxn ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-buildfbamodel.pl" $(TARGET)/bin/kbfba-buildfbamodel ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-exportfba.pl" $(TARGET)/bin/kbfba-exportfba ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-exportfbamodel.pl" $(TARGET)/bin/kbfba-exportfbamodel ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-exportgenome.pl" $(TARGET)/bin/kbfba-exportgenome ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-exportmedia.pl" $(TARGET)/bin/kbfba-exportmedia ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-exportobject.pl" $(TARGET)/bin/kbfba-exportobject ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-exportphenosim.pl" $(TARGET)/bin/kbfba-exportphenosim ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-gapfill.pl" $(TARGET)/bin/kbfba-gapfill ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-gapgen.pl" $(TARGET)/bin/kbfba-gapgen ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getbio.pl" $(TARGET)/bin/kbfba-getbio ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getcompounds.pl" $(TARGET)/bin/kbfba-getcompounds ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getfbas.pl" $(TARGET)/bin/kbfba-getfbas ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getgapfills.pl" $(TARGET)/bin/kbfba-getgapfills ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getgapgens.pl" $(TARGET)/bin/kbfba-getgapgens ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getmap.pl" $(TARGET)/bin/kbfba-getmap ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getmedia.pl" $(TARGET)/bin/kbfba-getmedia ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getmodels.pl" $(TARGET)/bin/kbfba-getmodels ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-getreactions.pl" $(TARGET)/bin/kbfba-getreactions ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-gettemplate.pl" $(TARGET)/bin/kbfba-gettemplate ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-importfbamodel.pl" $(TARGET)/bin/kbfba-importfbamodel ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-importpheno.pl" $(TARGET)/bin/kbfba-importpheno ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-importprobanno.pl" $(TARGET)/bin/kbfba-importprobanno ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-importtemplate.pl" $(TARGET)/bin/kbfba-importtemplate ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-importtranslation.pl" $(TARGET)/bin/kbfba-importtranslation ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-integratesolution.pl" $(TARGET)/bin/kbfba-integratesolution ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-jobdone.pl" $(TARGET)/bin/kbfba-jobdone ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-loadgenome.pl" $(TARGET)/bin/kbfba-loadgenome ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-queuefba.pl" $(TARGET)/bin/kbfba-queuefba ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-runfba.pl" $(TARGET)/bin/kbfba-runfba ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-runjob.pl" $(TARGET)/bin/kbfba-runjob ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-simpheno.pl" $(TARGET)/bin/kbfba-simpheno ; \
	$(TOOLS_DIR)/tools/wrap_perl "$(TARGET)/plbin/fba-url.pl" $(TARGET)/bin/kbfba-url ; \

deploy-dir:
	if [ ! -d $(SERV_SERVICE_DIR) ] ; then mkdir $(SERV_SERVICE_DIR) ; fi
	if [ ! -d $(SERV_SERVICE_DIR)/webroot ] ; then mkdir $(SERV_SERVICE_DIR)/webroot ; fi 

deploy-libs:
	rsync -arv lib/. $(TARGET)/lib/.

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

include $(KB_TOP)/tools/Makefile.common.rules

