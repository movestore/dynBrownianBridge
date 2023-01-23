# Utilisation Distribution (Dynamic Brownian Bridge)"
MoveApps

Github repository: *github.com/movestore/dynBrownianBridge*

## Description
Estimates a utilisation distribution of your tracked animals using the dynamic Brownian Bridge Movement Model. Different maps with contours are generated. Tip: Consider subsampling your data (e.g. use the app "Thin Data by Time") at first runs and if your data are collected at a very high frequency.

## Documentation
Based on a user-defined grid size and extent, a raster is defined on top of the area of the input data tracks. Using the R-function brownian.bridge.dyn() and getVolumeUD(), this App calculates the utilisation distributions (UD; =occurance distribution) per individual track. An average UD combining the UDs of all tracks is calculated. Please beware that the average UD is only useful if resolutions of the different tracks are comparable. The user-specified contours are displayed for the average UD, per individual in separate maps and for all individuals in one map. A table with the UD sizes in Km^2 for the average and per individual and specified contours is returned. The contours can also be downloaded as shapefiles. 

Some parameters of the function brownian.bridge.dyn() are fixed, as they do not influence the results strongly (window.size=31, margin=11). The time step is used as `median time lag/15` (with a minimum of 1 secs) to prevent very long running times. The location error has to be provided by the user (see below).

Often, tracking data can contain large time gaps with missing data. During this period of time, there is higher uncertainty where the animal could have been, increasing drastically the area that the function needs to calculate the UD (because the animal could have been virtually anywhere). To prevent this from happening, the user can provide a maximum time lag (in hours) to be included in the calculations, i.e. for segments with time lags above the provided value no estimation will be calculated. If very large time gaps are included, the result might just be one big "blob".

Consider subsampling your data at first runs (e.g. use the app "Thin Data by Time"). High resolution data lead to rather long run times (for many species a time lag of 10-15mins is high enough).

This App is strongly based on the dynamic Brownian Bridge model developed in this manuscript: Kranstauber, B., Kays, R., LaPoint, S. D., Wikelski, M., & Safi, K. (2012). A dynamic Brownian bridge movement model to estimate utilization distributions for heterogeneous animal movement. Journal of Animal Ecology, 81(4), 738-746.

### Input data
moveStack in Movebank format

### Output data
moveStack in Movebank format

### Artefacts
`UD_size_per_contour.csv`: table containing the UD size in Km^2 per contour and individual

`UD_contour_xx_xx_xx`: the shapefile of the contuors of all individuals

`UD_ContourMap_color_xxxx_contours:xxx_xxx_xxx.png`: OpenStreetMap of your tracking area with the modelled utilisation probabilities as requested by the variable `conts`. All individual UDs are superimposed on one map for comparison.

`UD_ContourMap_per_Indv_contours_xxx_xxx_xx.pdf`: OpenStreetMap of your tracking area with the modelled utilisation probabilities for each individual track (`ID`, one map per track, and one additional average UD map) as requested by the variable `conts`.

`Avg_UD_ContourMap_contours_xxx_xxx_xxx.png`: OpenStreetMap of your tracks with average modelled utilisation probability contour areas as requrest by the variable `conts`.

### Parameters 
`Spatial Resolution for the Utilisation/Occurance Distribution Raster [raster_resol]`: Resolution/grid size of the raster in which to estimate the utilisation distribution. Unit metre. Defaults to 10000 m = 10 km. For each data set the adequate grid size is different, we suggest to have a look at the message in the logs of the App referring to the span of the used data, to make a more informed choice of this parameter. Also see `Null or error handling` below.

`Estimated location error [loc.err]`: Location error that shall be used for the dynamic BBMM estimations. Usually related to the max. accepted inaccuracy of your tracking locations. Unit metre. Defaults to 30 m.  Also see `Null or error handling` below.

`Contour percentages [conts]`: One or more contour percentages that you want calculated and plotted on the map. For multiple values please separate by comma. Needs to be between 0 and 1.

`Map extent [ext]`: Additive value for enlarging the map area for the dynamic BBMM calculations into all four directions, as it is necessary for edge effects. Unit metre. Defaults to 20000 m = 20 km. Also see `Null or error handling` below.

`Maximum time lag in hours [ignoreTimeHrs]`: maximum time lag in hours to be included in the calculations, for segments with larger time lags no estimation will be calculated . Default is 24h. Also see `Null or error handling` below.

`Diferenciation by color in map with all individuals [colorBy]`: The map displaying the UDs of all individuals can be colored by: `trackID`, `contour level` or  `trackID and contour level`. The defalt option is by trackID.

`Save as Shapefile [saveAsSHP]`: the specified contours of the UDs can be saved as shapefiles. This option can also be unchecked.

### Null or error handling:
**`Spatial Resolution for the Utilisation/Occurance Distribution Raster [raster_resol]`:**: The resolution of the model outcome should be sufficiently small for making out your areas of interest, but should also not be too small, as runtime of the App then increases strongly.

**`Estimated location error [loc.err]`**: This value strongly influences the width of the utilisation areas. If it is too small, the areas appear too restricted. If it is too large, the areas are very wide. Negative values are not permitted.

**`Contour percentages [conts]`**: If this value is not restricted between 0 and 1, you will get errors. Please do not use too many contours, as the map might get difficult to interpret then.

**`Map extent [ext]`**: Select this value reasonably, accounting for the tracking area of your data. It will add to the area evenly on all four directions. Depending on the size of your study, you might not see you tracks if this value is too large. However, if this value is too small, an error will occur that your extent is not large enough for the calculations (this error is very common, simply increase this value). If you get the error: "no contour lines", this value is to large.

**`Maximum time lag in hours [ignoreTimeHrs]`**: A time lag that is at least double or triple of the scheduled fix rate is reasonable. It allows for some missed fixes, but excludes larger periods with missed fixes, turned of tag, malfunctioning of the tag, etc. If very large time gaps are included, the result might just be one big "blob".

**Data:** The full input data set is returned for further use in a next App and cannot be empty.

