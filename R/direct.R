#' Rearrange data from gemtc input format to a format suitable for direct
#' meta-analysis
#'
#' @param input.df A \code{data.frame} This should be in one of two formats. Arm
#'   level data must contain the columns 'study' and 'treatment' where study is
#'   a study id number (1, 2, 3 ...) and treatment is a treatment id number.
#'   Relative effect data (e.g. log odds ratio, log rate ratio) must contain the
#'   same study and treatment columns plus the columns 'diff' and 'std.err'. Set
#'   diff=NA for the baseline arm. The column std.err should be the standard
#'   error of the relative effect estimate. For trials with more than two arms
#'   set std.err as the standard error of the baseline arm. This determines the
#'   covariance which is used to adjust for the correlation in multiarm studies.
#' @param dataType A character string specifying which type of data has been
#'   provided. Currently only 'treatment difference' or 'binary are supported
#'
#' @return A data frame
#'
#' @seealso \code{\link[gemtc]{mtc.network}}
formatDataToDirectMA = function(input.df, dataType) {
  #get a list of unique study IDs and count how many
  studyID = unique(input.df$study)

  for (s in studyID) {
    #pull out the current study
    study = dplyr::filter(input.df, study == s)

    #identify the set of all possible pairwise comparisons in this study
    comparisons = combn(study$treatment, 2)

    #rearrange treatment difference data
    if (dataType == 'treatment difference') {
      #set up a temporary data frame
      df = data_frame(
        StudyName = NA, study = NA, comparator = NA, treatment = NA, diff = NA,
        std.err = NA, NumberAnalysedComparator = NA, NumberAnalysedTreatment = NA,
        ComparatorName = NA, TreatmentName = NA
      )

      #loop through the set of comparisons and rearrange the data
      for (i in 1:ncol(comparisons)) {
        comp = dplyr::filter(study, study$treatment %in% comparisons[,i])

        #only report the direct comparisons as reported in the data
        if (any(is.na(comp$diff))) {
          df[i,'StudyName'] = as.character(comp$StudyName[1])
          df[i,'study'] = as.integer(s)
          df[i,'treatment'] = as.integer(comp$treatment[2])
          df[i,'comparator'] = as.integer(comp$treatment[1])
          df[i,'diff'] = comp$diff[2]
          df[i,'std.err'] = comp$std.err[2]
          df[i,'NumberAnalysedComparator'] = as.integer(comp$NumberAnalysed[1])
          df[i,'NumberAnalysedTreatment'] = as.integer(comp$NumberAnalysed[2])
          df[i,'ComparatorName'] = as.character(comp$TreatmentName[1])
          df[i,'TreatmentName'] = as.character(comp$TreatmentName[2])
        }
      }

      if (s == 1) {
        directData = df
      } else {
        directData = dplyr::bind_rows(directData, df)
      }
    }

    #rearrange binary data
    if (dataType == 'binary') {
      #set up a temporary data frame
      df = dplyr::data_frame(
        StudyName = NA, study = NA, comparator = NA, treatment = NA,
        NumberEventsComparator = NA, NumberAnalysedComparator = NA,
        NumberEventsTreatment = NA, NumberAnalysedTreatment = NA,
        ComparatorName = NA, TreatmentName = NA
      )

      #loop through the set of comparisons and rearrange the data
      for (i in 1:ncol(comparisons)) {
        comp = dplyr::filter(study, study$treatment %in% comparisons[,i])
        df[i, 'StudyName'] = as.character(comp$StudyName[1])
        df[i,'study'] = as.integer(s)
        df[i,'treatment'] = as.integer(comp$treatment[2])
        df[i,'comparator'] = as.integer(comp$treatment[1])
        df[i,'NumberEventsComparator'] = as.integer(comp$responders[1])
        df[i,'NumberAnalysedComparator'] = as.integer(comp$sampleSize[1])
        df[i,'NumberEventsTreatment'] = as.integer(comp$responders[2])
        df[i,'NumberAnalysedTreatment'] = as.integer(comp$sampleSize[2])
        df[i,'ComparatorName'] = as.character(comp$TreatmentName[1])
        df[i,'TreatmentName'] = as.character(comp$TreatmentName[2])
      }

      if (s == 1) {
        directData = df
      } else {
        directData = dplyr::bind_rows(directData, df)
      }
    }
  }
  return(directData)
}

