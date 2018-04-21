FROM golang:1.10

RUN apt-get update
RUN apt-get install less tree pkg-config libtool autoconf build-essential git -y --force-yes

ENV PATH /usr/local/go/bin:$PATH

# adding Dep golang's package manager
RUN go get -u github.com/golang/dep/cmd/dep
