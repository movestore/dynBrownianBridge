library('move')
library('raster')
library('sp')
library('rgdal')
library('ggmap')
library('OpenStreetMap')

rFunction <- function(data,raster_resol=10000,loc.err=30,conts=0.999,ext=20000)
{
  Sys.setenv(tz="UTC")

  #indicate the area spanned by the data for the user
  ix1 <- which(coordinates(data)[,1]==min(coordinates(data)[,1],na.rm=TRUE))
  ix2 <- which(coordinates(data)[,1]==max(coordinates(data)[,1],na.rm=TRUE))
  ix3 <- which(coordinates(data)[,2]==min(coordinates(data)[,2],na.rm=TRUE))
  ix4 <- which(coordinates(data)[,2]==max(coordinates(data)[,2],na.rm=TRUE))
  
  londist <- round(pointDistance(coordinates(data)[c(ix1,ix2),],lonlat=TRUE)[2,1])
  latdist <- round(pointDistance(coordinates(data)[c(ix3,ix4),],lonlat=TRUE)[2,1])
  logger.info(paste("Your data set spans the maximum longitude distance:",londist,"m and maximum latitude distance:",latdist,"m. Please adapt your parameters accordingly."))
  
  cnts <- as.numeric(trimws(strsplit(as.character(conts),",")[[1]])) #if more than one contour percentage given by user, this makes a vector our of the comma-separated string
  
  # need to project data on flat surface for BBMM
  data_t <- spTransform(data, center=TRUE) #aeqd in metre
  
  Ra <- raster(extent(data_t)+c(-ext,ext,-ext,ext), resolution=raster_resol, crs = crs(data_t) , vals=NULL) ## option to vary the amount the area gets enlarged, as the error "Lower x grid not large enough, consider extending the raster in that direction or enlarging the ext argument" is a pretty common error that the raster is not large enough in some direction
  data_resol <- median(unlist(timeLag(data,units="mins")),na.rm=TRUE)
  
  data_t_dBBMM <- brownian.bridge.dyn(data_t, raster = Ra,  window.size = 31, margin=11, time.step = data_resol/15, location.error = loc.err)
  
  # plan: make multiple page pdf of UDs and UDvolumes with contours, one per ID and one for all

  # combine all individual UDs into one
  data_t_dBBMM_split <- move::split(data_t_dBBMM)
  id_areas <- as.numeric(length(data_t_dBBMM_split))
  
  data_dBBMM_all <- data_t_dBBMM_split[[1]]
  id_areas[1] <- (sum(values(getVolumeUD(data_t_dBBMM_split[[1]]))))
  for (i in seq(along=data_t_dBBMM_split)[-1])
  {
    data_dBBMM_all <- data_dBBMM_all + data_t_dBBMM_split[[i]]
    id_areas[i] <- (sum(values(getVolumeUD(data_t_dBBMM_split[[i]]))))
  }
  
  data_dBBMM_avg <- data_dBBMM_all/sum(values(data_dBBMM_all))
  
  # sum of all pixels is 1, change class to be able to use getVolumeUD
  data_dBBMM_avg_UD <- as(data_dBBMM_avg,".UD") # now raster is of class .UD
  data_dBBMM_avg_UDVol <- getVolumeUD(data_dBBMM_avg_UD)
  
  #plot(data_dBBMM_avg_UD)
  #contour(data_dBBMM_avg_UDVol,levels=c(0.5,0.95,0.999999))
  #sum(values(data_dBBMM_avg_UDVol)) #area in km^2
  
  data_tt <- spTransform(data_t, CRSobj = "+proj=longlat +datum=WGS84")
  
  data_dBBMM_avg_UDVol_t <- projectRaster(data_dBBMM_avg_UDVol,crs="+proj=longlat +datum=WGS84")
  xyz <- rasterToPoints(data_dBBMM_avg_UDVol_t)
  xyz_df <- data.frame(xyz)
  names(xyz_df)[3] <- "layer"
  
  map1 <- get_map(bbox(extent(data_dBBMM_avg_UDVol_t)))
  
  mapF <- ggmap(map1) +
    #geom_point(data=as.data.frame(data_tt),aes(x=location_long,y=location_lat,group=trackId),colour="red") +
    geom_contour_filled(data=xyz_df,aes(x,y,z=layer),breaks=cnts,alpha=0.8) + #,show.legend=FALSE
    geom_contour(data=xyz_df,aes(x,y,z=layer),breaks=c(0.999),colour="red")
  
  png(file=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"dynBBMM_ContourMap.png"),res=300,height=2000,width=2000)
  print(mapF)
  dev.off()
  
  #maps for single individuals
  for (i in seq(along=data_t_dBBMM_split))
  {
    data_t_dBBMM_iUDVol <- getVolumeUD(as(data_t_dBBMM_split[[i]],".UD"))
    xyz_df_i <- data.frame(rasterToPoints(projectRaster(data_t_dBBMM_iUDVol,crs="+proj=longlat +datum=WGS84")))
    names(xyz_df_i)[3] <- "layer"
    
    map_i <- ggmap(map1) +
      #geom_point(data=as.data.frame(data_tt),aes(x=location_long,y=location_lat,group=trackId),colour="red") +
      geom_contour_filled(data=xyz_df_i,aes(x,y,z=layer),breaks=cnts,alpha=0.8) + #,show.legend=FALSE
      geom_contour(data=xyz_df_i,aes(x,y,z=layer),breaks=c(0.999),colour="red")
    
    png(file=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"dynBBMM_ContourMap_",names(data_t_dBBMM_split[[i]]),".png"),res=300,height=2000,width=2000)
    print(map_i)
    dev.off()
  }
  
  result <- data
  return(result)
}

  
  
  
  
  
  
  
  
  
  
