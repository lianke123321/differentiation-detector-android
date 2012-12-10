baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggrDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
opar = par();
newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);


convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

readConnData <- function(fName) {
  print("Readingfile")
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  print ("Read File");
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts); 
  connData$duration = convertStringColsToDouble(connData$duration);
  connData$ts = convertStringColsToDouble(connData$ts);
  print("Done conversions");
  connData;
}

getDataRateMatrix <- function(reqTechnology) {
  startTime <- as.numeric(as.POSIXlt("2012-11-01",tz="America/Los_Angeles", epoch="1970-01-01"))
  stopTime <- as.numeric(as.POSIXlt("2012-12-01",tz="America/Los_Angeles", epoch="1970-01-01"))
  plotsFolder <- paste(plotsDir,"/userDataRates/", sep="")
  dir.create(plotsFolder)
  u<-1
  dataRateMatrix <- matrix(nrow=100, ncol=14);
  for (userLogsDir in list.dirs(broLogsDir, recursive=FALSE)) { 
    userName <-basename(userLogsDir);
    #if (userName == "arvind-iphone") {
    #  break;
    #}
    fName <- paste(userLogsDir, "/conn.log.ann", sep="");
    connData <- readConnData(fName);
    
    connData$tot_bytes <- connData$resp_ip_bytes + connData$orig_ip_bytes
    if (sum(connData$tot_bytes) < 100*10^6){ 
      print (paste("Insufficient total volumne, Not using ", userName));
      next;
    }
    cellConns <- connData[(connData$ts > startTime & connData$ts < stopTime), ]
    cellConns <- cellConns[cellConns$technology==reqTechnology,];
    cellConns <- cellConns[cellConns$duration > 0, ]
    if (nrow(cellConns) < 5) {
      print (paste("Not using ", userName))
      next;
    }
    
    cellConns$bytespersecond <- (cellConns$tot_bytes)/(cellConns$duration)
    print ("Computed the bytes per second for each row")
    bytesPerSecond <- cellConns$bytespersecond
    totBytes <- cellConns$tot_bytes;
    durationVals <- cellConns$duration;
    i<-1
    userRate <- matrix(nrow=(stopTime-startTime), ncol=2)
    userRate[,1] <- (startTime:(stopTime-1))
    userRate[,2] <- 0;
    print("Starting loop");
    for (ts in cellConns$ts) {
      startCol <- round(ts - startTime) + 1;
      endTime <- ts+durationVals[i];
      endCol <- round(ts-startTime+durationVals[i])+1
      if (endTime > stopTime) {
        endCol <- nrow(userRate)-1;
        print(paste("Check duration field", userName, i));
        next;
      }
      bps <- bytesPerSecond[i];
      if (endCol == startCol) {
        bps <- totBytes[i];
      }
      if (totBytes[i] < 1*10^6) {
        bps = 0;
      }
      i<-i+1;
      if (i %% 1000 == 0) {
        print(i);
      }
      userRate[startCol:endCol,2] <- userRate[startCol:endCol,2]+bps;
    }
    #userRate<-userRate[(min(cellConns$ts) - startTime): (max(cellConns$ts) - startTime), ]
    rateTable <- NULL;
    rateTable  <- data.frame(ts=userRate[,1]);
    rateTable$ts_date <- as.POSIXlt(as.numeric(rateTable$ts), tz="America/Los_Angeles", origin = "1970-01-01")
    rateTable$hour <- rateTable$ts_date$hour
    rateTable$yday <- rateTable$ts_date$yday
    rateTable$minute <- rateTable$ts_date$min
    rateTable$sortorder <- rateTable$yday + (rateTable$hour/24)
    rateTable$bps<-userRate[,2];
    
    # The maximum data rate observed in a time window of 60 seconds
    # once sort order is given the other two are redundant
    aggrMinute <- aggregate(rateTable[c("bps")], 
                            by=list(yday=rateTable$yday, hour=rateTable$hour, minute=rateTable$minute, sortorder=rateTable$sortorder), 
                            FUN=max);    
    aggrMinute <-aggrMinute[order(aggrMinute$sortorder),]
    # Idea was use to use percentile on per minute max. But then decided to go with max which makes minutes redundant
    aggrHour <- aggregate(aggrMinute[c("bps")], 
                          by=list(yday=aggrMinute$yday, hour=aggrMinute$hour, sortorder=aggrMinute$sortorder), 
                          FUN=max)  
    aggrHour <- aggrHour[order(aggrHour$sortorder),]
    
    #  pdf(paste(plotsFolder, "dataRate-", userName,"-hour.pdf", sep=""))
    #  par(newpar)
    #  plot(aggrHour$bps*8/(10^6), xlab="Hour (index)", ylab="Data Rate (Mbps)", 
    #       ylim=c(0, round(max(aggrHour$bps*8/(10^6))+0.5)), pch="+", main=paste(unique(cellConns$isp_info)));
    #  grid(lwd=1)
    #  dev.off();
    
    #  pdf(paste(plotsFolder, "dataRate-", userName,"-minute.pdf", sep=""))
    #  par(newpar)
    #  plot(aggrMinute$bps*8/(10^6), xlab="Hour (index)", ylab="Data Rate (Mbps)", 
    #       ylim=c(0, round(max(aggrMinute$bps*8/(10^6))+0.5)), pch="+", main=paste(unique(cellConns$isp_info)));
    #  grid(lwd=1)
    #  dev.off();
    
    #  pdf(paste(plotsFolder, "dataRate-", userName,"-hour.pdf", sep=""))  
    #  plot(ecdf(x*8/(10^6)), pch=".")  
    #  grid(lwd=1)
    #  dev.off()
    x<-aggrHour$bps;
    x<-x[x>0.0];
    dataRateMatrix[u,] <- c(userName, sum(totBytes), min(cellConns$ts) , max(cellConns$ts), sum(durationVals), paste(unique(cellConns$oper_sys)), paste(unlist(unique(cellConns$isp_info)), collapse=" | "), quantile(x*8/10^6, c(0, 0.05, 0.25, 0.5, 0.75, 0.95, 1.0)))
    u<-u+1;
  }
  
  dataRateMatrix <- dataRateMatrix[1:u-1, ];
  write.table(dataRateMatrix, paste(broAggrDir, "/dataRates", reqTechnology, ".txt", sep=""), col.names=c("user_id", "tot_bytes", "start", "stop", "on_duration", "os", "isp_info","min", "5", "25", "median", "75", "95", "max"), row.names=FALSE, quote=FALSE, sep="\t")
  dataRateMatrix;
}
cellDataRateMatrix<-getDataRateMatrix("Cellular");
wifiDataRateMatrix <- getDataRateMatrix("Wi-Fi");

