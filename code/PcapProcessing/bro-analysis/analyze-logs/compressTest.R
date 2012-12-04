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

getCompressFailRows <- function() {
  # find entries with gzip in content_type
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
  print("Finding Text")
  rowIDs <- grep("text", httpData$mime_type);
  
  rowIDs <- append(rowIDs, grep("text", httpData$content_type));
  rowIDs <- unique(sort(rowIDs));
  textRows <- httpData[rowIDs, ];  
  print("Finding Zip")
  zipRows <- textRows[grep("zip", textRows$content_encoding), ];
  
  zipRows$content_length <- convertStringColsToDouble(zipRows$content_length)
  zipRows$response_body_len <- convertStringColsToDouble(zipRows$response_body_len)
  print("Finding Compress Fail")
  compressFailRows <- zipRows[(zipRows$content_length > zipRows$response_body_len),];
  compressFailRows;
}

displayTopFailSources <- function(compressFailRows) {
  #compAggr<-aggregate(compressFailRows[c("ts")],
  #                   by=list(host=compressFailRows$host, technology=compressFailRows$technology,
  #                           oper_sys=compressFailRows$oper_sys), 
  #                   FUN=length)
  compAggr<-aggregate(compressFailRows[c("ts")],
                      by=list(top_host=compressFailRows$top_host), 
                      FUN=length)
  compAggr<-aggregate(compressFailRows[c("ts")],
                     by=list(oper_sys=compressFailRows$oper_sys), 
                     FUN=length)
  httpAggr<-aggregate(httpData[c("ts")],
                      by=list(oper_sys=httpData$oper_sys), 
                      FUN=length)
  
  compAggr<-compAggr[order(compAggr$ts, decreasing=TRUE),]
}
textRows
compressFailRows <- getCompressFailRows();
