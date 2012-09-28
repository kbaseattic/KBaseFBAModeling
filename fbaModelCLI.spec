/*

API for executing command line functions. This API acts as a
pass-through service for executing command line functions for FBA
modeling hosted in KBase. This aleviates the need to have specifically
tailored CLI commands.

*/
module fbaModelCLI {
    typedef list<string> ARGV;
    typedef string STDIN;
    typedef string STDOUT;
    typedef string STDERR;
    
    funcdef execute_command ( ARGV args, STDIN stdin ) returns ( int status, STDOUT stdout, STDERR stderr );
};