cellRateMatrix <- read.table(paste(broAggrDir, "/dataRatesCellular.txt", sep=""), sep="\t", header=TRUE);
wifiRateMatrix <- read.table(paste(broAggrDir, "/dataRatesWi-Fi.txt", sep=""), sep="\t", header=TRUE);

cellRateMatrix <- cellRateMatrix[cellRateMatrix$tot_bytes > 100*10^6,]
cellRateMatrix <- cellRateMatrix[order(cellRateMatrix$median),];
plotMatrix <- matrix(nrow=nrow(cellRateMatrix), ncol=7)
i<-1
for (cellUser in cellRateMatrix$user_id) {
  wifiEntry <- wifiRateMatrix[wifiRateMatrix$user_id == cellUser, ];
  cellEntry <- cellRateMatrix[cellRateMatrix$user_id == cellUser, ];
  plotMatrix[i,] <- c(cellUser, cellEntry$X25, cellEntry$median, cellEntry$X75, wifiEntry$X25, wifiEntry$median, wifiEntry$X75)
  i<-i+1;
}



#plot(cellRateMatrix$max, pch="^", ylim=c(0.001,max(cellRateMatrix$max)+1));
pdf(paste(plotsDir, "/dataRate.pdf", sep=""))
par(newpar)
maxVal <- max(c(max(as.numeric(plotMatrix[,7])),max(as.numeric(plotMatrix[,7]))))

offset <- 0.1
plot((1:length(plotMatrix[,1]))+offset, as.numeric(plotMatrix[,7]), pch=2,
     xaxs="r", yaxs="r",
     ylim=c(0, maxVal+0.2), xlim=c(0, length(plotMatrix[,1])+1),
     ylab="Data Transfer Rate (Mbps)", xlab="User ID (ordered by median data transfer rate)");
points((1:length(plotMatrix[,1]))-offset, as.numeric(plotMatrix[,4]), pch=0)  
points((1:length(plotMatrix[,1]))+offset, as.numeric(plotMatrix[,6]), pch=1);
points((1:length(plotMatrix[,1]))-offset, as.numeric(plotMatrix[,3]), pch=3);
points((1:length(plotMatrix[,1]))+offset, as.numeric(plotMatrix[,5]), pch=4);
points((1:length(plotMatrix[,1]))-offset, as.numeric(plotMatrix[,2]), pch=6);
#textVector <- (as.numeric(plotMatrix[,3])/as.numeric(plotMatrix[,6]));
#textVector <- round(textVector*100)/100;
#textVector[is.na(textVector)] <- "-"
#textVector <- paste("(", textVector, ")", sep="")
grid(lwd=1)
legend(1, 12, c("Wi-Fi 75th Percentile", "Cellular 75th Percentile", "Wi-Fi Median", "Cellular Median",
               "Wi-Fi  25th Percentile", "Cellular 25th Percentile"), 
       pch=c(2,0,1,3,4,6))
#text(1:length(plotMatrix[,1]), y=10, labels=textVector, xpd=TRUE, srt=90);
dev.off()

