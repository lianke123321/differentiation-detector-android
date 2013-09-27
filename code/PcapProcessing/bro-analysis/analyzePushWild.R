baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
cexVal<-1.6
source(paste(scriptsDir, "/readLogFiles.R", sep=""))

minInterTime <- 30
maxInterTime <- 4000
pushPorts <- c(5223, 5228, 2195, 2196)

#########################################################################################
# The functions used ####################################################################
#########################################################################################
getUserPushInterArrivals <- function (userPushes) {
  userPushes <- userPushes [order(userPushes$ts),]
  cellLst <- c(0)
  wifiLst <- c(0)
  print(nrow(userPushes))
  if (nrow(userPushes) < 2)  {
    return(list(wifiLst=wifiLst, cellLst=cellLst))
  }
  entry <- userPushes[1, ]
  if (entry$id.resp_p %in% pushPorts) {
    prevIP <- entry$id.orig_h # we are the source      
  } else {
    prevIP <- entry$id.resp_h # we are the destination      
  }
  prevTech <- entry$technology
  prevEntry <- entry
  for (i in 2:nrow(userPushes)) {
    entry <- userPushes[i, ]
    if (entry$id.resp_p %in% pushPorts) {
      currIP <- entry$id.orig_h # we are the source
    } else {
      currIP <- entry$id.resp_h # we are the destination
    }
    currTech <- entry$technology
    #if ((currIP == prevIP)| (tech=="c")) {
    # For wifi the same IP is mandatory else for cellular the same technology is mandatory
    if ((currIP == prevIP)| (currTech=="c" & prevTech=="c")) {
      if (currTech =="c") {
        cellLst <- c(cellLst, entry$ts - prevEntry$ts)
      } else { 
        wifiLst <- c(wifiLst, entry$ts - prevEntry$ts)
      }        
    }
    prevEntry <- entry
    prevIP <- currIP;
    prevTech <- currTech
    if (i %% 1000 == 0) {
      print(i)
    }
  }
  print(paste("Done Diff for user"))
  cellLst <- cellLst[(cellLst > minInterTime) & (cellLst < maxInterTime)]
  wifiLst <- wifiLst[(wifiLst > minInterTime) & (wifiLst < maxInterTime)]  
  return(list(wifiLst=wifiLst, cellLst=cellLst))
}

error.bar <- function(x, y, upper, lower=upper, length=0.1,...){
  if(length(x) != length(y) | length(y) !=length(lower) | length(lower) != length(upper))
    stop("vectors must be same length")
  arrows(x,upper, x, lower, angle=90, code=3, length=length, ...)
}

getInterQuantilesList <- function (userPushes) {  
  diffVals <- getUserPushInterArrivals(userPushes)
  cellQuants <- quantile (diffVals$cellLst, seq(0.01, 1, 0.01))  
  attributes(cellQuants)<-NULL
  wifiQuants <- quantile (diffVals$wifiLst, seq(0.01, 1, 0.01))  
  attributes(wifiQuants)<-NULL
  allQuants <- quantile(c(diffVals$wifiLst, diffVals$cellLst), seq(0.01, 1, 0.01))
  attributes(allQuants)<-NULL
  print("Computed the quantiles")
  return(list(cellQuants=cellQuants, wifiQuants=wifiQuants, allQuants=allQuants,
              cellLst=diffVals$cellLst, wifiLst=diffVals$wifiLs, allLst=c(diffVals$wifiLst, diffVals$cellLst)))
}

filterChats <- function(pushTmp) {
  pushiOS <- pushTmp[(pushTmp$operating_system=="i") & 
                      ((pushTmp$id.orig_p == 5223)|(pushTmp$id.resp_p == 5223)),]
  pushAndroid <- pushTmp[(pushTmp$operating_system=="a") &                         
                          ((pushTmp$id.orig_p == 5228)|(pushTmp$id.resp_p == 5228)),]
  pushTmp <- rbind(pushiOS, pushAndroid)
  return(pushTmp)
}
###############################################################################
###################### Plot for the push notifications across devices #########
###############################################################################

