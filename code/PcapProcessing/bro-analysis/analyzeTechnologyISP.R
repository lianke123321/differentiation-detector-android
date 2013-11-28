baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
cexVal<-1.5
source(paste(scriptsDir, "/readLogFiles.R", sep=""))

maxRTT <- 60; #max RTT in seconds


connData <- readConnData(paste(broAggDir, "filter.rtt.conn.log.info", sep=""))
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
serverISPs <- c(-1, 16, 46, 48, 54)

connData$e2e_rtt <-  (connData$ack_time - connData$ts)*1000;
connData$serv_latency <- (connData$ack_time - connData$synack_time)*1000;
connData <- connData[connData$serv_latency>1,]

error.bar <- function(x, y, upper, lower=upper, length=0.1,...){
  if(length(x) != length(y) | length(y) !=length(lower) | length(lower) != length(upper))
    stop("vectors must be same length")
  arrows(x,upper, x, lower, angle=90, code=3, length=length, ...)
}

############################################################################################
#### FILTER THE CONNECTIONS TO REMOVE THE CONNECTIONS COMING FROM THE SERVER NETWORKS ######
############################################################################################

serverISPs <- c(-1, 16, 46, 48, 54)
filterConn <- connData[!(connData$isp_id %in% serverISPs),]

############################################################################################
#### PER PREFIX BASED ANALYSIS #############################################################
############################################################################################

aggregateLatency <- aggregate(filterConn[("serv_latency")],
                           by=list(prefix_id=filterConn$prefix_id, technology=filterConn$technology),                            
                           FUN=quantile, probs=c(0.09, 0.25, 0.5, 0.75, 0.91))
# note order median is at 3rd position
# order by median
aggregateLatency <- aggregateLatency[order(aggregateLatency$serv_latency[,3]),]
numPrefixs <- nrow(aggregateLatency)
cellLatency <- aggregateLatency[aggregateLatency$technology=="c",]
wifiLatency <- aggregateLatency[aggregateLatency$technology=="w",]
aggregateLatency <- rbind(cellLatency, wifiLatency)
aggregateLatency$sort_order <- 1:nrow(aggregateLatency)

###############################################
### THIS IS WHERE WE KEEP THE ORDER OF PREFIXes
prefix_order <- data.frame(prefix_id=aggregateLatency$prefix_id, sort_order <- aggregateLatency$sort_order)
###############################################
# Now plot
pdf(paste(resultsDir, "/latency_prefix_whisker.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(1:numPrefixs, aggregateLatency$serv_latency[,3], log="y",
     xlim=c(1, numPrefixs),
     pch=1,
     yaxt="n",
     ylim=c(1, max(aggregateLatency$serv_latency[,5])),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Prefix ID (ordered by median latency and technology)",
     ylab="Latency (ms)")
axis(2, at=c(1,10, 100, 1000), labels=c(1, 10, 100, 1000),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,numISPs,1), labels=F)
axis(2, at=c(seq(1,10,1), seq(20, 100, 10), seq(100, 1000, 100)), labels=F)
error.bar(1:numPrefixs, aggregateLatency$serv_latency[,3],  
          aggregateLatency$serv_latency[,5], aggregateLatency$serv_latency[,1])
abline(v=nrow(cellLatency)+0.5, h=NULL, lty=2,lwd=5, col="black")
text(nrow(cellLatency)-1, 2, "Cellular", cex=cexVal, adj=1)
text(nrow(cellLatency)+1, 2, "Wi-Fi", cex=cexVal, adj=0)
legend(75, 10, c("Median Latency"), pch=c(1), cex=cexVal)
dev.off()

############################################################################################
#### PER AS BASED ANALYSIS #################################################################
############################################################################################
aggregateLatency <- aggregate(filterConn[("serv_latency")],
                              by=list(as=filterConn$as, technology=filterConn$technology),                            
                              FUN=quantile, probs=c(0.09, 0.25, 0.5, 0.75, 0.91))
