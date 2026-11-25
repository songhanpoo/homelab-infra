@merge jte {
    allow_scm_jenkinsfile = false
}

// Default CI stages — all repos share these.
// The 'ci' library steps auto-detect language from config.
stages {
    @merge stage_checkout {
        scm_checkout
    }
    @override stage_compile {
        ci_install
    }
    @override stage_build {
        ci_build
    }
    // stage_build {
    //     ci_build
    // }
}

// Default libraries for all repos.
@merge libraries {
    helpers
    scm
    ci
}