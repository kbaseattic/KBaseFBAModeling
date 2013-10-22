#!/usr/bin/python
from biokbase.fbaModelServices.Client import fbaModelServices

import optparse
import subprocess
import sys

usage = """%prog object_type"
E.g. %prog compound
"""
description = """ Get all the valid alias sets (e.g. ModelSEED, KEGG, ...) that can be queried
with getcompound\getreaction and related functions. Known good object types: compound, reaction """
parser = optparse.OptionParser(usage=usage, description=description)
(options, args) = parser.parse_args()

# Print help if nothing is provided (note - need to test if it works after
# wrapping it up)
if len(args) < 1:
    p = subprocess.Popen(["python", sys.argv[0], "-h"], stdout=subprocess.PIPE)
    stdout, stderr = p.communicate()
    print stdout
    exit(1)

fbaClient = fbaModelServices("http://localhost:7036")

object_type = args[0]

input_params = { "object_type" : object_type  }

output = fbaClient.get_aliassets(input_params)
if len(output) == 0:
    raise ValueError("ERROR: Unable to get aliassets for %s" %(object_type) )
else:
    print "\n".join(fbaClient.get_aliassets(input_params))
