#' Check, if there are more than two prev_str0x columns in the streams attribute table.
#' 
#' It is checked, if there are columns names "prev_str03","prev_str04" and 
#' "prev_str05" in the attribute table of streams_v derived with r.stream.order,
#' hence, if there are more than two inflows to a junction.
#'
#' @param none.
#'
#' @return TRUE if there are complex junctions.
#' 
#' @note \code{\link{setup_grass_environment}}, \code{\link{import_data}} and 
#' \colde{\ling{derive_streams}} must be run before.
#' 
#' @author Mira Kattwinkel \email{kattwinkel-mira@@uni-landau.de}
#' @export
#'
#' @examples
#' \donttest{
#' library(rgrass7)
#' initGRASS(gisBase = "/usr/lib/grass70/",
#'   home = tempdir(),
#'   override = TRUE)
#' gmeta()
#' dem_path <- system.file("extdata", "nc", "elev_ned_30m.tif", package = "openSTARS")
#' sites_path <- system.file("extdata", "nc", "sites_nc.shp", package = "openSTARS")
#' setup_grass_environment(dem = dem_path, sites = sites_path)
#' import_data(dem = dem_path, sites = sites_path)
#' derive_streams()
#' check_compl_junctions()
#' }

check_compl_junctions <- function(){
  ret <- FALSE
  cnames<-execGRASS("db.columns",
                    parameters = list(
                      table = "streams_v"
                    ), intern=T)
  if(any(c("prev_str03","prev_str04","prev_str05") %in% cnames)){
    message('There are complex confluences in the stream network. Please run correct_compl_junctions for correction. \n')
    if(length(grep("prev_str",cnames)) > 3) {
      message('There are junctions with more than three inflows. Currently, correct_compl_junctions only works for three inflows.')
    }
    ret <- TRUE
  }
  return(ret)
}