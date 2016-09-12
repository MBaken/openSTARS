#' Correct junctions with three inflows.
#'
#' At complex junctions, the outflow is broken into two segments at 1/3 of the 
#' dem's cellsize downstream of the start using 
#' \href{https://grass.osgeo.org/grass73/manuals/v.edit.html}{v.edit, tool = break}.
#' Then, the stream with the smallest angle to the outflow is moved to this new junction using 
#' \href{https://grass.osgeo.org/grass73/manuals/v.edit.html}{v.edit, tool = vertexmove}.
#' So far, this function works only for junctions with three inflows, not more.
#' 
#' @import data.table
#' 
#' @param clean logical; Should intermediate layers and files be removed from GRASS session?
#' 
#' @return Nothing. The function changes features in
#' \itemize{
#'  \item{"streams_v"}{updated streams with topology (vector)}
#'  \item{"streams_r}{updated stream raster (new cat) (raster)}
#' }
#' and copies the oringial to 
#' \itemize{
#'  \item{"streams_v_o"}{originally derived streams with topology (vector)}
#'  \item{"streams_r_o"}{originally derived stream raster (raster)}
#' }
#'
#' @note \code{\link{setup_grass_environment}}, \code{\link{import_data}} and \colde{\ling{derive_streams}} must be run before.
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
#' cj <- check_compl_junctions()
#' if(cj){
#'   correct_compl_junctions()
#' } 
#' dem <- readRAST('dem', ignore.stderr = TRUE)
#' sites <- readVECT('sites_o', ignore.stderr = TRUE)
#' streams <- readVECT('streams_v', ignore.stderr = TRUE)
#' streams_o <- readVECT('streams_v_o', ignore.stderr = TRUE)
#' plot(dem, col = terrain.colors(20))
#' points(sites, pch = 4)
#' lines(streams_o, col = 'red')
#' lines(streams, col = 'blue')
#' }

