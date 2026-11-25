package helpers

/**
 * Helper to create Jenkins folders with JTE (Jenkins Templating Engine)
 * configurationProvider and librarySources wired to a Git SCM repository.
 *
 * Usage in a Job DSL script:
 *
 *   import helpers.FolderBuilder
 *
 *   FolderBuilder.createJteFolder(this, [
 *       folderPath    : 'Projects/CI',
 *       displayName   : 'CI',
 *       description   : 'Continuous Integration pipelines using JTE',
 *       repoUrl       : 'git@github.com:songhanpoo/jenkins-inventory.git',
 *       credentialsId : 'github-private',
 *       branch        : '*\/master',
 *       configBaseDir : 'templates\/ci',
 *       libraryBaseDir: 'libraries',
 *   ])
**/

class FolderBuilder {
    /**
     * Create a Jenkins folder with JTE governance configuration.
     *
     * @param dslContext  The Job DSL script context (pass `this` from the seed script).
     * @param config      A map with the following keys:
     *   - folderPath      (String, required) – Full folder path, e.g. 'Projects/CI'.
     *   - displayName     (String, optional) – Human-readable name shown in the Jenkins UI.
     *   - description     (String, optional) – Folder description.
     *   - repoUrl         (String, required) – Git repository URL for both config and libraries.
     *   - credentialsId   (String, required) – Jenkins credentials ID for Git authentication.
     *   - branch          (String, optional) – Branch spec, defaults to '*​/master'.
     *   - configBaseDir   (String, required) – Base directory for JTE pipeline configuration (e.g. 'templates/ci').
     *   - libraryBaseDir  (String, optional) – Base directory for JTE libraries, defaults to 'libraries'.
     *   - jtePluginVersion(String, optional) – templating-engine plugin version, defaults to '2.5.5'.
     */
    static void createJteFolder(def dslContext, Map config) {
        def folderPath     = config.folderPath
        def folderDisplay  = config.displayName ?: folderPath.tokenize('/').last()
        def folderDesc     = config.description ?: ''
        def repoUrl        = config.repoUrl
        def credentialsId  = config.credentialsId
        def branch         = config.branch ?: '*/master'
        def configBaseDir  = config.configBaseDir
        def libraryBaseDir = config.libraryBaseDir ?: 'libraries'
        def pluginVersion  = config.jtePluginVersion ?: '2.5.5'

        dslContext.folder(folderPath) {
            displayName(folderDisplay)
            description(folderDesc)
            configure { folderNode ->
                def properties = folderNode / 'properties'
                properties << "org.boozallen.plugins.jte.init.governance.TemplateConfigFolderProperty"(plugin: "templating-engine@${pluginVersion}") {
                    tier {
                        configurationProvider(class: 'org.boozallen.plugins.jte.init.governance.config.ScmPipelineConfigurationProvider') {
                            delegate.baseDir(configBaseDir)
                            scm(class: 'hudson.plugins.git.GitSCM') {
                                configVersion('2')
                                userRemoteConfigs {
                                    'hudson.plugins.git.UserRemoteConfig' {
                                        delegate.url(repoUrl)
                                        delegate.credentialsId(credentialsId)
                                    }
                                }
                                branches {
                                    'hudson.plugins.git.BranchSpec' {
                                        name(branch)
                                    }
                                }
                                doGenerateSubmoduleConfigurations('false')
                                submoduleCfg(class: 'empty-list')
                                extensions()
                            }
                        }
                        librarySources {
                            'org.boozallen.plugins.jte.init.governance.libs.LibrarySource' {
                                libraryProvider(class: 'org.boozallen.plugins.jte.init.governance.libs.ScmLibraryProvider') {
                                    delegate.baseDir(libraryBaseDir)
                                    scm(class: 'hudson.plugins.git.GitSCM') {
                                        configVersion('2')
                                        userRemoteConfigs {
                                            'hudson.plugins.git.UserRemoteConfig' {
                                                delegate.url(repoUrl)
                                                delegate.credentialsId(credentialsId)
                                            }
                                        }
                                        branches {
                                            'hudson.plugins.git.BranchSpec' {
                                                name(branch)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
