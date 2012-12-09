baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
opar = par();

newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);
#par(cex=1.5, xaxs="i", yaxs="i",lwd=3)
#par = opar;


convertStringColsToDouble <- function (stringCol) {
   stringCol <- as.double(stringCol)
   stringCol[is.na(stringCol)] <-0;
   stringCol;
}
 
computeAggregateConnMeta <- function(connData) {
   x <- connData;
   print("Processing")
   # POST PROCESSING BASED ON PORT VALUES
   
   x[(x$proto=="tcp" & (x$id.resp_p==443 | x$id.resp_p==5228 | x$id.resp_p== 8883 | x$id.resp_p==5222 |  x$id.resp_p == 1237 | x$id.resp_p == 993 | x$id.resp_p == 995| x$id.resp_p == 7275)),]$service = "ssl"
   x[(x$proto=="tcp" & (x$id.orig_p==443 | x$id.orig_p==5228 | x$id.orig_p== 8883 | x$id.orig_p==5222 |  x$id.orig_p == 1237 | x$id.orig_p == 993 | x$id.orig_p == 995| x$id.orig_p == 7275)),]$service = "ssl"
     
   #TODO:: What about VNC??
   x[(x$proto=="tcp" & x$id.resp_p ==5900),]$service = "ssl"
   
   x[(x$proto=="tcp") & (x$id.resp_p==5223) & (x$oper_sys=="iOS"),]$service="ssl"
   
   # next line fails for current data set
   #x[(x$proto=="tcp") & (x$id.orig_p==5223) & (x$oper_sys=="iOS"),]$service="ssl"
   
   # 5228 gtalk android
   # 8882 mqtt ssl 
   x[(x$proto=="tcp" & x$id.resp_p==80),]$service = "http"
   #x[(x$proto=="tcp" & x$id.orig_p==80),]$service = "http"
   
   y<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],
                by=list(user_id=x$user_id, as=x$as, isp_info=x$isp_info, oper_sys=x$oper_sys, technology=x$technology, proto=x$proto, service=x$service, technology=x$technology), 
                FUN=sum)
   z<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],
                by=list(user_id=x$user_id, as=x$as, isp_info=x$isp_info, oper_sys=x$oper_sys, technology=x$technology, proto=x$proto, service=x$service, technology=x$technology), 
                FUN=length)
   
   y$num_flows <- z$orig_pkts;
   y
}

createAndSaveConnMeta <- function () {
  userDir <- broAggDir;
  fName <- paste(userDir, "/conn.log.ann", sep="");
  print("Read file")
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts);   
  connMeta <- computeAggregateConnMeta(connData) 
  fName <- paste(userDir, "/connAggr.txt", sep="");
  write.table(connMeta, fName, sep="\t", quote=F, col.names=c(colnames(connMeta)), row.names=FALSE)
}

getAggrTableForPlots <- function () {
  userDir <- broAggDir;
  fName <- paste(userDir, "/connAggr.txt", sep="");
  aggrData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  x <- aggrData;
  x$resp_ip_bytes <- convertStringColsToDouble(x$resp_ip_bytes);
  x$orig_ip_bytes <- convertStringColsToDouble(x$orig_ip_bytes);
  x$resp_pkts <- convertStringColsToDouble(x$resp_pkts);
  x$orig_pkts <- convertStringColsToDouble(x$orig_pkts);
  
  x[(x$proto=="tcp") & (x$service!="ssl") & (x$service!="http"),]$service = "other"
  x[(x$proto=="udp"),]$service = ""
  x[(x$proto!="udp") & (x$proto != "tcp"),]$proto = "other"
  x[(x$proto=="other"),]$service = ""
  x$sort_order <- rep(1000, nrow(x));
  x[(x$proto=="tcp") & (x$service == "http"),]$sort_order<-1
  x[(x$proto=="tcp") & (x$service == "ssl"),]$sort_order<-2
  x[(x$proto=="udp"), ]$sort_order<-3
  x[(x$proto=="tcp") & (x$service == "other"), ]$sort_order<-4
  x[(x$proto=="other"), ]$sort_order<-5
  tmpx <- x;
  tmpx$upanddown <- tmpx$orig_ip_bytes + tmpx$resp_ip_bytes
  userSum <- aggregate(tmpx[c("upanddown")], by=list(user_id=tmpx$user_id), FUN=sum)
  newTab <- NULL;
  # Filter users how have contributed less than 150 MB
  for (user_id in userSum$user_id) {
    userentries <- x[x$user_id ==user_id,];
    if (sum(userSum[userSum$user_id == user_id,]$upanddown) < (150*10^6)) {
      print(paste("Removing entries for",user_id));
      next;
    }
    newTab <- rbind(newTab, userentries)
  }
  x <- newTab;
  x;
}

