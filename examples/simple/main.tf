resource "azurerm_resource_group" "example" {
  name     = "terraformdns-example"
  location = "West US"
}

resource "azurerm_dns_zone" "example" {
  resource_group_name = azurerm_resource_group.example.name

  name = "example.com"
}

module "dns_records" {
  source = "../../"

  resource_group_name = azurerm_dns_zone.example.resource_group_name
  dns_zone_name       = basename(azurerm_dns_zone.example.id)
  recordsets = [
    {
      name = "www"
      type = "A"
      ttl  = 3600
      records = [
        "192.0.2.56",
      ]
    },
    {
      name = ""
      type = "MX"
      ttl  = 3600
      records = [
        "1 mail1",
        "5 mail2",
        "5 mail3",
      ]
    },
    {
      name = ""
      type = "TXT"
      ttl  = 3600
      records = [
        "\"v=spf1 ip4:192.0.2.3 include:backoff.${azurerm_dns_zone.example.name} -all\"",
      ]
    },
    {
      name = "_sip._tcp"
      type = "SRV"
      ttl  = 3600
      records = [
        "10 60 5060 sip1",
        "10 20 5060 sip2",
        "10 20 5060 sip3",
        "20  0 5060 sip4",
      ]
    },
  ]
}