#' Perform multiple direct head to head meta-analyses from a single data frame
#'
#' @param df A data frame as returned by \code{formatDataToDirectMA}
#' @param effectCode A character string indicating the underlying effect
#'   estimate. This is used to set the \code{sm} argument of the underlying
#'   analysis functions from the \code{meta} package. Acceptable values are
#'   'RD', 'RR', 'OR', 'HR', 'ASD', 'MD', 'SMD'
#' @param dataType A character string specifying which type of data has been
#'   provided. Currently only 'treatment difference' or 'binary are supported
#' @param backtransf A logical indicating whether results should be back
#'   transformed. This is used to set the corresponding \code{backtransf}
#'   argument of the underlying functions from the \code{meta} package. If
#'   \code{backtransf=TRUE} then log odds ratios (or hazard ratios etc) will be
#'   converted to odds ratios on plots and print outs
#' @details This function provides a wrapper around the \code{metagen} or
#'   \code{metabin} functions from the \code{meta} package to one or more
#'   analyses to be carried out from a single data frame. This is most useful
#'   when direct meta-analysis is required to support all pairwise comparisons
#'   in a network meta-analyis or effect estimates are required for multiple
#'   pairs of treatments to perform simple indirect meta-analysis using the
#'   Bucher method
#'
#' @return A data frame
#'
#' @seealso \code{\link{formatDataToDirectMA}}, \code{\link[meta]{metagen}}, \code{\link[meta]{metabin}}
doDirectMeta = function(df, effectCode, dataType, backtransf = FALSE) {
  #create a list object to store the results
  resList = list()

  #identify the set of treatment comparisons present in the data
  comparisons = dplyr::distinct(df[,3:4])

  for (i in 1:nrow(comparisons)) {
    #get data for the first comparison
    comp = dplyr::filter(df, comparator == comparisons$comparator[i],
                  treatment == comparisons$treatment[i])

    #run the analysis for different data types
    if (dataType == 'treatment difference') {
      #Generic inverse variance method for treatment differences
      #backtransf=TRUE converts log effect estimates (e.g log OR) back to linear scale
      directRes = meta::metagen(
        TE = comp$diff, seTE = comp$std.err,sm = effectCode, backtransf = backtransf,
        studlab = comp$StudyName, n.e = comp$NumberAnalysedTreatment,
        n.c = comp$NumberAnalysedComparator, label.e = comp$TreatmentName,
        label.c = comp$ComparatorName
      )
    }
    if (dataType == 'binary') {
      #Analysis of binary data provided as n/N
      directRes = meta::metabin(
        event.e = comp$NumberEventsTreatment, n.e = comp$NumberAnalysedTreatment,
        event.c = comp$NumberEventsComparator, n.c = comp$NumberAnalysedComparator,
        sm = effectCode, backtransf = backtransf, studlab = comp$StudyName,
        label.e = comp$TreatmentName, label.c = comp$ComparatorName,
        method = ifelse(nrow(comp) > 1, "MH", "Inverse")
      )
    }
    #add the treatment codes to the results object. These will be needed later
    directRes$e.code = comparisons$treatment[i]
    directRes$c.code = comparisons$comparator[i]

    #compile the results into a list
    if (length(resList) == 0) {
      resList[[1]] = directRes
    } else {
      resList[[length(resList) + 1]] = directRes
    }
  }
  return(resList)
}

.backtransform = function(df) {
  #simple function to convert log OR (or HR or RR) back to a linear scale
  #df - a data frame derived from a metagen summary object

  #relabel column names to preserve the log results
  colnames(df)[c(1,3:4)] = paste0('log.', colnames(df)[c(1,3:4)])
  colnames(df)[2] = paste0(colnames(df)[2], '.log')
  #exponentiate the effect estimate and CI
  df$TE = exp(df$log.TE)
  df$lower = exp(df$log.lower)
  df$upper = exp(df$log.upper)
  df
}

