# appMetadata -------------------------------------------------------------

test_that("clear error if no files", {
  dir <- local_temp_app()
  expect_snapshot(appMetadata(dir), error = TRUE)
})

test_that("quarto affects mode inference", {
  dir <- local_temp_app(list("foo.Rmd" = ""))

  metadata <- appMetadata(dir)
  expect_equal(metadata$appMode, "rmd-static")

  metadata <- appMetadata(dir, quarto = "quarto")
  expect_equal(metadata$appMode, "quarto-static")
})

test_that("handles special case of appPrimaryDoc as R file", {
  dir <- local_temp_app(list("foo.R" = ""))
  metadata <- appMetadata(dir, appPrimaryDoc = "foo.R")
  expect_equal(metadata$appMode, "shiny")
})

# inferAppMode ------------------------------------------------------------

test_that("can infer mode for APIs", {
  expect_equal(inferAppMode("plumber.R"), "api")
  expect_equal(inferAppMode("entrypoint.R"), "api")
})

test_that("can infer mode for shiny apps", {
  expect_equal(inferAppMode("app.R"), "shiny")
  expect_equal(inferAppMode("server.R"), "shiny")
})

test_that("can infer mode for static quarto and rmd docs", {
  dir <- local_temp_app(list("foo.Rmd" = ""))
  paths <- list.files(dir, full.names = TRUE)

  expect_equal(inferAppMode(paths), "rmd-static")
  expect_equal(inferAppMode(paths, hasQuarto = TRUE), "quarto-static")
  # Static R Markdown treated as rmd-shiny for shinyapps and rstudio.cloud targets
  expect_equal(inferAppMode(paths, isCloudServer = TRUE), "rmd-shiny")
})

test_that("quarto docs require quarto", {
  dir <- local_temp_app(list("foo.qmd" = ""))
  single_qmd <- list.files(dir, full.names = TRUE)

  dir <- local_temp_app(list("foo.Rmd" = "", "_quarto.yaml" = ""))
  rmd_and_quarto_yml <- list.files(dir, full.names = TRUE)

  expect_snapshot(error = TRUE, {
    inferAppMode(single_qmd)
    inferAppMode(rmd_and_quarto_yml)
  })
})

test_that("can infer mode for shiny rmd docs", {
  yaml_runtime <- function(runtime) {
    c("---", paste0("runtime: ", runtime), "---")
  }

  dir <- local_temp_app(list("index.Rmd" = yaml_runtime("shiny")))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths), "rmd-shiny")

  dir <- local_temp_app(list("index.Rmd" = yaml_runtime("shinyrmd")))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths), "rmd-shiny")

  dir <- local_temp_app(list("index.Rmd" = yaml_runtime("shiny_prerendered")))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths), "rmd-shiny")

  # can pair server.R with shiny runtime
  dir <- local_temp_app(list("index.Rmd" = yaml_runtime("shiny"), "server.R" = ""))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths), "rmd-shiny")

  # Beats static rmarkdowns
  dir <- local_temp_app(list("index.Rmd" = yaml_runtime("shiny"), "foo.Rmd" = ""))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths), "rmd-shiny")
})

test_that("can infer mode for shiny qmd docs", {
  yaml_runtime <- function(runtime) {
    c("---", paste0("runtime: ", runtime), "---")
  }

  dir <- local_temp_app(list("index.Qmd" = yaml_runtime("shiny")))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths, hasQuarto = TRUE), "quarto-shiny")

  # Can force Rmd to use quarto
  dir <- local_temp_app(list("index.Rmd" = yaml_runtime("shiny")))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths, hasQuarto = TRUE), "quarto-shiny")

  # Prefers quarto if both present
  dir <- local_temp_app(list(
    "index.Qmd" = yaml_runtime("shiny"),
    "index.Rmd" = yaml_runtime("shiny")
  ))
  paths <- list.files(dir, full.names = TRUE)
  expect_equal(inferAppMode(paths, hasQuarto = TRUE), "quarto-shiny")
})

