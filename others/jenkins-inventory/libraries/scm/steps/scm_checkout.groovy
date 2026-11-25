/**
 * SCM checkout step — cleans workspace and checks out source code.
 */
void call() {
  deleteDir()
  logging.info "Checking out source code..."
  
  def scmVars = checkout(scm)

  env.APP_COMMIT_HASH = scmVars.GIT_COMMIT
  env.GIT_URL         = scmVars.GIT_URL

  logging.success "Checkout completed"
}