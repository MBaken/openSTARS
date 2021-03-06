% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calc_edges.R
\name{get_cats_edges_in_catchment}
\alias{get_cats_edges_in_catchment}
\title{get_cats_edges_in_catchment#' 
Returns the cats of this and all upstream edges#'}
\usage{
get_cats_edges_in_catchment(dt, str_id)
}
\arguments{
\item{dt}{data.table containing the attributes of the stream segments}

\item{str_id}{integer giving the stream_id ('stream') of the starting edge}
}
\value{
vector of cat values of all upstream edges and the calling one.
}
\description{
Recursive function to get the stream_ids from one segment upstream.
This function is used internally and is not intended to be called by the user.
}
\author{
Mira Kattwinkel, \email{mira.kattwinkel@gmx.net}
}