test_that("Shiny R Markdown files are detected correctly", {
  expect_true(isShinyRmd(test_path("shiny-rmds/shiny-rmd-dashes.Rmd")))
  expect_true(isShinyRmd(test_path("shiny-rmds/shiny-rmd-dots.Rmd")))
  expect_false(isShinyRmd(test_path("shiny-rmds/non-shiny-rmd.Rmd")))
})

test_that("shiny metadata process correctly", {
  expect_false(is_shiny_prerendered(NULL, NULL))
  expect_true(is_shiny_prerendered("shiny_prerendered", NULL))
  expect_true(is_shiny_prerendered("shinyrmd", NULL))
  expect_true(is_shiny_prerendered(NULL, "shiny"))
  expect_true(is_shiny_prerendered(NULL, list(type = "shiny")))
})

test_that("can infer tensorflow models", {
  expect_equal(inferAppMode("saved_model.pb"), "tensorflow-saved-model")
})

test_that("otherwise, fallsback to static deploy", {
  expect_equal(inferAppMode(c("a.html", "b.html")), "static")
})

# inferAppPrimaryDoc ------------------------------------------------------

test_that("leaves addPrimaryDoc unchanged or not a document", {
  expect_equal(inferAppPrimaryDoc("foo.Rmd"), "foo.Rmd")
  expect_equal(inferAppPrimaryDoc(NULL, appMode = "shiny"), NULL)
  expect_equal(inferAppPrimaryDoc(NULL, appMode = "api"), NULL)
})

test_that("uses index file if present", {
  files <- c("index.html", "index.Rmd", "a.html", "b.html", "a.Rmd", "b.Rmd")
  expect_equal(inferAppPrimaryDoc(NULL, files, "static"), "index.html")
  expect_equal(inferAppPrimaryDoc(NULL, files, "rmd-shiny"), "index.Rmd")
})

test_that("otherwise fails back to first file with matching extensions", {
  files <- c("a.html", "b.html", "a.Rmd", "b.Rmd")
  expect_equal(inferAppPrimaryDoc(NULL, files, "static"), "a.html")
  expect_equal(inferAppPrimaryDoc(NULL, files, "rmd-shiny"), "a.Rmd")
})

test_that("errors if no files with needed extension", {
  expect_snapshot(error = TRUE, {
    inferAppPrimaryDoc(NULL, "a.R", "static")
    inferAppPrimaryDoc(NULL, "a.R", "rmd-shiny")
  })
})

# appHasParameters --------------------------------------------------------

test_that("non-documents don't have parameters", {
  dir <- local_temp_app(list("foo.R" = ""))

  expect_false(appHasParameters(dir, "foo.R", "static"))
  expect_false(appHasParameters(dir, "foo.R", "shiny"))
})

test_that("documents don't have parameters if part of a site", {
  dir <- local_temp_app(list("index.Rmd" = c("---", "params: [1, 2]", "---")))

  expect_false(appHasParameters(dir, "index.Rmd", "rmd-static", "site"))
  expect_false(appHasParameters(dir, "index.Rmd", "qmd-shiny", "site"))
})

test_that("non-Rmd files don't have parameters", {
  dir <- local_temp_app(list("app.r" = c("")))
  expect_false(appHasParameters(dir, "app.R", "rmd-shiny"))
})

test_that("otherwise look at yaml metadata", {
  dir <- local_temp_app(list("index.Rmd" = c("---", "params: [1, 2]", "---")))
  expect_true(appHasParameters(dir, "index.Rmd", "rmd-shiny"))

  dir <- local_temp_app(list("index.Rmd" = c("---", "params: ~", "---")))
  expect_false(appHasParameters(dir, "index.Rmd", "rmd-shiny"))
})


# detectPythonInDocuments -------------------------------------------------

test_that("dir without Rmds doesn't have have python", {
  dir <- local_temp_app()
  expect_false(detectPythonInDocuments(dir))

  dir <- local_temp_app(list("foo.R" = ""))
  expect_false(detectPythonInDocuments(dir))
})

