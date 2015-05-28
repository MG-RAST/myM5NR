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
