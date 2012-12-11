baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
opar = par();
newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

getHTTPData <- function() {
  fName <- paste(broAggDir, "/http.log.ann", sep="");
  if (file.exists(fName) == FALSE) {
    print(fName);
    return(NA);
  }
  print("Reading Http")
  httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
  if (nrow(httpData) < 10) {
    print(fName);
    return(NA);
  } 
  httpData$content_length <- convertStringColsToDouble(httpData$content_length)
  httpData$response_body_len <- convertStringColsToDouble(httpData$response_body_len)
  httpData$request_body_len <- convertStringColsToDouble(httpData$request_body_len)
  httpData$connLen <- httpData$request_body_len + httpData$content_length;
  httpData[httpData$technology=="Unknown",]$technology<-"Wi-Fi"
  httpData;
}

getTextRows <-function(httpData){
  print("Finding Text")
  
  rowIDs <- grep("text", httpData$mime_type);
  rowIDs <- append(rowIDs, grep("text", httpData$content_type));
  
  rowIDs <- unique(sort(rowIDs));
  textRows <- httpData[rowIDs, ];  
  textRows;
}

getZipRows <- function(textRows) {
  print("Finding Zip")
  zipRows <- textRows[grep("zip", textRows$content_encoding), ];
  
  zipRows;  
}

getChunkedRows <- function(textRows) {
  print("Finding Chunked")
  zipRows <- textRows[grep("chunked", textRows$transfer_encoding), ];
  zipRows;  
}

getUnCompressed <- function(textRows) {
  uncomp <- textRows[textRows$content_length == textRows$response_body_len, ]
  uncomp;
}

getCompressFailRows <- function(zipRows) {
  # find entries with gzip in content_type
  print("Finding Compress Fail")
  compressFailRows <- zipRows[(zipRows$content_length > zipRows$response_body_len),];
  compressFailRows;
}

httpData <- getHTTPData();
textRows <- getTextRows(httpData);
zipRows <- getZipRows(textRows)
chunkRows <- getChunkedRows(textRows)
uncompRows <- getUnCompressed(textRows)
compressFail <- getCompressFailRows(zipRows);


httpAggr <- aggregate(httpData[c("connLen", "request_body_len", "response_body_len")],
                      by=list(oper_sys=httpData$oper_sys, technology=httpData$technology),
                      FUN=sum);
httpAggr$count <- aggregate(httpData[c("connLen")],
                            by=list(oper_sys=httpData$oper_sys, technology=httpData$technology),
                            FUN=length)$connLen; 

textAggr <- aggregate(textRows[c("connLen", "request_body_len", "response_body_len")],
                      by=list(oper_sys=textRows$oper_sys, technology=textRows$technology),
                      FUN=sum);
# Assumption that row orders are maintained.
textAggr$count <- aggregate(textRows[c("connLen")],
                      by=list(oper_sys=textRows$oper_sys, technology=textRows$technology),
                      FUN=length)$connLen;

textAggr$connLen/httpAggr$connLen

zipAggr <- aggregate(zipRows[c("connLen", "request_body_len", "response_body_len")],
                     by=list(oper_sys=zipRows$oper_sys, technology=zipRows$technology),
                     FUN=sum);
zipAggr$count <- aggregate(zipRows[c("connLen")],
                     by=list(oper_sys=zipRows$oper_sys, technology=zipRows$technology),
                     FUN=length)$connLen;
compressFailAggr <- aggregate(compressFail[c("connLen", "request_body_len", "response_body_len")],
                              by=list(oper_sys=compressFail$oper_sys, technology=compressFail$technology),
                              FUN=sum);
compressFailAggr$count <- aggregate(compressFail[c("connLen")],
                                    by=list(oper_sys=compressFail$oper_sys, technology=compressFail$technology),
                                    FUN=length)$connLen;

compressFailRows <- getCompressFailRows();

topFailures <- aggregate(compressFail[c("connLen")],
                         by=list(oper_sys=compressFail$oper_sys, host=compressFail$host),
                         FUN=length);
topFailures <- topFailures[order(topFailures$connLen, decreasing=TRUE),]

nrow(textRows)/nrow(httpData)
sum(textRows$connLen)/sum(httpData$connLen)

nrow(zipRows)/nrow(textRows)
sum(zipRows$connLen)/sum(textRows$connLen)

nrow(chunkRows)/nrow(textRows)
sum(chunkRows$connLen)/sum(textRows$connLen)

nrow(uncompRows)/nrow(textRows)
sum(uncompRows$connLen)/sum(textRows$connLen)

nrow(uncompRows)/nrow(httpData)
sum(uncompRows$connLen)/sum(httpData$connLen)

nrow(compressFail)/nrow(textRows)
sum(compressFail$content_length)/sum(textRows$content_length)


# displayTopFailSources <- function(compressFailRows) {
#   #compAggr<-aggregate(compressFailRows[c("ts")],
#   #                   by=list(host=compressFailRows$host, technology=compressFailRows$technology,
#   #                           oper_sys=compressFailRows$oper_sys), 
#   #                   FUN=length)
#   compAggr<-aggregate(compressFailRows[c("ts")],
#                       by=list(top_host=compressFailRows$top_host), 
#                       FUN=length)
#   compAggr<-aggregate(compressFailRows[c("ts")],
#                       by=list(oper_sys=compressFailRows$oper_sys), 
#                       FUN=length)
#   httpAggr<-aggregate(httpData[c("ts")],
#                       by=list(oper_sys=httpData$oper_sys), 
#                       FUN=length)
#   
#   compAggr<-compAggr[order(compAggr$ts, decreasing=TRUE),]
# }