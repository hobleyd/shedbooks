FROM dart:stable AS build

WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# ─── Runtime image ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

# PowerShell + ExchangeOnlineManagement are required for O365 member sync
# (server/lib/infrastructure/services/exchange_online_mail_contact_sync_service.dart):
# Microsoft Graph has no supported write path for org-wide (GAL) mail
# contacts in a cloud-only tenant, so creating/updating them is only
# possible via Exchange Online PowerShell's New-MailContact/Set-MailContact.
# This adds several hundred MB to the image — accepted tradeoff, see
# 2026-08-16-o365-member-sync.md.
#
# Installed from Microsoft's official GitHub release tarball rather than
# their apt feed — that feed has historically only published amd64 packages,
# which would silently break this build on arm64 hosts (e.g. Apple Silicon,
# AWS Graviton). PS_VERSION is pinned; check for a newer release before
# relying on this long-term; https://github.com/PowerShell/PowerShell/releases
#
# openssl generates the self-signed certificate used for Exchange Online
# app-only auth (server/lib/infrastructure/services/openssl_certificate_generator.dart)
# — PowerShell's New-SelfSignedCertificate is part of the Windows-only PKI
# module and unavailable on PowerShell Core/Linux.
ARG PS_VERSION=7.4.6
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget libicu72 openssl \
    && rm -rf /var/lib/apt/lists/* \
    && case "$(dpkg --print-architecture)" in \
         amd64) PS_ARCH=x64 ;; \
         arm64) PS_ARCH=arm64 ;; \
         *) echo "Unsupported architecture for PowerShell: $(dpkg --print-architecture)" >&2; exit 1 ;; \
       esac \
    && wget -q "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-${PS_ARCH}.tar.gz" -O /tmp/powershell.tar.gz \
    && mkdir -p /opt/microsoft/powershell/7 \
    && tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
    && rm /tmp/powershell.tar.gz \
    && chmod +x /opt/microsoft/powershell/7/pwsh \
    && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
    && pwsh -NoProfile -Command " \
         Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
         Install-Module -Name ExchangeOnlineManagement -Force -Scope AllUsers"

WORKDIR /app
COPY --from=build /app/bin/server ./bin/server
COPY --from=build /app/lib/infrastructure/database/migrations ./migrations/
COPY --from=build /app/lib/infrastructure/services/scripts ./scripts/

EXPOSE 8080
CMD ["./bin/server"]