plotFractionFlows <- function (x) {
  #x is table of connAggr.txt with modifications based on port and service 
  osList <- c("Android", "iOS")
  ytot <- NULL;
  i<-1
  for (os in osList) {
    tmpx <- x[x$oper_sys == os, ]
    tmpx$upanddown <- tmpx$orig_ip_bytes + tmpx$resp_ip_bytes
    tmpy<-aggregate(tmpx[c("num_flows")],
                    by=list(oper_sys=tmpx$oper_sys, proto=tmpx$proto, service=tmpx$service, sort_order=tmpx$sort_order), 
                    FUN=sum)
    tmpy$num_flows = tmpy$num_flows/sum(tmpy$num_flows)
    tmpy <- tmpy[order(tmpy$sort_order),] 
    
    tmpybytes <- aggregate(tmpx[c("upanddown")],
                          by=list(oper_sys=tmpx$oper_sys, proto=tmpx$proto, service=tmpx$service, sort_order=tmpx$sort_order), 
                          FUN=sum)
    tmpybytes$upanddown = tmpybytes$upanddown/sum(tmpybytes$upanddown)
    tmpybytes <- tmpybytes[order(tmpybytes$sort_order),]
    tmpy$upanddown <- tmpybytes$upanddown
    
    ytot[[i]] <- tmpy;
    i<-i+1;
  }
  xval <- paste(tmpy$proto, tmpy$service)
  yval <- ytot[[1]]$upanddown;
  #pdf(file=paste(plotsDir,"deviceTrafficShare.pdf", sep=""));
  tiff(file=paste(plotsDir,"deviceTrafficShare.tiff", sep=""))
  par(newpar);
  plot(1:length(xval), yval, pch=1, xlim=c(1,length(xval)), ylim=c(0,1),
       xaxt="n", xaxs="r", yaxs="r",
       xlab="Protocol", ylab="Fraction of data traffic");
  yval <- ytot[[2]]$upanddown;
  points(1:length(xval), yval, pch=2)
  
  yval <- ytot[[1]]$num_flows;
  points(1:length(xval), yval, pch=3)

  yval <- ytot[[2]]$num_flows;
  points(1:length(xval), yval, pch=4)
  
  axis(1, at=1:length(xval), lab=xval, las=1)
  # Grid before legend to avoid grid inside the legend
  grid(lwd=2)
  legendText <- c("Android (Volume)", "iOS (Volume)", "Android (Flows)", "iOS (Flows)")
  legend(x=2,y=1,legend=legendText, pch=c(1,2,3,4), box.lwd=1)
  dev.off()
  ytot;
}

