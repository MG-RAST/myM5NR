

# Solr M5NR

```bash
sudo docker run -t -i -v /mnt/solr_mnt/:/mnt -p 8983:8983 solr-m5nr
```


modify /m5nr/Makefile, e.g. M5NR Version
```bash
cd /m5nr/ && make standalone-solr
```


## Upload Solr dump to Shock

Please specify solr version used, as the dump will be version specific:

```bash
curl -X POST -H "Authorization: OAuth $TOKEN" -F "upload=@solr-m5nr_v1_solr_v4.10.3.tgz" -F attributes_str='{"type":"data-library","data-library-name":"Solr M5NR v1 with Solr v4.10.3", "version":"1", "member": "1/1", "provenance" : { "creation_type" : "manual", "note": "tar -zcvf solr-m5nr_v1_solr_v4.10.3.tgz /mnt/m5nr_1/data/index/"} }' "http://shock.metagenomics.anl.gov/node"
```
