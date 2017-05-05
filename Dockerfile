

FROM ubuntu

RUN apt-get update && apt-get install -y \
  git-core \
  lftp \
  libdbi-perl  \
  libdbd-pg-perl wget\
  make \
  python-biopython  \
  vim 

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
COPY . /root
ENV PATH $PATH:/root/bin


# create working directoris 
RUN mkdir -p /root/mym5nr/Sources \
	&& mkdir -p /root/mym5nr/Parsed

# download_m5nr_sources.sh

# source2ach.sh

