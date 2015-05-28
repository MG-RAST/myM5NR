myM5NR
======

local version of M5NR

Installation
------------

- Installing the database
- Installing perl library
- Installing REST Service
- Installing command line tool
- Creating M5NR data 
  - download from sources and create tables
  - load data


### Creating M5NR data

sources.cfg configures which database are included. The download and parsing wrapper scripts (download_m5nr_sources.sh and source2ach.sh) will try to automatically source the sources.cfg. Run scripts without arguments to get usage.

Create directories:

```bash
mkdir Sources
mkdir Parsed
```

1. Download sources
```bash
apt-get -y install lftp
download_m5nr_sources.sh
```

2. Parse sources
```bash
apt-get -y install python-biopython libdbi-perl libdbd-pg-perl
source2ach.sh
```

## M5NR and M5RNA FASTA files
```bash
cd Sources
source sources.cfg
```

(Partially merge) sort all md52seq files
```bash
for i in ${SOURCES_PROTEIN} ${SOURCES_RNA} ; do cat ${i}/*.md52seq | sort -S 50% -u > ${i}_sorted.md52seq_part && mv ${i}_sorted.md52seq_part ${i}_sorted.md52seq ; done (warning: exclude CAZy ! it has no .md52seq file, or use empty file ?)
```

Check if files exist
```bash
for i in ${SOURCES_PROTEIN} ; do file ${i}_sorted.md52seq ; done
```

Merge sorted files (sort -m does not sort!)
```bash
sort -m -u -S 50% `for i in ${SOURCES_PROTEIN} ; do echo -n "${i}_sorted.md52seq " ; done` -o all_protein.md52seq
```

Create actual FASTA files
```bash
cat all_rna.md52seq | while read md5 seq ; do echo ">"$md5 ; echo $seq ; done > m5rna.fasta
cat all_protein.md52seq | while read md5 seq ; do echo ">"$md5 ; echo $seq ; done > m5nr.fasta
```