plotTechUploadDownloads <- function (x) {
  #techList <- unique(x$technology) 
  #techList <- techList[techList!= "Unknown"];
  techList <- c("Wi-Fi", "Cellular");
  ytot <- NULL;
  i<-1
  for (tech in techList) {
    if (tech == "Unknown" ) {
      next;
    }
    tmpx <- x[x$technology == tech, ]
    tmpx$upanddown <- tmpx$orig_ip_bytes + tmpx$resp_ip_bytes
    tmpy<-aggregate(tmpx[c("orig_ip_bytes", "resp_ip_bytes", "upanddown")],
                    by=list(proto=tmpx$proto, service=tmpx$service, sort_order=tmpx$sort_order), 
                    FUN=sum)
    tmpy <- tmpy[order(tmpy$sort_order),] 
    totbytes <- sum(tmpy$upanddown);
    tmpy$orig_ip_bytes <- tmpy$orig_ip_bytes/totbytes;
    tmpy$resp_ip_bytes <- tmpy$resp_ip_bytes/totbytes;
    tmpy$upanddown <- tmpy$upanddown/totbytes;
    
    tmpyflows<-aggregate(tmpx[c("num_flows")],
                    by=list(proto=tmpx$proto, service=tmpx$service, sort_order=tmpx$sort_order), 
                    FUN=sum)
    tmpy$num_flows <- tmpyflows$num_flows/sum(tmpyflows$num_flows)   
    
    tmpymed<-aggregate(tmpx[c("upanddown")],
                       by=list(proto=tmpx$proto, service=tmpx$service, sort_order=tmpx$sort_order, user_id=tmpx$user_id), 
                       FUN=sum)
    # What is the total traffic from each user
    userSum <- aggregate(tmpymed[c("upanddown")],
                         by=list(user_id=tmpymed$user_id), 
                         FUN=sum)
    j<-1
    for (user_id in userSum$user_id) {
      # For each user divide the measure traffic for each proto+service+technology by the total traffic from that user
      # This makes sure that while taking the median for a given technology we normalize it by the 
      # total traffic generated by the user
      tmpymed[tmpymed$user_id ==user_id,]$upanddown <- tmpymed[tmpymed$user_id==user_id,]$upanddown/(userSum[j, ]$upanddown);
      j<-j+1;
    }
    # Now take the median across users. 
    tmpymed<-aggregate(tmpymed[c("upanddown")],
                    by=list(proto=tmpymed$proto, service=tmpymed$service, sort_order=tmpymed$sort_order), 
                    FUN=median)
    # The median of up and down individually do not mean anything because they can be for different users.
    tmpymed <- tmpymed[order(tmpymed$sort_order),] 
    tmpy$upanddown_med <- tmpymed$upanddown
    ytot[[i]] <- tmpy;
    i<-i+1;
  }
  
  #pdf(file=paste(plotsDir,"technologyProtocolShare.pdf", sep=""));
  tiff(file=paste(plotsDir,"technologyProtocolShare.tiff", sep=""))
  #legendText<-c(paste(techList[1], "total (aggregate)"), paste(techList[1], "upload (aggregate)"), paste(techList[1], "total (median)"),
  #              paste(techList[2], "total (aggregate)"), paste(techList[2], "upload (aggregate)"), paste(techList[2], "total (median)"))
  legendText<-c(paste(techList[1], "(aggregate)"), paste(techList[1], "(median)"),
                paste(techList[2], "(aggregate)"), paste(techList[2], "(median)"))
  
  xval <- paste(tmpy$proto, tmpy$service)
  #yval <- ytot[[1]]$orig_ip_bytes;
  yval <- ytot[[1]]$upanddown
  par(newpar);
  plot(1:length(xval), yval, pch=1, xlim=c(1,length(xval)), ylim=c(0,1),
       xaxt="n", xaxs="r", yaxs="r",
       xlab="Protocol", ylab="Fraction of traffic volume for a technology");
  
  #yval <- ytot[[1]]$orig_ip_bytes;
  #points(1:length(xval), yval, pch=2)
 
  yval <- ytot[[1]]$upanddown_med;
  points(1:length(xval), yval, pch=11)
  
  yval <- ytot[[2]]$upanddown;
  points(1:length(xval), yval, pch=3) 
  
  #yval <- ytot[[2]]$orig_ip_bytes;
  #points(1:length(xval), yval, pch=0)
 
  yval <- ytot[[2]]$upanddown_med;
  points(1:length(xval), yval, pch=4)
  
  axis(1, at=1:length(xval), lab=xval, las=0)
  grid(lwd=2);
  legend(x=2,y=1,legend=legendText, pch=c(1,11,3,4), box.lwd=1)
  dev.off()
  ytot;
}

