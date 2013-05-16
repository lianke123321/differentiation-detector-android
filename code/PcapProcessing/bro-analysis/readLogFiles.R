# Functions to read the log files and convert the 

measurementStartTime <- 1351727700
# Nov 1 2012

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

readConnData <- function(fName) {
  print(paste("Reading file name", fName))
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData$orig_ip_bytes <- convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes <- convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts <- convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts <- convertStringColsToDouble(connData$resp_pkts);
  connData$resp_pkts <- convertStringColsToDouble(connData$resp_pkts);
  connData$duration <- convertStringColsToDouble(connData$duration);
  connData$ts <- convertStringColsToDouble(connData$ts);  
  connData <- connData[connData$ts > measurementStartTime, ]
  print("Done")
  connData;
}

readHttpData <- function(fName) {
  print(paste("Reading file name", fName))
  httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  httpData$content_length <- convertStringColsToDouble(httpData$content_length)
  httpData$response_body_len <- convertStringColsToDouble(httpData$response_body_len)
  httpData$request_body_len <- convertStringColsToDouble(httpData$request_body_len)
  httpData<-httpData[httpData$ts > measurementStartTime, ]
  print("Done")
  httpData
}

readSslData <- function(fName) {
  print(paste("Reading file name", fName))
  sslData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");  
  # Todo add stuff here!
  sslData$ts <- convertStringColsToDouble(sslData$ts);  
  sslData<-sslData[httpData$ts>measurementStartTime, ]
  print("Done")
  sslDataData
}

readTable <- function(fName) {
  print(paste("Reading file name", fName))
  tableData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  print("Done")
  tableData
}
