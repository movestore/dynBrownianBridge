library('move')
library('raster')
library('sp')
library('rgdal')
library('ggmap')
library('OpenStreetMap')

library("ggspatial")
# library("viridis")

rFunction <- function(data,raster_resol=10000,loc.err=30,conts=0.999,ext=20000, colorBy=c("trackID", "contourLevel", "both"), saveAsSHP=TRUE){
  Sys.setenv(tz="UTC")
  
  #indicate the area spanned by the data for the user
  ix1 <- which(coordinates(data)[,1]==min(coordinates(data)[,1],na.rm=TRUE))
  ix2 <- which(coordinates(data)[,1]==max(coordinates(data)[,1],na.rm=TRUE))
  ix3 <- which(coordinates(data)[,2]==min(coordinates(data)[,2],na.rm=TRUE))
  ix4 <- which(coordinates(data)[,2]==max(coordinates(data)[,2],na.rm=TRUE))
  
  londist <- round(pointDistance(coordinates(data)[c(ix1,ix2),],lonlat=TRUE)[2,1])
  latdist <- round(pointDistance(coordinates(data)[c(ix3,ix4),],lonlat=TRUE)[2,1])
  logger.info(paste("Your data set spans the maximum longitude distance:",londist,"m and maximum latitude distance:",latdist,"m. Please adapt your parameters accordingly."))
  
  # cnts <- as.numeric(trimws(strsplit(as.character(conts),",")[[1]])) #if more than one contour percentage given by user, this makes a vector our of the comma-separated string ==> this was only keeping the 1st contour, at leaast in R. In moveapps it seems to work for some reason....
  cnts <- as.numeric(unlist(lapply(strsplit(as.character(conts),","),trimws))) ## fixed?
  
  # need to project data on flat surface for BBMM
  data_t <- spTransform(data, center=TRUE) #aeqd in metre
  
  Ra <- raster(extent(data_t)+c(-ext,ext,-ext,ext), resolution=raster_resol, crs = crs(data_t) , vals=NULL) ## option to vary the amount the area gets enlarged, as the error "Lower x grid not large enough, consider extending the raster in that direction or enlarging the ext argument" is a pretty common error that the raster is not large enough in some direction
  data_resol <- median(unlist(timeLag(data,units="mins")),na.rm=TRUE)
  
  data_t_dBBMM <- brownian.bridge.dyn(data_t, raster = Ra,  window.size = 31, margin=11, time.step = data_resol/15, location.error = loc.err, verbose=F)
  
  # get UDs for all
  data_t_UD <- getVolumeUD(data_t_dBBMM) 
  
  # get UD size in Km2 per contour
  UD_size_L <- lapply(cnts, function(ctr){
    UDsel <- data_t_UD<=ctr 
    UDsizem2 <- cellStats(UDsel, 'sum')*raster_resol*raster_resol
    UDsizeKm2 <- UDsizem2/1000000
    df <- data.frame(track=names(data_t_UD), UD_size_Km2=UDsizeKm2, contour=ctr, row.names = NULL) # CHECK COLUMN NAMES
    return(df)
  })
  UD_size_df <- do.call("rbind",UD_size_L)
  write.csv(UD_size_df, row.names=F, file = paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"UD_size_per_contour.csv"))
  
  # get contours into a SLDF object
  UD_cont <- raster2contour(data_t_dBBMM, level=cnts)
  # plot(UD_cont, col=as.factor(UD_cont$individual.local.identifier)) 
  # plot(UD_cont, col=as.factor(UD_cont$level))
  
  # changing ID names of the SLDF as the default ones cannot be interpreted
  UD_cont <-  spChFIDs(UD_cont, as.character(paste0(UD_cont$individual.local.identifier,"_",UD_cont$level))) # CHECK WHAT HAPPENS IF trackId IS NOT THE SAME TO individual.local.identifyoer!!
  
  UD_cont_t <- spTransform(UD_cont,CRS("+proj=longlat"))
  # save contour as shp
  if(saveAsSHP){
    writeOGR(UD_cont_t,dsn=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/")),layer=paste0("UD:",cnts,collapse="_") ,driver="ESRI Shapefile",overwrite_layer=TRUE)
  }
  
  # prepare SLDF for ggplot
  ud_cont_fort <- ggplot2::fortify(UD_cont_t)
  ud_cont_fort$track <- unlist(lapply(strsplit(ud_cont_fort$id,"_"),function(x) {x[1]}))
  ud_cont_fort$contour <- unlist(lapply(strsplit(ud_cont_fort$id,"_"),function(x) {x[2]}))
  
  # map for all individuals
  data_df <- as.data.frame(data)
  map1 <- get_map(bbox(extent(UD_cont_t)*1.5))
  
  mapF <- ggmap(map1) +
    geom_path(data=data_df, aes(x=location.long, y=location.lat),alpha=0.2)+
    geom_point(data=data_df, aes(x=location.long, y=location.lat),alpha=0.1, shape=20)+
    ggspatial::geom_spatial_path(data = ud_cont_fort, aes(long,lat, group=group, color=if(colorBy=="trackID"){track}else if(colorBy=="contourLevel"){contour}else if(colorBy=="both"){id}),size=1)+ 
    scale_colour_manual("",values = rainbow(if(colorBy=="trackID"){length(unique(ud_cont_fort$track))}else if(colorBy=="contourLevel"){length(unique(ud_cont_fort$contour))}else if(colorBy=="both"){length(unique(ud_cont_fort$id))})) #+
  # scale_color_viridis("",option="turbo", discrete=T)#+
  # labs(x="",y="")+
  # theme(axis.text=element_blank(),axis.ticks=element_blank())
  
  png(file=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"UD_ContourMap_color:",colorBy,".png"),res=300,height=2000,width=2000) 
  print(mapF)
  dev.off()
  
  # on map per indiv in 1 pdf
  ud_cont_fort_L <- split(ud_cont_fort, ud_cont_fort$track) # CHECK IF THESE STILL MATCH WHEN trackID AND indiv.local.identif ARE DIFFERENT !!!
  data_df_L <- split(data_df,data_df$trackId)
  
  UD_cont_t_L <- move::split(UD_cont_t,UD_cont_t$individual.local.identifier)
  
  pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "UD_ContourMap_per_Indv.pdf")) 
  lapply(UD_cont_t_L, function(UDcontIndiv){
    Indv_ud_cont_fort <- ggplot2::fortify(UDcontIndiv)
    Indv_ud_cont_fort$track <- unlist(lapply(strsplit(Indv_ud_cont_fort$id,"_"),function(x) {x[1]}))
    Indv_ud_cont_fort$contour <- unlist(lapply(strsplit(Indv_ud_cont_fort$id,"_"),function(x) {x[2]}))
    
    # map for all individuals
    Indv_data_df <- data_df[data_df$trackId%in%unique(Indv_ud_cont_fort$track),]
    map1 <- get_map(bbox(extent(UDcontIndiv)*1.5))
    
    mapF <- ggmap(map1) +
      geom_path(data=Indv_data_df, aes(x=location.long, y=location.lat),alpha=0.2)+
      geom_point(data=Indv_data_df, aes(x=location.long, y=location.lat),alpha=0.1, shape=20)+
      ggspatial::geom_spatial_path(data = Indv_ud_cont_fort, aes(long,lat, group=group, color=id),size=1)+
      scale_colour_manual("",values = rainbow(length(unique(Indv_ud_cont_fort$id)))) #+
    # scale_color_viridis("",option="turbo", discrete=T)#+
    # labs(x="",y="")+
    # theme(axis.text=element_blank(),axis.ticks=element_blank())
    print(mapF) 
  })
  dev.off()
  
  return(data)
}