plotTechShare <- function (x) {
  ytot <- NULL;
  i<-1
  tmpx <- x[x$technology!="Unknown", ];
  tmpx$sort_order <- rep(1000, nrow(tmpx));
  tmpx[tmpx$technology=="Wi-Fi", ]$sort_order <- 1;
  tmpx[tmpx$technology!="Wi-Fi", ]$sort_order <- 2;
  tmpx$upanddown <- tmpx$orig_ip_bytes + tmpx$resp_ip_bytes
  
  tmpy<-aggregate(tmpx[c("orig_ip_bytes", "resp_ip_bytes", "upanddown")],
                    by=list(sort_order=tmpx$sort_order, technology=tmpx$technology), 
                    FUN=sum)
  tmpy <- tmpy[order(tmpy$sort_order),]
  totbytes <- sum(tmpy$upanddown)
  tmpy$orig_ip_bytes <- tmpy$orig_ip_bytes/totbytes;
  tmpy$resp_ip_bytes <- tmpy$resp_ip_bytes/totbytes;
  tmpy$upanddown <- tmpy$upanddown/totbytes;
  
  
  # Compute the total traffic from users for a given technology  
  tmpysum<-aggregate(tmpx[c("upanddown")],
                     by=list(technology=tmpx$technology, sort_order=tmpx$sort_order, user_id=tmpx$user_id), 
                     FUN=sum)
  # What is the total traffic from each user across technologies
  userSum <- aggregate(tmpysum[c("upanddown")],
                       by=list(user_id=tmpysum$user_id), 
                       FUN=sum)
  j<-1
  newTab <- NULL
  for (user_id in userSum$user_id) {
    # Make sure that each user has two entries per technology else median can get screwed
    userentries <- tmpysum[tmpysum$user_id ==user_id,];
    newTab <- rbind(newTab, userentries)
    if (nrow(userentries) == 1) {
      userTechs <- userentries$technology;
      for (tech in c("Wi-Fi", "Cellular")) {
        if ((tech %in% userTechs) == FALSE) {
          tmpentry <- userentries;
          tmpentry$technology <- tech
          tmpentry$upanddown <- 0;
          if(tech == "Wi-Fi") {
            tmpentry$sort_order <- 1;
          } else {
            tmpentry$sort_order <- 2;
          }
          newTab <- rbind(newTab, tmpentry)
        }
      }
    }
    # For each user what is the fraction of traffic for a given technology
    newTab[newTab$user_id ==user_id,]$upanddown <- newTab[newTab$user_id==user_id,]$upanddown/(userSum[j, ]$upanddown);
    j<-j+1;
  }
  # Filtered set of users.
  tmpysum <- newTab
  # Now take the median of this fraction 
  tmpymed<-aggregate(tmpysum[c("upanddown")],
                     by=list(technology=tmpysum$technology, sort_order=tmpysum$sort_order), 
                     FUN=median)
  tmpymed <- tmpymed[order(tmpymed$sort_order),]
  tmpy$upanddown_med <- tmpymed$upanddown

  tabUsers <- tmpysum[tmpysum$upanddown==0,]$user_id;
  allUsers <- unique(tmpysum$user_id);
  tmpysumNotTab<-NULL;
  for (uTab in allUsers) {
    if ((uTab %in% tabUsers) == FALSE) {
      userEntries <- tmpysum[tmpysum$user_id == uTab,];
      tmpysumNotTab <- rbind(tmpysumNotTab, userEntries)
    }
    
  }
  tmpymed<-aggregate(tmpysumNotTab[c("upanddown")],
                     by=list(sort_order=tmpysumNotTab$sort_order, technology=tmpysumNotTab$technology), 
                     FUN=median)
  
  tmpymed <- tmpymed[order(tmpymed$sort_order),]
  tmpy$upanddown_mednottab <- tmpymed$upanddown
  
  
  # take the max of this fraction  
  tmpymed<-aggregate(tmpysumNotTab[c("upanddown")],
                     by=list(sort_order=tmpysumNotTab$sort_order, technology=tmpysumNotTab$technology), 
                     FUN=max)
  tmpymed <- tmpymed[order(tmpymed$sort_order),]
  tmpy$upanddown_max <- tmpymed$upanddown
  
  # take the min of this fraction  
  tmpymed<-aggregate(tmpysumNotTab[c("upanddown")],
                     by=list(sort_order=tmpysumNotTab$sort_order, technology=tmpysumNotTab$technology), 
                     FUN=min)
  tmpymed <- tmpymed[order(tmpymed$sort_order),]
  tmpy$upanddown_min <- tmpymed$upanddown
  
  #pdf(file=paste(plotsDir,"technologyShare.pdf", sep=""));
  #eps(file=paste(plotsDir,"technologyShare.eps", sep=""));
  #png(file=paste(plotsDir,"technologyShare.png", sep=""))
  tiff(file=paste(plotsDir,"technologyShare.tiff", sep=""))
  legendText<-c("max (w/o tablets)", "aggregate (with tablets)", "median (with tablets)", "median (w/o tablets)", "min (w/o tablets)");
  xval <- c("Wi-Fi", "Cellular");
  #yval <- ytot[[1]]$orig_ip_bytes;
  yval <- tmpy$upanddown_max
  par(newpar);
  plot(1:length(xval), yval, pch=0, xlim=c(1,length(xval)), ylim=c(0,1),
       xaxt="n", xaxs="r", yaxs="r", 
       xlab="Access Technology", ylab="Fraction of traffic volume");
  
  yval <- tmpy$upanddown;
  points(1:length(xval), yval, pch=1)
  
  yval <- tmpy$upanddown_med;
  points(1:length(xval), yval, pch=3)
  
  yval <- tmpy$upanddown_mednottab;
  points(1:length(xval), yval, pch=5)
  
  yval <- tmpy$upanddown_min;
  points(1:length(xval), yval, pch=4)
  
  axis(1, at=1:length(xval), lab=xval, las=0)
  grid(lwd=2);
  legend(x=1.2,y=1,legend=legendText, pch=c(0,1,3,5, 4), box.lwd=1)
  #dev.copy(png, paste(plotsDir,"technologyShare.png", sep=""));
  dev.off();
  tmpy;
}

