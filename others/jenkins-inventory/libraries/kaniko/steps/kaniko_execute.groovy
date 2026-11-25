/**
 * Kaniko library step — builds container images securely in userspace.
 */
void call() {
    container('kaniko') {
        // sh '/kaniko/executor --version || true'

        if (fileExists('/var/run/secrets/nexus/.dockerconfigjson')) {
            sh 'mkdir -p /kaniko/.docker && cp /var/run/secrets/nexus/.dockerconfigjson /kaniko/.docker/config.json'
            logging.info "Successfully loaded Nexus docker credentials!"
        } else {
            logging.warning "Warning: nexus-docker-registries secret not mounted."
        }

        logging.info "Triggering Kaniko executor sequentially."

        def dockerfile    = config.dockerfile ?: 'Dockerfile'
        def context       = config.context ?: 'dir://.'
        if (!context.startsWith("http") && !context.startsWith("git") && !context.startsWith("dir://")) {
            context = "dir://${context}"
        }

        def cmd = ["/kaniko/executor"]
        cmd << "--dockerfile=${dockerfile}"
        cmd << "--context=${context}"

        // Auto-detect repository name from git URL or job name
        def repoName = 'unknown-repo'
        def gitUrl = env.GIT_URL ?: ''
        if (gitUrl) {
            def parts = gitUrl.split('/')
            def lastPart = parts[-1]
            if (lastPart.endsWith('.git')) {
                lastPart = lastPart.substring(0, lastPart.length() - 4)
            }
            repoName = lastPart
        } else {
            def jobName = env.JOB_NAME ?: ''
            if (jobName) {
                def jobParts = jobName.split('/')
                if (jobParts.length >= 2) {
                    repoName = jobParts[-2]
                } else {
                    repoName = jobParts[-1]
                }
            }
        }

        // Resolve destinations and auto-tag if base image is provided
        def destinations = []
        def containerRepo = config.repository ?: "nexus-docker-private"
        def rawDestinations = ["${containerRepo}.local.proxy/${repoName}"]

        def gitCommit = env.APP_COMMIT_HASH ?: env.GIT_COMMIT ?: 'unknown'
        if (gitCommit.length() > 8) {
            gitCommit = gitCommit.substring(0, 8)
        }
        def buildNumber = env.BUILD_NUMBER ?: '0'

        rawDestinations.each { dest ->
            def parts = dest.split('/')
            def lastPart = parts[-1]
            if (!lastPart.contains(':')) {
                // Default auto_push_tag_latest to false
                def autoPushLatest = config.auto_push_tag_latest == true
                if (autoPushLatest) {
                    destinations << "${dest}:latest"
                }
                destinations << "${dest}:${gitCommit}-${buildNumber}"
            } else {
                destinations << dest
            }
        }

        def autoSkipTlsRegistries = []
        if (destinations) {
            destinations.each { dest ->
                cmd << "--destination=${dest}"
                def registryName = dest.split('/')[0]
                if (registryName.endsWith(".proxy") || registryName.endsWith(".local") || registryName.endsWith(".localdev.me")) {
                    autoSkipTlsRegistries << registryName
                }
            }
        } else {
            cmd << "--no-push"
        }

        // Digest file configuration
        def digestFile = config.digest_file ?: '/kaniko/digest-file'
        cmd << "--digest-file=${digestFile}"

        // Optional flags mapping
        if (config.force) {
            cmd << "--force"
        }
        if (config.git) {
            cmd << "--git=${config.git}"
        }
        if (config.image_name_with_digest_file) {
            cmd << "--image-name-with-digest-file=${config.image_name_with_digest_file}"
        }
        if (config.image_name_tag_with_digest_file) {
            cmd << "--image-name-tag-with-digest-file=${config.image_name_tag_with_digest_file}"
        }
        if (config.insecure) {
            cmd << "--insecure"
        }
        if (config.insecure_pull) {
            cmd << "--insecure-pull"
        }
        if (config.insecure_registry instanceof List) {
            config.insecure_registry.each { reg -> cmd << "--insecure-registry=${reg}" }
        } else if (config.insecure_registry) {
            cmd << "--insecure-registry=${config.insecure_registry}"
        }

        // Labels handling: merging global and local labels
        def allLabels = []
        try { if (globally.labels instanceof List) allLabels.addAll(globally.labels) } catch (Exception e) {}
        if (config.labels instanceof List) {
            allLabels.addAll(config.labels)
        } else if (config.labels instanceof Map) {
            config.labels.each { k, v -> allLabels << "${k}=${v}" }
        } else if (config.labels) {
            allLabels << config.labels.toString()
        }
        allLabels.unique().each { lbl ->
            cmd << "--label=\"${lbl}\""
        }

        if (config.log_format) {
            cmd << "--log-format=${config.log_format}"
        }
        if (config.log_timestamp != null) {
            cmd << "--log-timestamp=${config.log_timestamp}"
        }
        if (config.no_push) {
            cmd << "--no-push"
        }
        if (config.no_push_cache) {
            cmd << "--no-push-cache"
        }
        if (config.oci_layout_path) {
            cmd << "--oci-layout-path=${config.oci_layout_path}"
        }
        if (config.push_ignore_immutable_tag_errors) {
            cmd << "--push-ignore-immutable-tag-errors"
        }
        if (config.push_retry != null) {
            cmd << "--push-retry=${config.push_retry}"
        }
        if (config.registry_certificate instanceof List) {
            config.registry_certificate.each { cert -> cmd << "--registry-certificate=${cert}" }
        } else if (config.registry_certificate) {
            cmd << "--registry-certificate=${config.registry_certificate}"
        }
        if (config.registry_client_cert instanceof List) {
            config.registry_client_cert.each { cert -> cmd << "--registry-client-cert=${cert}" }
        } else if (config.registry_client_cert) {
            cmd << "--registry-client-cert=${config.registry_client_cert}"
        }
        if (config.registry_map instanceof List) {
            config.registry_map.each { map -> cmd << "--registry-map=${map}" }
        } else if (config.registry_map) {
            cmd << "--registry-map=${config.registry_map}"
        }
        if (config.registry_mirror instanceof List) {
            config.registry_mirror.each { mirror -> cmd << "--registry-mirror=${mirror}" }
        } else if (config.registry_mirror) {
            cmd << "--registry-mirror=${config.registry_mirror}"
        }
        if (config.skip_default_registry_fallback) {
            cmd << "--skip-default-registry-fallback"
        }
        if (config.reproducible) {
            cmd << "--reproducible"
        }
        if (config.single_snapshot) {
            cmd << "--single-snapshot"
        }
        if (config.skip_push_permission_check) {
            cmd << "--skip-push-permission-check"
        }
        if (config.skip_tls_verify) {
            cmd << "--skip-tls-verify"
        }
        if (config.skip_tls_verify_pull) {
            cmd << "--skip-tls-verify-pull"
        }

        // skip_tls_verify_registry handling
        def skipTlsRegistries = []
        skipTlsRegistries.addAll(autoSkipTlsRegistries)
        if (config.skip_tls_verify_registry instanceof List) {
            skipTlsRegistries.addAll(config.skip_tls_verify_registry)
        } else if (config.skip_tls_verify_registry) {
            skipTlsRegistries << config.skip_tls_verify_registry
        }
        skipTlsRegistries.unique().each { reg ->
            cmd << "--skip-tls-verify-registry=${reg}"
        }

        if (config.skip_unused_stages) {
            cmd << "--skip-unused-stages"
        }

        // snapshot_mode handling: backward compatible with boolean snapshot_mode
        if (config.snapshot_mode instanceof Boolean && config.snapshot_mode) {
            cmd << "--snapshot-mode=redo"
        } else if (config.snapshot_mode instanceof String) {
            cmd << "--snapshot-mode=${config.snapshot_mode}"
        }

        if (config.tar_path) {
            cmd << "--tar-path=${config.tar_path}"
        }
        if (config.target) {
            cmd << "--target=${config.target}"
        }
        if (config.use_new_run) {
            cmd << "--use-new-run"
        }
        if (config.verbosity) {
            cmd << "--verbosity=${config.verbosity}"
        }
        if (config.ignore_var_run != null) {
            cmd << "--ignore-var-run=${config.ignore_var_run}"
        }
        if (config.ignore_path instanceof List) {
            config.ignore_path.each { p -> cmd << "--ignore-path=${p}" }
        } else if (config.ignore_path) {
            cmd << "--ignore-path=${config.ignore_path}"
        }
        if (config.image_fs_extract_retry != null) {
            cmd << "--image-fs-extract-retry=${config.image_fs_extract_retry}"
        }
        if (config.image_download_retry != null) {
            cmd << "--image-download-retry=${config.image_download_retry}"
        }

        def buildCommand = cmd.join(" \\\n    ")

        logging.info "Running Unprivileged Kaniko Build:\n${buildCommand}"
        sh buildCommand

        logging.success "Container image built successfully."
    }
}