# Note this motivates why we take the 80th percentile.
pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
pushInfo <- filterChats(pushInfo)
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
#connUsers <- unique(connSummary$user_id)
sortOrder <- readTable (paste(broAggDir, "devices.sortorder.txt", sep=""))
connUsers <- unique(sortOrder$user_id)
#userInfo <- userInfo[!duplicated(userInfo$user_id), ]

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
iOSCumulCellInterArrivals <-c()
iOSCumulWifiInterArrivals <-c()
iOSCumulAllInterArrivals <-c()
androidCumulCellInterArrivals <-c()
androidCumulWifiInterArrivals <-c()
androidCumulAllInterArrivals <-c()
iOSCnt <-0
AndroidCnt <- 0
for (u in connUsers[order(connUsers)]) {    
  print(paste("Computed the pushes for user", u))
  lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u,])
  os <- sortOrder[sortOrder$user_id==u,]$operating_system  
  if (os == "i") {
    print(paste("Computed the pushes for user", u, "an iOS user"))
    iOSCnt <- iOSCnt + 1;      
    iOSInterArrivals[iOSCnt, ] <- lst$allQuants
    iOSCellInterArrivals[iOSCnt, ] <- lst$cellQuants    
    iOSWifiInterArrivals[iOSCnt, ] <- lst$wifiQuants
    iOSCumulCellInterArrivals <- c(iOSCumulCellInterArrivals, lst$cellLst)
    iOSCumulWifiInterArrivals <- c(iOSCumulWifiInterArrivals, lst$wifiLst)
    iOSCumulAllInterArrivals <- c(iOSCumulAllInterArrivals, lst$allLst)    
  } else {
    print(paste("Computed the pushes for user", u, "an Android user"))
    AndroidCnt <- AndroidCnt + 1;        
    androidInterArrivals [AndroidCnt, ]<- lst$allQuants
    androidCellInterArrivals[AndroidCnt, ] <- lst$cellQuants    
    androidWifiInterArrivals[AndroidCnt, ] <- lst$wifiQuants
    androidCumulCellInterArrivals <- c(androidCumulCellInterArrivals, lst$cellLst)
    androidCumulWifiInterArrivals <- c(androidCumulWifiInterArrivals, lst$wifiLst)
    androidCumulAllInterArrivals <- c(androidCumulAllInterArrivals, lst$allLst)
  }
}
iOSInterArrivals <- getMedianFromMatrix(iOSInterArrivals,iOSCnt)
iOSWifiInterArrivals <- getMedianFromMatrix(iOSWifiInterArrivals, iOSCnt)
iOSCellInterArrivals <- getMedianFromMatrix(iOSCellInterArrivals,iOSCnt)
androidInterArrivals <- getMedianFromMatrix(androidInterArrivals, AndroidCnt)
androidWifiInterArrivals <- getMedianFromMatrix(androidWifiInterArrivals,AndroidCnt)
androidCellInterArrivals <- getMedianFromMatrix(androidCellInterArrivals, AndroidCnt)

pdf(paste(resultsDir, "/push_compare_os_tech_wild_distrib.pdf", sep=""), height=7, width=16, pointsize=25)
mar <- par()$mar
mar[1] <- mar[1]-0.75
mar[2] <- mar[2]+0.5
mar[3] <- 0.25
mar[4] <- 0.25
par(mar=mar)
#xvals <- knots(ecdf(androidCellInterArrivals))
#xvals <- androidCellInterArrivals
xvals <- knots(ecdf(androidCumulCellInterArrivals))
yvals <- (1:length(xvals))/length(xvals)     
majorx <- seq(0, 3600, 1000)
minorx <- seq(0, 3600, 100)
majory <- seq(0, 1, 0.2)
minory <- seq(0, 1, 0.02)
plot(xvals, yvals, xlim=c(0,3600), type="l", lty=1, lwd=6,
     xaxt="n", yaxt="n",
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Time between push notifications (seconds)",     
     ylab="CDF")
