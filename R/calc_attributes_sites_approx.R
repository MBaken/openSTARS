#' Calcuate attributes of the sites.
#'
#' For each site (observations or predictions) attributes (predictor variables)
#' are derived based on the values caluclated for the edge the site lies on.
#' This fuction calculates approximate values for site catchments as described
#' in Peterson & Ver Hoef, 2014: STARS: An ARCGIS Toolset Used to Calculate the
#' Spatial Information Needed to Fit Spatial Statistical Models to Stream
#' Network Data. J. Stat. Softw., 56 (2).
#'
#' @param sites_map character; name of the sites the attributes shall be
#'   calculated for. "sites" refers to the observation sites.
#' @param input_attr_name character vector; input column name in the edges
#'   attribute table.
#' @param output_attr_name character vector (optional); output column name
#'   appended to the site attribute data table. If not provided it is set to
#'   \code{input_attr_name}. Attribute names must not be longer than 10
#'   characters.
#' @param stat name or character vector giving the statistics to be calulated.
#'   See details below.
#' @param round_dig integer; number of digits to round results to.
#'
#' @return Nothing. The function appends new columns to the \code{sites_map}
#'   attribute table
#' \itemize{
#'  \item{'H2OAreaA':} {Total watershed area of the watershed upstream of each site.}
#'  \item{attr_name:} {Additional optional attributes calculated based on \code{input_attr_name}.}
#' }
#'
#' @details The apporximate total catchment area (H2OAreaA) is always calculated.
#' If \code{stat} is one of "min", "max", "mean" or "percent" the
#'   function assigns the value of the edge the site lies on. Otherwise, the
#'   value is calculated as the sum of all edges upstream of the previous
#'   junction and the proportional value of the edge the site lies on (based on
#'   distRatio); this is usefull e.g. for counts of dams or waste water
#'   treatment plant or total catchment area.
#'
#' @note \code{\link{import_data}}, \code{\link{derive_streams}},
#'   \code{\link{calc_edges}}, \code{\link{calc_sites}} or
#'   \code{\link{calc_prediction_sites}} and \code{\link{calc_attributes_edges}}
#'   must be run before.
#'
#' @author Mira Kattwinkel, \email{mira.kattwinkel@@gmx.net}
#' @export
#' @examples
#' \donttest{
#' # Initiate GRASS session
#' initGRASS(gisBase = "/usr/lib/grass70/",
#'     home = tempdir(),
#'     override = TRUE)
#'
#' # Load files into GRASS
#' dem_path <- system.file("extdata", "nc", "elev_ned_30m.tif", package = "openSTARS")
#' sites_path <- system.file("extdata", "nc", "sites_nc.shp", package = "openSTARS")
#' setup_grass_environment(dem = dem_path, sites = sites_path)
#' import_data(dem = dem_path, sites = sites_path)
#' gmeta()
#'
#' # Derive streams from DEM
#' derive_streams(burn = 0, accum_threshold = 700, condition = TRUE, clean = TRUE)
#'
#' # Test for and correct complex junctions
#' cp <- check_compl_junctions()
#' if (cp)
#'   correct_compl_junctions(clean=T)
#'
#' # Prepare edges
#' calc_edges()
#' execGRASS("r.slope.aspect", flags = c("overwrite","quiet"),
#' parameters = list(
#'   elevation = "dem",
#'   slope = "slope"
#'   ))
#' calc_attributes_edges(input_raster = rep("slope",3),
#'   stat = c("mean", "min","max"), attr_name = paste0(c("mean", "min","max"),"Slo"))
#'
#' # Prepare sites
#' calc_sites()
#' calc_attributes_sites_approx(input_attr_name = paste0(c("mean", "min","max"),"Slo"),
#'   stat = c("mean", "min","max"))
#'
#' # Plot data
#' dem <- readRAST('dem', ignore.stderr = TRUE)
#' edges <- readVECT('edges', ignore.stderr = TRUE)
#' sites <- readVECT('sites', ignore.stderr = TRUE)
#' plot(dem, col = terrain.colors(20))
#' cols <- colorRampPalette(c("blue", 'red'))(length(edges$meanSlo_e))[rank(edges$meanSlo_e)]
#' plot(edges,col=cols,add=T, lwd=2)
#' cols <- colorRampPalette(c("blue", 'red'))(length(sites$meanSlo))[rank(sites$meanSlo)]
#' points(sites, pch = 16, col = cols)
#' }

