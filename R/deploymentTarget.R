# calculate the deployment target based on the passed parameters and
# any saved deployments that we have
deploymentTarget <- function(appPath = ".",
                             appName = NULL,
                             appTitle = NULL,
                             appId = NULL,
                             account = NULL,
                             server = NULL,
                             error_call = caller_env()) {

  appDeployments <- deployments(
    appPath = appPath,
    nameFilter = appName,
    accountFilter = account,
    serverFilter = server
  )

  if (nrow(appDeployments) == 0) {
    fullAccount <- findAccount(account, server)
    if (is.null(appName)) {
      appName <- generateAppName(appTitle, appPath, account, unique = FALSE)
    }

    createDeploymentTarget(
      appPath,
      appName,
      appTitle %||% "",
      appId,
      fullAccount$name, # first deploy must be to own account
      fullAccount$name,
      fullAccount$server
    )
  } else if (nrow(appDeployments) == 1) {
    createDeploymentTarget(
      appPath,
      appDeployments$name,
      appTitle %||% appDeployments$title,
      appDeployments$appId,
      # if username not previously recorded, use current account
      appDeployments$username %||% appDeployments$account,
      appDeployments$account,
      appDeployments$server
    )
  } else {
    cli::cli_abort(
      c(
        "This app has been previously deployed in multiple places.",
        "Please use {.arg appName}, {.arg server} or {.arg account} to disambiguate.",
        i = "Known application names: {.str {unique(appDeployments$name)}}.",
        i = "Known servers: {.str {unique(appDeployments$server)}}.",
        i = "Known account names: {.str {unique(appDeployments$account)}}."
      ),
      call = error_call
    )
  }
}

createDeploymentTarget <- function(appPath,
                                   appName,
                                   appTitle,
                                   appId,
                                   username,
                                   account,
                                   server) {
  list(
    appName = appName,
    appTitle = appTitle,
    appId = appId,
    username = username,
    account = account,
    server = server
  )
}
