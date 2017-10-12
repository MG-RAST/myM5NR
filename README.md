myM5NR
======

local version of M5NR


## Installation with Docker ##

To build this image:


```bash
git clone --recursive https://github.com/MG-RAST/myM5NR.git
```

To build the image either download the Docker file into an empty directory of provide the url to Dockerfile as in this example:

```bash
docker build -t mgrast/mgrast/m5nr-build .
```

Example for manual invocation:
```bash
docker run -ti -name m5nr -v/var/tmp/m5nr:/m5nr_data mgrast/m5nr-build
```

From now steps execute inside the container

Set up some environment bits
```bash
mkdir -p /m5nr_data/Sources
mkdir -p /m5nr_data/Parsed

source /myM5NR/sources.cfg
```

To initiate the download
```bash
/myM5NR/bin/download_m5nr_sources.sh /m5nr_data/Sources 2>&1 | tee /m5nr_data/Sources/logfile.txt
```

To initiate the build
```bash
/myM5NR/bin/source2ach.sh 4 /m5nr_data/Sources /m5nr_data/Parsed 2>&1 | tee /m5nr_data/Parsed/logfile.txt
```
