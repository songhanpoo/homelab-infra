fields {
  optional {
    dockerfile                          = String
    context                             = String
    snapshot_mode                       = Boolean
    digest_file                         = String
    force                               = Boolean
    git                                 = String
    image_name_with_digest_file         = String
    image_name_tag_with_digest_file     = String
    insecure                            = Boolean
    insecure_pull                       = Boolean
    insecure_registry                   = List
    labels                              = List
    log_format                          = String
    log_timestamp                       = Boolean
    no_push                             = Boolean
    no_push_cache                       = Boolean
    oci_layout_path                     = String
    push_ignore_immutable_tag_errors    = Boolean
    push_retry                          = Integer
    registry_certificate                = List
    registry_client_cert                = List
    registry_map                        = List
    registry_mirror                     = List
    skip_default_registry_fallback      = Boolean
    reproducible                        = Boolean
    single_snapshot                     = Boolean
    skip_push_permission_check          = Boolean
    skip_tls_verify                     = Boolean
    skip_tls_verify_pull                = Boolean
    skip_tls_verify_registry            = List
    skip_unused_stages                  = Boolean
    tar_path                            = String
    target                              = String
    use_new_run                         = Boolean
    verbosity                           = String
    ignore_var_run                      = Boolean
    ignore_path                         = List
    image_fs_extract_retry              = Integer
    image_download_retry                = Integer
    auto_push_tag_latest                = Boolean
    repository                          = String
  }
}