#' Extract summary results for a direct meta-analysis
#'
#' @param metaRes An object of class \code{c("metagen", "meta")} or c("metabin",
#'   "meta"). These objects are lists containing the results of direct
#'   meta-analysis. See \code{\link[meta]{metagen}}, \code{\link[meta]{metabin}}
#'   for a description of exactly what is contained in the list
#' @param effect a character string describing the effect estimate, e.g. 'Rate
#'   Ratio', 'Odds Ratio', 'Hazard Ratio'
#' @param intervention A character string describing the name of the
#'   intervention. Defaults to 'Int' if not provided
#' @param comparator A character string describing the name of the comparator.
#'   Defaults to 'Con' if not provided
#' @param backtransf A logical indicating whether results should be back
#'   transformed. If \code{backtransf=TRUE} then log odds ratios (or hazard
#'   ratios etc) will be converted to odds ratios on plots and print outs.
#'
#' @details This function extracts the results of a meta-analysis from a
#'   list-type object produced by the \code{meta} package and returns them as a
#'   data frame. If there is only one study comparing two treatments then no
#'   meta-anlaysis is performed but the results of the primary study are
#'   included in the output. In this case the fields \code{Model},
#'   \code{Tau.sq}, \code{method.tau} and \code{I.sq} in the output will be
#'   blank as these fields have no meaning for a single study. This is useful if
#'   you want to use these results to perform simple indirect (Bucher) analyses.
#'
#'   If more than one study is available then both fixed effect and random
#'   effects results will be returned
#'
#' @return A data frame with the following columns:
#' \itemize{
#'  \item \code{Intervention} The name of the intervention
#'  \item \code{InterventionCode} The ID number of the intervention in the
#'  current set of analyses. NA if not provided
#'  \item \code{Comparator} The name of the comparator
#'  \item \code{ComparatorCode} The ID number of the comparator in the current
#'    set of analyses
#'  \item \code{Effect} The type of effect measure. Takes the
#'    value of the \code{effect} argument
#'  \item \code{Model} The type of model. Fixed effect or Random Effects.
#'    Blank if there is only one study
#'  \item \code{log.TE} The treatment effect on log scale, e.g. log OR
#'  \item \code{seTE.log} The standard error for the log treatment effect
#'  \item \code{log.lower}, \code{log.upper} The upper and lower 95\% confidence
#'    intervals for the log treatment effect
#'  \item \code{z}, \code{p} The z-value and corresponding p-value for the test
#'    of effect
#'  \item \code{level} The level for the confidence intervals. Defaults to 0.95
#'    for a 95\% confidence interval
#'  \item \code{TE}, \code{lower}, \code{upper} The treatment effect with lower
#'    and upper confidence intervals backtransformed to a linear scale
#'  \item \code{Tau.sq} The heterogeneity variance
#'  \item \code{I.sq}, \code{I.sq.lower}, \code{I.sq.upper} The heterogeneity statistic
#'    I-squared with upper and lower confidence intervals.
#' }
#'
#' @seealso \code{\link[meta]{metagen}}, \code{\link[meta]{metabin}}
extractDirectRes = function(metaRes, effect, intervention = 'Int',
                            comparator = 'Con', interventionCode = NA,
                            comparatorCode = NA, backtransf = FALSE) {

  #create a summary of the results, extract fixed and random
  res = summary(metaRes)
  fixed = as.data.frame(res$fixed)
  random = as.data.frame(res$random)[1:7]
  if (backtransf == TRUE) {
    #exponentiate the effect estimates if required
    fixed = .backtransform(fixed)
    random = .backtransform(random)
  }

  #if more than one study then this must be a meta-analysis and both fixed and
  #random are expected if there is only one study then use the fixed results as
  #all results are just the result of the original study
  if (res$k > 1) {
    df = rbind(fixed, random)
    model = c('Fixed', 'Random')
    df = data.frame('Model' = model, df, stringsAsFactors = FALSE)
  } else {
    df = fixed
    df = data.frame('Model' = NA, df, stringsAsFactors = FALSE)
  }
  studies = paste0(metaRes$studlab, collapse = ', ')
  df = data.frame(
    'Intervention' = intervention, 'InterventionCode' = interventionCode,
    'Comparator' = comparator, 'ComparatorCode' = comparatorCode,
    'Effect' = effect, df,'Tau.sq' = res$tau,
    'method.tau' = res$method.tau, 'I.sq' = res$I2, 'n.studies' = res$k,
    'studies' = studies, stringsAsFactors = FALSE
  )

}

#' Draw a forest plot
#'
#' @param meta an object of class c("metagen", "meta") or c("metabin", "meta")
#'   as returned by the functions \code{metagen} or \code{metabin} in the
#'   package meta
#' @param showFixed,showRandom Logical indicating whether fixed effect and/or
#'   random effects results should be shown on the forest plot. By default both
#'   are shown set the appropriate argument to FALSE if you want to exclude that
#'   result from the plot.
#' @param ... additional arguments to be passed to \code{forest}
#'   e.g. \code{col.square='red'}, \code{col.diamond='black'}, \code{smlab='Odds
#'   Ratio'}
#'
#' @details This function provides a very simple wrapper around \code{forest}
#'   from the \code{meta} package. The main purpose is to allow some defaults
#'   to be set for the arguments to \code{forest} and to work out a reasonable
#'   scale for the x-axis automatically.
#'
#'   By default pooled estimates for both fixed and random effects models will
#'   be shown. If there is only one study comparing a given pair of treatments
#'   then the results of that study are shown but no pooled estimates are
#'   displayed.
#'
#'   @return NULL
#'
#' @seealso \code{\link[meta]{forest}}
drawForest = function(meta, showFixed = TRUE, showRandom = TRUE, ...) {

  #work out sensible values for the x-axis limits
  limits = c(
    meta$lower, meta$upper, meta$lower.fixed, meta$upper.fixed,
    meta$lower.random, meta$upper.random
  )
  limits = range(exp(limits))
  xlower = ifelse(limits[1] < 0.2, round(limits[1], 1), 0.2)
  xupper = ifelse(limits[2] > 5, round(limits[2]), 5)
  xlimits = c(xlower, xupper)

  #don't show the pooled estimate if there is only one study
  if (meta$k == 1) {
    showFixed = FALSE
    showRandom = FALSE
  }

  #forest plot
  meta::forest(
    meta, hetlab = NULL, text.I2 = 'I-sq', text.tau2 = 'tau-sq', xlim = xlimits,
    comb.fixed = showFixed, comb.random = showRandom, lty.fixed = 0,
    lty.random = 0, just.studlab='right', ...
  )
}