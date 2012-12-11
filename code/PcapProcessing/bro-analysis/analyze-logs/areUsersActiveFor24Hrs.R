#Are all users active for at least one 24 hour cycle


baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
opar = par();
newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);

fName <- paste(broAggDir, "/conn.log.ann", sep="");
connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");

connData$ts_date <- as.POSIXlt(as.numeric(connData$ts), tz="America/Los_Angeles", origin = "1970-01-01")
connData$yday <- connData$ts_date$yday;
connData$hour <- connData$ts_date$hour;
connData$or
connAggr <- aggregate(connData[c("orig_bytes")],
                      by=list(user_id=connData$user_id, yday=connData$yday, hour=connData$hour),
                      FUN=length);
connHourAggr <- aggregate(connAggr[c("hour")],
                          by=list(user_id=connAggr$user_id, yday=connAggr$yday),
                          FUN=length);
connMaxHour <- aggregate(connHourAggr[c("hour")],
                         by=list(user_id=connHourAggr$user_id),
                         FUN=max);

                          