axis(1, at=majorx, label=majorx, cex.axis=cexVal, cex.lab=cexVal)
axis(2, at=majory, label=majory, cex.axis=cexVal, cex.lab=cexVal, las=1)
par(tcl=0.22)
axis(1, at=minorx, label=F)
axis(2, at=minory, label=F)
#xvals <- androidWifiInterArrivals
xvals <- knots(ecdf(androidCumulWifiInterArrivals))
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=2, lwd=6)
#xvals <- iOSCellInterArrivals
xvals <- knots(ecdf(iOSCumulCellInterArrivals))
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=3, lwd=6)
#xvals <- iOSWifiInterArrivals
xvals <- knots(ecdf(iOSCumulWifiInterArrivals))
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=4, lwd=6)
grid(lwd=3)
legend(2000, 0.8, legend=c("Wi-fi (iOS)", "Cell (iOS)", "Wi-fi (Android)", "Cell (Android)"), cex=cexVal,
       lty=c(4, 3, 2,1), lwd=6)
dev.off()

######################################################################################
############### Night time analysis of push notifications ############################
######################################################################################
pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
pushInfo <- filterChats(pushInfo)
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
connUsers <- unique(connSummary$user_id)
userInfo <- readTable (paste(miscDataDir, "userInfo.txt", sep=""))
userInfo <- userInfo[!duplicated(userInfo$user_id), ]

iOSNightInterArrivals <- matrix(0, nrow=length(connUsers), ncol=100)
iOSOtherInterArrivals<-iOSNightInterArrivals
androidNightInterArrivals <- iOSNightInterArrivals
androidOtherInterArrivals <- iOSNightInterArrivals
iOSCumulNightInterArrivals <- c()
iOSCumulOtherInterArrivals <- c()
androidCumulNightInterArrivals <-c() 
androidCumulOtherInterArrivals <- c() 

iOSCnt <- 0
AndroidCnt <- 0
for (u in connUsers[order(connUsers)]) {      
  os <- sortOrder[sortOrder$user_id==u,]$operating_system  
  if (os == "i") {    
    iOSCnt <- iOSCnt + 1  
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & (pushInfo$hour >= 3 & pushInfo$hour<6),])
    iOSNightInterArrivals[iOSCnt, ] <- lst$allQuants
    iOSCumulNightInterArrivals <- c(iOSCumulNightInterArrivals, lst$allLst)
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & (pushInfo$hour< 3 | pushInfo$hour>=6),])
    iOSOtherInterArrivals[iOSCnt, ] <- lst$allQuants
    iOSCumulOtherInterArrivals <- c(iOSCumulOtherInterArrivals, lst$allLst)
  } else {    
    AndroidCnt <- AndroidCnt + 1;
    lst <- getInterQuantilesList(pushInfo[pushInfo$user_id==u & (pushInfo$hour >= 3 & pushInfo$hour<6),])
    androidNightInterArrivals[AndroidCnt,] <- lst$allQuants    
    androidCumulNightInterArrivals <- c(androidCumulNightInterArrivals, lst$allLst)
    lst <-  getInterQuantilesList(pushInfo[pushInfo$user_id==u & (pushInfo$hour< 3 | pushInfo$hour>=6),])
    androidOtherInterArrivals[AndroidCnt,] <- lst$allQuants
    androidCumulOtherInterArrivals <- c(androidCumulOtherInterArrivals, lst$allLst)
  }
}

iOSNightInterArrivals <- getMedianFromMatrix(iOSNightInterArrivals,iOSCnt)
iOSOtherInterArrivals <- getMedianFromMatrix(iOSOtherInterArrivals, iOSCnt)
androidNightInterArrivals <- getMedianFromMatrix(androidNightInterArrivals, AndroidCnt)
androidOtherInterArrivals <- getMedianFromMatrix(androidOtherInterArrivals, AndroidCnt)

pdf(paste(resultsDir, "/push_compare_diurnal_wild_distrib.pdf", sep=""), height=7, width=16, pointsize=25)
mar <- par()$mar
mar[1] <- mar[1]-0.75
mar[2] <- mar[2]+0.5
mar[3] <- 0.25
mar[4] <- 0.25
par(mar=mar)
#xvals <- knots(ecdf(iOSNightInterArrivals))
#xvals <- iOSNightInterArrivals
xvals <- knots(ecdf(iOSCumulNightInterArrivals))
yvals <- (1:length(xvals))/length(xvals)     
plot(xvals, yvals, xlim=c(0,3600), type="l", lty=4, lwd=5,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     las=1, xaxt="n", yaxt="n",
     xlab="Time between push notifications (seconds)",
     ylab="CDF")
