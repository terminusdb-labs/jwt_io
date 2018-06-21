FROM swipl:latest
LABEL maintainer "Can Bican <can@bican.net>"
RUN apt-get update
RUN apt-get install -y gcc make dh-autoreconf wget pkg-config libssl-dev git libgpm2
RUN wget https://github.com/akheron/jansson/archive/v2.11.tar.gz && tar xvzfp v2.11.tar.gz && cd jansson-2.11 && autoreconf -i && ./configure && make && make install && cd .. && rm -rf jansson-2.11 v2.11.tar.gz
RUN wget https://github.com/benmcollins/libjwt/archive/v1.9.0.tar.gz && tar xvzfp v1.9.0.tar.gz && cd libjwt-1.9.0 && autoreconf -i && ./configure && make && make install && cd .. && rm -rf v1.9.0.tar.gz libjwt-1.9.0
