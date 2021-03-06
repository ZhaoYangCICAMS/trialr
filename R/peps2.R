
# Using the BEBOP model in PePS2

#' @title Get data to run the PePS2 trial example
#'
#' @description Get data to run the BEBOP model in the PePS2 trial. The trial
#' investigates pembrolizumab in non-small-cell lung cancer. Patients may be
#' previously treated (PT) or treatment naive (TN). Pembro response rates in
#' lung cancer have been shown to increase with PD-L1 tumour proportion score.
#' PD-L1 score is measured at baseline. Each patient belongs to one of the Low,
#' Medium or High categories. These two baseline variables stratify the patient
#' population and are used as predictive variables to stratify the analysis.
#' The BEBOP model studies co-primary efficacy and toxicity outcomes in the
#' presence of predictive data. Thus, PePS2 studies efficacy and toxicity in
#' 6 distinct cohorts:
#' TN Low, TN Medium, TN High, PT Low, PT Medium, PT High.
#' The design admits all-comers and does not target specific sample sizes in the
#' individual cohorts.
#' Hyperprior parmaters have defaults to match those used in PePS2, but all may
#' be overridden.
#' The returned object includes randomly-sampled outcomes, as well as parameters
#' to run the model. These are all combined in the same list object for passing
#' to RStan, as is the convention.
#' See the accompanying vignette for a full description.
#'
#' @param num_patients Total number of patients to use, positive integer.
#' @param cohort_probs Probabilities that a patient belongs to each of the 6
#' cohorts, in the order given above; a vector of numbers between 0 and 1 that
#' add up to 1. \code{cohort_probs} or \code{cohort_rho} must be specified.
#' @param prob_eff Probabilities of efficacy in each of the 6 cohorts, in the
#' order given above; a vector of numbers between 0 and 1
#' @param prob_tox Probabilities of toxicity in each of the 6 cohorts, in the
#' order given above; a vector of numbers between 0 and 1
#' @param eff_tox_or Measure of strength of association between efficacy and
#' toxicity, in each of the 6 cohorts, in the order given above; a vector of
#' numbers. Use 1 for no association; numbers increasingly greater than 1 for
#' stronger positive associations, and numbers less than 1 for stronger nagative
#' associations
#' @param cohort_rho Concentration parameters for cohort membership, in the
#' order given above, using a Dirichlet distribution. This leads to randomly-
#' sampled cohort sizes distributed Dir(cohort_rho). \code{cohort_probs} or
#' \code{cohort_rho} must be specified.
#' @param alpha_mean The prior mean of alpha. Alpha is the efficacy model
#' intercept.
#' @param alpha_sd The prior standard deviation of alpha. Alpha is the efficacy
#' model  intercept.
#' @param beta_mean The prior mean of beta. Beta is the efficacy model term
#' for being previously treated.
#' @param beta_sd The prior standard deviation of beta. Beta is the efficacy
#' model term for being previously treated.
#' @param gamma_mean The prior mean of gamma. Gamma is the efficacy model term
#' for being PD-L1 score = Low.
#' @param gamma_sd The prior standard deviation of gamma. Gamma is the efficacy
#' model term for being PD-L1 score = Low.
#' @param zeta_mean The prior mean of zeta. Zeta is the efficacy model term
#' for being PD-L1 score = Medium.
#' @param zeta_sd The prior standard deviation of zeta. Zeta is the efficacy
#' model term for being PD-L1 score = Medium.
#' @param lambda_mean The prior mean of lambda. Lambda is the toxicity model
#' intercept.
#' @param lambda_sd The prior standard deviation of lambda. Lambda is the
#' toxicity model intercept.
#' @param psi_mean The prior mean of psi. Psi is the joint model association
#' parameter.
#' @param psi_sd The prior standard deviation of psi. Psi is the joint model
#' association parameter.
#'
#' @return a \code{list} of parameters, described in \code{peps2_params}
#' @export
#'
#' @examples
#' set.seed(123)
#' dat <- peps2_get_data(num_patients = 60,
#'                       prob_eff = c(0.167, 0.192, 0.5, 0.091, 0.156, 0.439),
#'                       prob_tox = rep(0.1, 6),
#'                       eff_tox_or = rep(1, 6))
#' samp = rstan::sampling(stanmodels$BebopInPeps2, data = dat)
#'
#' @seealso \code{\link{peps2_params}}
peps2_get_data <- function(num_patients, cohort_probs = NULL,
                           prob_eff, prob_tox, eff_tox_or,
                           cohort_rho = c(15.7, 21.8, 12.4, 20.7, 18.0, 11.4),
                           alpha_mean = -2.2, alpha_sd = 2,
                           beta_mean = -0.5, beta_sd = 2,
                           gamma_mean = -0.5, gamma_sd = 2,
                           zeta_mean = -0.5, zeta_sd = 2,
                           lambda_mean = -2.2, lambda_sd = 2,
                           psi_mean = 0, psi_sd = 1) {

  if (is.null(cohort_probs))
    cohort_probs <- gtools::rdirichlet(1, cohort_rho)
  cohort_sizes <- c(stats::rmultinom(1, size = num_patients,
                                     prob = cohort_probs))
  cohorts <- rep(1:length(cohort_sizes), times = cohort_sizes)
  cohorts = factor(cohorts, levels = 1:length(cohort_rho))

  cohort.params = cbind(cohort_sizes, prob_eff, prob_tox, eff_tox_or)
  cohort.params = split(cohort.params, 1:length(cohort_sizes))
  outcomes <- lapply(cohort.params, function(x) ranBin2(x[1], x[2:3], psi=x[4]))
  outcomes <- do.call(rbind, outcomes)

  eff <- outcomes[, 1]
  tox <- outcomes[, 2]
  x1 <- as.integer(cohorts %in% 4:6)
  x2 <- as.integer(cohorts == 1 | cohorts == 4)
  x3 <- as.integer(cohorts == 2 | cohorts == 5)
  cohort_eff = unname(tapply(eff, cohorts, sum))
  cohort_eff[is.na(cohort_eff)] = 0
  cohort_tox = unname(tapply(tox, cohorts, sum))
  cohort_tox[is.na(cohort_tox)] = 0

  dat <- list(
    # Data
    J = num_patients,
    eff = eff,
    tox = tox,
    x1 = x1,
    x2 = x2,
    x3 = x3,
    # Cohort counts
    cohort_n = cohort_sizes,
    cohort_eff = cohort_eff,
    cohort_tox = cohort_tox,
    # Hyperparameters
    alpha_mean = alpha_mean,
    alpha_sd = alpha_sd,
    beta_mean = beta_mean,
    beta_sd = beta_sd,
    gamma_mean = gamma_mean,
    gamma_sd = gamma_sd,
    zeta_mean = zeta_mean,
    zeta_sd = zeta_sd,
    lambda_mean = lambda_mean,
    lambda_sd = lambda_sd,
    psi_mean = psi_mean,
    psi_sd = psi_sd
  )
  return(dat)
}


