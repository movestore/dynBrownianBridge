library('move')
library('raster')
library('sp')
library('rgdal')
library('ggmap')
library('OpenStreetMap')

rFunction <- function(data,raster_resol=1000,loc.err=30,conts=0.999,ext=1.5)
{
  Sys.setenv(tz="UTC")

  cnts <- as.numeric(trimws(strsplit(as.character(conts),",")[[1]])) #if more than one contour percentage given by user, this makes a vector our of the comma-separated string
  
  # need to project data on flat surface for BBMM
  data_t <- spTransform(data, center=TRUE)
  
  Ra <- raster(extent(data_t)*ext, resolution=raster_resol, crs = crs(data_t) , vals=NULL) ## option to vary the amount the area gets enlarged, as the error "Lower x grid not large enough, consider extending the raster in that direction or enlarging the ext argument" is a pretty common error that the raster is not large enough in some direction
  data_resol <- median(unlist(timeLag(data,units="mins")),na.rm=TRUE)
  
  data_t_dBBMM <- brownian.bridge.dyn(data_t, raster = Ra,  window.size = 31, margin=11, time.step = data_resol/15, location.error = loc.err)
  
  # plan: make multiple page pdf of UDs and UDvolumes with contours, one per ID and one for all

  # combine all individual UDs into one
  data_t_dBBMM_split <- move::split(data_t_dBBMM)
  id_areas <- numeric(length(data_t_dBBMM_split))
  
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
  
  map1 <- get_map(bbox(extent(data_tt)+c(-ext,ext,-ext,ext)))
  
  mapF <- ggmap(map1) +
    #geom_point(data=as.data.frame(data_tt),aes(x=location_long,y=location_lat,group=trackId),colour="red") +
    geom_contour_filled(data=xyz_df,aes(x,y,z=layer),breaks=cnts,alpha=0.8) + #,show.legend=FALSE
    geom_contour(data=xyz_df,aes(x,y,z=layer),breaks=c(0.999),colour="red")
  
  png(file=paste0(Sys.getenv(x = "APP_ARTIFACTS_DIR", "/tmp/"),"dynBBMM_ContourMap.png"),res=300,height=2000,width=2000)
  print(mapF)
  dev.off()
  
  result <- data
  return(result)
}

  
  
  
  
  
  
  
  
  
  