test_that("Rmd or qmd with python chunk has python", {
  dir <- local_temp_app(list("foo.qmd" = c("```{r}", "1+1", "````")))
  expect_false(detectPythonInDocuments(dir))

  dir <- local_temp_app(list("foo.Rmd" = c("```{python}", "1+1", "````")))
  expect_true(detectPythonInDocuments(dir))

  dir <- local_temp_app(list("foo.qmd" = c("```{python}", "1+1", "````")))
  expect_true(detectPythonInDocuments(dir))
})

# quarto ------------------------------------------------------------------

fakeQuartoMetadata <- function(version, engines) {
  # See quarto-r/R/publish.R lines 396 and 113.
  metadata <- list()
  metadata$quarto_version <- version
  metadata$quarto_engines <- I(engines)
  return(metadata)
}


test_that("inferQuartoInfo returns null when no quarto is provided", {
  expect_null(inferQuartoInfo(quarto = NULL, metadata = list()))
})


test_that("inferQuartoInfo correctly detects info when quarto is provided alone", {
  quarto <- quartoPathOrSkip()

  quartoInfo <- inferQuartoInfo(
    appDir = test_path("quarto-doc-none"),
    appPrimaryDoc = "quarto-doc-none.qmd",
    quarto = quarto,
    metadata = list()
  )
  expect_named(quartoInfo, c("version", "engines"))
  expect_equal(quartoInfo$engines, I(c("markdown")))

  quartoInfo <- inferQuartoInfo(
    appDir = test_path("quarto-website-r"),
    appPrimaryDoc = NULL,
    quarto = quarto,
    metadata = list()
  )
  expect_named(quartoInfo, c("version", "engines"))
  expect_equal(quartoInfo$engines, I(c("knitr")))
})

test_that("inferQuartoInfo extracts info from metadata", {
  metadata <- fakeQuartoMetadata(version = "99.9.9", engines = c("internal-combustion"))

  quartoInfo <- inferQuartoInfo(
    appDir = test_path("quarto-website-r"),
    appPrimaryDoc = NULL,
    quarto = NULL,
    metadata = metadata
  )
  expect_equal(quartoInfo, list(
    version = "99.9.9",
    engines = I("internal-combustion")
  ))
})

test_that("inferQuartoInfo prefers using metadata over quarto inspect", {
  quarto <- quartoPathOrSkip()

  metadata <- fakeQuartoMetadata(version = "99.9.9", engines = c("internal-combustion"))

  quartoInfo <- inferQuartoInfo(
    appDir = test_path("quarto-website-r"),
    appPrimaryDoc = NULL,
    quarto = quarto,
    metadata = metadata
  )
  expect_equal(quartoInfo$engines, I(c("internal-combustion")))
})

test_that("inferQuartoInfo returns NULL for non-quarto content", {
  quarto <- quartoPathOrSkip()

  quartoInfo <- inferQuartoInfo(
    appDir = test_path("shinyapp-simple"),
    appPrimaryDoc = NULL,
    quarto = quarto,
    metadata = list()
  )
  expect_null(quartoInfo)
})

test_that("quartoInspect identifies on Quarto projects", {
  quarto <- quartoPathOrSkip()

  inspect <- quartoInspect(quarto, test_path("quarto-website-r"))
  expect_true(all(c("quarto", "engines") %in% names(inspect)))

  inspect <- quartoInspect(quarto, test_path("quarto-proj-r-shiny"))
  expect_true(all(c("quarto", "engines") %in% names(inspect)))
})

test_that("quartoInspect identifies Quarto documents", {
  quarto <- quartoPathOrSkip()

  inspect <- quartoInspect(
    quarto,
    appDir = test_path("quarto-doc-none"),
    appPrimaryDoc = "quarto-doc-none.qmd"
  )
  expect_true(all(c("quarto", "engines") %in% names(inspect)))
})

test_that("quartoInspect returns NULL on non-quarto Quarto content", {
  quarto <- quartoPathOrSkip()

  inspect <- quartoInspect(quarto, test_path("shinyapp-simple"))
  expect_null(inspect)
})
