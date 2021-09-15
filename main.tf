
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
  recordsets       = { for rs in var.recordsets : rs.type => rs... }
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

resource "azurerm_dns_a_record" "name" {
  for_each = { for rs in local.a_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(each.value.name, "@")
  ttl     = each.value.ttl
  records = each.value.records
}

resource "azurerm_dns_aaaa_record" "name" {
  for_each = { for rs in local.aaaa_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(each.value.name, "@")
  ttl     = each.value.ttl
  records = each.value.records
}

resource "azurerm_dns_cname_record" "name" {
  for_each = { for r in local.cname_records : r.name => r }


  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name   = coalesce(each.value.name, "@")
  ttl    = each.value.ttl
  record = each.value.data
}

resource "azurerm_dns_mx_record" "name" {
  for_each = { for rs in local.mx_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name = coalesce(each.value.name, "@")
  ttl  = each.value.ttl

  dynamic "record" {
    for_each = [for line in each.value.records : {
      clean_line = replace(line, "/\\s+/", " ")
    }]
    content {
      preference = split(" ", record.value.clean_line)[0]
      exchange   = split(" ", record.value.clean_line)[1]
    }
  }
}

resource "azurerm_dns_ns_record" "name" {
  for_each = { for rs in local.ns_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(each.value.name, "@")
  ttl     = each.value.ttl
  records = each.value.records
}

resource "azurerm_dns_ptr_record" "name" {
  for_each = { for rs in local.ptr_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name    = coalesce(each.value.name, "@")
  ttl     = each.value.ttl
  records = each.value.records
}

resource "azurerm_dns_srv_record" "name" {
  for_each = { for rs in local.srv_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name = coalesce(each.value.name, "@")
  ttl  = each.value.ttl

  dynamic "record" {
    for_each = [for line in each.value.records : {
      clean_line = replace(line, "/\\s+/", " ")
    }]
    content {
      priority = tonumber(split(" ", record.value.clean_line)[0])
      weight   = tonumber(split(" ", record.value.clean_line)[1])
      port     = tonumber(split(" ", record.value.clean_line)[2])
      target   = split(" ", record.value.clean_line)[3]
    }
  }
}

resource "azurerm_dns_txt_record" "name" {
  for_each = { for rs in local.txt_recordsets : rs.name => rs }

  resource_group_name = data.azurerm_dns_zone.example.resource_group_name
  zone_name           = data.azurerm_dns_zone.example.name

  name = coalesce(each.value.name, "@")
  ttl  = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      value = record.value
    }
  }
}
