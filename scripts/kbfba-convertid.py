#!/usr/bin/python

from biokbase.fbaModelServices.Client import fbaModelServices
import optparse
import subprocess
import sys

usage = """%prog object_type input_id_type output_id_type <input_ids, ;-delimited>
E.g. %prog compound ModelSEED name "cpd00001;cpd00002"
"""
description = """ Convert one type of alias into another. """
parser = optparse.OptionParser(usage=usage, description=description)
(options, args) = parser.parse_args()

if len(args) < 4:
    p = subprocess.Popen(["python", sys.argv[0], "-h"], stdout=subprocess.PIPE)
    stdout, stderr = p.communicate()
    print stdout
    exit(1)

fbaClient = fbaModelServices("http://localhost:7036")

input_params = { "object_type" : args[0],
                 "input_id_type" : args[1],
                 "output_id_type" : args[2],
                 "input_ids" : args[3].split(";")
                 }

aliaslist = fbaClient.get_alias(input_params)

for aliases in aliaslist:
    print aliases
