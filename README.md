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

1. Create an empty databse in your PostgreSQL instance: "create database m5nr"
2. Create the database tables, execute psql -U DBADMIN -d m5nr -f PATH_TO/create_pg_tables.sql

The load scripts will create indicies on the database tables.

### Creating M5NR data

1. Download data from all data sources to be included in the M5NR release, e.g from UniProt. Examples of download commands can be found in download_m5nr_sources.sh.
	 
2. Create mapping tables. source2ach.py -v -t -c -o -f genbank -p 8 -d parsed/NCBI RefSeq raw/RefSeq/*
	

#### Load data into PostgreSQL

Mapping tables can be created locally or downloaded from the ftp site (ftp.metagenomics.anl.gov/data/m5nr/current)

The ftp site contains:

After creating the mapping tables locally or downloading the mapping tables from




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