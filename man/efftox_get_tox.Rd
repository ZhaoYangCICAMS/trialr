% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/efftox.R
\name{efftox_get_tox}
\alias{efftox_get_tox}
\title{Get the probability of toxicity for probability-of-efficacy and utility pairs}
\usage{
efftox_get_tox(eff, util, p, eff0, tox1)
}
\arguments{
\item{eff}{Probability of efficacy; number between 0 and 1}

\item{util}{Utility score; number}

\item{p}{p-index of EffTox utility contours. Use \code{efftox_solve_p}}

\item{eff0}{Efficacy probability required when toxicity is impossible;
a number between 0 and 1}

\item{tox1}{Toxicity probability permitted when efficacy is guaranteed;
a number between 0 and 1}
}
\value{
Probability(s) of toxicity
}
\description{
Get the probability of toxicity for probability-of-efficacy and utility pairs
}
\note{
Various ways of vectorising the function are demonstrated in the examples
}
\examples{
p <- efftox_solve_p(0.5, 0.65, 0.7, 0.25)

prob_tox <- efftox_get_tox(0.7, 0, p, eff0 = 0.5, tox1 = 0.65)
round(prob_tox, 2) == 0.25

prob_tox <- efftox_get_tox(0.7, seq(-0.5, 0.25, by = 0.25), p, eff0 = 0.5, tox1 = 0.65)
round(prob_tox, 2) == c(0.57, 0.41, 0.25, 0.09)

prob_tox <- efftox_get_tox(c(0.5, 0.7, 0.8), 0.25, p, eff0 = 0.5, tox1 = 0.65)
round(prob_tox, 2) == c(NaN, 0.09, 0.22)

prob_tox <- efftox_get_tox(c(0.5, 0.7, 0.8), c(-1, 0, 1), p, eff0 = 0.5, tox1 = 0.65)
round(prob_tox, 2) == c(0.63, 0.25, NaN)

}
\seealso{
\code{\link{efftox_solve_p}}
}
