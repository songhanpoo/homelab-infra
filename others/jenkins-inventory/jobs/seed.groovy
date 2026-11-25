import helpers.FileUtils
import helpers.FolderBuilder
import helpers.MultiBranchBuilder

// ─── Load job inventory from YAML ─────────────────────────────────
def config = FileUtils.fetchAndParseYAML(this, out, 'nonprod.yaml')

// ─── Create plain folders ─────────────────────────────────────────
config.folders?.each { f ->
    folder(f.path) {
        if (f.displayName) {
            displayName(f.displayName)
        }
        if (f.description) {
            description(f.description)
        }
    }
}

// ─── Create JTE governance folders ────────────────────────────────
config.jteFolders?.each { jte ->
    FolderBuilder.createJteFolder(this, jte)
}

// ─── Create multibranch pipeline jobs ─────────────────────────────
config.multibranchJobs?.each { mb ->
    MultiBranchBuilder.create(this, mb)
}