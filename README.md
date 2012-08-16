KBaseFBAModeling
================

This is the repository for the KBase module containing the web services for FBA modeling in KBase.


Development Deployment
----------------------

This module depends upon the following KBase modules:

* MFAToolkit
* kb_model_seed
* idserver

And the following services:

* Running instance of mongodb (version >= 1.9)

### Setup MongoDB ###

Version of mongodb must be 1.9 or greater. Download and
install an updated version if this is not the case.

    wget http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.0.7.tgz
    tar -xzf mongodb-linux-x86_64-2.0.7.tgz
    cp -r mongodb-linux-x86_64-2.0.7/bin/* /kb/runtime/bin
    mkdir /data
    mkdir /mnt/db
    ln -s /mnt/db /data/db
    mongod   # wait for it to initialize journel files, then Ctrl-C
    mongod 1>/dev/null 2>&1 &

### Setup Services ### 

To deploy a test version (with test data):

    git clone kbase@git.kbase.us:dev_container.git
    cd dev_container/modules
    git clone git://github.com/ModelSEED/MFAToolkit.git 
    git clone kbase@git.kbase.us:kb_model_seed.git
    git clone kbase@git.kbase.us:idserver.git
    cd ..
    ./bootstrap /kb/runtime
    source user-env.sh
    make
    make deploy

### Setup Test-Data ###

    # add /kb/deployment/bin to PATH and /kb/deployment/lib/perl5 to PERL5LIB
    ms createuser kbase   # password kbase
    ms login kbase        # password kbase
    ms stores add mongo --type mongo --host localhost
    ms import biochemistry default
    ms import mapping default -b default

### Start Service ###

    cd /kb/deployment/services/fbaModelingService
    ./start_service

### Run Commands ###

See `modules/KBaseFBAModeling/scripts` for scripts to run.
