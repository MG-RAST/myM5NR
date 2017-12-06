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
docker build -t mgrast/m5nr-build .
```

Example for manual invocation:
```bash
docker run -ti --name m5nr -v /var/tmp/m5nr:/m5nr_data mgrast/m5nr-build
```

From now steps execute inside the container

Set up some environment bits
```bash
mkdir -p /m5nr_data/Sources
mkdir -p /m5nr_data/Parsed
```

To initiate the download (you can use --force to delete old _part directories)
```bash
cd /m5nr_data
/myM5NR/bin/m5nr_compiler.py download --debug 2>&1 | tee /m5nr_data/Sources/logfile.txt
```

To initiate the parsing (work in progress)
```bash
cd /m5nr_data
/myM5NR/bin/m5nr_compiler.py parse --debug 2>&1 | tee /m5nr_data/Parsed/logfile.txt
```

To view status
```bash
cd /m5nr_data
/myM5NR/bin/m5nr_compiler.py status --debug
```