# note order median is at 3rd position
# order by median
aggregateLatency <- aggregateLatency[order(aggregateLatency$serv_latency[,3]),]
numASs <- nrow(aggregateLatency)
cellLatency <- aggregateLatency[aggregateLatency$technology=="c",]
wifiLatency <- aggregateLatency[aggregateLatency$technology=="w",]
aggregateLatency <- rbind(cellLatency, wifiLatency)
aggregateLatency$sort_order <- 1:nrow(aggregateLatency)

### THIS IS WHERE WE KEEP THE ORDER OF PREFIXes
as_order <- data.frame(as=aggregateLatency$as, sort_order <- aggregateLatency$sort_order)
###############################################
### THIS IS WHERE WE KEEP THE ORDER OF PREFIXes
###############################################
# Now plot
pdf(paste(resultsDir, "/latency_as_whisker.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(1:numASs, aggregateLatency$serv_latency[,3], log="y",
     xlim=c(1, numASs),
     pch=1,
     yaxt="n",
     ylim=c(1, max(aggregateLatency$serv_latency[,5])),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Prefix ID (ordered by median latency and technology)",
     ylab="Latency (ms)")
axis(2, at=c(1,10, 100, 1000), labels=c(1, 10, 100, 1000),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,numISPs,1), labels=F)
axis(2, at=c(seq(1,10,1), seq(20, 100, 10), seq(100, 1000, 100)), labels=F)
error.bar(1:numASs, aggregateLatency$serv_latency[,3],  
          aggregateLatency$serv_latency[,5], aggregateLatency$serv_latency[,1])
abline(v=nrow(cellLatency)+0.5, h=NULL, lty=2,lwd=5, col="black")
text(nrow(cellLatency)-1, 2, "Cellular", cex=cexVal, adj=1)
text(nrow(cellLatency)+1, 2, "Wi-Fi", cex=cexVal, adj=0)
legend(75, 10, c("Median Latency"), pch=c(1), cex=cexVal)
dev.off()




##### Cherry pick three ISPs and plot the latency observed with time of the day

#### Get the time evolution of the serv_latency
aggregateLatency <- aggregate(filterConn[c("serv_latency")],
                              by=list(isp_id=filterConn$isp_id, technology=filterConn$technology,
                                      prefix_id=filterConn$prefix_id,as=filterConn$as, 
                                      user_id=filterConn$user_id, year=filterConn$year, mon=filterConn$mon, 
                                      day=filterConn$day),
                              FUN=median)
#aggregateLatency$xval <- (aggregateLatency$day)+(aggregateLatency$hour/24)
aggregateLatency <- aggregateLatency[order(aggregateLatency$ts), ]
attLatency <- aggregateLatency[aggregateLatency$isp_id %in% c(11)
                               &aggregateLatency$user_id%in%c(7,1)
                               &aggregateLatency$year==112
                               &aggregateLatency$mon==11,]
attLatency <- aggregate(attLatency[c("serv_latency")],
                        by=list(day=attLatency$day),
                        FUN=median)
tmobLatency <- aggregateLatency[aggregateLatency$isp_id %in% c(15,17)                                
                                &aggregateLatency$year==112
                                &aggregateLatency$mon==11,]
tmobLatency <- aggregate(tmobLatency[c("serv_latency")],
                        by=list(day=tmobLatency$day),
                        FUN=median)
comcastLatency <- aggregateLatency[aggregateLatency$isp_id %in% c(26,27)
                                   &aggregateLatency$year==112
                                   &aggregateLatency$mon==11,]
comcastLatency <- aggregate(comcastLatency[c("serv_latency")],
                            by=list(day=comcastLatency$day),
                            FUN=median)

