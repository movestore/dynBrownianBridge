library('move')
library('raster')
library('sp')
library('rgdal')
library('ggmap') #needs installation from github: stadiamaps/ggmap
library('OpenStreetMap')
library("ggspatial")
library("plyr")
# library("viridis")

# data <- readRDS("./data/raw/fishersmv.rds")
# plot(data)
# raster_resol=100
# loc.err=30
# conts=c("0.5","0.75","0.99")
# ext=5000
# ignoreTimeHrs=6
# colorBy= "both" #c("trackID", "contourLevel", "both")
# saveAsSHP=F
# stamen_key="7d59ce66-d885-4899-8888-b3bde8bd8a6b"

rFunction <- function(data,raster_resol=10000,loc.err=30,conts=0.999,ext=20000,ignoreTimeHrs=NULL, colorBy=c("trackID", "contourLevel", "both"), saveAsSHP=TRUE,stamen_key=NULL){
  Sys.setenv(tz="UTC")

  #indicate the area spanned by the data for the user
  ix1 <- which(coordinates(data)[,1]==min(coordinates(data)[,1],na.rm=TRUE))
  ix2 <- which(coordinates(data)[,1]==max(coordinates(data)[,1],na.rm=TRUE))
  ix3 <- which(coordinates(data)[,2]==min(coordinates(data)[,2],na.rm=TRUE))
  ix4 <- which(coordinates(data)[,2]==max(coordinates(data)[,2],na.rm=TRUE))
  
  londist <- round(pointDistance(coordinates(data)[c(ix1,ix2),],lonlat=TRUE)[2,1])
  latdist <- round(pointDistance(coordinates(data)[c(ix3,ix4),],lonlat=TRUE)[2,1])
  logger.info(paste("Your data set spans the maximum longitude distance:",londist,"m and maximum latitude distance:",latdist,"m. Please adapt your parameters accordingly."))
  
  logger.info(paste("Your data set has a min time lag:",round(min(unlist(timeLag(data,"hours"))),4),"hours,", "a median time lag:",round(median(unlist(timeLag(data,"hours"))),4),"hours,","and a max time lag:",round(max(unlist(timeLag(data,"hours"))),4),"hours.","Choose your timelag to ignore accordingly."))
  
  # cnts <- as.numeric(trimws(strsplit(as.character(conts),",")[[1]])) #if more than one contour percentage given by user, this makes a vector our of the comma-separated string ==> this was only keeping the 1st contour, at least in R. In moveapps it seems to work for some reason....
  cnts <- as.numeric(unlist(lapply(strsplit(as.character(conts),","),trimws))) ## fixed?
  # if(0.999%in%cnts){cnts}else{cnts <- c(cnts,0.999)} # NOT SURE IF TO EXCLUDE THIS. IF SOMEONE IS JUST INTEREST IN THE 0.25, AND THE 0.99 IS ALWAYS THERE (ALSO ZOOMING ALWAYS OUT TO THE ENTIRE TRACK) COULD BE ANNOYING....
  if(0%in%cnts){ 
    cnts <- cnts[!cnts%in%c(0)]
    logger.warn("Countour of 0% cannot be calculated, it has been excluded") ## apparently this is not clear to everyone...
  }else{cnts <- cnts}
  
  # need to project data on flat surface for BBMM
  data_t <- spTransform(data, center=TRUE) #aeqd in metre
  
  Ra <- raster(extent(data_t)+c(-ext,ext,-ext,ext), resolution=raster_resol, crs = crs(data_t) , vals=NULL) ## option to vary the amount the area gets enlarged, as the error "Lower x grid not large enough, consider extending the raster in that direction or enlarging the ext argument" is a pretty common error that the raster is not large enough in some direction
  data_resol <- median(unlist(timeLag(data,units="mins")),na.rm=TRUE) 
  if(data_resol<=0.25){timeStep <- 0.25/15}else{timeStep <- data_resol/15} ## if timelag is less then 15secs, make time.step==to 1sec chuncks, else take the median timelag. CHECK WITH BART IF TO GO HIGHER THAN 15secs AND 1secs CHUNCKS!
  
  # calculate first the variance to be able to exclude larger timegaps that increase uncertanty
  data_t_dBBvar <- brownian.motion.variance.dyn(data_t, location.error=loc.err, margin=11, window.size=31)
  if(!is.null(ignoreTimeHrs)){
  data_t_dBBvar@interest[unlist(timeLag(data_t,"hours"))>ignoreTimeHrs] <- FALSE ## excluding segments longer than "ignoreTimeHrs" hours from the dbbmm
  }
  # calculate dBB of the variance
  data_t_dBBMM <- brownian.bridge.dyn(data_t_dBBvar, raster = Ra,  window.size = 31, margin=11, time.step = timeStep, location.error = rep(loc.err,length(data_t_dBBvar)), verbose=F)
  
  # get UDs for all
  data_t_UD <- getVolumeUD(data_t_dBBMM) 
  
  # AK: calculate average UD for all tracks together ("population average")
  data_t_UD_av <- stackApply(data_t_UD,indices=rep(1,dim(data_t_UD)[3]),fun="mean") # this seems to make sense, and also table of UD sizes make sense
  # plot(data_t_UD_av); contour(data_t_UD_av, level=0.99, add=T)
  data_t_UD_pav <- stack(data_t_UD,data_t_UD_av) #add the average raster layer to the indiv UDs, then can run this through your lapply for the UD sizes..
  names(data_t_UD_pav)[dim(data_t_UD)[3]+1] <- "average"
  
  ## get min countur size for avg UD
  mV <- minValue(data_t_UD_av) ## if the cnts contain values smaller than the min value of the avg raster it gives the error: "rasterToContour(data_t_UD_av, levels = ctr) : no contour lines"
  rmV <- plyr::round_any((mV+0.05), accuracy = 0.01, f = ceiling)
  if(any(cnts<mV | min(cnts)==mV)){
    logger.warn(paste0("Smallest UD contour for the average UD is: ", rmV,". All smaller UD contours selected in the settings can not be displayed on the average UD map. The smallest possible (",rmV ,") plus all larger ones will be displayed. The countur of ",rmV," will be added to the Table of UD sizes"))
    cntsAvg <- c(cnts[cnts>=mV], rmV) # adding the minimum available
    if(min(cnts)==mV){cntsAvg <- cntsAvg[!cntsAvg%in%min(cnts)]} # this contour gives error in ~L102
    cntsAvg <- cntsAvg[order(cntsAvg)]
    cntsAvg <- cntsAvg[!duplicated(cntsAvg)]
  }else{cntsAvg <- cnts}
  
  # get UD size in Km2 per contour
  # AK: adapted here data_t_UD to data_t_UD_pav, so that also the contour sizes of the average UD is in
  cntsSize <- c(cnts,rmV) ## adding the smallest possible of the avg UD, better have more than less, right?
  cntsSize <- cntsSize[order(cntsSize)] 
  UD_size_L <- lapply(cntsSize, function(ctr){
    UDsel <- data_t_UD_pav<=ctr 
    UDsizem2 <- cellStats(UDsel, 'sum')*raster_resol*raster_resol
    UDsizeKm2 <- UDsizem2/1000000
    df <- data.frame(trackID=names(data_t_UD_pav), UD_size_Km2=UDsizeKm2, contour=ctr, row.names = NULL) # add individualID and TrackID in the future?
    return(df)
  })
  UD_size_df <- do.call("rbind",UD_size_L) #what does this give? the sizes of all contours for each track? YES, each row is a track, a contour level, and its UD size in Km2. each combi track-contour gets its own row and ud size value
  write.csv(UD_size_df, row.names=F, file = paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"UD_size_per_contour.csv"))
  
  # get contours into a SLDF object
  UD_sldf <- raster2contour(data_t_dBBMM, level=cnts)
  
  # get contours into a SLDF object of avg layer
   avg_sldf_L <- lapply(cntsAvg, function(ctr){
     # print(ctr)
    rasterToContour(data_t_UD_av, levels=ctr)
  })
  avg_sldf <- do.call("rbind",avg_sldf_L)
  avg_sldf$individual.local.identifier <- "average"
  # joining both
  UD_sldf <- rbind(UD_sldf,avg_sldf)
  
  # changing ID names of the SLDF as the default ones cannot be interpreted
  UD_sldf <-  spChFIDs(UD_sldf, as.character(paste0(UD_sldf$individual.local.identifier,"_",UD_sldf$level))) 
  
  UD_sldf_t <- spTransform(UD_sldf,CRS("+proj=longlat"))
  
  # save contour as shp
  if(saveAsSHP){writeOGR(UD_sldf_t, dsn=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/")), layer=paste0("UD_contour:",paste0(cnts,collapse="_")), driver="ESRI Shapefile", overwrite_layer=TRUE)}
  
  # prepare SLDF for ggplot
  UD_sldf_fort <- ggplot2::fortify(UD_sldf_t[!UD_sldf_t$individual.local.identifier=="average",]) #for stack of individual plots leave out average
  UD_sldf_fort$track <- unlist(lapply(strsplit(UD_sldf_fort$id,"_"),function(x) {paste0(x[1:length(x)-1], collapse="_")}))
  UD_sldf_fort$contour <- unlist(lapply(strsplit(UD_sldf_fort$id,"_"),function(x) {x[length(x)]}))
  
  # map for all individuals
  data_df <- data.frame(coordinates(data))
  colnames(data_df) <- c("long","lat")
  data_df$indv <- trackId(data)
  
  if (is.null(stamen_key)) {logger.info("You have not entered a stadia API key. Until MoveApps provides its OSM mirror, this is required. Register with stamen until then, it is free. Go to: https://stadiamaps.com/stamen/onboarding/create-account")} else {
    register_stadiamaps(stamen_key)
    
    logger.info("Your stadia API key is registered.")
    map1 <- get_map(bbox(extent(UD_sldf_t)*1.5),maptype="stamen_terrain", source="stadia")
  
  mapF <- ggmap(map1) +
    geom_path(data=data_df, aes(x=long, y=lat, group=indv),alpha=0.2)+
    geom_point(data=data_df, aes(x=long, y=lat, group=indv),alpha=0.1, shape=20)+
    ggspatial::geom_spatial_path(data = UD_sldf_fort, aes(long,lat, group=group, color=if(colorBy=="trackID"){track}else if(colorBy=="contourLevel"){contour}else if(colorBy=="both"){id}))+ #,size=1
    scale_colour_manual("",values = rainbow(if(colorBy=="trackID"){length(unique(UD_sldf_fort$track))}else if(colorBy=="contourLevel"){length(unique(UD_sldf_fort$contour))}else if(colorBy=="both"){length(unique(UD_sldf_fort$id))})) #+
  # scale_color_viridis("",option="turbo", discrete=T)#+
  # labs(x="",y="")+
  # theme(axis.text=element_blank(),axis.ticks=element_blank())

  png(file=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"UD_ContourMap_color_",colorBy,"_contours_",paste0(cnts,collapse="_"),".png"),res=300,height=2000,width=2000) 
  print(mapF)
  dev.off()
  
  # one map per indiv in 1 pdf, incl. map of average
  UD_sldf_t_L <- move::split(UD_sldf_t,UD_sldf_t$individual.local.identifier)
  
  pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "UD_ContourMap_per_Indv","_contours_",paste0(cnts,collapse="_"),".pdf")) 
  lapply(UD_sldf_t_L, function(UDcontIndiv){
    Indv_UD_sldf_fort <- ggplot2::fortify(UDcontIndiv)
    Indv_UD_sldf_fort$track <- unlist(lapply(strsplit(Indv_UD_sldf_fort$id,"_"),function(x) {x[1]}))
    Indv_UD_sldf_fort$contour <- unlist(lapply(strsplit(Indv_UD_sldf_fort$id,"_"),function(x) {x[2]}))
    
    # map for all individuals
    Indv_data_df <- data_df[data_df$indv%in%unique(Indv_UD_sldf_fort$track),]
    map1 <- get_map(bbox(extent(UD_sldf_t)*1.5),maptype="stamen_terrain", source="stadia")
    
    mapF <- ggmap(map1) +
      geom_path(data=Indv_data_df, aes(x=long, y=lat),alpha=0.2)+
      geom_point(data=Indv_data_df, aes(x=long, y=lat),alpha=0.1, shape=20)+
      ggspatial::geom_spatial_path(data = Indv_UD_sldf_fort, aes(long,lat, group=group, color=id))+ #,size=1
      scale_colour_manual("",values = rainbow(length(unique(Indv_UD_sldf_fort$id)))) #+
    # scale_color_viridis("",option="turbo", discrete=T)#+
    # labs(x="",y="")+
    # theme(axis.text=element_blank(),axis.ticks=element_blank())
    print(mapF) 
  })
  dev.off()
  
  # AK: map with average contours

  # prepare SLDF for ggplot
  UD_sldf_fort_avg <- ggplot2::fortify(UD_sldf_t[UD_sldf_t$individual.local.identifier=="average",])
  
  # map for all individuals
  data_df <- data.frame(coordinates(data))
  colnames(data_df) <- c("long","lat")
  data_df$indv <- trackId(data)
  map1avg <- get_map(bbox(extent(UD_sldf_t)*1.5),maptype="stamen_terrain", source="stadia")
  
  ## OPTION 1: all levels in one plot 
  mapFavg <- ggmap(map1avg) +
    geom_path(data=data_df, aes(x=long, y=lat, group=indv),alpha=0.2)+
    geom_point(data=data_df, aes(x=long, y=lat, group=indv),alpha=0.1, shape=20)+
    ggspatial::geom_spatial_path(data = UD_sldf_fort_avg, aes(long,lat, group=group, color=id))+ #,size=1
    scale_colour_manual("",values = rainbow(length(unique(UD_sldf_fort$id))))

  png(file=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"Avg_UD_ContourMap","_contours_",paste0(cnts,collapse="_"),".png"),res=300,height=2000,width=2000) 
  print(mapFavg)
  dev.off()
  ## option1

  ## OPTION 2: each levels in a separate plot 
  #UD_sldf_fort_L <- split(UD_sldf_fort_avg, UD_sldf_fort_avg$id)
  #pdf(paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"), "Avg_UD_ContourMap2","_contours_",paste0(cnts,collapse="_"),".pdf")) 
  #lapply(UD_sldf_fort_L, function(avgCont){
  
  #  mapFavg <- ggmap(map1avg) +
  #    geom_path(data=data_df, aes(x=long, y=lat, group=indv),alpha=0.2)+
  #    geom_point(data=data_df, aes(x=long, y=lat, group=indv),alpha=0.1, shape=20)+
  #    ggspatial::geom_spatial_path(data = avgCont, aes(long,lat, group=group, color=id))+ #,size=1
  #    scale_colour_manual("",values = rainbow(length(unique(UD_sldf_fort$id))))
  #  print(mapFavg) 
  #})
  #dev.off()
  ## option2
}
  return(data)
}
