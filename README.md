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
cd MG-RASTv4
docker build -t mgrast/myM5NR .
```

Example for manual invocation:
```bash
docker run -ti -name m5nr -v/var/tmp/m5nr:/root/mym5nr
```