correct_compl_junctions <- function(clean = TRUE){
  cnames<-execGRASS("db.columns",
                    parameters = list(
                      table = "streams_v"
                    ), intern=T)
  
  if (any(c("prev_str04","prev_str05") %in% cnames))
    stop('There are four or more inflows to one outflow. Currently, this 
         function only works for complex juctions with three inflows.')
  
  # Create temporary directory
  dir.create("temp")
  
  # get cellcize of dem raster
  cellsize <- execGRASS("g.region", flags = "p",intern=T)
  cellsize <- as.numeric(do.call(rbind,strsplit(cellsize[grep("res",cellsize)],split=":"))[,2])
  if(cellsize[1] != cellsize[2]){
    message("north-south cell size != east-west cell size. Please check")
  } else cellsize <- cellsize[1]
  
  # get stream ID of features that have more than two inflows, and stream IDs of those inflows
  df.junctions<-do.call(rbind,strsplit(
    execGRASS("db.select",
              parameters = list(
                sql = 'select stream, prev_str01, prev_str02, prev_str03 from streams_v where prev_str03 > 0'
              ), intern=T),
    split='\\|'))
  colnames(df.junctions) <- df.junctions[1,]
  df.junctions <- data.frame(df.junctions[-1,])
  df.junctions <- sapply(df.junctions,as.character)
  df.junctions <- apply(df.junctions,2,as.numeric)

  # Create new vector with all segments that form complex junctions
  str1<-paste(df.junctions,collapse = ",")
  str1<-paste0("(", str1, ")",sep="")
  execGRASS("v.extract",
            flags = c("overwrite","quiet"),
            parameters = list(
              input = "streams_v",
              output = "complex_flows",
              type = "line",
              where = paste0('stream in ',str1)
            ))
  
  # Create file of point positions 1 cellsize  upstream (inflows) and  downstream (outflows) from junction to get the flow direction close to the juction
  points <- file.path("temp","complex_points.txt")
  # MiKatt: Old method could lead to identical point id if one segment is cut in more than one piece (start and end)
  #         write(paste(paste("P ",c(df.junctions),c(df.junctions),c(rep(0.5*cellsize,nrow(df.junctions)),
  #                           rep(-0.5*cellsize,(ncol(df.junctions)-1)*nrow(df.junctions)))),collapse="\n"), file = points)
  str1<-paste(df.junctions,collapse = ",")
  str1<-paste0("(", str1, ")",sep="")
  dt<-data.table(do.call(rbind,strsplit(
    execGRASS("db.select",
              parameters = list(
                sql = paste0('select stream, length from streams_v where stream in',str1)
              ), intern=T),
    split='\\|'))[-1,])
  setattr(dt,"names",c("stream","len"))
  dt[,stream:= as.numeric(as.character(stream))]
  dt[,len:=as.numeric(as.character(dt[,len]))]
  dt3<-melt(setDT(data.frame(df.junctions)),measure.vars = colnames(df.junctions))
  dt<-merge(dt3,dt,by.x="value",by.y="stream")
  setnames(dt, "value","stream")
  dt[,newlen := -cellsize]
  dt[grepl("prev_str",variable) & len < cellsize, newlen:=-len]
  dt[variable == "stream", newlen:=cellsize]
  dt[variable == "stream" & len < cellsize,newlen:=len]
  dt[,pcat := seq(1,nrow(dt))]
  write(paste(paste("P ",dt[,pcat],c(dt[,stream]),dt[,newlen],collapse="\n")),
        file = points)
  # Create point feature with points on complex flows based on points created above
  execGRASS("v.segment",
            flags = c("overwrite","quiet"),
            parameters = list(
              input = "complex_flows",
              output = "complex_flows_p",
              rules = points
            ))
  # Get flow direction at these points
  execGRASS("v.db.addtable", flags = c("quiet"),
            parameters = list(
              map = "complex_flows_p",
              columns = "dir int"
            ))
  execGRASS("v.what.rast", flags = c("quiet"),
            parameters = list(
              map = "complex_flows_p",
              raster = "dirs",
              column = "dir"
            ))
  
  # Get coordinates of ends of juction segments (only used for the inflows)
  dt.endcoord<-data.frame(do.call(rbind,strsplit(
    execGRASS("v.to.db", flags =c("p","quiet"),
              parameters = list(
                map = "complex_flows", #"streams_v",
                type = "line",
                option = "end"
              ),intern=T),
    split = '\\|'))[,-4])
  setDT(dt.endcoord)
  setattr(dt.endcoord,"names",c("cat","end_x","end_y"))
  dt.endcoord[,':='(end_x = as.numeric(as.character(end_x)), end_y = as.numeric(as.character(end_y)),cat = as.numeric(as.character(cat)))]
  #dt.endcoord <- dt.endcoord[cat %in% c(df.junctions)]
  setkey(dt.endcoord,cat)
  
  # Merge endcoordinates with flow directions one cell above / below juction
  dt.dirs<-readVECT("complex_flows_p",ignore.stderr = T)
  dt.dirs<-merge(dt,dt.dirs,by.y="cat",by.x="pcat")
  dt.endcoord<- merge(dt.dirs,dt.endcoord,by.x="stream",by.y="cat")
  rm(list=c("dt.dirs"))

  # Find that inflow with the largest differnce in flow direction to the outflow (= smallest angle) -> 'move_stream'
  # "This gives a signed angle for any angles:
  # a = targetA - sourceA
  # a = (a + 180) % 360 - 180"
  # Adjusted for directions (1:8)
  df.move_streams<-matrix(nrow=nrow(df.junctions),ncol=2)
  colnames(df.move_streams)<-c("move_stream","cut_stream")
  for(i in 1:nrow(df.junctions)){
    # direction of outflow
    outdir <- dt.endcoord[stream==df.junctions[i,"stream"] & variable == "stream",dir]
    # cat and direction of inflows
    indirs <- dt.endcoord[stream %in% df.junctions[i,-1] & grepl("prev_",variable),.(stream,dir)]
    # difference between inflow and outflow directions; 
    indirs[, dif:=abs((outdir-dir+4) %% 8 -4)]
    ms <- indirs[dif==max(dif),][1,stream] # if there are tow inflows with same angel to outflow, always take the first for reproducability
    df.move_streams[i,] <- c(ms,df.junctions[i,1])
  }
  dt.xy_move<-dt.endcoord[stream %in% df.move_streams[,"move_stream"],.(stream,end_x,end_y)]
  df.move_streams <- merge(df.move_streams, dt.xy_move,by.x="move_stream",by.y="stream")
  colnames(df.move_streams)[colnames(df.move_streams) == "end_x"] <- "move_end_x"
  colnames(df.move_streams)[colnames(df.move_streams) == "end_y"] <- "move_end_y"
  rm("dt.endcoord")
  
  # Create file of point positions 1/3 cellsize downstream of start of outflow to cut outflow
  # P <point id>   <line cat> <offset> [<side offset>]
  points <- file.path("temp","cut_points.txt")
  write(paste(paste("P ",df.junctions[,"stream"],df.junctions[,"stream"],c(rep(cellsize/3,nrow(df.junctions)))),collapse="\n"),
        file = points)
  execGRASS("v.segment",
            flags = c("overwrite","quiet"),
            parameters = list(
              input = "complex_flows",
              output = "complex_flows_cp",
              rules = points
            ))
  cut_coords<-apply(do.call(rbind,strsplit(
    execGRASS("v.out.ascii", 
              flags = c("overwrite", "quiet"),
              parameters = list(
                input = "complex_flows_cp"
              ),intern=T),
    split='\\|')),2,as.numeric)
  colnames(cut_coords) <- c("cut_x","cut_y","cut_stream")
  df.move_streams <- merge(df.move_streams,cut_coords,by="cut_stream")
  
  # Save oringinal derived network to streams_v_o
  execGRASS("g.copy",
            flags = c('overwrite', 'quiet'),
            parameters = list(
              vector = 'streams_v,streams_v_o'), ignore.stderr = TRUE)
  
  message("Original stream topology file moved to streams_v_o.\n")
  message("Breaking lines and moving vertices...\n")

  # Break features at cut coordinates
  for(i in 1:nrow(df.junctions)){
    #print(i)
    execGRASS("v.edit",
              flags = c('quiet',"overwrite"),
              parameters = list(
                map = 'streams_v',
                type = 'line',
                tool = 'break',
                threshold = 1,
                #where = paste0('stream = ',df.junctions[i,"stream"]),
                coords = c(cut_coords[i,c("cut_x","cut_y")])
              ))
  }
  # Move end vertices of move streams to cut coordinates
  for(i in 1:nrow(df.move_streams)){
    #print(i)
    execGRASS("v.edit",
              flags = c('quiet',"overwrite"),
              parameters = list(
                map = 'streams_v',
                type = 'line',
                tool = 'vertexmove',
                threshold = c(1,cellsize/3,0),
                where = paste0('stream = ',df.move_streams[i,"move_stream"]),
                coords = c(df.move_streams[i,"move_end_x"],df.move_streams[i,"move_end_y"]),
                move = c(df.move_streams[i,"cut_x"]- df.move_streams[i,"move_end_x"],df.move_streams[i,"cut_y"]- df.move_streams[i,"move_end_y"],0),
                snap = "node"
              ))
  }
  
  # Seems to be the easiest way to assingn new, unique cat values to all features
  streams <- readVECT(vname = "streams_v", type = "line", remove.duplicates = FALSE, ignore.stderr = T)
  streams$cat_old <- streams$cat
  ncat <- max(streams$cat) +1
  for(i in 1:nrow(df.junctions)){
    j <- which(streams$cat == df.junctions[i,"stream"])
    if(!length(j) > 1){
      print(i)
    } else {
      streams$cat[j[2]] <- ncat
      ncat <- ncat +1
    }
  }
  # writeVECT produces new cat column; 
  # IMPORTANT: Take care not to base calculations on that but to use manually updated cat_ (= new 'stream'))
  writeVECT(streams,"streams_v",v.in.ogr_flags=c("overwrite","quiet"), ignore.stderr = TRUE)
  rm("streams")
  
  # Recalculate length of line segments
  execGRASS("v.to.db", flags = c("quiet"),
            parameters = list(
              map = "streams_v",
              option = "length",
              type = "line",
              columns = "length"
            ))
  # Find new cat_ of short and long pieces of cut streams
  str1<-paste(df.junctions[,"stream"],collapse = ",")
  str1<-paste0("(", str1, ")",sep="")
  dt.cut <- do.call(rbind,strsplit(
    execGRASS("db.select",
              parameters = list(
                sql = paste0('select stream, length, cat_ from streams_v where stream in', str1)
              ),intern = T),
    split = '\\|'))
  colnames(dt.cut)<-dt.cut[1,]
  dt.cut <- data.table(dt.cut[-1,])
  dt.cut[,':=' (stream = as.numeric(stream),length = as.numeric(length),cat_ = as.numeric(cat_))]
  dt.smallcut <- dt.cut[dt.cut[, .I[length == min(length)], by=stream]$V1]
  setnames(dt.smallcut,"cat_","cat_small")
  dt.largecut <- dt.cut[dt.cut[, .I[length == max(length)], by=stream]$V1]
  setnames(dt.largecut,"cat_","cat_large")
  
  df.junctions <- merge(df.junctions,df.move_streams,by.x="stream",by.y = "cut_stream")
  df.junctions <- merge(df.junctions, dt.smallcut[,.(stream,cat_small)],by="stream")
  df.junctions <- merge(df.junctions, dt.largecut[,.(stream,cat_large)],by="stream")

  # assign updated cat_ value to 'stream' for cut stream segments
  str1<-paste(c(dt.smallcut[,cat_small],dt.largecut[,cat_large]),collapse = ",")
  str1<-paste0("(", str1, ")",sep="")
  execGRASS("v.db.update", flags = c("quiet"),
            parameters = list(
              map = "streams_v",
              column = "stream",
              where = paste0('cat_ in ',str1),
              query_column = "cat_"
            ))
  
  remove(list = c(tables(silent=T)$NAME))
  
  message("Updating topology...\n")
  
  for(i in 1:nrow(df.junctions)){
    # set "next_stream" of cat_small amd move_stream to cat_large
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "next_stream",
                where = paste0('stream in ',paste0("(",paste(df.junctions[i,c("cat_small","move_stream")],collapse=","),")")),
                value = paste0(df.junctions[i,"cat_large"])
              ))
    # set "prev_str01" and "prev_str02" of cat_small to the not moved streams
    prev <- df.junctions[i,c("prev_str01", "prev_str02", "prev_str03")]
    prev <- prev[prev != df.junctions[i,"move_stream"]]
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "prev_str01",
                where = paste0('stream == ',df.junctions[i,"cat_small"]),
                value = paste0(prev[1])
              ))
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "prev_str02",
                where = paste0('stream == ',df.junctions[i,"cat_small"]),
                value = paste0(prev[2])
              ))
    # set "next_stream" of prev_str01 and prev_str02 to cat_small
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "next_stream",
                where = paste0('stream in ',paste0("(",paste(prev,collapse=","),")")),
                value = paste(df.junctions[i,"cat_small"])
              ))
    # set "prev_str01" and "prev_str02" of cat_large to cat_small and move_stream
    prev <- df.junctions[i,c("cat_small", "move_stream")]
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "prev_str01",
                where = paste0('stream == ',df.junctions[i,"cat_large"]),
                value = paste0(prev[1])
              ))
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "prev_str02",
                where = paste0('stream == ',df.junctions[i,"cat_large"]),
                value = paste0(prev[2])
              ))
    # set 'prev_str01' or 'prev_str02' of next_stream of cat_large to cat_large
    ns<-execGRASS("db.select",
                parameters = list(
                  sql = paste0('select next_stream from streams_v where stream == ', df.junctions[i,"cat_large"])
                ),intern = T)[2]
    prev.ns<-unlist(strsplit(
                  execGRASS("db.select",
                    parameters = list(
                      sql = paste0('select prev_str01, prev_str02 from streams_v where stream == ', ns)
                    ),intern = T)[2],
               split = '\\|'))
    prev<-which(as.numeric(prev.ns) == df.junctions[i,"cat_small"])
    if(length(prev)>0){
      prev<-paste0("prev_str0",prev)
      execGRASS("v.db.update", flags = c("quiet"),
                parameters = list(
                  map = "streams_v",
                  column = prev,
                  where = paste0('stream == ',ns),
                  value = paste0(df.junctions[i,"cat_large"])
                ))
    }
  }

  # Mark changed features
  execGRASS("v.db.addcolumn", flags = c("quiet"),
            parameters = list(
              map = "streams_v",
              columns = "changed int"
            ))
  # Set 'changed' to '0' for all streams
  execGRASS("v.db.update", flags = c("quiet"),
            parameters = list(
              map = "streams_v",
              column = "changed",
              value = "0"
            ))
  # Set 'changed' to '1' for the changed ones
  for(i in 1:nrow(df.junctions)){
    #print(i)
    str1<-paste(unique(unlist(df.junctions[i,c("prev_str01","prev_str02","prev_str03","cat_small","cat_large")])),collapse = ",")
    str1<-paste0("(", str1, ")",sep="")
    execGRASS("v.db.update", flags = c("quiet"),
              parameters = list(
                map = "streams_v",
                column = "changed",
                where = paste0('stream in ',str1),
                value = "1"
              ))
  }
  
  # !MiKatt: crashes when str1 contains many streams but works row wise on df.junctions
  # str1<-paste(sort(unique(unlist(df.junctions[c("prev_str01","prev_str02","prev_str03","cat_small","cat_large")]))),collapse = ",")
  # str1<-paste0("(", str1, ")",sep="")
  # execGRASS("v.db.update", flags = c("quiet"),
  #           parameters = list(
  #             map = "streams_v",
  #             column = "changed2",
  #             where = paste0('stream in ',str1),
  #             value = "1"
  #           ))
  # execGRASS("v.db.update", flags = c("quiet"),
  #           parameters = list(
  #             map = "streams_v",
  #             column = "changed",
  #             where = paste0('stream not in ',str1),
  #             value = "0"
  #           ))
  
  # delete column prev_str03
  execGRASS("v.db.dropcolumn", flags = c("quiet"),
            parameters = list(
              map = "streams_v",
              columns = "prev_str03"
            ))
  
  message("Original stream raster moved to streams_r_o.\n")
  execGRASS("g.copy",
            flags = c('overwrite', 'quiet'),
            parameters = list(
              raster = 'streams_r,streams_r_o'))
  
  # now use automatically assigned 'cat'
  execGRASS("v.to.rast", flags = c("overwrite", "quiet"),
            parameters = list(
              input = "streams_v",
              type = "line",
              output = "streams_r",
              use = "attr",
              attribute_column = "cat"
            ))
 
  if(clean){
    # Remove temporary directory
    unlink("temp", recursive =T, force = TRUE) 
    
    # Remove temporary vector files
    execGRASS("g.remove",
              flags = c('quiet', 'f'),
              parameters = list(
                type = 'vector',
                name = c("complex_flows","complex_flows_cp","complex_flows_p")
              ))
  }
  
  message("Complex junctions were removed. Please check changed features in streams_v.")
}