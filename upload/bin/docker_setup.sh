#!/bin/bash

if [ "$1" != "" ]; then
    DOCKERVERSION=$1
fi

if [ -z "$DOCKERVERSION" ] ; then
  echo "Variable DOCKERVERSION is not set"
  exit 1
fi

rm -f /usr/bin/docker

# "/docker" is a host directory, use it as cache
echo "installing docker version ${DOCKERVERSION}"
if [ ! -e /docker/docker-${DOCKERVERSION} ]; then
   cd /docker
   curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   mv /docker/docker /docker/docker-${DOCKERVERSION}
fi

chmod +x /docker/docker-${DOCKERVERSION}
ln -s /docker/docker-${DOCKERVERSION} /usr/bin/docker

set -e
# test to make sure client and server version of docker are the same
echo "installed:"
/usr/bin/docker version
set +e
