
terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = ">= 1.7.0"
  }
}

data "azurerm_dns_zone" "example" {
  # We request this only as an early check that it exists. We don't actually
  # need any additional information from it, since its identifier is its name.
  resource_group_name = var.resource_group_name
  name                = var.dns_zone_name
}

# Since the azurerm provider uses a separate resource type for each DNS record
# type, we'll need to split up our input list.
locals {
  recordsets       = {for rs in var.recordsets : rs.type => rs ...}
  a_recordsets     = lookup(local.recordsets, "A", [])
  aaaa_recordsets  = lookup(local.recordsets, "AAAA", [])
  cname_recordsets = lookup(local.recordsets, "CNAME", [])
  mx_recordsets    = lookup(local.recordsets, "MX", [])
  ns_recordsets    = lookup(local.recordsets, "NS", [])
  ptr_recordsets   = lookup(local.recordsets, "PTR", [])
  srv_recordsets   = lookup(local.recordsets, "SRV", [])
  txt_recordsets   = lookup(local.recordsets, "TXT", [])

  # Some of the resources only deal with one record at a time, and so we need
  # to flatten these.
  cname_records = flatten([
    for rs in local.cname_recordsets : [
      for r in rs.records : {
        name = rs.name
        type = rs.type
        ttl  = rs.ttl
        data = r
      }
    ]
  ])

  # With just our list splitting technique above, records of unsupported types
  # would be silently ignored. The following two expressions ensure that
  # such records will produce an error message instead, albeit not a very
  # helpful one.
  supported_record_types = {
    A     = true
    AAAA  = true
    CNAME = true
    MX    = true
    NS    = true
    PTR   = true
    SRV   = true
    TXT   = true
  }
  check_supported_types = [
    # The index operation here will fail if one of the records has
    # an unsupported type.
    for rs in var.recordsets : local.supported_record_types[rs.type]
  ]
}

resource "azurerm_dns_a_record" "this" {
  count = length(local.a_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(local.a_recordsets[count.index].name, "@")
  ttl     = local.a_recordsets[count.index].ttl
  records = local.a_recordsets[count.index].records
}

resource "azurerm_dns_aaaa_record" "this" {
  count = length(local.aaaa_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(local.aaaa_recordsets[count.index].name, "@")
  ttl     = local.aaaa_recordsets[count.index].ttl
  records = local.aaaa_recordsets[count.index].records
}

resource "azurerm_dns_cname_record" "this" {
  count = length(local.cname_records)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name   = coalesce(local.cname_records[count.index].name, "@")
  ttl    = local.cname_records[count.index].ttl
  record = local.cname_records[count.index].data
}

resource "azurerm_dns_mx_record" "this" {
  count = length(local.mx_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name = coalesce(local.mx_recordsets[count.index].name, "@")
  ttl  = local.mx_recordsets[count.index].ttl

  dynamic "record" {
    for_each = mx_recordsets[count.index].records
    content {
      preference = split(record.value, " ")[0]
      exchange   = split(record.value, " ")[1]
    }
  }
}

resource "azurerm_dns_ns_record" "this" {
  count = length(local.ns_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(local.ns_recordsets[count.index].name, "@")
  ttl     = local.ns_recordsets[count.index].ttl
  records = local.ns_recordsets[count.index].records
}

resource "azurerm_dns_ptr_record" "this" {
  count = length(local.ptr_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(local.ptr_recordsets[count.index].name, "@")
  ttl     = local.ptr_recordsets[count.index].ttl
  records = local.ptr_recordsets[count.index].records
}

resource "azurerm_dns_srv_record" "this" {
  count = length(local.srv_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name = coalesce(local.srv_recordsets[count.index].name, "@")
  ttl  = local.srv_recordsets[count.index].ttl

  dynamic "record" {
    for_each = srv_recordsets[count.index].records
    content {
      priority = split(record.value, " ")[0]
      weight   = split(record.value, " ")[1]
      port     = split(record.value, " ")[2]
      target   = split(record.value, " ")[3]
    }
  }
}

resource "azurerm_dns_txt_record" "this" {
  count = length(local.txt_recordsets)

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name = coalesce(local.txt_recordsets[count.index].name, "@")
  ttl  = local.txt_recordsets[count.index].ttl

  dynamic "record" {
    for_each = txt_recordsets[count.index].records
    content {
      value = record.value
    }
  }
}
