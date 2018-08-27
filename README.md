myM5NR
======

local version of M5NR


## Installation with Docker ##

To build this image:


```bash
git clone https://github.com/MG-RAST/myM5NR.git
```

There are seperate dockerfiles for the different actions available: download, parse, build, upload
They can be built with the following commands:

```bash
docker build -t mgrast/m5nr-download -f download/Dockerfile-download .
docker build -t mgrast/m5nr-parse -f parse/Dockerfile-parse .
docker build -t mgrast/m5nr-build -f build/Dockerfile-build .
docker build -t mgrast/m5nr-upload -f upload/Dockerfile-upload .
```

Examples for manual invocation:
```bash
docker run -t -d --name m5nr-download -v /var/tmp/m5nr:/m5nr_data mgrast/m5nr-download bash
docker run -t -d --name m5nr-parse -v /var/tmp/m5nr:/m5nr_data mgrast/m5nr-parse bash
docker run -t -d --name m5nr-build -v /var/tmp/m5nr:/m5nr_data mgrast/m5nr-build bash
docker run -t -d --name m5nr-upload -v /var/tmp/m5nr:/m5nr_data mgrast/m5nr-upload bash
```

From now steps execute inside the container

Set up some environment bits
```bash
mkdir -p /m5nr_data/Sources
mkdir -p /m5nr_data/Parsed
mkdir -p /m5nr_data/Build
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
