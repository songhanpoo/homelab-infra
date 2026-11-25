/**
 * CI Install step — reads app_type from application_environments and installs dependencies.
 *
 * Repo pipeline_config.groovy:
 *   application_environments {
 *       globally {
 *           app_type = "node"            // "node", "python", "java"
 *           package_manager = "pnpm"     // node only: "npm", "yarn", "pnpm"
 *       }
 *   }
 *
 * Falls back to auto-detection from project files if app_type is not set.
 */
void call() {
    def lang = getAppType()
    logging.info "CI Install — app_type: ${lang}"

    switch (lang) {
        case 'node':
            node_install()
            break
        case 'python':
            installPython()
            break
        case 'java':
            installJava()
            break
        default:
            logging.warning "Unknown app_type '${lang}', skipping install"
    }
}

// ─── Read app_type from application_environments ──────────────────

private String getAppType() {
    try {
        return globally.app_type?.toLowerCase()
    } catch (Exception e) {
        logging.debug "No app_type configured, auto-detecting..."
        return detectLanguage()
    }
}

private String getPackageManager() {
    try {
        return globally.package_manager?.toLowerCase()
    } catch (Exception e) {
        return autoDetectPM()
    }
}


// ─── Python ───────────────────────────────────────────────────────

private void installPython() {
    container('python') {
        sh 'python --version'
        logging.info "Installing Python dependencies..."

        if (fileExists('requirements.txt')) {
            sh 'pip install -r requirements.txt'
        } else if (fileExists('Pipfile')) {
            sh 'pip install pipenv && pipenv install --deploy'
        } else if (fileExists('pyproject.toml')) {
            sh 'pip install -e .'
        }

        logging.success "Python dependencies installed"
    }
}

// ─── Java ─────────────────────────────────────────────────────────

private void installJava() {
    container('maven') {
        sh 'java -version'
        sh 'mvn -version'
        logging.info "Resolving Java dependencies..."

        if (fileExists('pom.xml')) {
            sh 'mvn dependency:resolve -B'
        } else if (fileExists('build.gradle') || fileExists('build.gradle.kts')) {
            sh './gradlew dependencies'
        }

        logging.success "Java dependencies resolved"
    }
}

// ─── Auto-detect language from project files ──────────────────────

private String detectLanguage() {
    if (fileExists('package.json'))    return 'node'
    if (fileExists('requirements.txt') || fileExists('pyproject.toml') || fileExists('Pipfile')) return 'python'
    if (fileExists('pom.xml') || fileExists('build.gradle') || fileExists('build.gradle.kts'))   return 'java'
    return 'unknown'
}
