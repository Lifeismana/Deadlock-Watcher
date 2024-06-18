FROM debian:bookworm-slim AS base
RUN echo '\nAcquire::Retries "100";\nAcquire::https::Timeout "240";\nAcquire::http::Timeout "240";\nAPT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' > /etc/apt/apt.conf.d/99custom && \
    apt-get update && apt-get install -y \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

FROM golang:1.22 AS go
RUN git clone https://github.com/xPaw/elf-strings && \
    cd elf-strings && \
    go mod init elf-strings && \
    go get github.com/ianlancetaylor/demangle && \
    go build -o elf-strings

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS dotnet
ARG BUILDARCH
# https://stackoverflow.com/questions/70369368/check-architecture-in-dockerfile-to-get-amd-arm
RUN echo "BUILDARCH: $BUILDARCH" && \
    ARCH=$(echo $BUILDARCH | sed s/amd64/x64/) && \ 
    mkdir /data && \
    cd /data && \
    git clone --depth=1  https://github.com/SteamDatabase/ValveResourceFormat.git && \
    cd ValveResourceFormat && \
    dotnet build -c Release ./Decompiler/Decompiler.csproj && \
    dotnet publish --configuration Release -p:PublishSingleFile=true -p:DebugType=embedded --self-contained --runtime linux-${ARCH} Decompiler/Decompiler.csproj && \
    mv ./Decompiler/bin/Release/linux-${ARCH}/publish /data/Decompiler && \
    cd /data && \
    git clone --depth=1 https://github.com/SteamRE/DepotDownloader.git && \
    cd DepotDownloader && \
    dotnet build -c Release ./DepotDownloader/DepotDownloader.csproj && \
    dotnet publish --configuration Release -p:PublishSingleFile=true -p:DebugType=embedded --self-contained --runtime linux-${ARCH} DepotDownloader/DepotDownloader.csproj && \
    mv ./DepotDownloader/bin/Release/net8.0/linux-${ARCH}/publish/DepotDownloader /data/DepotDownloader_export

FROM base AS download
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /data && \
    cd /data && \
    git clone https://github.com/Penguinwizzard/VPKTool.git && \
    cd VPKTool && \
    make

FROM base as main
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    binutils \
    gawk \
    gnupg \
    php \
    php-common \
    php-mbstring \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*
COPY --from=go /go/elf-strings/elf-strings /data/elfstrings/elfstrings
COPY --from=dotnet /data/Decompiler /data/Decompiler/ 
COPY --from=dotnet /data/DepotDownloader_export /data/DepotDownloader/DepotDownloader
COPY --from=download /data/VPKTool/vpktool /data/VPKTool/vpktool

WORKDIR /data

RUN useradd -m bot -d /data -u 1001 && chmod -R 755 /data  && chown -R bot:bot /data
USER bot

COPY --chmod=777 files/script.sh /data/script.sh
COPY --chmod=777 files/fix_encoding /data/fix_encoding

CMD ["/data/script.sh"]