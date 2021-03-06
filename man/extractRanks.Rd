% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/nma.R
\name{extractRanks}
\alias{extractRanks}
\title{Extract ranking probabilities}
\usage{
extractRanks(ranks, treatments)
}
\arguments{
\item{ranks}{An object of class \code{mtc.rank.probability} as returned by
the \code{probability} function in the \code{gemtc} package}

\item{treatments}{A data frame with columns 'description' defining the
treatment names and 'id' defining the treatment ID numbers.}
}
\value{
A data frame
}
\description{
Extract ranking probabilities
}
\details{
This function takes the ranking probablilities returned by \code{rank.probability}, matches the treatment names to the id numbers and returns the results as a data frame
}
\seealso{
\code{\link[gemtc]{rank.probability}}
}

