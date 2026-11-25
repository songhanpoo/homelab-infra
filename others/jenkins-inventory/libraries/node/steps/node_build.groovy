/**
 * Node.js build step — runs the build script using the detected package manager.
 */
void call() {
    container('node') {
        logging.info "Running build..."
        def utils = node_utils()
        def pm = utils.detectPackageManager()
        logging.info "Using package manager: ${pm}"

        sh "${pm} run build"

        logging.success "Build completed"
    }
}