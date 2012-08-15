KBaseFBAModeling
================

This is the repository for the KBase module containing the web services for FBA modeling in KBase.

How to deploy:

- clone following modules
   * 'git clone https://github.com/ModelSEED/MFAToolkit.git'
   * 'git clone kbase@git.kbase.us:kb_model_seed.git'
   * 'git clone kbase@git.kbase.us:idserver.git'
- add /kb/deployment/bin to $PATH and /kb/deployment/lib/perl5:/kb/deployment/lib to $PERL5LIB
- if mongodb (mongod --version) is older than 2.0.*, then download new from http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.0.7.tgz and mv binaries to /usr/bin
- setup mongodb
   * 'mkdir /data'
   * 'mkdir /mnt/db'
   * 'ln -s /mnt/db /data/db'
   * 'mongod' (wait for it to build journels)
   * 'mongod 1>/dev/null 2>&1 &'

- install dependency for idservice
   * 'cpanm -l /kb/deployment Taint::Util'

- ms createuser kbase
- ms login kbase
- ms stores add mongo --type mongo --host localhost
- ms import biochemistry default
- ms import mapping default -b default
