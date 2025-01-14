appMetadata <- function(appDir,
                        appFiles = NULL,
                        appPrimaryDoc = NULL,
                        quarto = NULL,
                        contentCategory = NULL,
                        isCloudServer = FALSE,
                        metadata = list()) {

  appFiles <- standardizeAppFiles(appDir, appFiles)

  # User has supplied quarto path or quarto package/IDE has supplied metadata
  # https://github.com/quarto-dev/quarto-r/blob/08caf0f42504e7/R/publish.R#L117-L121
  # https://github.com/rstudio/rstudio/blob/3d45a20307f650/src/cpp/session/modules/SessionRSConnect.cpp#L81-L123
  hasQuarto <- !is.null(quarto) || hasQuartoMetadata(metadata)

  # Generally we want to infer appPrimaryDoc from appMode, but there's one
  # special case
  if (!is.null(appPrimaryDoc) &&
      tolower(tools::file_ext(appPrimaryDoc)) == "r") {
    appMode <- "shiny"
  } else {
    # Inference only uses top-level files
    rootFiles <- appFiles[dirname(appFiles) == "."]
    appMode <- inferAppMode(
      file.path(appDir, appFiles),
      hasQuarto = hasQuarto,
      isCloudServer = isCloudServer
    )
  }

  appPrimaryDoc <- inferAppPrimaryDoc(
    appPrimaryDoc = appPrimaryDoc,
    appFiles = appFiles,
    appMode = appMode
  )
  hasParameters <- appHasParameters(
    appDir = appDir,
    appPrimaryDoc = appPrimaryDoc,
    appMode = appMode,
    contentCategory = contentCategory
  )
  documentsHavePython <- detectPythonInDocuments(
    appDir = appDir,
    files = appFiles
  )
  quartoInfo <- inferQuartoInfo(
    appDir = appDir,
    appPrimaryDoc = appPrimaryDoc,
    quarto = quarto,
    metadata = metadata
  )

  list(
    appMode = appMode,
    appPrimaryDoc = appPrimaryDoc,
    hasParameters = hasParameters,
    documentsHavePython = documentsHavePython,
    quartoInfo = quartoInfo
  )
}

# infer the mode of the application from files in the root dir
inferAppMode <- function(absoluteAppFiles,
                         hasQuarto = FALSE,
                         isCloudServer = FALSE) {

  matchingNames <- function(paths, pattern) {
    idx <- grepl(pattern, basename(paths), ignore.case = TRUE, perl = TRUE)
    paths[idx]
  }

  # plumber API
  plumberFiles <- matchingNames(absoluteAppFiles, "^(plumber|entrypoint).r$")
  if (length(plumberFiles) > 0) {
    return("api")
  }

  # Shiny application using single-file app.R style.
  appR <- matchingNames(absoluteAppFiles, "^app.r$")
  if (length(appR) > 0) {
    return("shiny")
  }

  rmdFiles <- matchingNames(absoluteAppFiles, "\\.rmd$")
  qmdFiles <- matchingNames(absoluteAppFiles, "\\.qmd$")

  # We make Quarto requirement conditional on the presence of files that Quarto
  # can render and _quarto.yml, because keying off the presence of qmds
  # *or* _quarto.yml was causing deployment failures in static content.
  # https://github.com/rstudio/rstudio/issues/11444
  quartoYml <- matchingNames(absoluteAppFiles, "^_quarto.y(a)?ml$")
  hasQuartoYaml <- length(quartoYml) > 0
  hasQuartoCompatibleFiles <- length(qmdFiles) > 0 || length(rmdFiles > 0)
  requiresQuarto <- (hasQuartoCompatibleFiles && hasQuartoYaml) || length(qmdFiles) > 0

  # We gate the deployment of content that appears to be Quarto behind the
  # presence of Quarto metadata. Rmd files can still be deployed as Quarto
  if (requiresQuarto && !hasQuarto) {
    cli::cli_abort(c(
      "Can't deploy Quarto content when {.arg quarto} is {.code NULL}.",
      i = "Please supply a path to a quarto binary in {.arg quarto}."
    ))
  }

  # Documents with "server: shiny" in their YAML front matter need shiny too
  hasShinyRmd <- any(sapply(rmdFiles, isShinyRmd))
  hasShinyQmd <- any(sapply(qmdFiles, isShinyRmd))

  if (hasShinyQmd) {
    return("quarto-shiny")
  } else if (hasShinyRmd) {
    if (hasQuarto) {
      return("quarto-shiny")
    } else {
      return("rmd-shiny")
    }
  }

  # Shiny application using server.R; checked later than Rmd with shiny runtime
  # because server.R may contain the server code paired with a ShinyRmd and needs
  # to be run by rmarkdown::run (rmd-shiny).
  serverR <- matchingNames(absoluteAppFiles, "^server.r$")
  if (length(serverR) > 0) {
    return("shiny")
  }

  # Any non-Shiny R Markdown or Quarto documents are rendered content and get
  # rmd-static or quarto-static.
  if (length(rmdFiles) > 0 || length(qmdFiles) > 0) {
    if (hasQuarto) {
      return("quarto-static")
    } else {
      # For Shinyapps and posit.cloud, treat "rmd-static" app mode as "rmd-shiny" so that
      # they can be served from a shiny process in Connect until we have better support of
      # rmarkdown static content
      if (isCloudServer) {
        return("rmd-shiny")
      }
      return("rmd-static")
    }
  }

  # We don't have an RMarkdown, Shiny app, or Plumber API, but we have a saved model
  modelFiles <- matchingNames(absoluteAppFiles, "^(saved_model.pb|saved_model.pbtxt)$")
  if (length(modelFiles) > 0) {
    return("tensorflow-saved-model")
  }

  # no renderable content
  "static"
}

