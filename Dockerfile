FROM alpine:3.8
RUN apk --no-cache add \
    git \
    wget \
    perl-app-cpanminus \
    build-base \
    python \
    R \
    bash

RUN git clone https://github.com/lorenzgerber/opera.git
WORKDIR /opera
RUN rm -rf .git
RUN make
ENTRYPOINT ["perl", "OPERA-MS.pl"]

