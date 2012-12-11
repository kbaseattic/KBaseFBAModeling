KBaseFBAModeling
================

This is the repository for the KBase module containing the web
services for FBA modeling in KBase.


Development Deployment
----------------------

This module depends upon the following KBase modules:

* kb_model_seed
* idserver
* workspace_service

And the following services / software:

* Running IDServer
* Running workspace_service
* GLPK ( run `which glpsol` to see if you have it)

The setup commands should be run as root to allow for creation and
editing of base level directories.

Checkout a dev_container and run the bootstrap script in the
container. Source the resulting user-env.sh script. Checkout this
repository into the modules directory.

    cd ~
    git clone kbase@git.kbase.us:dev_container.git
    cd ~/dev_container
    ./bootstrap /kb/runtime
    source user-env.sh
    cd modules
    git clone kbase@git.kbase.us:KBaseFBAModeling.git 

### Setup Services ### 

To deploy a test version (with test data):

    cd ~/dev_container/modules
    git clone kbase@git.kbase.us:kb_model_seed.git
    git clone kbase@git.kbase.us:idserver.git
    cd ..
    ./bootstrap /kb/runtime
    source user-env.sh
    make
    make deploy

The make and make deploy scripts may complain about missing modules.
However the deploy will automatically download and install those
missing modules.

### Setup Test-Data ###

    export PATH=$PATH:/kb/deployment/bin
    export PERL5LIB=$PERL5LIB:/kb/deployment/lib/perl5
    ms createuser kbase   # use the password 'kbase' when prompted
    ms login kbase        # use the password 'kbase' when prompted
    ms stores add mongo --type mongo --host localhost
    ms import biochemistry default
    ms import mapping default -b default

### Service Configuration ###

Copy the sample configuration file, modifying the workspace-url to the URL
of the current production workspace server.

    cp config/sample.ini ~/config.ini
    vi config.ini
    export KB_DEPLOYMENT_CONFIG=$HOME/config.ini
    export KB_SERVICE_NAME=fbaModelingServices

### Start Service ###

    cd /kb/deployment/services/fbaModelServices
    ./start_service

### Run Commands ###

See `modules/KBaseFBAModeling/scripts` for scripts to run.
