# Utilisation Distribution (Dynamic Brownian Bridge)
MoveApps

Github repository: *github.com/movestore/dynBrownianBridge*

## Description
Estimates a utilisation distribution (UD) of your tracked animals or track segments using the dynamic Brownian Bridge Movement Model. Results include a table of UD sized per contours, as maps indicating the probability of space use for each track and for the entire dataset and an optional shapefile. Tip: Consider subsampling your data (e.g., using the app "Thin Data by Time") at first and if your data are collected at a very high frequency.

## Documentation
Based on a user-defined grid size and extent, a raster is defined on top of the area of the input data tracks. Using the R-function brownian.bridge.dyn() and getVolumeUD(), this App calculates the utilisation distributions (UD, i.e., occurance distribution) per track, as well as an average UD combining the UDs of all tracks, based on user-specified contours representing the probability of space use. These contours are displayed for the average UD, for all tracks in one map and per track in separate maps, and as a table with the UD sizes in km^2 per specified contours per track and for the average UD. The contours can also be downloaded as a shapefile. This App is strongly based on the dynamic Brownian Bridge model implemented in the [move](https://cran.r-project.org/web/packages/move/index.html) package and developed in Kranstauber et al. (2012): Kranstauber B, Kays R, LaPoint SD, Wikelski M, Safi K. 2012. A dynamic Brownian bridge movement model to estimate utilization distributions for heterogeneous animal movement. Journal of Animal Ecology. 81(4):738-746. [https://doi.org/10.1111/j.1365-2656.2012.01955.x](https://doi.org/10.1111/j.1365-2656.2012.01955.x)

Please beware that

* Calculations are performed on "TrackID" in the dataset, which can indicate individual animals, or track segments, depending on the results of previous Apps in the workflow. If individual's tracks have been segmented, the Track IDs will be named as the animal ID with a number added to the end.
* The average UD is only useful if resolutions and duration of the different tracks are comparable. 
* It may occur that for the average UD not all the user-specified contours can be displayed; in this case the smallest possible value will be displayed.

Some parameters of the function brownian.bridge.dyn() are fixed, as they do not influence the results strongly (window.size = 31, margin = 11). The time step used is `median time lag/15` (with a minimum of 1 sec) to prevent very long running times. The estimated location error is provided by the user (see below).

Often, tracking data can contain large time gaps with missing data. During this period of time, there is higher uncertainty where an animal could have been, drastically increasing the area that the function needs to calculate the UD (because the animal could have been virtually anywhere). To prevent this from happening, the user can provide a `maximum time lag (in hours)` to be included in the calculations. If provided, no estimation will be calculated for segments exceeding this time lag. A time lag that is at least double or triple of the scheduled fix rate is reasonable. This allows for some missed fixes, but excludes larger periods with missed fixes, turned of tag, malfunctioning of the tag, etc. If very large time gaps are included, the result might just be one big "blob". See the message in the logs of the App (after the 1st run) referring to the time lag of the data. The median time lag will most probably reflect the intended scheduled fix rate.

Consider subsampling your data for the first run (e.g., using the app "Thin Data by Time"). High-resolution data lead to rather long run times (for many species a time lag of 10-15 mins is high enough).

The settings of this App are very dependent on the input data. While the App settings will not change the biological significance of results, they affect whether the calculations can be performed. Often it takes a bit of "playing around" to find the optimal settings, or even to just get the App to run without errors. The `raster resolution` and `map extent increase` are the settings that have to be often fined tuned:

  - The `map extent increase` is needed for the function to have "space" to do its calculations, that is, to include space beyond the outer boundaries of the cloud of locations to calculate the probabilities, as there is also some probability that an animal occurred beyond the extent of the locations. If the value is set too large or too small, an error will occur (see Section [Most common errors](#most-common-errors)).
  
  - The `raster resolution` will provide the level of detail at which the results are provided. Fine raster resolutions (smaller raster resolution/pixel size, e.g., 100 m vs 1 km) will provide specially more detail about where the animal spent more or less time. The smaller the pixel size, the longer the calculation will take; the larger the pixel size, the coarser the results (the contour lines will display "steps"); and if the size is too large, an error will occur (see Section [Most common errors](#most-common-errors)).

### Input data
moveStack in Movebank format

### Output data
moveStack in Movebank format

### Artefacts
`UD_size_per_contour.csv`: table containing the UD size in km^2 per contour, for each track and as an average 

`UD_contour_xx_xx_xx`: the shapefile of the contours of all tracks

`UD_ContourMap_color_xxxx_contours:xxx_xxx_xxx.png`: OpenStreetMap of your tracking area with the modelled utilisation probabilities as requested by the variable `conts`. All UDs are superimposed on one map for comparison.

`UD_ContourMap_per_Track_contours_xxx_xxx_xx.pdf`: OpenStreetMap of your tracking area with the modelled utilisation probabilities for each track (`ID`, one map per track, and one additional average UD map) as requested by the variable `conts`.

`Avg_UD_ContourMap_contours_xxx_xxx_xxx.png`: OpenStreetMap of your tracks with average modelled utilisation probability contour areas as request by the variable `conts`.

### Parameters
**Spatial resolution for the UD raster (`raster_resol`):** Resolution/grid size of the raster on which to estimate the utilisation distribution. Unit metre. Defaults to 10000 m = 10 km. The adequate grid size is different for each dataset; we suggest having a look at the message in the logs of the App referring to the span of the used data, to make a more informed choice of this parameter. Also see `Null or error handling` below.

**Estimated location error (`loc.err`):** Location error that will be used for the dynamic BBMM estimations. This should typically indicate the maximum estimated or acceptable inaccuracy of your tracking locations. Unit metre. Defaults to 30 m.  Also see `Null or error handling` below.

**Contour percentages (`conts`):** One or more contour percentages that you want calculated and plotted on the map. For multiple values please separate by comma. Needs to be between 0 and 1.

**Map extent increase (`ext`):** Additive value for enlarging the map area beyond the outer boundaries of the locations. This value will be added evenly on all four directions and is needed for calculation of the utilization probabilities. Unit metre. Defaults to 20000 m = 20 km. The adequate value is different for each dataset; we suggest having a look at the message in the logs of the App referring to the span of the used data, to make a more informed choice of this parameter. Also see `Null or error handling` below.

**Maximum time lag in hours (`ignoreTimeHrs`):** Maximum time lag in hours to be included in the calculations; for segments with larger time lags, no estimation will be calculated. Default is 24h. We suggest having a look at the message in the logs of the App referring to the time lag of the data, to make a more informed choice of this parameter. Also see `Null or error handling` below.

**Differentiation by color in map with all tracks (`colorBy`):** The map displaying the UDs of all tracks can be colored by: `trackID`, `contour level` or  `trackID and contour level`. The default option is trackID.

**Save as Shapefile (`saveAsSHP`):** The specified contours of the UDs can be saved as shapefiles. This option can also be unchecked.

### Most common errors
ERROR: `“Error in rasterToContour(data_t_UD_av, levels = ctr) : no contour lines”`. CAUSE 1: Probably the raster resolution was set too large, such that the track only covers a few raster cells, and more raster cells are needed to do the calculation. SOLUTION 1: Have a look in the logs of the app at the span of your data, and set the raster resolution to a size so that a single track will cover many raster cells. *Many* being in the order of at least 2 digits (a guesstimate). CAUSE 2: The `map extent increase` value is too large. SOLUTION 2: reduce the value of the `map extent increase`; often half of the span of the data is sufficient.

ERROR: `Error in .local(object, raster, location.error = location.error, ext = ext, : Lower y grid not large enough, consider extending the raster in that direction or enlarging the ext argument`. CAUSE: The `map extent increase` value is too small. SOLUTION: Increase the value of the `map extent increase` step by step.

### Null or error handling:
**Spatial resolution for the UD raster (`raster_resol`):** The resolution of the model outcome should be sufficiently small for making out your areas of interest, but should also not be too small, as runtime of the App then increases strongly.

**Estimated location error (`loc.err`):** This value strongly influences the width of the utilisation areas. If it is too small, the areas appear too restricted. If it is too large, the areas are very wide. Negative values are not permitted.

**Contour percentages (`conts`):** If this value is not restricted between 0 and 1, you will get errors. Please do not use too many contours, as the map might get difficult to interpret.

**Map extent increase (`ext`):** Select this value reasonably, accounting for the tracking area of your data. It will add to the area evenly on all four directions. Depending on the size of your study, you might not see you tracks if this value is too large. However, if this value is too small, an error will occur that your extent is not large enough for the calculations (this error is very common, simply increase this value). If you get the error: "no contour lines", this value is too large.

**Maximum time lag in hours (`ignoreTimeHrs`):** A time lag that is at least double or triple of the scheduled fix rate is reasonable. It allows for some missed fixes, but excludes larger periods with missed fixes, tags turned off or malfunctioning, etc. If very large time gaps are included, the result might just be one big "blob". See the message in the logs of the App referring to the time lag of the data. The median time lag will most probably reflect the intended scheduled fix rate.

**Data:** The full input data set is returned for further use in subsequent Apps and cannot be empty.
