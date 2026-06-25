#cloud-config
# Bootstrap script for Ubuntu 22.04 ARM64 on OCI VM.Standard.A1.Flex.
# Installs Docker CE and sets up the shedbooks directory structure and systemd service.
#
# OCIR authentication is deliberately NOT configured here — the auth token must
# not enter Terraform state or OCI instance metadata. Run scripts/setup-instance.sh
# after provisioning to configure docker login via SSH.
#
# The shedbooks stack is NOT started automatically. After setup-instance.sh:
#   1. Place TLS certs in /opt/shedbooks/certs/ and /opt/shedbooks/certs/postgres/
#   2. Fill in secrets in /opt/shedbooks/.env
#   3. sudo systemctl start shedbooks

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

      # OCIR image references (populated by Terraform via image_tag variable)
      SHEDBOOKS_DB_IMAGE=${ocir_prefix}/db:${image_tag}
      SHEDBOOKS_SERVER_IMAGE=${ocir_prefix}/server:${image_tag}
      SHEDBOOKS_CLIENT_IMAGE=${ocir_prefix}/client:${image_tag}

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

  # Directory structure — TLS certs and postgres SSL certs are placed manually
  - mkdir -p /opt/shedbooks/certs/postgres
  - chmod 700 /opt/shedbooks/certs

  # Register the service; do NOT start until OCIR auth, certs, and .env are ready
  - systemctl enable shedbooks
