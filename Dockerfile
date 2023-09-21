FROM mcr.microsoft.com/dotnet/sdk:8.0-cbl-mariner AS build
WORKDIR /source

COPY *.csproj .
RUN dotnet restore --use-current-runtime

COPY . .
RUN dotnet publish --use-current-runtime --self-contained false --no-restore -o /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0-cbl-mariner
WORKDIR /app

RUN tdnf install -y openssl

COPY --from=build /app .

ENTRYPOINT ["/app/auto-rotation-test"]