calc_attributes_sites_approx <- function(sites_map = "sites",
                                         input_attr_name,
                                         output_attr_name = NULL,
                                         stat,
                                         round_dig = 2){

  if(is.null(output_attr_name))
    output_attr_name <- input_attr_name
  output_attr_name <- c("H2OAreaA", output_attr_name)

  input_attr_name <- c("H2OArea", input_attr_name)

  stat <- c("totalArea", stat)

  if(length(input_attr_name) != length(output_attr_name))
    stop("There must be the same number of input and output attribute names.")

  if(any(nchar(output_attr_name)) > 10)
    stop("Attribute names must not be longer than ten characters.")

   if(length(round_dig) == 1)
    round_dig <- rep(round_dig, length(output_attr_name))

  if(length(round_dig) < length(output_attr_name))
    round_dig <- c(max(round_dig), round_dig)

  if(length(unique(c(length(input_attr_name), length(stat),length(output_attr_name)))) > 1)
    stop(paste0("There must be the same number of input attribute names (",length(input_attr_name), "),
                output attribute names (", length(output_attr_name), ") and
                statistics to calculate  (", length(stat),")."))

  execGRASS("v.db.addcolumn",
            flags = c("quiet"),
            parameters = list(
              map = sites_map,
              columns = paste0(output_attr_name," double precision", collapse = ", ")
            ))

  for(i in seq_along(input_attr_name)){
    if(input_attr_name[i] == "H2OArea"){
      # calculate site attribute as attribute of the two previous edges +
      # (1-distRatio) * contribution of edge to total edge attribute
      ecat_prev1 <-  paste0("(SELECT cat FROM edges WHERE edges.stream=(SELECT prev_str01 FROM edges WHERE edges.cat=",sites_map,".cat_edge))")
      ecat_prev2 <-  paste0("(SELECT cat FROM edges WHERE edges.stream=(SELECT prev_str02 FROM edges WHERE edges.cat=",sites_map,".cat_edge))")
      sql_str <-paste0("UPDATE ", sites_map," SET ",output_attr_name[i],
             " = ROUND(((1-distRatio)*",
              "(SELECT rcaArea FROM edges WHERE ", sites_map,".cat_edge = edges.cat) +",
              "(SELECT H2OArea FROM edges WHERE edges.cat=",ecat_prev1,") +",
              "(SELECT H2OArea FROM edges WHERE edges.cat=",ecat_prev2,")),",round_dig[i],")")
      execGRASS("db.execute",
                parameters = list(
                  sql = sql_str
                ))
      # correct for those segments that do not have previous streams
      sql_str <- paste0("UPDATE ", sites_map," SET ",output_attr_name[i],
                        " = (1-distRatio)*(SELECT rcaArea FROM edges WHERE ",
                        sites_map,".cat_edge = edges.cat) WHERE cat_edge IN ",
                        "(SELECT cat FROM edges WHERE prev_str01=0)")
      execGRASS("db.execute",
                parameters = list(
                  sql = sql_str
                ))
      # ROUND does not work with WHERE ... IN ...
      execGRASS("db.execute",
                parameters = list(
                  sql = paste0("UPDATE ",sites_map, " SET ",output_attr_name[i],
                               "= ROUND(",output_attr_name[i],",",round_dig[i],")")
                ))
    }else{
      if(stat[i] %in% c("min", "max", "mean", "percent")){
        execGRASS("db.execute",
                  parameters = list(
                    sql = paste0("UPDATE ", sites_map," SET ", output_attr_name[i], "=",
                                 "(SELECT ", paste0(input_attr_name[i],"_c"),
                                 " FROM edges WHERE edges.cat=", sites_map,".cat_edge)")
                  ))
      } else {
        # calculate site attribute as attribute of the two previous edges +
        # (1-distRatio) * contribution of edge to total edge attribute
        # Usefull e.g. for total numbers (no of WWTP per catchment)
        ecat_prev1 <-  paste0("(SELECT cat FROM edges WHERE edges.stream=(SELECT prev_str01 FROM edges WHERE edges.cat=",sites_map,".cat_edge))")
        ecat_prev2 <-  paste0("(SELECT cat FROM edges WHERE edges.stream=(SELECT prev_str02 FROM edges WHERE edges.cat=",sites_map,".cat_edge))")
        sql_str <-paste0("UPDATE ", sites_map," SET ",output_attr_name[i],
                         " = ROUND(((1-distRatio)*",
                         "(SELECT ", paste0(input_attr_name[i],"_e"), " FROM edges WHERE ", sites_map,".cat_edge = edges.cat) +",
                         "(SELECT ", paste0(input_attr_name[i],"_c"), " FROM edges WHERE edges.cat=",ecat_prev1,") +",
                         "(SELECT ", paste0(input_attr_name[i],"_c"), " FROM edges WHERE edges.cat=",ecat_prev2,")),",round_dig[i],")")
        execGRASS("db.execute",
                  parameters = list(
                    sql = sql_str
                  ))
        # correct for those segments that do not have previous streams
        sql_str <- paste0("UPDATE ", sites_map," SET ",output_attr_name[i],
                          " = (1-distRatio)*(SELECT ", paste0(input_attr_name[i],"_e"),
                          " FROM edges WHERE ", sites_map,".cat_edge = edges.cat) WHERE cat_edge IN ",
                          "(SELECT cat FROM edges WHERE prev_str01=0)")
        execGRASS("db.execute",
                  parameters = list(
                    sql = sql_str
                  ))
        # ROUND does not work with WHERE ... IN ...
        execGRASS("db.execute",
                  parameters = list(
                    sql = paste0("UPDATE ",sites_map, " SET ",output_attr_name[i],
                                 "= ROUND(",output_attr_name[i],",",round_dig[i],")")
                  ))
      }
    }
  }
}