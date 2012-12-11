baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broLogsDir<-paste(baseDir, "bro-results/", sep="");
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
adBytesFile <- paste(broAggDir, "adBytes.txt", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
adData <- read.table(paste(broAggDir, "adDomain.txt", sep=""), header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
opar = par();
newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

fName <- paste(broAggDir, "/conn.log.ann", sep="");
connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");

connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts);
connData$duration <- convertStringColsToDouble(connData$duration);

startTime <- as.numeric(as.POSIXlt("2012-11-01",tz="America/Los_Angeles", epoch="1970-01-01"))
stopTime <- as.numeric(as.POSIXlt("2012-12-01",tz="America/Los_Angeles", epoch="1970-01-01"))
connData <- connData[connData$ts >=startTime, ];
connData <- connData[connData$ts <= stopTime, ];
connData$tot_bytes <- connData$orig_ip_bytes + connData$resp_ip_bytes;
connData$ts_date <- as.POSIXlt(as.numeric(connData$ts), tz="America/Los_Angeles", origin = "1970-01-01")
connData$hour <- connData$ts_date$hour;
connData$yday <- connData$ts_date$yday 
aggrUser <- aggregate(connData[c("tot_bytes", "resp_ip_bytes", "orig_ip_bytes", "duration")],
                      by=list(user_id=connData$user_id, oper_sys=connData$oper_sys, yday=connData$yday, hour=connData$hour),
                      FUN=sum)

tmpFlows <- aggregate(connData[c("tot_bytes")], #dummy variable for length
                      by=list(user_id=connData$user_id, oper_sys=connData$oper_sys, yday=connData$yday, hour=connData$hour),
                      FUN=length)
aggrUser$num_flows <- tmpFlows$tot_bytes

nHours <- aggregate(aggrUser[c("hour")], by=list(user_id=aggrUser$user_id), FUN=length);
#nBytes <- aggregate(aggrUser[c("tot_bytes")], by=list(user_id=aggrUser$user_id), FUN=sum);

aggrData <- aggregate(aggrUser[c("tot_bytes", "resp_ip_bytes", "orig_ip_bytes", "duration", "num_flows")],
                      by=list(user_id=aggrUser$user_id, oper_sys=aggrUser$oper_sys),
                      FUN=sum)
aggrData$nhours <- nHours$hour;
#aggrData$nBytes <- nBytes$tot_bytes;
aggrData$BytesPerHour <- aggrData$tot_bytes/aggrData$nhours;
aggrData$FlowsPerHour <- aggrData$num_flows/aggrData$nhours;

aggrData <- aggrData[(aggrData$tot_bytes>(100*10^6)),];

sumBytesPerHour <- aggregate(aggrData[c("BytesPerHour", "FlowsPerHour")],
                             by=list(oper_sys=aggrData$oper_sys),
                             FUN=sum);
nDevices <- aggregate(aggrData[c("duration")], #dummy variable for length
                      by=list(oper_sys=aggrData$oper_sys),
                      FUN=length);
sumBytesPerHour$ndevices <- nDevices$duration
sumBytesPerHour$normBytesPerHour <- sumBytesPerHour$BytesPerHour/sumBytesPerHour$ndevices
sumBytesPerHour$normFlowsPerHour <- sumBytesPerHour$FlowsPerHour/sumBytesPerHour$ndevices