isShinyRmd <- function(filename) {
  yaml <- yamlFromRmd(filename)
  if (is.null(yaml)) {
    return(FALSE)
  }
  is_shiny_prerendered(yaml$runtime, yaml$server)
}
# Adapted from rmarkdown:::is_shiny_prerendered()
is_shiny_prerendered <- function(runtime, server = NULL) {
  if (!is.null(runtime) && grepl("^shiny", runtime)) {
    TRUE
  } else if (identical(server, "shiny")) {
    TRUE
  } else if (is.list(server) && identical(server[["type"]], "shiny")) {
    TRUE
  } else {
    FALSE
  }
}

# If deploying an R Markdown, Quarto, or static content, infer a primary
# document if one is not already specified.
# Note: functionality in inferQuartoInfo() depends on primary doc inference
# working the same across app modes.
inferAppPrimaryDoc <- function(appPrimaryDoc, appFiles, appMode) {
  if (!is.null(appPrimaryDoc)) {
    return(appPrimaryDoc)
  }

  # Only documents and static apps don't have primary _doc_
  if (!(appIsDocument(appMode) || appMode == "static")) {
    return(appPrimaryDoc)
  }

  # determine expected primary document extension
  ext <- if (appMode == "static") "\\.html?$" else "\\.[Rq]md$"

  # use index file if it exists
  matching <- grepl(paste0("^index", ext), appFiles, ignore.case = TRUE)
  if (!any(matching)) {
    # no index file found, so pick the first one we find
    matching <- grepl(ext, appFiles, ignore.case = TRUE)

    if (!any(matching)) {
      cli::cli_abort(c(
        "Failed to determine {.arg appPrimaryDoc}.",
        x = "No files matching {.str {ext}}."
      ))
    }
  }

  if (sum(matching) > 1) {
    # if we have multiple matches, pick the first
    appFiles[matching][[1]]
  } else {
    appFiles[matching]
  }
}

appIsDocument <- function(appMode) {
  appMode %in% c(
    "rmd-static",
    "rmd-shiny",
    "quarto-static",
    "quarto-shiny"
  )
}

appHasParameters <- function(appDir, appPrimaryDoc, appMode, contentCategory = NULL) {
  # Only Rmd deployments are marked as having parameters. Shiny applications
  # may distribute an Rmd alongside app.R, but that does not cause the
  # deployment to be considered parameterized.
  #
  # https://github.com/rstudio/rsconnect/issues/246
  if (!(appIsDocument(appMode))) {
    return(FALSE)
  }
  # Sites don't ever have parameters
  if (identical(contentCategory, "site")) {
    return(FALSE)
  }

  # Only Rmd files have parameters.
  if (tolower(tools::file_ext(appPrimaryDoc)) == "rmd") {
    filename <- file.path(appDir, appPrimaryDoc)
    yaml <- yamlFromRmd(filename)
    if (!is.null(yaml)) {
      params <- yaml[["params"]]
      # We don't care about deep parameter processing, only that they exist.
      return(!is.null(params) && length(params) > 0)
    }
  }
  FALSE
}

detectPythonInDocuments <- function(appDir, files = NULL) {
  if (is.null(files)) {
    # for testing
    files <- bundleFiles(appDir)
  }

  rmdFiles <- grep("^[^/\\\\]+\\.[rq]md$", files, ignore.case = TRUE, perl = TRUE, value = TRUE)
  for (rmdFile in rmdFiles) {
    if (documentHasPythonChunk(file.path(appDir, rmdFile))) {
      return(TRUE)
    }
  }
  return(FALSE)
}
documentHasPythonChunk <- function(filename) {
  lines <- readLines(filename, warn = FALSE, encoding = "UTF-8")
  matches <- grep("`{python", lines, fixed = TRUE)
  return(length(matches) > 0)
}

inferQuartoInfo <- function(appDir, appPrimaryDoc, quarto, metadata) {
  if (hasQuartoMetadata(metadata)) {
    return(list(
      version = metadata[["quarto_version"]],
      engines = metadata[["quarto_engines"]]
    ))
  }

  if (is.null(quarto)) {
    return(NULL)
  }

  # If we don't yet have Quarto details, run quarto inspect ourselves
  inspect <- quartoInspect(
    quarto = quarto,
    appDir = appDir,
    appPrimaryDoc = appPrimaryDoc
  )
  if (is.null(inspect)) {
    return(NULL)
  }

  list(
    version = inspect[["quarto"]][["version"]],
    engines = I(inspect[["engines"]])
  )
}

hasQuartoMetadata <- function(x) {
  !is.null(x$quarto_version)
}

# Run "quarto inspect" on the target and returns its output as a parsed object.
quartoInspect <- function(quarto, appDir = NULL, appPrimaryDoc = NULL) {
  # If "quarto inspect appDir" fails, we will try "quarto inspect
  # appPrimaryDoc", so that we can support single files as well as projects.
  paths <- c(appDir, file.path(appDir, appPrimaryDoc))

  for (path in paths) {
    args <- c("inspect", path.expand(path))
    inspect <- tryCatch(
      {
        json <- suppressWarnings(system2(quarto, args, stdout = TRUE, stderr = TRUE))
        parsed <- jsonlite::fromJSON(json)
        return(parsed)
      },
      error = function(e) NULL
    )
  }
  return(NULL)
}
