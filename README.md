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

### Installing database schema

Prerequisits: PostgreSQL installed and Admin/Create Database priviledges 

1. Create an empty database in your PostgreSQL instance: "create database m5nr"
2. Create the database tables, execute psql -U DBADMIN -d m5nr -f PATH_TO/create_pg_tables.sql

The load scripts will create indicies on the database tables.

## More detailed instruction for use with Docker

If you use docker, you can make it use a directory on the host with the -v parameter:
```bash
sudo docker run -t -i -v /mnt/m5nr:/m5nr_data --name m5nr ubuntu:14.04
```
Software needed:
```bash
apt-get -y update && apt-get -y install postgresql postgresql-contrib 
```

You may need to change authentication settings. To find the config file you can follow this approach:

```bash
/etc/init.d/postgresql start
sudo -u postgres -i
psql
SHOW hba_file;
\q
#example: /etc/postgresql/9.3/main/pg_hba.conf
```

Authentication: If you use Postgres only locally within your host or container, you can simply disable authentication: entries local, ipv4 host and ipv6 host set method to “trust”.

You may have to change the default data directory for Postgres, e.g. if you use docker and want to store data on a mounted host directory. Either follow these instructions to create  a new data directory (recommended, but I did not test it)
```bash
http://www.postgresql.org/docs/8.3/static/creating-cluster.html
```
or move the existing data directory where you want to have it (ugly, did work for me):
```bash
cp -rp /var/lib/postgresql/ /m5nr_data/
```

In either case you have to configure Postgres:
Example: /etc/postgresql/9.3/main/postgresql.conf
data_directory = '/m5nr_data/postgresql/9.3/main'
and
/etc/init.d/postgresql start OR restart

## creating tables
```bash
git clone https://github.com/MG-RAST/M5nr.git
sudo -u postgres -i
export BIN=/M5nr/Babel/bin 
export ${DATABASE}=m5nr_test

psql -d template1 -c "CREATE DATABASE ${DATABASE}"
# NOTICE is normal
psql -d m5nr_v$X -f $BIN/create_pg_tables.sql
```

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


#### Load data into PostgreSQL

Mapping tables can be created locally or downloaded from the ftp site (ftp.metagenomics.anl.gov/data/m5nr/current)

The ftp site contains:

After creating the mapping tables locally or downloading the mapping tables from


### User Interface

### Developing
The user interface is based on the Retina git submodule. Please execute from within you repo following two commands to get the code.
1. git submodule init
2. git submodule update

Directories
-----------

- lib
- bin
- db
- service
- ui

Dependencies
------------

- PostgreSQL
- Perl 5, version 12, subversion 3 (v5.12.3) (tested)
- Solr (http://lucene.apache.org/solr/)
