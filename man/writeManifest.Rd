% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/writeManifest.R
\name{writeManifest}
\alias{writeManifest}
\title{Create a manifest.json describing deployment requirements.}
\usage{
writeManifest(
  appDir = getwd(),
  appFiles = NULL,
  appPrimaryDoc = NULL,
  contentCategory = NULL,
  python = NULL,
  forceGeneratePythonEnvironment = FALSE,
  quarto = NULL,
  image = NULL,
  verbose = FALSE
)
}
\arguments{
\item{appDir}{Directory containing application. Defaults to current working
directory.}

\item{appFiles}{A character vector given relative paths to the files and
directories to bundle and deploy. The default, \code{NULL}, will include all
files in \code{appDir}, apart from any listed in an \code{.rscignore} file.}

\item{appPrimaryDoc}{If the application contains more than one document, this
parameter indicates the primary one, as a path relative to \code{appDir}. Can be
\code{NULL}, in which case the primary document is inferred from the contents
being deployed.}

\item{contentCategory}{Optional; the kind of content being deployed (e.g.
\code{"plot"} or \code{"site"}).}

\item{python}{Full path to a python binary for use by \code{reticulate}.
Required if \code{reticulate} is a dependency of the app being deployed.
If python = NULL, and RETICULATE_PYTHON or RETICULATE_PYTHON_FALLBACK is
set in the environment, its value will be used. The specified python binary
will be invoked to determine its version and to list the python packages
installed in the environment.}

\item{forceGeneratePythonEnvironment}{Optional. If an existing
\code{requirements.txt} file is found, it will be overwritten when this argument
is \code{TRUE}.}

\item{quarto}{Optional. Full path to a Quarto binary for use deploying Quarto
content. The provided Quarto binary will be used to run \verb{quarto inspect}
to gather information about the content.}

\item{image}{Optional. The name of the image to use when building and
executing this content. If none is provided, Posit Connect will
attempt to choose an image based on the content requirements.}

\item{verbose}{If TRUE, prints progress messages to the console}
}
\description{
Given a directory content targeted for deployment, write a manifest.json into
that directory describing the deployment requirements for that content.
}
