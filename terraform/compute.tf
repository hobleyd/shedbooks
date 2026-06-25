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

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_22_04_arm" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

locals {
  ocir_registry = "${var.region}.ocir.io"
  ocir_prefix   = "${local.ocir_registry}/${data.oci_objectstorage_namespace.ns.namespace}/shedbooks"
}

resource "oci_core_instance" "shedbooks" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = local.compartment_id
  display_name        = "shedbooks-app"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_22_04_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "shedbooks"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # OCIR auth token is intentionally NOT passed through cloud-init/user-data.
    # Run scripts/setup-instance.sh after provisioning to configure docker login
    # via SSH, keeping the token out of Terraform state and OCI instance metadata.
    user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
      ocir_prefix = local.ocir_prefix
      image_tag   = var.image_tag
    }))
  }

  freeform_tags = local.tags
}
