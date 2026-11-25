/**
 * Node.js test step — runs the test script using the detected package manager.
 */
void call() {
    container('node') {
        logging.info "Running tests..."

        def pm = detectPM()
        sh "${pm} test || ${pm} run test"

        logging.success "Tests completed"
    }
}

private String detectPM() {
    if (fileExists('pnpm-lock.yaml')) return 'pnpm'
    if (fileExists('yarn.lock')) return 'yarn'
    return 'npm'
}
