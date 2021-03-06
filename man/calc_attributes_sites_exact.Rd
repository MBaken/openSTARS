% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calc_attributes_sites_exact.R
\name{calc_attributes_sites_exact}
\alias{calc_attributes_sites_exact}
\title{Calculate attributes of the sites.}
\usage{
calc_attributes_sites_exact(sites_map = "sites", input_raster = NULL,
  stat = NULL, attr_name = NULL, round_dig = 2, calc_basin_area = TRUE,
  keep_basins = FALSE)
}
\arguments{
\item{sites_map}{character; name of the sites (observation or prediction) 
attributes shall be calculated for. "sites" (default) refers to the observation sites.}

\item{input_raster}{character vector (optional); name of additional raster
maps to calculate attributes from.}

\item{stat}{character vector (optional); statistics to be calculated, one of:
min, max, mean, stddev, variance, sum, median or percentile_X (where X
gives the desired percentile e.g. 25 for the first). Must be provided if 
\code{input_raster} are given.}

\item{attr_name}{character vector (optional); column name for the attributes
to be calculated. Attribute names must not be longer than 10 characters.
Must be provided if \code{input_raster} are given.}

\item{round_dig}{integer; number of digits to round results to. Can be a vector
of different values or just one value for all attributes.}

\item{calc_basin_area}{boolean; shall the catchment area be calculated? (Useful
if the function has been called before with \code{keep_basins = TRUE}.)}

\item{keep_basins}{boolean; shall raster maps of all the watersheds be kept?}
}
\value{
Nothing. The function appends new columns to the \code{sites_map} attribute table
\itemize{
 \item{'H2OArea':} {Total watershed area of the watershed upstream of each site.}
 \item{attr_name:} {Additional optional attributes calculated based on input_raster maps.}
}
Please note that for sampling points that lie in the same dem raster cell 
 along a stream identical values are calculated, because identical watersheds
 are derived.
}
\description{
For each site (observation or prediction) the total catchment area is
calculated ('H2OArea'). Additionally, other attributes (predictor variables)
can be derived based on given raster maps. This function calculates
exact values for catchments derived with
\href{https://grass.osgeo.org/grass70/manuals/addons/r.stream.basins.html}{r.stream.basins}
and can take considerable time if there are many sites.
Catchment raster maps can optionally be stored as "sitename_catchm_X" (X = locID).
}
\note{
\code{\link{import_data}}, \code{\link{derive_streams}},
  \code{\link{calc_edges}} and \code{\link{calc_sites}} or
  \code{\link{calc_prediction_sites}} must be run before.
  
If \code{calc_basin_area = F} but there are no raster maps called 'sitename_catchm_x' 
with x = locID of all sites the catchments (and their area) are derived.
}
\examples{
\donttest{
# Initiate GRASS session
if(.Platform$OS.type == "windows"){
  gisbase = "c:/Program Files/GRASS GIS 7.2.0"
  } else {
  gisbase = "/usr/lib/grass72/"
  }
initGRASS(gisBase = gisbase,
    home = tempdir(),
    override = TRUE)

# Load files into GRASS
dem_path <- system.file("extdata", "nc", "elev_ned_30m.tif", package = "openSTARS")
sites_path <- system.file("extdata", "nc", "sites_nc.shp", package = "openSTARS")
setup_grass_environment(dem = dem_path, sites = sites_path)
import_data(dem = dem_path, sites = sites_path)
gmeta()

# Derive streams from DEM
derive_streams(burn = 0, accum_threshold = 700, condition = TRUE, clean = TRUE)

# Prepare edges
calc_edges()
execGRASS("r.slope.aspect", flags = c("overwrite","quiet"),
parameters = list(
  elevation = "dem",
  slope = "slope"
  ))
calc_attributes_edges(input_raster = "slope", stat = "max", attr_name = "maxSlo")

# Prepare sites
calc_sites()
calc_attributes_sites_approx(input_attr_name = "maxSlo", stat = "max")
calc_attributes_sites_exact(input_raster = "slope", attr_name = "maxSloE", stat = "max")

# Plot data
dem <- readRAST('dem', ignore.stderr = TRUE)
edges <- readVECT('edges', ignore.stderr = TRUE)
sites <- readVECT('sites', ignore.stderr = TRUE)
plot(dem, col = terrain.colors(20))
mm <- range(c(edges$maxSlo_e, sites$maxSlo, sites$maxSloE))
b <- seq(from = mm[1], to = mm[2] + diff(mm) * 0.01, length.out = 10)
c_ramp <- colorRampPalette(c("blue", "red"))
cols <- c_ramp(length(b))[as.numeric(cut(edges$maxSlo_e, breaks = b, right = FALSE))]
lines(edges,col = cols, lwd = 2)
cols <- c_ramp(length(b))[as.numeric(cut(sites$maxSlo,breaks = b,right = FALSE))]
points(sites, pch = 19, col = cols)
cols <- c_ramp(length(b))[as.numeric(cut(sites$maxSloE,breaks = b,right = FALSE))]
points(sites, pch = 21, bg = cols, cex = 0.7)
# Some points in the centre of the map indicate a difference in max slope between
# approximate and exact calculation (different colors for inner and outer points)
}
}
\author{
Mira Kattwinkel, \email{mira.kattwinkel@gmx.net}, 
  Eduard Szoecs, \email{eduardszoecs@gmail.com}
}
