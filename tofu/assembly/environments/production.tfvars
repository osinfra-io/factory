billing_account_id = "01C550-A2C86B-B8F16B"
environment        = "production"
host_project_team  = "factory"

gke_fleet_host = {
  location = "us-east1-b"
  team     = "factory"
}

private_service_range = "172.16.0.0/16"

# Records carried over from the legacy osinfra.io zone; runtime hosts are created by Runtime.
dns_records = [
  {
    name    = ""
    rrdatas = ["198.185.159.144"]
    ttl     = 300
    type    = "A"
  },
  {
    name    = ""
    rrdatas = ["1 aspmx.l.google.com.", "2 alt1.aspmx.l.google.com.", "3 alt2.aspmx.l.google.com.", "4 alt3.aspmx.l.google.com.", "5 alt4.aspmx.l.google.com."]
    ttl     = 14400
    type    = "MX"
  },
  {
    name    = ""
    rrdatas = ["\"v=spf1 include:_spf.google.com ~all\""]
    ttl     = 300
    type    = "TXT"
  },
  {
    name    = "_github-pages-challenge-osinfra-io.docs"
    rrdatas = ["\"260a3c93669cea53331a51d8890497\""]
    ttl     = 300
    type    = "TXT"
  },
  {
    name    = "atr652ahedcj"
    rrdatas = ["gv-3zczsukfcv3ul2.dv.googlehosted.com."]
    ttl     = 300
    type    = "CNAME"
  },
  {
    name    = "docs"
    rrdatas = ["osinfra-io.github.io."]
    ttl     = 300
    type    = "CNAME"
  },
  {
    name    = "google._domainkey"
    rrdatas = ["\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo+1Rmobg2euHqXS2gcrM8T1z57g4wMEt2h3UZEWdx20gNTk94ngWRMkGe1VNALUe+6ftZ4VU/DOFDjA8SmMNmPA+IEEpbk+CP4m8BYz/Ksts2GLOGd3rD2ffHKxvAJtdjykUNOYcChBjf9XlohXpgDz30PKfH0F80/\" \"BXoNFaPKJq0WOadrZVzEdEBFcjRjpXMAGv0In64vsDNDHV23pRpO1q66xt5gM4dvHtqe82NrLxa16UoZE2r4DCkipoDXGb30k11PIvAHAZBZxObdN9Hv0+b1R1PzkUWxBgCJRQHxyJJqKfEMovRw5u1EpZ0vj7kqjZvUhXPR4TD0YA552vIQIDAQAB\""]
    ttl     = 300
    type    = "TXT"
  },
  {
    name    = "nonprod"
    rrdatas = ["ns-cloud-d1.googledomains.com.", "ns-cloud-d2.googledomains.com.", "ns-cloud-d3.googledomains.com.", "ns-cloud-d4.googledomains.com."]
    ttl     = 300
    type    = "NS"
  },
  {
    name    = "sb"
    rrdatas = ["ns-cloud-b1.googledomains.com.", "ns-cloud-b2.googledomains.com.", "ns-cloud-b3.googledomains.com.", "ns-cloud-b4.googledomains.com."]
    ttl     = 300
    type    = "NS"
  },
  {
    name    = "www"
    rrdatas = ["s.multiscreensite.com."]
    ttl     = 300
    type    = "CNAME"
  },
]