pdf(paste(resultsDir, "/compare_isp_latency.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(comcastLatency$day, comcastLatency$serv_latency, pch=1, log="y",
     xlim=c(1,30), 
     yaxt="n",
     ylim=c(1, max(c(attLatency$serv_latency,tmobLatency$serv_latency, comcastLatency$serv_latency))),
     xlab="Day",
     ylab="Latency (ms)",
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
axis(2,at=c(1,10,100),labels=c(1,10,100),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,30,1), labels=F)
axis(2, at=c(seq(1,10,1), seq(20,100,10), seq(200, 1000,100)), labels=F)
points(attLatency$day, attLatency$serv_latency, pch=2, cex=cexVal)
points(tmobLatency$day, tmobLatency$serv_latency, pch=3, cex=cexVal)
lines(comcastLatency$day, comcastLatency$serv_latency, lty=3, lwd=1)
lines(attLatency$day, attLatency$serv_latency, lty=3, lwd=1)
lines(tmobLatency$day, tmobLatency$serv_latency, lty=3, lwd=1)
legend(10, 10, c("ISP1 (3G)", "ISP2 (LTE)", "ISP3 (Wi-Fi)"),
       pch=c(3,2,1), cex=cexVal*0.8)
dev.off()

### Time to access specific hosts.
#### Check the time required for google com for http

# Some of the the google rows
googleRows <- c(grep("173.194", connData$id.resp_h), 
                grep("74.125", connData$id.resp_h),
                grep("72.14.", connData$id.resp_h))
googleConns <- connData[googleRows, ]
googleConns$delay_ratio <- googleConns$serv_latency/googleConns$e2e_rtt
aggregateLatency <- aggregate(googleConns[c("delay_ratio")],
                              by=list(isp_id=googleConns$isp_id, technology=googleConns$technology),
                              FUN=quantile, probs=c(0.09, 0.25, 0.5, 0.75, 0.91))
aggregateLatency <- merge(x=aggregateLatency, y=isp_order, by="isp_id")
pdf(paste(resultsDir, "/delay_ratio_isp_whisker.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(aggregateLatency$sort_order, aggregateLatency$delay_ratio[,3],
     xlim=c(1, numISPs),
     pch=1,
     yaxt="n",
     ylim=c(0, 1),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="ISP ID (ordered by median latency and technology)",
     ylab="Delay Ratio (Latency/RTT)")
axis(2, at=seq(0,1,0.2), labels=seq(0, 1,0.2), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,numISPs,1), labels=F)
axis(2, at=seq(0,1,0.02), labels=F)
error.bar(aggregateLatency$sort_order, aggregateLatency$delay_ratio[,3],  
          aggregateLatency$delay_ratio[,5], aggregateLatency$delay_ratio[,1])
abline(v=nrow(cellLatency)+0.5, h=NULL, lty=2,lwd=5, col="black")
text(nrow(cellLatency)-1, 0.02, "Cellular", cex=cexVal, adj=1)
text(nrow(cellLatency)+1, 0.02, "Wi-Fi", cex=cexVal, adj=0)
legend(32, 0.4, c("Median"), pch=c(1), cex=cexVal)
grid(lwd=3)
dev.off()


###########################################################################
########## Distribution of LTE vs 3G vs Wifi of latency #################
###########################################################################

lteLatency <- filterConn[filterConn$isp_id == 11,]$serv_latency
cellLatency <- filterConn[((!(filterConn$isp_id == 11))
                          &filterConn$technology=="c"),]$serv_latency
wifiLatency <- filterConn[filterConn$technology=="w",]$serv_latency
pdf(paste(resultsDir, "/distrib_latency_technology.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
x<-knots(ecdf(lteLatency))
y<-(1:length(x))/length(x)
plot(x,y, type="l", log="x", lty=2, lwd=5,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlim=c(1,10*1000), ylim=c(0,1), xaxt="n",yaxt="n",
     xlab="Latency (ms)",
     ylab="CDF")
axis(2, at=seq(0,1,0.2), labels=seq(0, 1,0.2), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
axis(1, at=c(1,10,100,1000,10000), labels=c(1,10,100,1000,10000), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(2, at=seq(0,1,0.02), labels=F)
axis(1, at=c(seq(1,10,1), seq(20,100,10), seq(200,1000, 100), seq(2000,10000,1000)), 
     labels=F)
x<-knots(ecdf(cellLatency))
y<-(1:length(x))/length(x)
lines(x,y, lty=3, lwd=5)
x<-knots(ecdf(wifiLatency))
y<-(1:length(x))/length(x)
lines(x,y, lty=1, lwd=5)
grid(lwd=3)
legend(1,1,c("Wi-Fi", "LTE", "3G"), cex=cexVal, 
       lty=c(1,2,3), lwd=5)
dev.off()

################################################################################################
################################################################################################
################################################################################################

connData<-connData[connData$duration>0,]
connData$year <- convertStringColsToDouble(connData$year)
connData$day  <- convertStringColsToDouble(connData$day)
connData$mon  <- convertStringColsToDouble(connData$mon)
connData$hour <- convertStringColsToDouble(connData$hour)
connData$est_thpt <- (connData$orig_ip_bytes+connData$resp_ip_bytes)/(connData$duration)

maxRates <- aggregate(connData[c("est_thpt")],
                      by=list(user_id=connData$user_id, technology=connData$technology,
                              hour=connData$hour, year=connData$year, day=connData$day, mon=connData$mon),
                      FUN=max)
cellRates <- maxRates[connData$technology=="c",]
cellRates$hour_sig <- ((cellRates$year)*400*30*40)+((cellRates$mon)*30*40)+((cellRates$day)*30)+(cellRates$hour)
cellRates <- cellRates[!(is.na(cellRates$hour_sig)),]
wifiRates <- maxRates[connData$technology=="w",]
wifiRates$hour_sig <- ((wifiRates$year)*400*30*40)+((wifiRates$mon)*30*40)+((wifiRates$day)*30)+(wifiRates$hour)
wifiRates <- wifiRates[!(is.na(wifiRates$hour_sig)),]

## For some reason this is failing...
handoffRates <- merge(x=cellRates, y=wifiRates, by=c("user_id", "hour_sig") all=FALSE)










#isp_order <- data.frame(isp_id=aggregateLatency$isp_id, sort_order <- aggregateLatency$sort_order)



#allUsers <- unique(connSummary$user_id)
# temp, add a dummy for tests
#allUsers <- c(allUsers, 1)

#unique(connData$isp_id)
#connData$e2e_rtt <-  (connData$ack_time - connData$ts)*1000;
#connData$serv_latency <- (connData$ack_time - connData$synack_time)*1000;
#connData <- connData[connData$serv_latency>1,]
#### Get this information from the miscData/isp_signature_table.txt
#### Note the _manual table has tmp ids. 
#otherNetworkConnData <- connData[!(connData$isp_id %in% serverISPs),]
#serverNetworkConnData <- connData[(connData$isp_id %in% serverISPs),]
#
#maxLatency <- max(otherNetworkConnData$serv_latency)

#cell <- otherNetworkConnData[otherNetworkConnData$technology=="c",];
#wifi <- otherNetworkConnData[otherNetworkConnData$technology=="w",];
#cell <- cell[(cell$e2e_rtt >0) & (cell$e2e_rtt > cell$serv_latency),]
#wifi <- wifi[(wifi$e2e_rtt>0) & (wifi$e2e_rtt > wifi$serv_latency),]

#pdf(paste(resultsDir,"distrib_delays.pdf", sep=""), height=10, width=16, pointsize=25) 
#mar <- par()$mar
#mar[4] <- 0.5
#par(mar=mar)
#x<-knots(ecdf(1-(cell$serv_latency/cell$e2e_rtt)))
#y<-(1:length(x))/length(x)
#plot(x,y, type="l", lwd=5,lty=1,
#     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,     
#     xlim=c(0,1), ylim=c(0,1),
#     yaxt="n",xaxt="n",
#     xlab="Delay Fraction",
##     ylab="CCDF");
#axis(2, at=seq(0,1,0.2), labels=seq(0, 1, 0.2), las=1,
#     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
#axis(1, at=seq(0,1,0.1), labels=seq(0, 1, 0.1), las=1,
#     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
#par(tcl=0.22)
#axis(2, seq(0, 1, 0.02), labels=F)
#axis(1, seq(0, 1, 0.01), labels=F);
#x<-knots(ecdf(1-(wifi$serv_latency/wifi$e2e_rtt)))
#y<-(1:length(x))/length(x)
#lines(x,y,lwd=5,lty=2)
#x<-knots(ecdf(wifi$e2e_rtt))
#y<-(1:length(x))/length(x)
#lines(x,y,lwd=5,lty=4)
#x<-knots(ecdf(cell$e2e_rtt))
#y<-(1:length(x))/length(x)
#lines(x,y,lwd=5,lty=3)
#grid(lwd=3)
#legend(0,1, c("Cell", "Wi-fi"),
#       lty=c(1,2),
#       lwd=5, cex=cexVal);
#dev.off()
#plot(x)



#androidCell <- otherNetworkConnData[otherNetworkConnData$operating_system=="a"
#                                    & otherNetworkConnData$technology=="c",];
#androidWifi <- otherNetworkConnData[otherNetworkConnData$operating_system=="a"
#                                    & otherNetworkConnData$technology=="w",];
#iOSWifi <- otherNetworkConnData[otherNetworkConnData$operating_system=="i"
#                                & otherNetworkConnData$technology=="w",];
#iOSCell <- otherNetworkConnData[otherNetworkConnData$operating_system=="i"
                                & otherNetworkConnData$technology=="c",];


# pdf(paste(resultsDir,"distrib_latency.pdf", sep=""), height=10, width=16, pointsize=25) 
# mar <- par()$mar
# mar[4] <- 0.5
# par(mar=mar)
# x<-knots(ecdf(androidCell$serv_latency))
# y<-(1:length(x))/length(x)
# plot(x,y, type="l", log="x", lwd=5,lty=1,
#      cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,     
#      xlim=c(1, 10*1000),
#      yaxt="n",
#      xlab="Latency (ms)",
#      ylab="CDF");
# axis(2, at=seq(0,1,0.2), labels=seq(0, 1, 0.2), las=1,
#      cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
# par(tcl=0.22)
# axis(2, seq(0, 1, 0.02), labels=F)
# axis(1, c(seq(1,10,1), seq(20, 100, 10), 
#           seq(200, 1000, 100), seq(2000, 10000, 1000)),
#      labels=F);
# x<-knots(ecdf(androidWifi$serv_latency))
# y<-(1:length(x))/length(x)
# lines(x,y,lwd=5,lty=2)
# x<-knots(ecdf(iOSCell$serv_latency))
# y<-(1:length(x))/length(x)
# lines(x,y,lwd=5,lty=3)
# x<-knots(ecdf(iOSWifi$serv_latency))
# y<-(1:length(x))/length(x)
# lines(x,y,lwd=5,lty=4)
# grid(lwd=3)
# legend(1,1, c("Cell (Android)", "Cell (iOS)", "Wi-fi (Android)", "Wi-fi (iOS)"),
#        lty=c(1,3,2,4),
#        lwd=5, cex=cexVal);
# dev.off()
# plot(x)


# # getUserLatencyForTech <- function (inputTable) {  
# #   filterLatency <- inputTable; 
# #   x <- aggregate(filterLatency[c("e2e_rtt", "serv_latency")],                 
# #                  by=list(user_id=filterLatency$user_id, 
# #                          technology=filterLatency$technology),
# #                  FUN=mean)
# #   x$serv_latency=x$serv_latency*1000;
# #   x$e2e_rtt=x$e2e_rtt*1000;  
# #   colnames(x) <- gsub("e2e_rtt", "mean_e2e_rtt", colnames(x))
# #   colnames(x) <- gsub("serv_latency", "mean_serv_latency", colnames(x)) 
# #   aggrLatency <- x;
# #   
# #   x <- aggregate(filterLatency[c("e2e_rtt", "serv_latency")],
# #                  by=list(user_id=filterLatency$user_id, 
# #                          isp_id=filterLatency$isp_id,
# #                          operating_system=filterLatency$operating_system, 
# #                          technology=filterLatency$technology),
# #                  FUN=median)
# #   x$serv_latency=x$serv_latency*1000;
# #   x$e2e_rtt=x$e2e_rtt*1000;    
# #   colnames(x) <- gsub("e2e_rtt", "median_e2e_rtt", colnames(x))
# #   colnames(x) <- gsub("serv_latency", "median_serv_latency", colnames(x))
# #   aggrLatency <- merge(x=aggrLatency, y=x, by=c("user_id", "technology"))
# #   return (aggrLatency)
# # }
# # 
# # # Plot the distribution of latencies over Wifi and Cellular networks
# # aggrOthNetLatency<- getUserLatencyForTech(otherNetworkConnData)  
# # aggrAllNetLatency<- getUserLatencyForTech(connData)  
# # 
# # #aggrOthNetLatency <- addDummyUsers(aggrOthNetLatency) 
# # #aggrAllNetLatency <- addDummyUsers(aggrAllNetLatency)
# # 
# # medianLatencies <- aggregate(aggrOthNetLatency[c("median_serv_latency")],
# #                              by=list(isp_id=aggrOthNetLatency$isp_id, technology=aggrOthNetLatency$technology),
# #                              FUN=median)
# # #cellLatencies <- medianLatencies[medianLatencies$technology=="c",]
# # #wifiLatencies <- medianLatencies[minLatencies$technology=="w",]
# # cellLatencies <- cellLatencies[order(cellLatencies$median_serv_latency, decreasing=TRUE),]
# # wifiLatencies <- wifiLatencies[order(wifiLatencies$median_serv_latency, decreasing=TRUE),]
# # numCell <- nrow(cellLatencies)
# # cellLatencies$sort_order <- 1:numCell
# # wifiLatencies$sort_order <- (1:nrow(wifiLatencies))+numCell
# # cellLatencies$median_serv_latency <- NULL;
# # wifiLatencies$median_serv_latency <- NULL;
# # x <- merge(x=aggrOthNetLatency, y=cellLatencies, by=c("isp_id", "technology"))
# # y <- merge(x=aggrOthNetLatency, y=wifiLatencies, by=c("isp_id", "technology"))
# # aggrOthNetLatency <- rbind(x, y)
# # rm(x)
# # rm(y)
# # pdf(paste(resultsDir, "/isp_delays.pdf", sep=""),, height=10, width=16, pointsize=25)
# # mar <- par()$mar
# # mar[4] <- 0.5
# # par(mar=mar)
# # plot(aggrOthNetLatency[aggrOthNetLatency$operating_system=="a",]$sort_order-0.25, 
# #      aggrOthNetLatency[aggrOthNetLatency$operating_system=="a",]$median_serv_latency,
# #      cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
# #      xlab="ISP ID (ordered by technology and median latency to server)",
# #      ylab="Delay (ms)",
# #      xlim=c(0, length(unique(aggrOthNetLatency$isp_id))),
# #      ylim=c(0, 500),     
# #      pch=1)
# # points(aggrOthNetLatency[aggrOthNetLatency$operating_system=="i",]$sort_order+0.25, 
# #        aggrOthNetLatency[aggrOthNetLatency$operating_system=="i",]$median_serv_latency,
# #        cex=cexVal,
# #        pch=2)
# # points(aggrOthNetLatency[aggrOthNetLatency$operating_system=="a",]$sort_order-0.25, 
# #        aggrOthNetLatency[aggrOthNetLatency$operating_system=="a",]$median_e2e_rtt,
# #        cex=cexVal,       
# #        pch=3)
# # points(aggrOthNetLatency[aggrOthNetLatency$operating_system=="i",]$sort_order+0.25, 
# #        aggrOthNetLatency[aggrOthNetLatency$operating_system=="i",]$median_e2e_rtt,
# #        cex=cexVal,       
# #        pch=4)
# #legend(1, 400, c("Android (Latency)", "iOS (Latency)", "Android (RTT)", "iOS (RTT)"),
# #       cex=cexVal, pch=c(1,2,3,4))
# #abline(v=(numCell+0.5), h=NULL, lty=2,lwd=5, col="black")     

     
     

     

# #minLatencies <- minLatencies[order(minLatencies$technology),]

                             
# #aggrOthNetLatency <- aggrOthNetLatency[order(aggrOthNetLatency$median_serv_latency),]






