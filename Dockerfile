FROM alpine:3.8
RUN apk --no-cache add \
    git \
    wget \
    perl-app-cpanminus \
    build-base \
    python \
    R \
    zip \
    zlib-dev \
    ncurses-dev \
    bash

RUN wget https://github.com/samtools/samtools/archive/0.1.19.zip
RUN unzip 0.1.19.zip
WORKDIR samtools-0.1.19
RUN make
WORKDIR /
RUN git clone https://github.com/lh3/bwa.git
WORKDIR bwa
RUN make
WORKDIR /
RUN git clone https://github.com/lorenzgerber/opera.git
WORKDIR /opera
RUN rm -rf .git
RUN make

ENV PATH="/samtools-0.1.19:/bwa:${PATH}"
ENTRYPOINT ["perl", "OPERA-MS.pl"]
