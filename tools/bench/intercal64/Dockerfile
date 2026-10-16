# TEMPORARY (goal 2's cleanup removes it): INTERCAL-64 (churn) benchmark baseline (Q30), built with .NET 10.
FROM mcr.microsoft.com/dotnet/sdk:10.0.402

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1

ARG INTERCAL64_COMMIT=81fe156bcfbc8b4ff1bf449849f8fdd1ee6a0951

# churn.csproj's CompileSyslib target is skipped under this SDK (PublishDir is set), so
# syslib64.dll is compiled by hand. churn only accepts a source path with no other dots
# and exits 0 even when it fails, hence the copy and the final test.
RUN mkdir -p /opt/src/intercal64 \
 && curl -fsSL https://github.com/PLEASE-ABSTAIN/INTERCAL64/archive/$INTERCAL64_COMMIT.tar.gz \
    | tar -xz --strip-components=1 -C /opt/src/intercal64 \
 && dotnet build /opt/src/intercal64/churn/churn.csproj -c Release \
 && cd /opt/src/intercal64/bin \
 && cp ../syslib64/syslib64.ic64 . \
 && dotnet churn.dll syslib64.ic64 -b -t:library -noplease \
 && rm syslib64.ic64 \
 && test -f syslib64.dll

COPY bench-build /usr/local/bin/bench-build
WORKDIR /work
