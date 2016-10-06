% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calc_attributes_sites_exact.R
\name{calc_attributes_sites_exact}
\alias{calc_attributes_sites_exact}
\title{Calcuate attributes of the sites.}
\usage{
calc_attributes_sites_exact(sites_map = "sites", input_raster = NULL,
  stat = NULL, attr_name = NULL, round_dig = 2, keep_basins = FALSE)
}
\arguments{
\item{sites_map}{string giving the name of the sites the attributes shall be
calculated for. "sites" refers to the observation sites.}

\item{input_raster}{character vector (optional); name of additional raster
maps to calculate attributes from.}

\item{stat}{character vector (optional); statistics to be calulated, one of:
min, max, mean, stddev, variance, sum, median or precentile_X (where X
gives the desired percentile e.g. 25 for the first).}

\item{attr_name}{character vector (optional); column name for the attributes
to be caculated. Please not that attribute names must not be longer than 10
characters.}

\item{round_dig}{integer; number of digits to round results to.}

\item{keep_basins}{boolean; shall raster maps of all the watersheds be kept?}
}
\value{
Nothing. The function appends new columns to the 'sites' attribute table
\itemize{
 \item{'H2OArea':} {Total watershed area of the watershed upstream of each site.}
 \item{attr_name:} {Additional optional attributes calculated based on input_raster maps.}
}
}
\description{
For each site the total catchment area is calculated ('H2Oarea'). Additionally, other
attributes (predictor variables) can be derived based on given raster maps. This fuction calculates
exact values for catchments derived with
\href{https://grass.osgeo.org/grass70/manuals/addons/r.stream.basins.html}{r.stream.basins}
and can take considerable time if there are many sites.
Catchment raster maps can optionally be stored as "catchm_X" (X = pid).
}
\note{
\code{\link{import_data}}, \code{\link{derive_streams}},
  \code{\link{calc_edges}} and code{\link{calc_sites}} must be run before.
}
\examples{
\donttest{
library(rgrass7)
initGRASS(gisBase = "/usr/lib/grass70/",
  home = tempdir(),
  override = TRUE)
gmeta()
dem_path <- system.file("extdata", "nc", "elev_ned_30m.tif", package = "openSTARS")
sites_path <- system.file("extdata", "nc", "sites_nc.shp", package = "openSTARS")
setup_grass_environment(dem = dem_path, sites = sites_path)
import_data(dem = dem_path, sites = sites_path)
derive_streams()
#' cj <- check_compl_junctions()
if(cj)
  correct_compl_junctions()
calc_edges()
calc_sites()
execGRASS("r.slope.aspect", flags = c("overwrite","quiet"),
parameters = list(
  elevation = "dem",
  slope = "slope"
  ))
calc_sites_attributes(input_raster = "slope",  stat = "mean", attr_name = "avgSlopeP")
}
}
\author{
Eduard Szoecs, \email{eduardszoecs@gmail.com}, Mira Kattwinkel, \email{mira.kattwinkel@gmx.net}
}
