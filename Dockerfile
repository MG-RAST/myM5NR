
# docker build -t mgrast/m5nr-build .

FROM ubuntu:16.04

RUN apt-get update && apt-get install -y \
  git-core \
  lftp \
  libdbi-perl  \
  libdbd-pg-perl \
  wget\
  unzip \
  make \
  python-biopython  \
  vim \
  curl \
  python-pip \
  python3 \
  python3-pip

RUN git clone https://github.com/google/leveldb.git && \
  cd leveldb/ && \
  make && \
  cp out-static/lib* out-shared/lib* /usr/local/lib/ && \
  cd include/ && \
  cp -r leveldb /usr/local/include/ && \
  ldconfig

RUN pip2 install plyvel

RUN pip3 install PrettyTable pyyaml

# install the SEED environment for Subsystem data download
RUN mkdir -p /sas/ && \
  cd sas && \
  wget http://blog.theseed.org/downloads/sas.tgz && \
  tar xvzf sas.tgz && \
  cd modules && \
  ./BUILD_MODULES

ENV PERL5LIB $PERL5LIB:/sas/lib:/sas/modules/lib
ENV PATH $PATH:/sas/bin

# copy stuff from the repo into the /root (note the .dockerignore file)
COPY . /myM5NR
ENV PATH $PATH:/root/bin

WORKDIR /myM5NR

# download_m5nr_sources.sh

# source2ach.sh

