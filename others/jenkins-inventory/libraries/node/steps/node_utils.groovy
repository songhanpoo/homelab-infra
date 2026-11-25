
/**
 * Make this step work as a helper object when called.
 * Usage: def utils = node_utils()
 */
def call() {
    return this
}

/**
 * Detects the package manager from config or lock files.
 */
String detectPackageManager() {
    // 1. Check if explicitly configured in pipeline_config.groovy
    try {
        def configured = config.package_manager
        if (configured) {
            logging.debug "Package manager from config: ${configured}"
            return configured.toLowerCase()
        }
    } catch (Exception e) {
        // config.package_manager not set, continue to auto-detect
        logging.info "config.package_manager not set, continue to auto-detect"
    }

    // 2. Auto-detect from lock files
    if (fileExists('pnpm-lock.yaml')) {
        logging.debug "Detected pnpm-lock.yaml"
        return 'pnpm'
    } else if (fileExists('yarn.lock')) {
        logging.debug "Detected yarn.lock"
        return 'yarn'
    } else {
        logging.debug "No lock file found, defaulting to npm"
        return 'npm'
    }
}

/**
 * Installs the package manager globally if it's not npm (npm is already bundled with Node).
 */
void installPackageManager(String pm) {
    if (pm == 'npm') {
        sh 'npm -v'
        return
    }

    // Check if already installed
    def installed = sh(script: "which ${pm} > /dev/null 2>&1", returnStatus: true) == 0

    if (!installed) {
        logging.info "Installing ${pm} globally..."
        def skip_env_validation = config.skip_env_validation
        switch (pm) {
            case 'pnpm':
                logging.info "Installing corepack globally..."
                sh 'npm install --global corepack@latest'
                sh 'corepack enable'
                logging.info "Installing ${pm} globally..."
                sh 'corepack prepare pnpm@latest-10 --activate'
                env.SKIP_ENV_VALIDATION = skip_env_validation
                break
            default:
                logging.info "Installing ${pm} globally..."
                sh "npm install -g ${pm}"
        }

    }

    sh "${pm} -v"
}