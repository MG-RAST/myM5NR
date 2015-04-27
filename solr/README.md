

# Solr M5NR

Build image:
```bash
docker build --tag=mgrast/m5nr-solr:latest --force-rm --no-cache https://raw.githubusercontent.com/MG-RAST/myM5NR/master/solr/docker/Dockerfile
```

After building the image using the Dockerfile in this repo you can start it like this:

```bash
sudo docker run -t -i -v /mnt/solr/:/mnt -p 8983:8983 mgrast/m5nr-solr:latest
```

You can either a) load the database using the Makefile or b) use an existing solr dump. In both cases check and adapt parameters in the Makefile, e.g. M5NR Version and shock node url if you want to use the cached solr database.

a) Loading from scratch:
```bash
cd /m5nr/ && make load-solr
```
b) Deploy cached solr database: 
```bash
cd /m5nr/ && make load-cached-solr
```

## Create Solr dump and upload to Shock

To be sure stop solr: "/etc/init.d/solr stop". 
```bash
tar -zcvf solr-m5nr_v1_solr_v5.0.0.tgz -C /mnt/m5nr_1/data/index/ .
```

For the upload to Shock, please specify the solr version used, as the dump will be solr-version specific:

```bash
curl -X POST -H "Authorization: OAuth $TOKEN" -F "upload=@solr-m5nr_v1_solr_v5.0.0.tgz" -F attributes_str='{"type":"data-library","data-library-name":"Solr M5NR", "description": "Solr M5NR v1 with Solr v5.0.0", "version":"1", "member": "1/1", "provenance" : { "creation_type" : "manual", "note": "tar -zcvf solr-m5nr_v1_solr_v5.0.0.tgz -C /mnt/m5nr_1/data/index/ ."} }' "http://shock.metagenomics.anl.gov/node"
```

And make the node public:
```bash
curl -X PUT -H "Authorization: OAuth $TOKEN" "http://shock.metagenomics.anl.gov/node/<node_id>/acl/public_read"
```