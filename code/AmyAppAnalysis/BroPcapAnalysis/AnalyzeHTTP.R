baseDir<-"/user/arao/home/controlled_experiments/community_experiments/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
broLogsDir<-paste(baseDir, "/bro-results/droid-10-min-amy/", sep="")
miscDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/results/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))

assignTrackerFlag <- function(trackerDomains, inpData) {  
  # TODO:: Read from Database the list of trackers and assign a tracker based on httpData
  print("Assigning Tracker Flags")  
  # Assuming that number of http flows are larger than the tracker rows~3k
  trackerRows <- unique(unlist(lapply(trackerDomains,  function(x) {grep(x, inpData$host)})))  
  inpData$tracker_flag <- FALSE;
  if (length(trackerRows) > 0) { 
    inpData[trackerRows, ]$tracker_flag <- TRUE;
  }
  print("Completed Tracker Flags")
  return(inpData)  
}

getDomains <- function(host) {
  domains<- unlist(lapply(host, function(x) { y<-unlist(strsplit(x,"\\."));
                                              if (length(y)>1) {
                                                if ((nchar(tail(y,1))>2) | ((y[length(y)-1])!= "co")) {
                                                  y<-tail(y,2);
                                                } else {
                                                  #print(y)
                                                  y<-tail(y,3);
                                                }
                                              }
                                              y <- paste(y,collapse=".", sep="");                                                                        
                                              return(y);  
  }))
  return(domains)
}

getPackageMeta <- function(pkgList) {
  #dbConn <- getDBConn(meddleConfigFile)
  packageMeta <- data.frame(pkgName=unique(pkgList),                          
                            stringsAsFactors=FALSE)
  packageMeta$domains <- unlist(lapply(packageMeta$pkgName, function(x) { y<-unlist(strsplit(x,"\\."));
                                                                          y <- rev(y);                                                                                                                                                             
                                                                          y <- y[(y!="android")&(y!="apps")&(y!="app")]
                                                                          y <- paste(y,collapse=".", sep="");                                                                             
                                                                          return(y);
  }))
  
  packageMeta$orgdomain <- unlist(lapply(packageMeta$domains, function(x) { y<-unlist(strsplit(x,"\\."));                 
                                                                            if (length(y)>1) {
                                                                              if ((nchar(tail(y,1))>2) | ((y[length(y)-1])!= "co")) {
                                                                                y<-tail(y,2);
                                                                              } else {
                                                                                #print(y)
                                                                                y<-tail(y,3);
                                                                              }
                                                                            }
                                                                            y <- paste(y,collapse=".", sep="");                                                                        
                                                                            return(y);
  }))
  
  packageMeta$appdomain <- unlist(lapply(packageMeta$domains, function(x) { y<-unlist(strsplit(x,"\\."));                 
                                                                            if (length(y)>1) {
                                                                              if ((nchar(tail(y,1))>2) | ((y[length(y)-1])!= "co")) {
                                                                                y<-tail(y,3);
                                                                              } else {
                                                                                #print(y)
                                                                                y<-tail(y,4);
                                                                              }
                                                                            }
                                                                            y <- paste(y,collapse=".", sep="");                                                                        
                                                                            return(y);
  }))
   return (packageMeta)
}






fName <- paste(broLogsDir, "http.log.pkg", sep="");
httpData <- readHttpData(fName)

trackerFile <- paste(miscDir, "trackerList.txt", sep="")
trackerTable <- read.table(trackerFile, header=T, sep="\t", quote="", 
                           comment.char="#", stringsAsFactors=FALSE)
httpData$num_flows <- 1
httpData <- assignTrackerFlag(trackerTable$domain, httpData)
httpData$domains <- getDomains(httpData$host)

trackerFreeHttpData <- httpData[httpData$tracker_flag==FALSE, ]

httpData$foundHost <- 0



  
  
grepl(packageMeta$orgdomain, httpData$host)
orgRows <- c(orgRows, grep(packageMeta$orgdomain, httpData$domains))

hostAggr <- aggregate(httpData[c("num_flows")],
                      by=list(host=httpData$host, pkgID=httpData$pkgID, pkgName=httpData$pkgName),
                      FUN=sum)
write.table(userAgent, paste(hostAggr, "userAgents.txt", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(hostAggr)), row.names=FALSE, fileEncoding="utf-8")




trackerFreeHttpData$num_flows <- 1;
hostAggr <- aggregate(trackerFreeHttpData[c("num_flows")],
                      by=list(domains=trackerFreeHttpData$domains, pkgID=trackerFreeHttpData$pkgID, pkgName=trackerFreeHttpData$pkgName),
                      FUN=sum)                  



httpData <- assignTrackerFlag(trackerTable$domain, httpData)
fName <- paste(broLogsDir, "conn.log.dns.pkg", sep="");
connData <- readConnData(fName)
x<-length(unique(connData$pkgID))
print(paste("Number of packages that generated traffic ", x))
x<-unique(connData[(connData$id.resp_p==80)|(connData$id.orig_h==80),]$pkgID)
print(paste("Number of packages that generated HTTP traffic ", length(x)))
y<-unique(httpData[httpData$tracker_flag==TRUE, ]$pkgID)
print(paste("Number of packages with ads ", length(y)))
print(paste("Number of packages with no ad traffic", length(setdiff(x,y))))
z<-unique(httpData[httpData$tracker_flag==FALSE, ]$pkgID)
print(paste("Number of packages with only ad traffic ", length(setdiff(x,z))))


##### ASSIGN PACKAGE NAMES
packageMeta <- getPackageMeta(unique(connData$pkgName))
httpHosts <- unique(httpData$host)
orgRows <- unlist(lapply(packageMeta$orgdomain, 
                         function(x) { if (length(grep(x, httpHosts))>0) {
                                           return (TRUE);      
                                       }                                      
                                       return (FALSE);
                         }));

packageMeta[orgRows,]$pkgName
print(paste("Found org for ", length(packageMeta[orgRows,]$pkgName)))
appRows <- unlist(lapply(packageMeta$appdomain, 
                         function(x) { if (length(grep(x, httpHosts))>0) {
                                          return (TRUE);      
                                      }                                      
                                      return (FALSE);
                                      }));
print(paste("Found app for ", length(packageMeta[appRows,]$pkgName)))



httpData$num_flows <- 1
userAgent <- aggregate(httpData[c("num_flows")],
                       by=list(user_agent=httpData$user_agent,
                               pkgName = httpData$pkgName,
                               pkgID = httpData$pkgID),
                       FUN=sum)
write.table(userAgent, paste(resultsDir, "userAgentsPkg.txt", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(userAgent)), row.names=FALSE, fileEncoding="utf-8")
userAgent <- data.frame(userAgent=unique(httpData$user_agent),
                        stringsAsFactors=FALSE)
write.table(userAgent, paste(resultsDir, "userAgents.txt", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(userAgent)), row.names=FALSE, fileEncoding="utf-8")