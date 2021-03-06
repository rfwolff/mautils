% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/diagnostics.R
\name{extractDACC}
\alias{extractDACC}
\title{Extract descriptive accuracy results from the output of \code{madad}}
\usage{
extractDACC(des, input)
}
\arguments{
\item{des}{An object of class \code{madad} as returned by the function
\code{madad} in the \code{mada} package}

\item{input}{A data frame of 2x2 diagnostic accuracy data. The following
columns must be present 'StudyID, 'TP', 'TN', 'FP', 'FN' corresponding to
the number of True Positives, True Negatives, False Postives and False
Negatives respectively.}
}
\value{
A data frame containing the input data plus summary estimates from
  each study for sensitvity, specificity, positive likelihood ratio, negative
  likelihood ratio and diagnostic odds ratio
}
\description{
Extract descriptive accuracy results from the output of \code{madad}
}
\seealso{
\code{\link[mada]{madad}}
}

