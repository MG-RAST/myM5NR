import sys
import csv

tsvin  = csv.reader(sys.stdin, dialect=csv.excel_tab)
csvout = csv.writer(sys.stdout, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
for row in tsvin:
    csvout.write(row)
