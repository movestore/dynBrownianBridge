# Dynamic Brownian Bridge
MoveApps

Github repository: *github.com/movestore/dynBrownianBridge*

## Description
Estimates a utilisation distribution of your tracked animals using the dynamic Brownian Bridge Movement Model. A map with (a) contour(s) is generated. Tip: Consider subsampling your data at first runs.

## Documentation
Based on a user-defined grid size and extent, a raster is defined on top of the area of the input data tracks. Using the R-function brownian.bridge.dyn(), this App calculates the utilisation distributions (UD; =occurance distribution) of the individual tracks in this area that are then (a) analysed separaterly as UD Volumes by individual and (b) combined as UD Volumes across all tracks. These summed values represent the probabilities with which a random animal of the data set can be found in a the specific grid cell in the time frame. With user-specified contour percentages, minimum areas of these probabilities are visualised (by individual and of the combined data set), a red outline of the 0.999 contour is added.

Some parameters of the funtion brownian.bridge.dyn() are fixed, as they do not influence the results strongly (window.size=31, margin=11). The time step is used as `data_resol/15` and the location error has to be provided by the user (see below).

Consider subsampling your data at first runs. High resolution data lead to rather long run times.

This App is strongly based on the dynamic Brownian Bridge model developed in this manuscript: Kranstauber, B., Kays, R., LaPoint, S. D., Wikelski, M., & Safi, K. (2012). A dynamic Brownian bridge movement model to estimate utilization distributions for heterogeneous animal movement. Journal of Animal Ecology, 81(4), 738-746.

### Input data
moveStack in Movebank format

### Output data
moveStack in Movebank format

### Artefacts
`dynBBMM_ContourMap.png`: OpenStreetMap of your tracking area with the modelled utilisation probabilities as requested by the variable `conts`. A red outline of the 0.999 contour is added.

`dynBBMM_ContourMap_ID.png`: OpenStreetMap of your tracking area with the modelled utilisation probabilities for each individual track (`ID`, one map per track) as requested by the variable `conts`. A red outline of the 0.999 contour is added.

### Parameters 
`raster_resol`: Resolution/grid size of the raster in which to estimate the utilisation distribution. Unit metre. Defaults to 10000 m = 10 km.

`loc.err`: Location error that shall be used for the dynamic BBMM estimations. Usually related to the max. accepted inaccuracy of your tracking locations. Unit metre. Defaults to 30 m.

`conts`: One or more contour percentages that you want calculated and plotted on the map. For multiple values please separate by comma. Needs to be between 0 and 1.

`ext`: Additive value for enlarging the map area for the dynamic BBMM calculations into all four directiony evenly, as is necessary for edge effects. This value needs to be larger than data extent area. Unit metre. Defaults to 20000 m = 20 km.

### Null or error handling:
**`raster_resol`**: The resolution of the model outcome should be sufficiently small for making out your areas of interest, but should also not be too small, as runtime of the App then increases strongly.

**`loc.err`**: This value strongly influences the width of the utilisation areas. If it is too small, the areas appear too restricted. If it is too large, the areas are very wide. Negative values are not permitted.

**`conts`**: If this value is not restricted between 0 and 1, you will get errors. Please do not use too many contours, as the map might get difficult to interpret then.

**`ext`**: Select this value reasonably, accounting for the tracking area of your data. It will add to the area evenly on all four directions. Depending on the size of your study, you might not see you tracks if this value is too large. However, if this value is too small, an error will occur that your extent is not large enough for the calcualtions (this error is very common, simply increase this value).

**Data:** The full input data set is returned for further use in a next App and cannot be empty.

