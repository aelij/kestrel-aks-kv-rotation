FROM mcr.microsoft.com/dotnet/runtime:8.0.0-preview.7-cbl-mariner2.0
RUN yum install -y openssl
WORKDIR /app
COPY . .
ENTRYPOINT ["/app/test1"]
