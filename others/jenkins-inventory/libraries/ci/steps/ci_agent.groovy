/**
 * Helper to dynamically determine the Kubernetes builder pod template labels
 * based on the globally.app_type determined by JTE application_environments.
 */
String call() {
    String appType = 'unknown'
    try { 
        appType = globally.app_type?.toLowerCase() ?: 'unknown' 
    } catch (Exception e) {
        logging.warning "Failed to determine app_type, falling back to fat pod"
    }

    switch (appType) {
        case 'node':   return 'node-22 alpine-3-22-4'
        case 'cots':   return 'kaniko alpine-3-22-4'
        case 'python': return 'python-311 alpine-3-22-4'
        default:       return 'node-22 python-311 kaniko alpine-3-22-4' // Fallback fat pod
    }
}