#' @title Process RStan samples from a BEBOP model fit to PePS2 data
#'
#' @description Process RStan samples from a BEBOP model fit to PePS2 data. This
#' step lets us make inferences about whether the modelled efficacy and toxicity
#' probabilities suggest the treatment is acceptable in each of the cohorts
#' under study.
#' The parameters have default values to match those used in the PePS2 trial.
#' See the accompanying vignette for a full description.
#'
#' @param dat An instance of \code{\link{peps2_params}}, a list of PePS2
#' data and parameters. An example is yielded by \code{\link{peps2_get_data}}.
#' @param fit An instance of \code{rstan::stanmodel}, derived by fitting data to
#' the BEBOP in PePS2 model.
#' Use \code{stan::sampling(stanmodels$BebopInPeps2, data = dat)}.
#' @param min_eff The lower efficacy probability threshold; a number between 0
#' and 1.
#' @param max_tox The upper toxicity probability threshold; a number between 0
#' and 1.
#' @param eff_cert Certainty required to infer the treatment is acceptable with
#' regards to being probably efficacious; a number between 0 and 1.
#' @param tox_cert Certainty required to infer the treatment is acceptable with
#' regards to being probably tolerable; a number between 0 and 1.
#'
#' @return a list with the following items:
#' \itemize{
#' \item \code{ProbEff}, the posterior mean probability of efficacy in the 6
#' cohorts.
#' \item \code{ProbAccEff}, the posterior mean probability that the probability
#' of efficacy exceeds \code{min_eff}, in the 6 cohorts.
#' \item \code{ProbTox}, the posterior mean probability of toxicity in the 6
#' cohorts.
#' \item \code{ProbAccTox}, the posterior mean probability that the probability
#' of toxicity is less than \code{max_tox}, in the 6 cohorts.
#' \item \code{Accept}, a vector of logical values to show whether treatment
#' should be accepted in the 6 cohorts. Treatment is acceptable when it is
#' probably efficacious and probably not toxic, with respect to the described
#' rules.
#' \item \code{alpha}, the posterior mean estimate of alpha.
#' \item \code{beta}, the posterior mean estimate of beta.
#' \item \code{gamma}, the posterior mean estimate of gamma.
#' \item \code{zeta}, the posterior mean estimate of zeta.
#' \item \code{lambda}, the posterior mean estimate of lambda.
#' \item \code{psi}, the posterior mean estimate of psi.
#' }
#' @export
#'
#' @examples
#' set.seed(123)
#' dat <- peps2_get_data(num_patients = 60,
#'                       prob_eff = c(0.167, 0.192, 0.5,
#'                                    0.091, 0.156, 0.439),
#'                       prob_tox = rep(0.1, 6),
#'                       eff_tox_or = rep(1, 6))
#' samp = rstan::sampling(stanmodels$BebopInPeps2, data = dat)
#' decision <- peps2_process(dat, samp)
#' decision$Accept   # Accept in cohort 2, 3, 5, 6 but not 1, 4
#' decision$ProbEff  # The probability of efficacy is driving that decision
#'
#' @seealso
#' \code{\link{peps2_params}}
#'
#' \code{\link{peps2_get_data}}
peps2_process <- function(dat, fit, min_eff = 0.1, max_tox = 0.3,
                                 eff_cert = 0.7, tox_cert = 0.9) {
  #fit = samp
  acc_eff <- rstan::extract(fit, par = 'prob_eff')[[1]] > min_eff
  acc_tox <- rstan::extract(fit, par = 'prob_tox')[[1]] < max_tox
  accept <- (apply(acc_eff, 2, mean) > eff_cert) &
    (apply(acc_tox, 2, mean) > tox_cert)
  prob_eff <- colMeans(rstan::extract(fit, 'prob_eff')[[1]])
  prob_tox <- colMeans(rstan::extract(fit, 'prob_tox')[[1]])
  l <- list(ProbEff = prob_eff, ProbAccEff = apply(acc_eff, 2, mean),
            ProbTox = prob_tox, ProbAccTox = apply(acc_tox, 2, mean),
            Accept = accept)
  # Append posterior parameter means
  l <- append(l, lapply(rstan::extract(fit, pars=c('alpha', 'beta', 'gamma',
                                                   'zeta', 'lambda')), mean))
  # Add psi posterior mean
  if('psi' %in% names(fit))
    l <- append(l, lapply(rstan::extract(fit, pars=c('psi')), mean))
  return(l)
}


