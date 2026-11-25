package helpers

/**
 * Helper to create Multibranch Pipeline Jobs with support for both
 * JTE (Jenkins Templating Engine) and standard Jenkinsfile scanning.
 *
 * Usage in a Job DSL script:
 *
 *   import helpers.MultiBranchBuilder
 *
 *   // JTE mode (default) — uses pipeline_config.groovy from repo
 *   MultiBranchBuilder.create(this, [
 *       name          : 'my-jte-project',
 *       repoUrl       : 'git@github.com:org/repo.git',
 *       credentialsId : 'github-private',
 *   ])
 *
 *   // Jenkinsfile mode — scans for Jenkinsfile in repo
 *   MultiBranchBuilder.create(this, [
 *       name          : 'my-classic-project',
 *       repoUrl       : 'git@github.com:org/repo.git',
 *       credentialsId : 'github-private',
 *       useJte        : false,
 *       scriptPath    : 'ci/Jenkinsfile',   // optional, defaults to 'Jenkinsfile'
 *   ])
 **/

class MultiBranchBuilder {
    /**
     * Create a Multibranch Pipeline Job.
     *
     * @param dslContext  The Job DSL script context (pass `this` from the seed script).
     * @param config      A map with the following keys:
     *   - name            (String, required)  – Job name, e.g. 'next-visa-bulletin'.
     *   - repoUrl         (String, required)  – Git repository URL.
     *   - credentialsId   (String, required)  – Jenkins credentials ID for Git authentication.
     *   - id              (String, optional)  – Unique identifier for the branch source, defaults to name.
     *   - includes        (String, optional)  – Branch include pattern, defaults to '*'.
     *   - excludes        (String, optional)  – Branch exclude pattern, defaults to '' (none).
     *   - numToKeep       (int, optional)     – Max orphaned items to keep, defaults to 20.
     *   - parentFolder    (String, optional)  – Parent folder path, e.g. 'Projects/CI'. If set, the
     *                                           job is created as '<parentFolder>/<name>'.
     *   - useJte          (boolean, optional) – true  = JTE template factory (pipeline_config.groovy),
     *                                           false = standard Jenkinsfile scanning.
     *                                           Defaults to true.
     *   - filterBranches  (boolean, optional) – JTE only: whether to filter branches, defaults to true.
     *   - scriptPath      (String, optional)  – Jenkinsfile only: path to the pipeline script,
     *                                           defaults to 'Jenkinsfile'.
     */
    static void create(def dslContext, Map config) {
        def name           = config.name
        def repoUrl        = config.repoUrl
        def credentialsId  = config.credentialsId
        def sourceId       = config.id ?: name
        def includes       = config.includes ?: '*'
        def excludes       = config.excludes ?: ''
        def numToKeep      = config.numToKeep ?: 20
        def useJte         = config.containsKey('useJte') ? config.useJte : true
        def filterBranches = config.containsKey('filterBranches') ? config.filterBranches : true
        def scriptPath     = config.scriptPath ?: 'Jenkinsfile'
        def jobPath        = config.parentFolder ? "${config.parentFolder}/${name}" : name

        dslContext.multibranchPipelineJob(jobPath) {
            branchSources {
                git {
                    id(sourceId)
                    remote(repoUrl)
                    delegate.credentialsId(credentialsId)
                    delegate.includes(includes)
                    if (excludes) {
                        delegate.excludes(excludes)
                    }
                }
            }
            orphanedItemStrategy {
                discardOldItems {
                    delegate.numToKeep(numToKeep)
                }
            }
            if (useJte) {
                // Use JTE template factory — reads pipeline_config.groovy from repo
                configure {
                    it / factory(class: 'org.boozallen.plugins.jte.job.TemplateBranchProjectFactory') {
                        delegate.filterBranches(filterBranches)
                    }
                }
            } else {
                // Use standard Jenkinsfile scanning
                factory {
                    workflowBranchProjectFactory {
                        delegate.scriptPath(scriptPath)
                    }
                }
            }
        }
    }
}

