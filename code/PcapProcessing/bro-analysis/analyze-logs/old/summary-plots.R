baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
plotsDir=paste(baseDir, "plots/", sep="");
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
opar = par();


par(cex.lab=1.3, cex.axis=1.3, cex.main=1.3, cex.sub=1.3,
    xaxs="i", yaxs="i",lwd=3);

# Fraction of Traffic for each protocol/service across different technologies.
for (technology in c("All", "Unknown", "Wi-Fi", "Cellular")) {
  fName <- paste(broAggDir,'connMeta.txt', sep="");
  connMeta <- read.table(fName, header=T);
  connMeta$orig_ip_bytes = as.double(connMeta$orig_ip_bytes);
  connMeta$resp_ip_bytes = as.double(connMeta$resp_ip_bytes);
  
  if (technology != "All") {
    connMeta = connMeta[connMeta$technology==technology,];
  }
  
  rawYVal <- (connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)/sum(connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)
  aggyval <- NULL;

  aggyval[1] <- sum(rawYVal[(connMeta$proto=="tcp") & (connMeta$service=="http")]);
  aggyval[2] <- sum(rawYVal[(connMeta$proto=="tcp") & (connMeta$service=="ssl")]);
  aggyval[3] <- sum(rawYVal[(connMeta$proto=="tcp") & (connMeta$service!="ssl") & (connMeta$service!="http")]);
  aggyval[4] <- sum(rawYVal[(connMeta$proto=="udp")]);
  aggyval[5] <- sum(rawYVal[(connMeta$proto!="udp") & (connMeta$proto!="tcp")]);

  userDirList <- list.dirs(broLogsDir, recursive=FALSE)
  userConnMeta<-NULL;
  i<-1
  for(userDir in userDirList) {
    fName=paste(userDir, "/connMeta.txt", sep="");
    if(file.exists(fName) == FALSE) {
      print(paste(fName, " does not exist"));
      next;
    }
    userName <- basename(userDir);
    print(fName);
    userTable <-read.table(fName, header=T, stringsAsFactors=FALSE)
    if (nrow(userTable)< 2) {
      next;
    }
    if (technology != "All") {
      userTable <- userTable[userTable$technology == technology,];
    }
    userConnMeta[[i]] <- userTable;
    i<-i+1;
  }
  
  yval <- matrix(ncol=5, nrow=length(userConnMeta))
  j<-1
  for (i in 1:length(userConnMeta)) {
    connMeta <- userConnMeta[[i]]
    connMeta$orig_ip_bytes = as.double(connMeta$orig_ip_bytes);
    connMeta$resp_ip_bytes = as.double(connMeta$resp_ip_bytes);
    if (technology == "All") {
      if ((sum(connMeta$resp_ip_bytes) + sum(connMeta$orig_ip_bytes)) < (300*10^6)) {
        print((sum(connMeta$resp_ip_bytes) + sum(connMeta$orig_ip_bytes))/10^6);
        print (i);
        next;
      }
    }
    rawYVal <- (connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)/sum(connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)  
    yval[j,1] <- sum(rawYVal[(connMeta$proto=="tcp") & (connMeta$service=="http")]);
    yval[j,2] <- sum(rawYVal[(connMeta$proto=="tcp") & (connMeta$service=="ssl")]);
    yval[j,3] <- sum(rawYVal[(connMeta$proto=="tcp") & (connMeta$service!="ssl") & (connMeta$service!="http")]);
    yval[j,4] <-  sum(rawYVal[(connMeta$proto=="udp")]);
    yval[j,5] <- sum(rawYVal[(connMeta$proto!="udp") & (connMeta$proto!="tcp")]);
    j<-j+1;
  }
  print("Number of users")
  print(j);
  xval <- c("tcp http", "tcp ssl", "tcp other", "udp", "other");
  yval <- yval[1:j-1,];

  pdf(file=paste(plotsDir,"protocolTrafficShare",technology, ".pdf", sep=""));
  plot(1:length(xval), apply(yval, 2, max), pch=2, 
       xaxt="n", xaxs="r", yaxs="r", ylim=c(0,1),
       xlab="Protocols", ylab="Fraction of Traffic Volume");
  points(1:length(xval), apply(yval, 2, median), pch=0)
  points(1:length(xval), aggyval, pch=1)
  points(1:length(xval), apply(yval, 2, min), pch=6)
  axis(1, at=1:length(xval), lab=xval, las=1)
  legend(x=length(xval)-1,y=1,legend=c("Max", "Median","Aggregate", "Min"), pch=c(2,0,1,6))
  grid();
  dev.off()
}

