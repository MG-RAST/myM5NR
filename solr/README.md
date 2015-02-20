

# Solr M5NR

After building the image using the Dockerfile in this repo you can start it like this:

```bash
sudo docker run -t -i -v /mnt/solr_mnt/:/mnt -p 8983:8983 solr-m5nr
```

You can either a) load the database using the Makefile or b) use an existing solr dump.

a) Check and adapt parameters in /m5nr/Makefile, e.g. M5NR Version. Then run:
```bash
cd /m5nr/ && make standalone-solr
```
b) 
```bash
cd /m5nr/ && make dependencies install-solr config-solr
```
This should do the same as standalone-solr, but skips the loading. Aftwards download solr dump from Shock and the place files in /mnt/m5nr_1/data/index/:
```bash
cd /mnt/m5nr_1/data/index/ && curl <shock_node_url> | tar xvz 
```


## Upload Solr dump to Shock

Please specify solr version used, as the dump will be version specific:

```bash
curl -X POST -H "Authorization: OAuth $TOKEN" -F "upload=@solr-m5nr_v1_solr_v4.10.3.tgz" -F attributes_str='{"type":"data-library","data-library-name":"Solr M5NR v1 with Solr v4.10.3", "version":"1", "member": "1/1", "provenance" : { "creation_type" : "manual", "note": "tar -zcvf solr-m5nr_v1_solr_v4.10.3.tgz -C /mnt/m5nr_1/data/index/ ."} }' "http://shock.metagenomics.anl.gov/node"
```

And make the node public:
```bash
curl -X PUT -H "Authorization: OAuth $TOKEN" "http://shock.metagenomics.anl.gov/node/<node_id>/acl/public_read"
```
