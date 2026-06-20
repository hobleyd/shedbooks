# Copyright (C) 2026 David Hobley
#
# This file is part of Shedbooks.
#
# Shedbooks is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Shedbooks is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

output "instance_public_ip" {
  description = "Public IP of the Shedbooks application instance"
  value       = oci_core_instance.shedbooks.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ubuntu@${oci_core_instance.shedbooks.public_ip}"
}

output "tenancy_namespace" {
  description = "OCI tenancy namespace (used in OCIR paths and Object Storage)"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "ocir_registry" {
  description = "OCIR registry hostname"
  value       = local.ocir_registry
}

output "ocir_prefix" {
  description = "Base path for all Shedbooks OCIR image tags"
  value       = local.ocir_prefix
}

output "ocir_image_db" {
  description = "Full OCIR image reference for the database image"
  value       = "${local.ocir_prefix}/db:latest"
}

output "ocir_image_server" {
  description = "Full OCIR image reference for the server image"
  value       = "${local.ocir_prefix}/server:latest"
}

output "ocir_image_client" {
  description = "Full OCIR image reference for the client image"
  value       = "${local.ocir_prefix}/client:latest"
}

output "backups_bucket" {
  description = "Object Storage bucket name for backups"
  value       = oci_objectstorage_bucket.backups.name
}

output "data_bucket" {
  description = "Object Storage bucket name for application file storage"
  value       = oci_objectstorage_bucket.data.name
}

output "object_storage_namespace" {
  description = "Object Storage namespace (same as tenancy namespace)"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "next_steps" {
  description = "Deployment checklist after terraform apply"
  value       = <<-EOT
    1. Add DNS A record → ${oci_core_instance.shedbooks.public_ip}
    2. Copy TLS certificates to the instance:
         scp your_domain.crt your_domain.key ubuntu@${oci_core_instance.shedbooks.public_ip}:/tmp/
         ssh ubuntu@${oci_core_instance.shedbooks.public_ip} 'sudo mkdir -p /opt/shedbooks/certs/postgres && sudo mv /tmp/your_domain.* /opt/shedbooks/certs/'
    3. Generate PostgreSQL SSL certs and place in /opt/shedbooks/certs/postgres/
    4. Edit /opt/shedbooks/.env on the instance and fill in secrets
    5. Build and push images:  cd terraform && ../scripts/build-and-push.sh
    6. Deploy:                 ../scripts/deploy.sh
    7. Start the stack:        ssh ubuntu@${oci_core_instance.shedbooks.public_ip} 'sudo systemctl start shedbooks'
  EOT
}