#' @title Run simulations of BEBOP in PePS2
#'
#' @description Run simulations of the BEBOP model in a PePS2 scenario.
#' The logic of creating the data to be passed to the Stan model is delegated to
#' a function, thus the user may tailor rates of efficacy and toxicity, priors,
#' cohort membership probabilities, by specialising this function. Similarly,
#' the post-processing to perform on the RStan sample is delegated to another
#' function. This pattern gives a flexible interface.
#'
#' @param num_sims integer, number of simulated iterations
#' @param sample_data_func delegate function that takes no parameters and
#' returns a list like \code{peps2_params}. This function is called
#' during each simulated iteration so it should contain random outcomes.
#' @param summarise_func delegate function that takes args \code{dat} and
#' \code{fit}, where \code{dat} is an instance of \code{peps2_params}
#' returned by \code{sample_data_func()}, and \code{fit} is an instance of
#' \code{rstan::stanmodel}, derived by sampling the BebopInPeps2 model. The
#' simulation routine collects this using
#' \code{stan::sampling(stanmodels$BebopInPeps2, data = dat)}. The objects
#' returned by this delegate are ultimately returned to the user. Thus, this
#' function should perform the post-processing to get the RStan sample into
#' some useful format. An example if \code{\link{peps2_process}}.
#' @param ... extra parameters passed to \code{rstan::sampling}.
#'
#' @return a list of length \code{num_sims}, with element \code{i} being the
#' result of the \code{i}th call to \code{summarise_func(dat, fit)}.
#' @export
#'
#' @examples
#' prob_eff <- c(0.167, 0.192, 0.5, 0.091, 0.156, 0.439)
#' prob_tox = c(0.1, 0.1, 0.1, 0.1, 0.1, 0.1)
#' peps2_scenario_data <- function() peps2_get_data(num_patients = 60,
#'                                                  prob_eff = prob_eff,
#'                                                  prob_tox = prob_tox,
#'                                                  eff_tox_or = rep(1, 6))
#' set.seed(123)
#' sims <- peps2_run_sims(num_sims = 10, sample_data_func = peps2_scenario_data,
#'                        summarise_func = peps2_process)
#' apply(sapply(sims, function(x) x$Accept), 1, mean)  # 0.5 0.7 1.0 0.2 0.5 1.0
#' # Simulation suggests we are likely to approve in cohorts 3 and 6.
#' # In real life, we run thousands of iterations, not 10. This is an example.
#'
#' @seealso
#' \code{\link{peps2_params}}
#'
#' \code{\link{peps2_get_data}}
#'
#' \code{\link{peps2_process}}
peps2_run_sims <- function(num_sims, sample_data_func, summarise_func, ...) {
  dat <- sample_data_func()
  model <- stanmodels$BebopInPeps2
  return(.run.sims(model, num_sims, sample_data_func, summarise_func, ...))
}