axis(1, at=majorx, label=majorx, cex.axis=cexVal, cex.lab=cexVal)
axis(2, at=majory, label=majory, cex.axis=cexVal, cex.lab=cexVal, las=1)
par(tcl=0.22)
axis(1, at=minorx, label=F)
axis(2, at=minory, label=F)
#xvals <- androidNightInterArrivals
xvals <- knots(ecdf(androidCumulNightInterArrivals))
yvals <- (1:length(xvals))/length(xvals)     
lines(xvals, yvals,lty=2, lwd=5)
#xvals <- iOSOtherInterArrivals
xvals <- knots(ecdf(iOSCumulOtherInterArrivals))
yvals <- (1:length(xvals))/length(xvals)    
lines(xvals, yvals,lty=3, lwd=6)
#xvals <- androidOtherInterArrivals
xvals <- knots(ecdf(androidCumulOtherInterArrivals))
yvals <- (1:length(xvals))/length(xvals)  
lines(xvals, yvals,lty=1, lwd=5)
grid(lwd=3)
legend(2000, 0.8, legend=c("Night (iOS)", "Day (iOS)", "Night (Android)", "Day (Android)"), cex=cexVal,
       lty=c(4, 3, 2,1), lwd=5)
dev.off()

################################################################################
####################### Volume of cell and wifi dur to Notifications ###########
################################################################################

pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
#connUsers <- unique(connSummary$user_id)
sortOrderTable <- readTable (paste(broAggDir, "devices.sortorder.txt", sep=""))
numIOS <- nrow(sortOrderTable[sortOrderTable$operating_system=="i",])

pushInfo$tot_bytes <- convertStringColsToDouble(pushInfo$orig_ip_bytes) + convertStringColsToDouble(pushInfo$resp_ip_bytes)
pushInfo$num_flows <- 1
connSummary$tot_bytes <- convertStringColsToDouble(connSummary$orig_ip_bytes) + convertStringColsToDouble(connSummary$resp_ip_bytes)
connSummary$num_flows <- 1
totAggr <- aggregate(connSummary[c("tot_bytes","num_flows")],
                    by=list(user_id=connSummary$user_id, 
                            operating_system=connSummary$operating_system),
                    FUN=sum)
pushAggr <- aggregate(pushInfo[c("tot_bytes", "num_flows")],
                      by=list(user_id=pushInfo$user_id, operating_system=pushInfo$operating_system),
                      FUN=sum)
colnames(pushAggr) <- gsub("num_flows", "push_flows", colnames(pushAggr))
colnames(pushAggr) <- gsub("tot_bytes", "push_bytes", colnames(pushAggr))
pushAggr <- merge(x=pushAggr, y=sortOrderTable, by=c("user_id", "operating_system"))
pushAggr$tot_bytes <- NULL;
pushAggr <- merge(x=pushAggr, y=totAggr, by=c("user_id", "operating_system"))
pushAggr <- pushAggr[(order(pushAggr$sort_order)),]
pushAggr$frac_bytes <- pushAggr$push_bytes/pushAggr$tot_bytes
pushAggr[pushAggr$frac_bytes > 0.05, ]$frac_bytes <- 0.05

cellSummary <- connSummary[connSummary$technology=="c", ]
totCellAggr <- aggregate(cellSummary[c("tot_bytes","num_flows")],
                     by=list(user_id=cellSummary$user_id,                              
                             operating_system=cellSummary$operating_system),
                     FUN=sum)
pushCellInfo <- pushInfo[pushInfo$technology=="c",]
pushCellAggr <- aggregate(pushCellInfo[c("tot_bytes", "num_flows")],
                          by=list(user_id=pushCellInfo$user_id, operating_system=pushCellInfo$operating_system),
                          FUN=sum)
