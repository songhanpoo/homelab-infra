/**
 * Logging utility for Jenkins pipelines with ANSI colors and sensitive data masking.
 *
 * Requires: ansiColor plugin + `options { ansiColor('xterm') }` in the Jenkinsfile.
 *
 * Usage in a JTE step or Jenkinsfile:
 *
 *   logging.debug   "Fetching artifact from ${url}"
 *   logging.info    "Build started for branch ${env.BRANCH_NAME}"
 *   logging.warning "Deprecated API version detected"
 *   logging.error   "Connection to registry failed"
 *   logging.success "All tests passed"
 */

void call(String message) {
    info(message)
}

void debug(String message) {
    def ts = new Date().format("yyyy-MM-dd HH:mm:ss")
    echo "\u001B[36m\u001B[1m⌕ [DEBUG]\u001B[0m \u001B[36m[${ts}] ${mask(message)}\u001B[0m"
}

void info(String message) {
    def ts = new Date().format("yyyy-MM-dd HH:mm:ss")
    echo "\u001B[34m\u001B[1mℹ [INFO]\u001B[0m \u001B[34m[${ts}] ${mask(message)}\u001B[0m"
}

void warning(String message) {
    def ts = new Date().format("yyyy-MM-dd HH:mm:ss")
    echo "\u001B[33m\u001B[1m♺ [WARNING]\u001B[0m \u001B[33m[${ts}] ${mask(message)}\u001B[0m"
}

void error(String message) {
    def ts = new Date().format("yyyy-MM-dd HH:mm:ss")
    echo "\u001B[31m\u001B[1m✖ [ERROR]\u001B[0m \u001B[31m[${ts}] ${mask(message)}\u001B[0m"
}

void success(String message) {
    def ts = new Date().format("yyyy-MM-dd HH:mm:ss")
    echo "\u001B[32m\u001B[1m✔ [SUCCESS]\u001B[0m \u001B[32m[${ts}] ${mask(message)}\u001B[0m"
}

// ─── Sensitive data masking ───────────────────────────────────────

private String mask(String message) {
    if (!message) return message

    def masked = message

    try {
        def patterns = [
            'PASSWORD', 'PASSWD', 'PASS',
            'SECRET', 'TOKEN',
            'API_KEY', 'APIKEY',
            'PRIVATE_KEY', 'PRIVATE',
            'CREDENTIAL', 'CREDENTIALS',
            'AUTH', 'SSH_KEY',
            'AWS_ACCESS_KEY', 'AWS_SECRET',
            'JENKINS_SERVER_COOKIE',
        ]
        def envVars = env.getEnvironment()
        envVars.each { key, value ->
            if (!value || value.trim().isEmpty()) return
            if (patterns.any { key.toUpperCase().contains(it) }) {
                masked = masked.replace(value, '****')
            }
        }
    } catch (Exception e) {
        // env.getEnvironment() may not be available in all contexts
    }

    return masked
}