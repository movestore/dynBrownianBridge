library('move')
library('move2')
library('raster')
library('sp')
library("ggspatial")
library("ggplot2")
library('sf')
library("scales")


# data <- readRDS("./data/raw/fishers.rds")
# plot(data)
# raster_resol=100
# loc.err=30
# conts=c("0.50","0.999") #"0.5","0.75",
# ext=10000
# ignoreTimeHrs=6
# colorBy= "both" #c("trackID", "contourLevel", "both")
# saveAsSHP=F
# mymtype="osm"
# myzoom= -1

## "individual.local.identifier" comes from the move object, the track id is assigned to it
## ToDo:
## make option stadia, if null, osm?
## add posibility to download all as a http

# rosm::osm.types()
# api key required: "opencycle" ,  "osmtransport" ,"thunderforestlandscape" ,"thunderforestoutdoors" 
# no api key: "osm", "hotstyle", "loviniahike","loviniacycle" , "cartodark", "cartolight" 
# error: "stamenbw", "stamenwatercolor" 


## For now just keep "osm" as map type as the others often give error and are not very informative. User can play with the zoom

rFunction <- function(data,raster_resol=10000,loc.err=30,conts=0.999,ext=20000,ignoreTimeHrs=NULL, 
                      colorBy=c("trackID", "contourLevel", "both"), saveAsSHP=TRUE,mymtype="osm",
                      myzoom= -1){
  
  datamv <- moveStack(to_move(data))
  
  #indicate the area spanned by the data for the user
  ix1 <- which(coordinates(datamv)[,1]==min(coordinates(datamv)[,1],na.rm=TRUE))
  ix2 <- which(coordinates(datamv)[,1]==max(coordinates(datamv)[,1],na.rm=TRUE))
  ix3 <- which(coordinates(datamv)[,2]==min(coordinates(datamv)[,2],na.rm=TRUE))
  ix4 <- which(coordinates(datamv)[,2]==max(coordinates(datamv)[,2],na.rm=TRUE))
  
  londist <- round(pointDistance(coordinates(datamv)[c(ix1,ix2),],lonlat=TRUE)[2,1])
  latdist <- round(pointDistance(coordinates(datamv)[c(ix3,ix4),],lonlat=TRUE)[2,1])
  logger.info(paste("Your data set spans the maximum longitude distance:",londist,"m and maximum latitude distance:",latdist,"m. Please adapt your parameters accordingly."))
  
  logger.info(paste("Your data set has a min time lag:",round(min(unlist(timeLag(datamv,"hours"))),4),"hours,", "a median time lag:",round(median(unlist(timeLag(datamv,"hours"))),4),"hours,","and a max time lag:",round(max(unlist(timeLag(datamv,"hours"))),4),"hours.","Choose your timelag to ignore accordingly."))
  
  # cnts <- as.numeric(trimws(strsplit(as.character(conts),",")[[1]])) #if more than one contour percentage given by user, this makes a vector our of the comma-separated string ==> this was only keeping the 1st contour, at least in R. In moveapps it seems to work for some reason....
  cnts <- as.numeric(unlist(lapply(strsplit(as.character(conts),","),trimws))) ## fixed?
  # if(0.999%in%cnts){cnts}else{cnts <- c(cnts,0.999)} # NOT SURE IF TO EXCLUDE THIS. IF SOMEONE IS JUST INTEREST IN THE 0.25, AND THE 0.99 IS ALWAYS THERE (ALSO ZOOMING ALWAYS OUT TO THE ENTIRE TRACK) COULD BE ANNOYING....
  if(0%in%cnts){ 
    cnts <- cnts[!cnts%in%c(0)]
    logger.warn("Countour of 0% cannot be calculated, it has been excluded") ## apparently this is not clear to everyone...
  }else{cnts <- cnts}
  
  # need to project data on flat surface for BBMM
  datamv_t <- spTransform(datamv, center=TRUE) #aeqd in metre
  
  Ra <- raster(extent(datamv_t)+c(-ext,ext,-ext,ext), resolution=raster_resol, crs = crs(datamv_t) , vals=NULL) ## option to vary the amount the area gets enlarged, as the error "Lower x grid not large enough, consider extending the raster in that direction or enlarging the ext argument" is a pretty common error that the raster is not large enough in some direction
  datamv_resol <- median(unlist(timeLag(datamv,units="mins")),na.rm=TRUE) 
  if(datamv_resol<=0.25){timeStep <- 0.25/15}else{timeStep <- datamv_resol/15} ## if timelag is less then 15secs, make time.step==to 1sec chuncks, else take the median timelag. CHECK WITH BART IF TO GO HIGHER THAN 15secs AND 1secs CHUNCKS!
  
  # calculate first the variance to be able to exclude larger timegaps that increase uncertanty
  datamv_t_dBBvar <- brownian.motion.variance.dyn(datamv_t, location.error=loc.err, margin=11, window.size=31)
  if(!is.null(ignoreTimeHrs)){
    datamv_t_dBBvar@interest[unlist(timeLag(datamv_t,"hours"))>ignoreTimeHrs] <- FALSE ## excluding segments longer than "ignoreTimeHrs" hours from the dbbmm
  }
  # calculate dBB of the variance
  datamv_t_dBBMM <- brownian.bridge.dyn(datamv_t_dBBvar, raster = Ra,  window.size = 31, margin=11, time.step = timeStep, location.error = rep(loc.err,length(datamv_t_dBBvar)), verbose=F)
  
  # get UDs for all
  datamv_t_UD <- getVolumeUD(datamv_t_dBBMM) 
  
  # get UD size in Km2 per contour
  cntsSize <- cnts
  cntsSize <- cntsSize[order(cntsSize)] 
  UD_size_L <- lapply(cntsSize, function(ctr){
    UDsel <- datamv_t_UD<=ctr 
    UDsizem2 <- cellStats(UDsel, 'sum')*raster_resol*raster_resol
    UDsizeKm2 <- UDsizem2/1000000
    df <- data.frame(trackID=names(datamv_t_UD), UD_size_Km2=UDsizeKm2, contour=ctr, row.names = NULL) # add individualID and TrackID in the future? ## contour 0.05 is always added, odd....
    return(df)
  })
  UD_size_df <- do.call("rbind",UD_size_L) #what does this give? the sizes of all contours for each track? YES, each row is a track, a contour level, and its UD size in Km2. each combi track-contour gets its own row and ud size value
  write.csv(UD_size_df, row.names=F, file = appArtifactPath("UD_size_per_contour.csv"))
  
  # get contours into a SLDF object
  UD_sldf <- raster2contour(datamv_t_dBBMM, level=cnts)
  
  # changing ID names of the SLDF as the default ones cannot be interpreted
  UD_sldf <-  spChFIDs(UD_sldf, as.character(paste0(UD_sldf$individual.local.identifier,"_",UD_sldf$level))) 
  
  UD_sldf_t <- spTransform(UD_sldf,CRS("+proj=longlat"))
  
  ###download UD as GeoPackage (GPKG)
  if(saveAsSHP){
    UD_sldf_t_sf <- st_as_sf(UD_sldf_t)
    st_write(UD_sldf_t_sf, appArtifactPath(paste0("UD_contour_",paste0(cnts,collapse="_"),".gpkg")), driver = "GPKG", delete_dsn = TRUE)
  }
  
  # convert to sf (sldf is deprecated in ggplot)
  UD_sf <- st_as_sf(UD_sldf_t)
  UD_sf$id <- paste0(UD_sf$individual.local.identifier,"_",UD_sf$level)
  
  ud_bbox <- sf::st_bbox(UD_sf)
  
  osmap_clrby <- ggplot() +
    ggspatial::annotation_map_tile(zoomin = as.numeric(myzoom), type=mymtype) +
    ggspatial::annotation_scale(aes(location="br")) +
    theme_linedraw() +
    geom_sf(data = mt_track_lines(data),color=alpha("black",0.25)) +
    geom_sf(data = data, color = alpha("black",0.25), size = 1)+
    annotation_spatial(data = UD_sf, aes(color=if(colorBy=="trackID"){individual.local.identifier}else if(colorBy=="contourLevel"){level}else if(colorBy=="both"){id}))+ #,size=1
    scale_colour_manual("",values = rainbow(if(colorBy=="trackID"){length(unique(UD_sf$individual.local.identifier))}else if(colorBy=="contourLevel"){length(unique(UD_sf$level))}else if(colorBy=="both"){length(unique(UD_sf$id))}))+
    coord_sf(
      xlim = c(ud_bbox["xmin"], ud_bbox["xmax"]),
      ylim = c(ud_bbox["ymin"], ud_bbox["ymax"]),
      crs=st_crs(UD_sf),expand = T)
  
  png(file=appArtifactPath(paste0("UD_ContourMap_color_",colorBy,"_contours_",paste0(cnts,collapse="_"),".png")),res=300,height=2000,width=2000) 
  print(osmap_clrby)
  dev.off()
  
  # one map per indiv in 1 pdf, incl. map of average
  UF_sf_L <- split(UD_sf,UD_sf$individual.local.identifier)
  
  pdf(appArtifactPath(paste0("UD_ContourMap_per_Indv","_contours_",paste0(cnts,collapse="_"),".pdf")))
  lapply(UF_sf_L, function(UDcontIndiv){
    # map for all individuals
    # Indv_datamv_df <- datamv_df[datamv_df$indv%in%unique(UDcontIndiv$individual.local.identifier),]
    Indv_data <- filter_track_data(data, .track_id = c(unique(UDcontIndiv$individual.local.identifier)))
    
    udI_bbox <- sf::st_bbox(UDcontIndiv)
    osmapInd <- ggplot() +
      ggspatial::annotation_map_tile(zoomin = as.numeric(myzoom), type=mymtype) +
      ggspatial::annotation_scale(aes(location="br")) +
      theme_linedraw() +
      geom_sf(data = mt_track_lines(Indv_data),color=alpha("black",0.25)) +
      geom_sf(data = Indv_data, color = alpha("black",0.25), size = 1)+
      annotation_spatial(data = UDcontIndiv, aes(color=id))+ #,size=1
      scale_colour_manual("",values = rainbow(length(unique(UDcontIndiv$id))))+
      coord_sf(
        xlim = c(udI_bbox["xmin"], udI_bbox["xmax"]),
        ylim = c(udI_bbox["ymin"], udI_bbox["ymax"]),
        crs=st_crs(UDcontIndiv),expand = T)
    
    print(osmapInd) 
  })
  dev.off()
  
  return(data)
}
