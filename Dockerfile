FROM mcr.microsoft.com/cbl-mariner/base/core:2.0
RUN yum install -y openssl
WORKDIR /app
COPY . .
ENTRYPOINT ["/app/test1"]
