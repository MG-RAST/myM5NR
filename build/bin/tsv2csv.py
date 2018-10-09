#!/usr/bin/python -u

import sys
import csv

csvout = csv.writer(sys.stdout, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
for line in sys.stdin:
    row = line.strip().split("\t")
    csvout.writerow(row)
