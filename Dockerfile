FROM alpine:3.7
RUN apk --no-cache add \
    git \
    wget \
    build-base \
    python \
    cpanminus \
    R \
  && rm -rf /var/cache/apk/*

RUN git clone https://github.com/lorenzgerber/OPERA-MS.git
WORKDIR /OPERA-MS
RUN make
ENTRYPOINT ["perl", "OPERA-MS.pl"]

