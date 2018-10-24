#!/usr/bin/python -u

import sys
import pickle

for line in sys.stdin:
    row = line.strip().split("\t")
    pickle.dump(row, sys.stdout, pickle.HIGHEST_PROTOCOL)
