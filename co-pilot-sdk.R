##################
## input/output ## adjust!
##################
## Provided testing datasets in `./data/raw`: 
## "input1_pigeons.rds", "input2_geese.rds", "input3_stork.rds", "input4_goat.rds"  
## for own data: file saved as a .rds containing a object of class MoveStack
inputFileName = "./data/raw/input4_goat.rds"

## optionally change the output file name
unlink("./data/output/", recursive = TRUE)
dir.create("./data/output/") 
outputFileName = "./data/output/output.rds" 

##########################
## Arguments/parameters ## adjust!
##########################
# There is no need to define the parameter "data", as the input data will be automatically assigned to it.
# The name of the field in the vector must be exactly the same as in the r function signature
# Example:
# rFunction = function(data, username, department)
# The parameter must look like:
#    args[["username"]] = "my_username"
#    args[["department"]] = "my_department"

args <- list()
# Add all your arguments of your r-function here
args[["raster_resol"]] = 50
args[["loc.err"]] = 30
args[["conts"]] = 	"0.5,0.95,0.99,0.999"
args[["ext"]] = 20000
args[["ignoreTimeHrs"]] = NULL #10/60
args[["colorBy"]] = "both" #c("trackID", "contourLevel", "both")
args[["saveAsSHP"]] = FALSE
##############################
## source, setup & simulate ## leave as is!
##############################
# this file is the home of your app code and will be bundled into the final app on MoveApps
source("RFunction.R")

# setup your environment
Sys.setenv(
    SOURCE_FILE = inputFileName, 
    OUTPUT_FILE = outputFileName, 
    ERROR_FILE="./data/output/error.log", 
    APP_ARTIFACTS_DIR ="./data/output/artifacts"
)

# simulate running your app on MoveApps
source("src/moveapps.R")
simulateMoveAppsRun(args)
