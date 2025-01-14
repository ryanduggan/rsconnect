findAccount <- function(accountName = NULL, server = NULL, error_call = caller_env()) {
  check_string(accountName, allow_null = TRUE, arg = "account", call = error_call)
  check_string(server, allow_null = TRUE, call = error_call)

  accounts <- accounts()
  if (nrow(accounts) == 0) {
    cli::cli_abort(
      c(
        "No accounts registered.",
        i = "Call {.fun rsconnect::setAccountInfo} to register an account."
      ),
      call = error_call
    )
  }

  if (!is.null(accountName) && !is.null(server)) {
    theseAccounts <- accounts[accounts$server == server & accounts$name == accountName, , drop = FALSE]
    if (nrow(theseAccounts) == 0) {
      cli::cli_abort(
        c(
          "Can't find account with {.arg name} = {.str {accountName}} and {.arg server} = {.str {server}}",
          i = "Call {.fun accounts} to see available options."
        ),
        call = error_call
      )
    }
  } else if (is.null(accountName) && !is.null(server)) {
    theseAccounts <- accounts[accounts$server == server, , drop = FALSE]
    if (nrow(theseAccounts) == 0) {
      cli::cli_abort(
        c(
          "Can't find any accounts with {.arg server} = {.str {server}}.",
          i = "Available servers: {.str {unique(accounts$server)}}."
        ),
        call = error_call
      )
    } else if (nrow(theseAccounts) > 1) {
      cli::cli_abort(
        c(
          "Found multiple accounts for {.arg server} = {.str {server}}.",
          "Please disambiguate by setting {.arg account}.",
          i = "Available account names: {.str {theseAccounts$name}}."
        ),
        call = error_call
      )
    }
  } else if (!is.null(accountName) && is.null(server)) {
    theseAccounts <- accounts[accounts$name == accountName, , drop = FALSE]
    if (nrow(theseAccounts) == 0) {
      cli::cli_abort(
        c(
          "Can't find any accounts with {.arg account} = {.str {accountName}}.",
          i = "Available account names: {.str {unique(accounts$name)}}."
        ),
        call = error_call
      )
    } else if (nrow(theseAccounts) > 1) {
      cli::cli_abort(
        c(
          "Found multiple accounts for {.arg account} = {.str {accountName}}.",
          "Please disambiguate by setting {.arg server}.",
          i = "Available servers: {.str {theseAccounts$server}}."
        ),
        call = error_call
      )
    }
  } else {
    theseAccounts <- accounts
    if (nrow(theseAccounts) > 1) {
      cli::cli_abort(
        c(
          "Found multiple accounts.",
          "Please disambiguate by setting {.arg server} and/or {.arg account}.",
          i = "Available servers: {.str {unique(theseAccounts$server)}}.",
          i = "Available account names: {.str {unique(theseAccounts$name)}}."
        ),
        call = error_call
      )
    }
  }
  as.list(theseAccounts)
}
