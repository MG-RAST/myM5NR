

FROM ubuntu:15.04

RUN apt-get update && apt-get install -y \
  git-core \
  lftp \
  python-biopython  \
  libdbi-perl  \
  libdbd-pg-perl wget


#SEED environment
RUN apt-get install -y make && \
  mkdir -p /sas/ && \
  cd sas && \
  wget http://blog.theseed.org/downloads/sas.tgz && \
  tar xvzf sas.tgz && \
  cd modules && \
  ./BUILD_MODULES


#Shock perl
RUN cd / ; git clone https://github.com/MG-RAST/Shock.git

ENV PERL5LIB $PERL5LIB:/sas/lib:/sas/modules/lib:/Shock/libs
ENV PATH $PATH:/sas/bin

RUN cd / && git clone https://github.com/MG-RAST/myM5NR.git
