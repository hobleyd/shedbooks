#cloud-config
# Bootstrap script for Ubuntu 22.04 ARM64 on OCI VM.Standard.A1.Flex
# Installs Docker CE, configures OCIR authentication, and sets up the
# shedbooks systemd service. The stack is NOT started automatically —
# TLS certs and the .env secrets must be placed first (see terraform outputs).

package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - unzip

write_files:
  - path: /opt/shedbooks/.env
    permissions: "0600"
    owner: root:root
    content: |
      # Shedbooks Production Environment
      # Fill in all CHANGE_ME values before starting the stack.

      DB_PASSWORD=CHANGE_ME
      ENCRYPTION_KEY=CHANGE_ME_USE_32_PLUS_RANDOM_CHARS
      AUTH0_DOMAIN=CHANGE_ME.auth0.com
      AUTH0_AUDIENCE=https://CHANGE_ME
      AUTH0_CLIENT_ID=CHANGE_ME
      CORS_ORIGIN=https://CHANGE_ME_YOUR_DOMAIN
      ABR_GUID=

      # OCIR image references (populated by Terraform)
      SHEDBOOKS_DB_IMAGE=${ocir_prefix}/db:latest
      SHEDBOOKS_SERVER_IMAGE=${ocir_prefix}/server:latest
      SHEDBOOKS_CLIENT_IMAGE=${ocir_prefix}/client:latest

  - path: /etc/systemd/system/shedbooks.service
    permissions: "0644"
    owner: root:root
    content: |
      [Unit]
      Description=Shedbooks Application Stack
      Requires=docker.service
      After=docker.service network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      WorkingDirectory=/opt/shedbooks
      ExecStart=/usr/bin/docker compose \
        --env-file /opt/shedbooks/.env \
        -f /opt/shedbooks/docker-compose.prod.yml \
        up -d --pull always
      ExecStop=/usr/bin/docker compose \
        -f /opt/shedbooks/docker-compose.prod.yml \
        down
      TimeoutStartSec=300

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Install Docker CE from the official upstream repo (ARM64 / Ubuntu 22.04)
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  - |
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
      > /etc/apt/sources.list.d/docker.list
  - apt-get update -qq
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  - systemctl enable docker
  - systemctl start docker

  # Directory structure
  - mkdir -p /opt/shedbooks/certs/postgres
  - chmod 700 /opt/shedbooks/certs

  # Authenticate with OCIR so the instance can pull images
  - echo "${ocir_token}" | docker login ${ocir_registry} --username "${ocir_docker_username}" --password-stdin

  # Register the service but do NOT start it yet — certs and .env secrets are still needed
  - systemctl enable shedbooks
