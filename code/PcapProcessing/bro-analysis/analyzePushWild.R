baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
cexVal<-1.5
source(paste(scriptsDir, "/readLogFiles.R", sep=""))

minInterTime <- 30
maxInterTime <- 5000
pushPorts <- c(5223, 5228, 2195, 2196)

getUserPushInterArrivals <- function (userPushes, tech="w") {
  diffVals <- c(0)
  userPushes <- userPushes [order(userPushes$ts),]
  print(nrow(userPushes))
  if (nrow(userPushes) > 2)  {
    entry <- userPushes[1, ]
    if (entry$id.resp_p %in% pushPorts) {
      prevIP <- entry$id.orig_h # we are the source
    } else {
      prevIP <- entry$id.resp_h # we are the destination
    }
    prevEntry <- entry
    for (i in 2:nrow(userPushes)) {
      entry <- userPushes[i, ]
      if (entry$id.resp_p %in% pushPorts) {
        currIP <- entry$id.orig_h # we are the source
      } else {
        currIP <- entry$id.resp_h # we are the destination
      }
      if ((currIP == prevIP)| (tech=="c")) {
        diffVals <- c(diffVals, entry$ts - prevEntry$ts)
      }
      prevEntry <- entry
      prevIP <- currIP;
      if (i %% 1000 == 0) {
        print(i)
      }
    }
    print("Done Diff")
    diffVals <- diffVals [(diffVals>minInterTime) & (diffVals<maxInterTime)]  
  } else {
    diffVals <- c(0)
  }
  return(diffVals)
}


error.bar <- function(x, y, upper, lower=upper, length=0.1,...){
  if(length(x) != length(y) | length(y) !=length(lower) | length(lower) != length(upper))
    stop("vectors must be same length")
  arrows(x,upper, x, lower, angle=90, code=3, length=length, ...)
}

getInterQuantilesList <- function (userPushes, tech="w") {  
  diffVals <- getUserPushInterArrivals(userPushes, tech)
  quants <- quantile (diffVals, seq(0.01, 1, 0.01))  
  attributes(quants)<-NULL
  return(quants)
}

###############################################################################
###################### Plot for the push notifications across devices #########
###############################################################################

# Note this motivates why we take the 80th percentile.
pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
connUsers <- unique(connSummary$user_id)
userInfo <- readTable (paste(miscDataDir, "userInfo.txt", sep=""))
userInfo <- userInfo[!duplicated(userInfo$user_id), ]

getMedianFromMatrix <- function(mat, nrow) {
  mat <- mat[1:nrow, ]
  mat[is.na(mat)] <-0
  mat <- mat[mat[,100]>0, ]
  # Get the median of each column. 
  # Each column in the mean
  x<-apply(mat, 2, median)  
  return(x)
}

iOSInterArrivals <- matrix(0, nrow=length(connUsers), ncol=100)
iOSCellInterArrivals <- iOSInterArrivals
iOSWifiInterArrivals <- iOSInterArrivals
androidInterArrivals <- iOSInterArrivals
androidCellInterArrivals <- iOSInterArrivals
androidWifiInterArrivals <- iOSInterArrivals
iOSCnt <-0
AndroidCnt <- 0
for (u in connUsers) {  
  print(u)
  lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u,])
  os <- userInfo[userInfo$user_id==u,]$operating_system  
  if (os == "iOS") {
    iOSCnt <- iOSCnt + 1;
    iOSInterArrivals[iOSCnt, ] <- lst
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$technology=="c",],"c")
    iOSCellInterArrivals[iOSCnt, ] <- lst
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$technology=="w",])
    iOSWifiInterArrivals[iOSCnt, ] <- lst
  } else {
    AndroidCnt <- AndroidCnt + 1;
    androidInterArrivals [AndroidCnt, ]<- lst
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$technology=="c",],"c")
    androidCellInterArrivals[AndroidCnt, ] <- lst
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$technology=="w",])
    androidWifiInterArrivals[AndroidCnt, ] <- lst
  }
}
iOSInterArrivals <- getMedianFromMatrix(iOSInterArrivals,iOSCnt)
iOSWifiInterArrivals <- getMedianFromMatrix(iOSWifiInterArrivals, iOSCnt)
iOSCellInterArrivals <- getMedianFromMatrix(iOSCellInterArrivals,iOSCnt)
androidInterArrivals <- getMedianFromMatrix(androidInterArrivals, AndroidCnt)
androidWifiInterArrivals <- getMedianFromMatrix(androidWifiInterArrivals,AndroidCnt)
androidCellInterArrivals <- getMedianFromMatrix(androidCellInterArrivals, AndroidCnt)

