/**
 * CI Build step — reads app_type from application_environments and runs the build.
 */
void call() {
    def lang = getAppType()
    logging.info "CI Build — app_type: ${lang}"

    switch (lang) {
        case 'node':
            node_build()
            break
        case 'python':
            container('python') {
                if (fileExists('setup.py')) {
                    sh 'python setup.py build'
                } else if (fileExists('pyproject.toml')) {
                    sh 'pip install build && python -m build'
                }
            }
            break
        case 'java':
            container('maven') {
                if (fileExists('pom.xml')) {
                    sh 'mvn package -B -DskipTests'
                } else {
                    sh './gradlew build -x test'
                }
            }
            break
        case 'cots':
            kaniko_execute()
            break
        default:
            logging.warning "No build configured for '${lang}'"
    }

    logging.success "Build completed"
}

private String getAppType() {
    try { return globally.app_type?.toLowerCase() }
    catch (Exception e) { return detectLanguage() }
}

private String getPackageManager() {
    try { return globally.package_manager?.toLowerCase() }
    catch (Exception e) { return autoDetectPM() }
}

private String autoDetectPM() {
    if (fileExists('pnpm-lock.yaml')) return 'pnpm'
    if (fileExists('yarn.lock')) return 'yarn'
    return 'npm'
}

private String detectLanguage() {
    if (fileExists('package.json'))    return 'node'
    if (fileExists('requirements.txt') || fileExists('pyproject.toml')) return 'python'
    if (fileExists('pom.xml') || fileExists('build.gradle'))           return 'java'
    return 'unknown'
}
