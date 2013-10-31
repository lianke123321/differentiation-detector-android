# Functions to read the log files and convert the 

measurementStartTime <- 1351727700
# Nov 1 2012

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

readConnData <- function(fName, filterTs=FALSE) {
  print(paste("Reading file name", fName))
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData$orig_ip_bytes <- convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes <- convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts <- convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts <- convertStringColsToDouble(connData$resp_pkts);
  connData$resp_pkts <- convertStringColsToDouble(connData$resp_pkts);
  connData$duration <- convertStringColsToDouble(connData$duration);
  connData$ts <- convertStringColsToDouble(connData$ts);  
  connData$ack_time <- convertStringColsToDouble (connData$ack_time)
  connData$synack_time <- convertStringColsToDouble (connData$synack_time)
  if (filterTs==TRUE) {
      connData <- connData[connData$ts > measurementStartTime, ]
  }
  print("Done")
  connData;
}

readHttpData <- function(fName, filterTs=FALSE) {
  print(paste("Reading file name", fName))
  httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  httpData$content_length <- convertStringColsToDouble(httpData$content_length)
  httpData$response_body_len <- convertStringColsToDouble(httpData$response_body_len)
  httpData$request_body_len <- convertStringColsToDouble(httpData$request_body_len)
  httpData$ts <- convertStringColsToDouble(httpData$ts);  
  if (filterTs==TRUE) {
       httpData<-httpData[httpData$ts > measurementStartTime, ]
  }
  print("Done")
  httpData
}

readSslData <- function(fName, filterTs) {
  print(paste("Reading file name", fName))
  sslData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");  
  # Todo add stuff here!
  sslData$ts <- convertStringColsToDouble(sslData$ts);  
  if (filterTs ==TRUE) {
     sslData<-sslData[sslData$ts>measurementStartTime, ]
  }
  print("Done")
  sslData
}

readTable <- function(fName) {
  print(paste("Reading file name", fName))
  tableData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  print("Done")
  tableData
}

#annotateLocalTime <- function(data) {
#  # Convert the time stamps to date time
  # For each user group by the day, hour, on which at least one packet was seen

  # This takes too much time 
  #connData$ts_date <- mapply(x=as.numeric(connData$ts), y=connData$time_zone, function(x,y) {z<-as.POSIXlt(x, tz=y, origin = "1970-01-01"); z})

#  unique_tz <- unique(data$time_zone)
#  data$year <- 0; data$mon <- 0; data$day <- 0; data$hour <- 0 ; data$min <- 0 ; data$sec <- 0
#  i<-1
#  data$ts_date <- as.POSIXlt(0, tz="America/Los_Angeles", origin = "1970-01-01")
#  for(i in 1:length(unique_tz)) {
#    tz_rows <- grep(unique_tz[i], data$time_zone)
#    print(paste(unique_tz[i], length(tz_rows)))
#    tsDate <- as.POSIXlt(data[tz_rows, ]$ts, tz=unique_tz[i], origin = "1970-01-01");
#    data[tz_rows, ]$hour <- tsDate$hour
#    data[tz_rows, ]$min <- tsDate$min
#    data[tz_rows, ]$sec <- tsDate$sec
#    data[tz_rows, ]$year <- tsDate$year
#    data[tz_rows, ]$mon <- tsDate$mon
#    data[tz_rows, ]$day <- tsDate$mday
#  }
#  data
#}