xvals <- androidInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
plot(xvals, yvals, xlim=c(0,5000), type="l", lty=1, lwd=3,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)     
#xvals <- knots(ecdf(androidCellInterArrivals))
xvals <- androidCellInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=2, lwd=5)
xvals <- androidWifiInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=3, lwd=4)
legend(1500, 0.6, legend=c("All", "Cell", "Wi-Fi"), cex=cexVal,
       lty=c(1, 2, 3), lwd=5)
xvals <- iOSInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
plot(xvals, yvals,xlim=c(0,5000), type="l", lty=1, lwd=4,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)  
xvals <- iOSCellInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=2, lwd=5)
xvals <- iOSWifiInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=3, lwd=5)
legend(1500, 0.6, legend=c("All", "Cell", "Wi-Fi"), cex=cexVal,
       lty=c(1, 2, 3), lwd=5)

pdf(paste(resultsDir, "/cdf_push_comparison_device_wild.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <- 0.5
par(mar=mar)
#xvals <- knots(ecdf(androidCellInterArrivals))
xvals <- androidCellInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
majorx <- seq(0, 5000, 1000)
minorx <- seq(0, 5000, 100)
majory <- seq(0, 1, 0.2)
minory <- seq(0, 1, 0.02)
plot(xvals, yvals, xlim=c(0,5000), type="l", lty=1, lwd=5,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Time between push notifications (seconds)",
     las=1,
     ylab="CDF")
par(tcl=0.22)
axis(1, at=minorx, label=F)
axis(2, at=minory, label=F)
xvals <- androidWifiInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=2, lwd=5)
xvals <- iOSCellInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=3, lwd=5)
xvals <- iOSWifiInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=4, lwd=5)
grid(lwd=3)
legend(1500, 0.6, legend=c("Cell (Android)", "Wi-fi (Android)", "Cell (iOS)", "Wi-fi (iOS)"), cex=cexVal,
       lty=c(1, 2, 3,4), lwd=5)
dev.off()

###############################################################################
###################### Plot for the median push notifications #################
###############################################################################
pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
connUsers <- unique(connSummary$user_id)
userInfo <- readTable (paste(miscDataDir, "userInfo.txt", sep=""))
userInfo <- userInfo[!duplicated(userInfo$user_id), ]
dummy <- c(0)

getMedianInterArrival <- function (userPushes, tech="w") {  
  # Note we return the 80% percentile despite the name
  diffVals <- getUserPushInterArrivals(userPushes, tech)
  x <- quantile(diffVals, c(0.10, 0.25, 0.5, 0.8, 0.90))
  return(x[4])
}

userInterArrivals <- data.frame(user_id=connUsers, median=0, median_cell=0, median_wifi=0)
for (u in connUsers)  {  
  print(u)
  result <- c(u, 
              getMedianInterArrival(pushInfo[pushInfo$user_id==u,]),
              getMedianInterArrival(pushInfo[pushInfo$user_id==u & pushInfo$technology=="c",], "c"),
              getMedianInterArrival(pushInfo[pushInfo$user_id==u & pushInfo$technology=="w",]))
  userInterArrivals[userInterArrivals$user_id==u,]<-result
}

userInterArrivals <- merge(x=userInterArrivals, y=userInfo, by="user_id")
userInterArrivals <- userInterArrivals[ order(userInterArrivals$median), ]
iOSInterArrivals <- userInterArrivals[userInterArrivals$operating_system=="iOS",]
iOSInterArrivals$sortOrder <- 1:nrow(iOSInterArrivals)
andInterArrivals <- userInterArrivals[userInterArrivals$operating_system=="Android",]
andInterArrivals$sortOrder <- nrow(iOSInterArrivals)+1:nrow(andInterArrivals)
userInterArrivals <- rbind(iOSInterArrival, androidInterArrivals)
write.table(userInterArrivals, paste(resultsDir, "userInterArrivals.txt", sep=""),
            sep="\t", quote=F, col.names=c(colnames(userInterArrivals)), row.names=FALSE)