# Wifi vs 3G vs Unknown in the same way across users
for (ptype in c("fraction", "absolute")) {
  fName <- paste(broAggDir,'connMeta.txt', sep="");
  connMeta <- read.table(fName, header=T);

  if (ptype == "absolute") {
    rawYVal <- (connMeta$orig_ip_bytes+connMeta$resp_ip_bytes);
  } else {
    rawYVal <- (connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)/sum(connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)
  }
  aggyval <- NULL;
  
  aggyval[1] <- sum(rawYVal[(connMeta$technology=="Wi-Fi")]);
  aggyval[2] <- sum(rawYVal[(connMeta$technology=="Cellular")]);
  aggyval[3] <- sum(rawYVal[(connMeta$technology=="Unknown")])
  userDirList <- list.dirs(broLogsDir, recursive=FALSE)

  userDirList <- list.dirs(broLogsDir, recursive=FALSE)
  userConnMeta<-NULL;
  i<-1
  for(userDir in userDirList) {
    fName=paste(userDir, "/connMeta.txt", sep="");
    if(file.exists(fName) == FALSE) {
      print(paste(fName, " does not exist"));
      next;
    }
    userName <- basename(userDir);
    print(fName);
    userTable <- read.table(fName, header=T, stringsAsFactors=FALSE)
    if (nrow(userTable) < 2) {
      next;
    }
    userConnMeta[[i]] <- userTable;
    i<-i+1;
  }
  yval <- matrix(ncol=3, nrow=length(userConnMeta))
  j<-1
  for (i in 1:length(userConnMeta)) {
    connMeta <- userConnMeta[[i]]
    connMeta$orig_ip_bytes = as.double(connMeta$orig_ip_bytes);
    connMeta$resp_ip_bytes = as.double(connMeta$resp_ip_bytes);
  
    if (ptype == "absolute") {
      rawYVal <- (connMeta$orig_ip_bytes+connMeta$resp_ip_bytes);      
    } else {
      rawYVal <- (connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)/sum(connMeta$orig_ip_bytes+connMeta$resp_ip_bytes)  
    }
    yval[j,1] <- sum(rawYVal[(connMeta$technology=="Wi-Fi")]); 
    yval[j,2] <- sum(rawYVal[(connMeta$technology=="Cellular")]);
    yval[j,3] <- sum(rawYVal[(connMeta$technology=="Unknown")])
    j<-j+1;
  }
  print("Number of users")
  print(j);
  xval <- c("Wi-Fi", "Cellular", "Unknown");
  yval <- yval[1:j-1,];
  pdf(file=paste(plotsDir,"technologyTrafficShare", ptype, ".pdf", sep=""));
  if (ptype == "absolute") {
    yval <- yval/(10^6);
    yval[yval<1]=1;    
    aggyval <- aggyval/(10^6);
    ylims <- c(1, max(aggyval))
    logstr <- "y"
    ylabstr <- "Traffic Volume (MB)"
  } else {
    ylims <- c(0, 1)
    logstr <- ""
    ylabstr <- "Fraction of Traffic Volume"
  }
  plot(1:length(xval), apply(yval, 2, max), pch=2, 
       xaxt="n", xaxs="r", yaxs="r", ylim=ylims,
       log = logstr,
       xlab="Access Technology", ylab=ylabstr);
  points(1:length(xval), apply(yval, 2, median), pch=0)
  points(1:length(xval), aggyval, pch=1)
  points(1:length(xval), apply(yval, 2, min), pch=6)
  axis(1, at=1:length(xval), lab=xval, las=1) 
  legend(x=length(xval)-0.5,y=max(ylims),legend=c("Max", "Median","Aggregate", "Min"), pch=c(2,0,1,6))
  grid();
  dev.off();
}  

