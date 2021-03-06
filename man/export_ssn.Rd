% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/export_ssn.R
\name{export_ssn}
\alias{export_ssn}
\title{Export 'SSN' object}
\usage{
export_ssn(path, predictions = NULL, delete_directory = FALSE)
}
\arguments{
\item{path}{character; path to write .ssn object to.}

\item{predictions}{name(s) of prediction map(s) (optional).}

\item{delete_directory}{boolean; shall the ssn directory and all files be
deleted before export in case it already exists? See details.}
}
\value{
Nothing. Files are written to the specified folder
}
\description{
This function exports the calculated sites, edges and binary IDs
to a folder which then can be read using the 'SSN' package.
}
\details{
First it is checked if one of the column names is longer than 10
characters (which cannot be exported to ESRI shape files as required by 'SSN').

\code{delete_directory = TRUE} is useful if the same directory name has been
used before and the existing data shall be overwritten.
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

# Check and correct complex junctions (there are no complex juctions in this 
# example date set)
cj <- check_compl_junctions()
if(cj){
  correct_compl_junctions()
}

# Prepare edges
calc_edges()

# Prepare site
calc_sites()

# Write data to SSN Folder
ssn_dir <- file.path(tempdir(), 'nc.ssn')
export_ssn(ssn_dir, delete_directory = TRUE)
list.files(ssn_dir)
}

}
\author{
Mira Kattwinkel,\email{mira.kattwinkel@gmx.net}, 
  Eduard Szoecs, \email{eduardszoecs@gmail.com}
}
