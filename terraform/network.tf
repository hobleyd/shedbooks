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

locals {
  compartment_id = var.compartment_ocid
  tags           = { project = "shedbooks", environment = var.environment }
}

resource "oci_core_vcn" "shedbooks" {
  compartment_id = local.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "shedbooks-vcn"
  dns_label      = "shedbooks"
  freeform_tags  = local.tags
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.shedbooks.id
  display_name   = "shedbooks-igw"
  enabled        = true
  freeform_tags  = local.tags
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.shedbooks.id
  display_name   = "shedbooks-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  freeform_tags = local.tags
}

resource "oci_core_security_list" "web" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.shedbooks.id
  display_name   = "shedbooks-web-sl"

  # Broad outbound egress is intentional: the instance needs to reach OCIR, Auth0,
  # apt mirrors, and the ABR API on dynamic addresses. Restrict further with NSGs
  # once destination CIDRs are known and stable.
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "6"
    stateless = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "6"
    stateless = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.ssh_allowed_cidrs
    content {
      source    = ingress_security_rules.value
      protocol  = "6"
      stateless = false
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # ICMP type 3 code 4 — "Fragmentation Needed", required for path MTU discovery
  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "1"
    stateless = false
    icmp_options {
      type = 3
      code = 4
    }
  }

  freeform_tags = local.tags
}

resource "oci_core_subnet" "public" {
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.shedbooks.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "shedbooks-public-subnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.web.id]
  freeform_tags     = local.tags
}