### Plot for Ads here 
pdf(file=paste(plotsDir,"userAdsShare.pdf", sep=""));
userAds <- read.table(paste(broLogsDir,"userAdBytes.txt", sep=""));
yvals <- matrix(nrow=nrow(userAds), ncol=3);
yvals[1:nrow(userAds),1] <- userAds$V3/userAds$V2;
yvals[1:nrow(userAds),2] <- userAds$V3;
yvals[1:nrow(userAds),3] <- userAds$V2;
yvals <- yvals[sort.list(yvals[,3],decreasing=TRUE),];
plot(yvals[,1]*100,
     xlab="User",
     ylim=c(0, max(yvals[,1]*1.5)*100),
     ylab="Percentage of Ad Traffic (Volume of Ad Traffic )");
text(x=1:nrow(yvals), y=(yvals[,1]*100+6), 
     paste(round(100*yvals[,2]/(10^6))/100, " MB/", round(100*yvals[,3]/(10^6))/100, " MB", sep=""), 
     xpd=TRUE, srt=90)
dev.off()

convertStringRowsToDouble <- function(rowData) {
  rowData <- as.double(rowData);
  rowData[is.na(rowData)] <-0
  rowData;
}


getFractionCompressedAmounts <- function(userDir) {
  # find entries with gzip in content_type
  # 
  fName <- paste(userDir, "/http.log", sep="");
  if (file.exists(fName) == FALSE) {
    print(fName);
    return(NA);
  }
  httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
  if (nrow(httpData) < 10) {
    print(fName);
    return(NA);
  }
  rowIDs <- grep("text", httpData$mime_type);
  rowIDs <- append(rowIDs, grep("text", httpData$content_type));
  rowIDs <- unique(sort(rowIDs));
  textRows <- httpData[rowIDs, ];  
  zipRows <- textRows[grep("zip", textRows$content_encoding), ];
  
  zipRows$content_length <- convertStringRowsToDouble(zipRows$content_length)
  zipRows$response_body_len <- convertStringRowsToDouble(zipRows$response_body_len)
  
  compressFailRows <- zipRows[(zipRows$content_length > zipRows$response_body_len),];
  
}

# mime_type
# hostname video, audio, pandora, netflix, youtube, 
# uri video, audio, mp3 m4p, aac, 

# fName <- paste(broAggDir,'http.log', sep="");
# httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
# httpLens <-(httpData$request_body_len + httpData$response_body_len) 
# httpLens <- as.numeric(httpLens); 
# httpLens[is.na(httpLens)] <- 0;
# clustersOnSize <- kmeans(httpLens, 2)
# x<-httpData[httpLens > (1*10^6),]$response_body_len
# unique(httpData$mime_type)








# 
# isAVContent <- function(avString, entryStrings) {
#   #avStrings <- list("audio", "video", "watch", "listen")
#   retVal <- FALSE;
#   for (avstr in avStrings) {
#     if(length(grep(avstr, entryStrings))>0) {
#       retVal <- TRUE;
#       break
#     } 
#   }
#   retVal;
# }
# avStrings <- list("audio", "video", "watch", "listen")
# for (i in 1:nrow(httpData)) {
#   entryList <- NULL;
#   entry <- httpData[i,];
#   entryStrings <- c(entry$host, entry$uri, entry$mime_type);
#   if (isAVContent(avStrings, entryStrings)) {
#     print(entryStrings);
#     entryList<-append(entryList, i);
#   }
# }
# avHttpStreams <- httpData[entryList, ];


