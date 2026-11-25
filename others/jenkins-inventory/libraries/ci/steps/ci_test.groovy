/**
 * CI Test step — reads app_type from application_environments and runs tests.
 */
void call() {
    def lang = getAppType()
    logging.info "CI Test — app_type: ${lang}"

    switch (lang) {
        case 'node':
            container('node') {
                def pm = getPackageManager()
                sh "${pm} run test || ${pm} test"
            }
            break
        case 'python':
            container('python') {
                if (fileExists('pytest.ini') || fileExists('setup.cfg') || fileExists('pyproject.toml')) {
                    sh 'python -m pytest'
                } else {
                    sh 'python -m unittest discover'
                }
            }
            break
        case 'java':
            container('maven') {
                if (fileExists('pom.xml')) {
                    sh 'mvn test -B'
                } else {
                    sh './gradlew test'
                }
            }
            break
        default:
            logging.warning "No test runner configured for '${lang}'"
    }

    logging.success "Tests completed"
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