colnames(pushCellAggr) <- gsub("num_flows", "push_flows", colnames(pushCellAggr))
colnames(pushCellAggr) <- gsub("tot_bytes", "push_bytes", colnames(pushCellAggr))
pushCellAggr <- merge(x=pushCellAggr, y=sortOrderTable, by=c("user_id", "operating_system"))
pushCellAggr$tot_bytes <- NULL;
pushCellAggr <- merge(x=pushCellAggr, y=totCellAggr, by=c("user_id", "operating_system"))
pushCellAggr <- pushCellAggr[(order(pushCellAggr$sort_order)),]
pushCellAggr$frac_bytes <- pushCellAggr$push_bytes/pushCellAggr$tot_bytes
pushCellAggr[pushCellAggr$frac_bytes > 0.06, ]$frac_bytes <- 0.06

pdf(paste(resultsDir, "/push_compare_trafficshare.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[2] <- mar[2]+0.5
mar[3] <- 0.75
mar[4] <- 0.25
par(mar=mar)
plot(pushAggr$sort_order, pushAggr$frac_bytes, pch=0, xlim=c(1,max(pushAggr$sort_order)), las=1,
     ylim=c(0,0.08), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     yaxt="n",
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="Notification Traffic Share")
axis(2, at=seq(0,0.08,0.02), labels=seq(0,0.08,0.02), 
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,nrow(pushAggr),1), labels=F)
axis(2, at=seq(0,0.08,0.005), labels=F)
points(pushCellAggr$sort_order, pushCellAggr$frac_bytes, pch=1, cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.04, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.04, "Android", cex=cexVal, adj=0)
grid(lwd=3)
legend(1,0.08, c("All (volume)", "Cellular (volume)"),
       pch=c(0,1,2), cex=cexVal)
dev.off()


################################################################################
####################### Source of Notifications ################################
################################################################################

pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info.dns",sep=""))
pushInfo$num_flows <- 1
pushAggr <- aggregate(pushInfo[c("num_flows")],
                      by=list(operating_system=pushInfo$operating_system,
                              dns_first_fqdn=pushInfo$dns_first_fqdn),
                      FUN=sum)
                      

# ###############################################################################
# ###################### Plot for the median push notifications #################
# ###############################################################################
# pushInfo <- readConnData(paste(broAggDir, "filter.push.conn.log.info",sep=""))
# connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
# connUsers <- unique(connSummary$user_id)
# userInfo <- readTable (paste(miscDataDir, "userInfo.txt", sep=""))
# userInfo <- userInfo[!duplicated(userInfo$user_id), ]
# dummy <- c(0)
# 
# getMedianInterArrival <- function (userPushes, tech="w") {  
#   # Note we return the 80% percentile despite the name
#   diffVals <- getUserPushInterArrivals(userPushes, tech)
#   x <- quantile(diffVals, c(0.10, 0.25, 0.5, 0.8, 0.90))
#   return(x[4])
# }
# 
# userInterArrivals <- data.frame(user_id=connUsers, median=0, median_cell=0, median_wifi=0)
# for (u in connUsers)  {  
#   print(u)
#   result <- c(u, 
#               getMedianInterArrival(pushInfo[pushInfo$user_id==u,]),
#               getMedianInterArrival(pushInfo[pushInfo$user_id==u & pushInfo$technology=="c",], "c"),
#               getMedianInterArrival(pushInfo[pushInfo$user_id==u & pushInfo$technology=="w",]))
#   userInterArrivals[userInterArrivals$user_id==u,]<-result
# }
# 
# userInterArrivals <- merge(x=userInterArrivals, y=userInfo, by="user_id")
# userInterArrivals <- userInterArrivals[ order(userInterArrivals$median), ]
# iOSInterArrivals <- userInterArrivals[userInterArrivals$operating_system=="iOS",]
# iOSInterArrivals$sortOrder <- 1:nrow(iOSInterArrivals)
# andInterArrivals <- userInterArrivals[userInterArrivals$operating_system=="Android",]
# andInterArrivals$sortOrder <- nrow(iOSInterArrivals)+1:nrow(andInterArrivals)
# userInterArrivals <- rbind(iOSInterArrival, androidInterArrivals)
# write.table(userInterArrivals, paste(resultsDir, "userInterArrivals.txt", sep=""),
#             sep="\t", quote=F, col.names=c(colnames(userInterArrivals)), row.names=FALSE)
# 
# 
# pdf(paste(resultsDir, "/push_inter_arrival_wild.pdf", sep=""), height=10, width=16, pointsize=25)
# mar <- par()$mar
# mar[4] <- 0.5
# par(mar=mar)
# plot(iOSInterArrivals$sortOrder, iOSInterArrivals$median,
#      xlim=c(0, nrow(userInterArrivals)),
#      ylim=c(0, 2500), 
#      xlab="Device ID (orded by OS and time between notifications)",
#      ylab="Time (seconds)",         
#      cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
#      pch=1);
# par(tcl=0.22)
# axis(1, at=seq(0,nrow(userInterArrivals), 1), label=F)
# axis(2, at=seq(0, 2500, 100), label=F)
# title("80th percentile of time between push notifications",cex=cexVal)
# points(andInterArrivals$sortOrder, andInterArrivals$median,
#        pch=1, cex=cexVal);
# points(iOSInterArrivals$sortOrder, iOSInterArrivals$median_cell,
#      pch=2, cex=cexVal);
# points(andInterArrivals$sortOrder, andInterArrivals$median_cell,
#        pch=2, cex=cexVal);
# points(iOSInterArrivals$sortOrder, iOSInterArrivals$median_wifi,
#        pch=3, cex=cexVal);
# points(andInterArrivals$sortOrder, andInterArrivals$median_wifi,
#        pch=3, cex=cexVal);
# #error.bar(iOSInterArrivals$sortOrder, iOSInterArrivals$p50, iOSInterArrivals$p25, iOSInterArrivals$p75)
# #error.bar(andInterArrivals$sortOrder, andInterArrivals$p50, andInterArrivals$p25, andInterArrivals$p75)
# grid(lwd=3)
# legend(nrow(iOSInterArrivals)+1, 2500, legend=c("All", "Cell", "Wi-Fi"),
#        pch=c(1, 2, 3), cex=cexVal)
# #arrows(14.5, 0, 14.5, 200,code=0)
# #arrows(14, 100, 10, 100,code=2)
# #arrows(15, 100, 19, 100,code=2)
# abline(v=nrow(iOSInterArrivals)+0.5, h=NULL, lty=2,lwd=5, col="black")
# text(nrow(iOSInterArrivals), 300, "iOS", cex=cexVal, adj=1)
# text(nrow(iOSInterArrivals)+1, 300, "Android", cex=cexVal, adj=0)
# dev.off()


# xvals <- androidInterArrivals
# yvals <- (1:length(xvals))/length(xvals)     
# plot(xvals, yvals, xlim=c(0,5000), type="l", lty=1, lwd=3,
#      cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)     
# #xvals <- knots(ecdf(androidCellInterArrivals))
# xvals <- androidCellInterArrivals
# yvals <- (1:length(xvals))/length(xvals)     
# lines(xvals, yvals,lty=2, lwd=5)
# xvals <- androidWifiInterArrivals
# yvals <- (1:length(xvals))/length(xvals)     
# lines(xvals, yvals,lty=3, lwd=4)
# legend(1500, 0.6, legend=c("All", "Cell", "Wi-Fi"), cex=cexVal,
#        lty=c(1, 2, 3), lwd=5)
# xvals <- iOSInterArrivals
# yvals <- (1:length(xvals))/length(xvals)     
# plot(xvals, yvals,xlim=c(0,5000), type="l", lty=1, lwd=4,
#      cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)  
# xvals <- iOSCellInterArrivals
# yvals <- (1:length(xvals))/length(xvals)     
# lines(xvals, yvals,lty=2, lwd=5)
# xvals <- iOSWifiInterArrivals
# yvals <- (1:length(xvals))/length(xvals)     
# lines(xvals, yvals,lty=3, lwd=5)
# legend(1500, 0.6, legend=c("All", "Cell", "Wi-Fi"), cex=cexVal,
#        lty=c(1, 2, 3), lwd=5)
# 
# 
# #xvals <- knots(ecdf(androidCumulCellInterArrivals))
# yvals <- (1:length(xvals))/length(xvals)     
# plot(xvals, yvals, type="l", lty=2, lwd=3)
# xvals <- knots(ecdf(iOSCumulCellInterArrivals))
# yvals <- (1:length(xvals))/length(xvals)     
# lines(xvals, yvals,lty=3, lwd=5)