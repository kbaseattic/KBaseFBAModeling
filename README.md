KBaseFBAModeling
================

This is the repository for the KBase module containing the web
services for FBA modeling in KBase.


Development Deployment
----------------------

This module depends upon the following KBase modules:

* MFAToolkit
* kb_model_seed
* idserver

And the following services / software:

* Running instance of mongodb (version >= 1.9)
* Running IDServer
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

### Setup MongoDB ###

Version of mongodb must be 1.9 or greater. Download and
install an updated version if this is not the case.

    cd ~
    wget http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.0.7.tgz
    tar -xzf mongodb-linux-x86_64-2.0.7.tgz
    cp -r mongodb-linux-x86_64-2.0.7/bin /kb/runtime/bin
    mkdir /data
    mkdir /mnt/db
    ln -s /mnt/db /data/db
    mongod   # wait for it to initialize journel files, then Ctrl-C
    mongod 1>/dev/null 2>&1 &

### Setup Services ### 

To deploy a test version (with test data):

    cd ~/dev_container/modules
    git clone git://github.com/ModelSEED/MFAToolkit.git 
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

    cp ~/dev_container/modules/KBaseFBAModeling/config/sample.ini ~/config.ini
    export KB_DEPLOYMENT_CONFIG=$HOME/config.ini
    export KB_SERVICE_NAME=fbaModelingServices

### Start Service ###

    cd /kb/deployment/services/fbaModelServices
    ./start_service

### Run Commands ###

See `modules/KBaseFBAModeling/scripts` for scripts to run.
