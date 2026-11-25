/**
 * Node.js library step — detects and uses the correct package manager
 * (yarn, pnpm, or npm) based on lock files, then installs dependencies.
 *
 * Configuration in pipeline_config.groovy:
 *
 *   libraries {
 *       node {
 *           package_manager = "pnpm"   // optional: force "yarn", "pnpm", or "npm"
 *       }
 *   }
 *
 * If `package_manager` is not set, auto-detects from lock files:
 *   - pnpm-lock.yaml  → pnpm
 *   - yarn.lock       → yarn
 *   - otherwise       → npm
 */
void call() {
    container('node') {
        logging.info "Node Agent CI step started"

        // Show runtime versions
        sh 'node -v'

        // Determine package manager
        def utils = node_utils()
        def pm = utils.detectPackageManager()
        logging.info "Using package manager: ${pm}"

        // Install the package manager if needed
        utils.installPackageManager(pm)

        // Install dependencies
        logging.info "Installing dependencies with ${pm}..."
        sh "${pm} install --frozen-lockfile || ${pm} install"

        logging.success "Node.js dependencies installed successfully"
    }
}