getOtherDetails<-function()  {
  userDir <- broAggDir;
  fName <- paste(userDir, "/conn.log.ann", sep="");
  print("Read file")
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts); 
  x<-connData; 
  
  y<-x[x$proto == "udp",];
  
  #x[(x$proto=="tcp") & (x$service!="ssl") & (x$service!="http"),]$service = "other"
  #x[(x$proto=="udp"),]$service = ""
  #x[(x$proto!="udp") & (x$proto != "tcp"),]$proto = "other"
  #x[(x$proto=="other"),]$service = ""
  
  x[(x$proto=="tcp" & (x$id.resp_p==443 | x$id.resp_p==5228 | x$id.resp_p== 8883 | x$id.resp_p==5222 |  x$id.resp_p == 1237 | x$id.resp_p == 993 | x$id.resp_p == 995| x$id.resp_p == 7275)),]$service = "ssl"
  x[(x$proto=="tcp" & (x$id.orig_p==443 | x$id.orig_p==5228 | x$id.orig_p== 8883 | x$id.orig_p==5222 |  x$id.orig_p == 1237 | x$id.orig_p == 993 | x$id.orig_p == 995| x$id.orig_p == 7275)),]$service = "ssl"
  
  x[(x$proto=="tcp") & (x$id.resp_p==5223) & (x$oper_sys=="iOS"),]$service="ssl"
  #x[(x$proto=="tcp") & (x$id.orig_p==5223) & (x$oper_sys=="iOS"),]$service="ssl"
  
  # 5228 gtalk android
  # 8882 mqtt ssl 
  x[(x$proto=="tcp" & x$id.resp_p==80),]$service = "http"
  #x[(x$proto=="tcp" & x$id.orig_p==80),]$service = "http"
  
  y <- x[(x$proto=="tcp") & (x$service!="ssl") & (x$service!="http"),]
  y$resp_p <- y$id.resp_p;
  a<- aggregate(y[c("orig_ip_bytes", "resp_ip_bytes")], by=list(resp_p=y$resp_p), FUN=sum)
}
createAndSaveConnMeta()
plotTable <-getAggrTableForPlots()
pd <- plotFractionFlows(plotTable);
# Similar trends for iOS and Android
# Significant fraction of flows due to SSL
# UDP primarily because of DNS requests preceede any HTTP and HTTPs traffic
pd <- plotTechUploadDownloads(plotTable);
# More of aggregate Wi-fi because 
# 1) we include tablets that only have Wi-Fi, users that do not have a data plan for their phones
# 2) Offloading to Wi-Fi by users
# 3) Median behavior shows that traffic share similar accross access technlogy
# 4) Median higher for cellular SSL because users tend to use cellular for mail
pd<-plotTechShare(plotTable)
# 1) Max for cellular is high because a user uses Cell connection at Home. Device uses Wi-Fi
#    but the home gateway uses Cell connection

  #ymed<-aggregate(x[c("orig_ip_bytes", "resp_ip_bytes")],
  #             by=list(oper_sys=x$oper_sys, technology=x$technology, proto=x$proto, service=x$service), 
  #             FUN=median)
  #ymin<-aggregate(x[c("orig_ip_bytes", "resp_ip_bytes")],
  #                by=list(oper_sys=x$oper_sys, technology=x$technology, proto=x$proto, service=x$service), 
  #                FUN=min)
  #ymax<-aggregate(x[c("orig_ip_bytes", "resp_ip_bytes")],
  #                by=list(oper_sys=x$oper_sys, technology=x$technology, proto=x$proto, service=x$service), 
  #                FUN=max)
  #ytot<-aggregate(x[c("orig_ip_bytes", "resp_ip_bytes")],
  #                by=list(oper_sys=x$oper_sys, technology=x$technology, proto=x$proto, service=x$service), 
  #                FUN=sum)
  #ytot$resp_ip_bytes/(10^6);
 