pdf(paste(resultsDir, "/push_inter_arrival_wild.pdf", sep=""), height=10, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(iOSInterArrivals$sortOrder, iOSInterArrivals$median,
     xlim=c(0, nrow(userInterArrivals)),
     ylim=c(0, 2500), 
     xlab="Device ID (orded by OS and time between notifications)",
     ylab="Time (seconds)",         
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     pch=1);
par(tcl=0.22)
axis(1, at=seq(0,nrow(userInterArrivals), 1), label=F)
axis(2, at=seq(0, 2500, 100), label=F)
title("80th percentile of time between push notifications",cex=cexVal)
points(andInterArrivals$sortOrder, andInterArrivals$median,
       pch=1, cex=cexVal);
points(iOSInterArrivals$sortOrder, iOSInterArrivals$median_cell,
     pch=2, cex=cexVal);
points(andInterArrivals$sortOrder, andInterArrivals$median_cell,
       pch=2, cex=cexVal);
points(iOSInterArrivals$sortOrder, iOSInterArrivals$median_wifi,
       pch=3, cex=cexVal);
points(andInterArrivals$sortOrder, andInterArrivals$median_wifi,
       pch=3, cex=cexVal);
#error.bar(iOSInterArrivals$sortOrder, iOSInterArrivals$p50, iOSInterArrivals$p25, iOSInterArrivals$p75)
#error.bar(andInterArrivals$sortOrder, andInterArrivals$p50, andInterArrivals$p25, andInterArrivals$p75)
grid(lwd=3)
legend(nrow(iOSInterArrivals)+1, 2500, legend=c("All", "Cell", "Wi-Fi"),
       pch=c(1, 2, 3), cex=cexVal)
#arrows(14.5, 0, 14.5, 200,code=0)
#arrows(14, 100, 10, 100,code=2)
#arrows(15, 100, 19, 100,code=2)
abline(v=nrow(iOSInterArrivals)+0.5, h=NULL, lty=2,lwd=5, col="black")
text(nrow(iOSInterArrivals), 300, "iOS", cex=cexVal, adj=1)
text(nrow(iOSInterArrivals)+1, 300, "Android", cex=cexVal, adj=0)
dev.off()
######################################################################################
############### Night time analysis of push notifications ############################
######################################################################################
pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
connUsers <- unique(connSummary$user_id)
userInfo <- readTable (paste(miscDataDir, "userInfo.txt", sep=""))
userInfo <- userInfo[!duplicated(userInfo$user_id), ]

iOSNightInterArrivals <- matrix(0, nrow=length(connUsers), ncol=100)
iOSOtherInterArrivals<-iOSNightInterArrivals
androidNightInterArrivals <- iOSNightInterArrivals
androidOtherInterArrivals <- iOSNightInterArrivals
iOSCnt <- 0
AndroidCnt <- 0
for (u in connUsers) {    
  os <- userInfo[userInfo$user_id==u,]$operating_system  
  if (os == "iOS") {    
    iOSCnt <- iOSCnt + 1
    iOSNightInterArrivals[iOSCnt, ] <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$hour<6,])
    iOSOtherInterArrivals[iOSCnt, ] <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$hour>=6,])
  } else {    
    AndroidCnt <- AndroidCnt + 1;
    androidNightInterArrivals[AndroidCnt,] <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$hour<6,])
    androidOtherInterArrivals[AndroidCnt,] <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & pushInfo$hour>=6,])
  }
}

iOSNightInterArrivals <- getMedianFromMatrix(iOSNightInterArrivals,iOSCnt)
iOSOtherInterArrivals <- getMedianFromMatrix(iOSOtherInterArrivals, iOSCnt)
androidNightInterArrivals <- getMedianFromMatrix(androidNightInterArrivals, AndroidCnt)
androidOtherInterArrivals <- getMedianFromMatrix(androidOtherInterArrivals, AndroidCnt)

pdf(paste(resultsDir, "/cdf_night_push_comparison_device_wild.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <- 0.5
par(mar=mar)
#xvals <- knots(ecdf(iOSNightInterArrivals))
xvals <- iOSNightInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
plot(xvals, yvals, xlim=c(0,5000), type="l", lty=1, lwd=5,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     las=1, 
     xlab="Time between push notifications (seconds)",
     ylab="CDF")
par(tcl=0.22)
axis(1, at=seq(0, 5000, 100), label=F)
axis(2, at=seq(0, 1, 0.02), label=F)
xvals <- androidNightInterArrivals
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=2, lwd=5)
xvals <- iOSOtherInterArrivals
yvals <- (1:length(xvals))/length(xvals)    
lines(xvals, yvals,lty=3, lwd=5)
xvals <- androidOtherInterArrivals
yvals <- (1:length(xvals))/length(xvals)  
lines(xvals, yvals,lty=4, lwd=5)
grid(lwd=3)
legend(1500, 0.6, legend=c("Night (iOS)", "Night (Android)", "Day (iOS)", "Day (Android)"), cex=cexVal,
       lty=c(1, 2, 3,4), lwd=5)
dev.off()
