# Migration aid for the Cloudflare provider v4 -> v5 upgrade.
# `cloudflare_record` was renamed to `cloudflare_dns_record`; these `moved`
# blocks let Terraform re-point existing state at the new resource type
# instead of destroying and recreating every DNS record.
#
# Safe to delete once `terraform apply` has completed successfully with
# these in place (check with `terraform state list` afterwards).

moved {
  from = cloudflare_record.terraform_managed_resource_8663194f1dcc57cdec36fed108dd2f25
  to   = cloudflare_dns_record.terraform_managed_resource_8663194f1dcc57cdec36fed108dd2f25
}

moved {
  from = cloudflare_record.terraform_managed_resource_e61c50ebcdbe13fb312bf66bad0a991e
  to   = cloudflare_dns_record.terraform_managed_resource_e61c50ebcdbe13fb312bf66bad0a991e
}

moved {
  from = cloudflare_record.terraform_managed_resource_dc575396724e6a3008ed90a8035bd75a
  to   = cloudflare_dns_record.terraform_managed_resource_dc575396724e6a3008ed90a8035bd75a
}

moved {
  from = cloudflare_record.terraform_managed_resource_694a6a23084a976f1a563d72e6e11bbb
  to   = cloudflare_dns_record.terraform_managed_resource_694a6a23084a976f1a563d72e6e11bbb
}

moved {
  from = cloudflare_record.terraform_managed_resource_1bb8fe9f88bbabbb1eeb9e68e6da10fd
  to   = cloudflare_dns_record.terraform_managed_resource_1bb8fe9f88bbabbb1eeb9e68e6da10fd
}

moved {
  from = cloudflare_record.terraform_managed_resource_cd5c8e6c433115f918c7dbf3d0a3a58f
  to   = cloudflare_dns_record.terraform_managed_resource_cd5c8e6c433115f918c7dbf3d0a3a58f
}

moved {
  from = cloudflare_record.terraform_managed_resource_fa7fe93582b72b86ad988c7e53231388
  to   = cloudflare_dns_record.terraform_managed_resource_fa7fe93582b72b86ad988c7e53231388
}

moved {
  from = cloudflare_record.terraform_managed_resource_c2b153bf6ff9452cd252f2aaac7a6da5
  to   = cloudflare_dns_record.terraform_managed_resource_c2b153bf6ff9452cd252f2aaac7a6da5
}

moved {
  from = cloudflare_record.terraform_managed_resource_4e0669bea856b1f22fd7a1bcdf42bc30
  to   = cloudflare_dns_record.terraform_managed_resource_4e0669bea856b1f22fd7a1bcdf42bc30
}

moved {
  from = cloudflare_record.terraform_managed_resource_e19dca3c2553b9608dbb3f9b43e09efe
  to   = cloudflare_dns_record.terraform_managed_resource_e19dca3c2553b9608dbb3f9b43e09efe
}

moved {
  from = cloudflare_record.terraform_managed_resource_a2845f3f5c9c427af3515290cb5c68d3
  to   = cloudflare_dns_record.terraform_managed_resource_a2845f3f5c9c427af3515290cb5c68d3
}

moved {
  from = cloudflare_record.terraform_managed_resource_397463f674c69ac8ea5157937eb2344c
  to   = cloudflare_dns_record.terraform_managed_resource_397463f674c69ac8ea5157937eb2344c
}

moved {
  from = cloudflare_record.github_asztalos_net
  to   = cloudflare_dns_record.github_asztalos_net
}
