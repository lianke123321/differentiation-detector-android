baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/analysis-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");

source(paste(scriptsDir, "/readLogFiles.R", sep=""))
opar <- par();
cexVal<-1.4
newpar <- par(cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal, xaxs="i", yaxs="i",lwd=3);

# The connData must be a info file that has the oper_sys information                  

fName <- paste(broAggDir, "/conn.log.info", sep="");
print(fName)
connData <- readConnData(fName) 
connData <- labelProtoService()
connData$num_flows <- 1
# Compute and save summary
y<-aggregate(connData[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes", "num_flows")],
               by=list(user_id=connData$user_id, proto=connData$proto, service=connData$service, 
                       isp_id=connData$isp_id, as=connData$as, prefix_id=connData$prefix_id, 
                       operating_system=connData$operating_system, 
                       technology=connData$technology), 
               FUN=sum)
fName <- paste(broAggDir, "/summary.conn.log.info", sep="");
print(paste("Writing Meta in", fName))
write.table(y, fName, sep="\t", quote=F, col.names=c(colnames(y)), row.names=FALSE)



###################################################################################
###################################################################################
#### Get the Summary Info in a table ##############################################
###################################################################################
###################################################################################
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
connSummary$tot_bytes <- connSummary$orig_ip_bytes+ connSummary$resp_ip_bytes
connSummary$tot_bytes <- as.numeric(connSummary$tot_bytes)
connSummary$num_flows <- as.numeric(connSummary$num_flows)
summaryAggr <- aggregate(connSummary[c("tot_bytes", "num_flows")],
                         by=list(proto=connSummary$proto,
                                 service=connSummary$service,
                                 technology=connSummary$technology,
                                 operating_system=connSummary$operating_system),
                         FUN=sum)
totBytes <- aggregate(connSummary[c("tot_bytes", "num_flows")],
                      by=list(operating_system=connSummary$operating_system,
                              technology=connSummary$technology),
                      FUN=sum)
colnames(totBytes) <- gsub("tot_bytes", "all_bytes",colnames(totBytes))
colnames(totBytes) <- gsub("num_flows", "all_flows",colnames(totBytes))
summaryAggr <- merge(x=summaryAggr, y=totBytes)
summaryAggr$perc_bytes <- 100*summaryAggr$tot_bytes/summaryAggr$all_bytes
summaryAggr$perc_flows <- 100*summaryAggr$num_flows/summaryAggr$all_flows
write.table(summaryAggr, paste(resultsDir, "/classifytraffic_techos_summary.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(summaryAggr)), row.names=FALSE)

###################################################################################
###################################################################################
#### Get the Sorting order for users  #############################################
###################################################################################
###################################################################################

connTcpAggr <- connSummary[connSummary$proto=="tcp",]
connTcpAggr <- aggregate(connTcpAggr[c("tot_bytes")],
                         by=list(user_id=connTcpAggr$user_id, 
                                 operating_system=connTcpAggr$operating_system),
                         FUN=sum)
connTcpAggr <- connTcpAggr[order(connTcpAggr$tot_bytes, decreasing=TRUE),]
connTcpAggr <- rbind(connTcpAggr[connTcpAggr$operating_system=="i",], connTcpAggr[connTcpAggr$operating_system=="a",])
#numIOS <- nrow(sortOrderTable[sortOrderTable$operating_system=="i",])
connTcpAggr$sort_order <- 1:nrow(connTcpAggr)
write.table(connTcpAggr, paste(broAggDir, "/devices.sortorder.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(connTcpAggr)), row.names=FALSE)


###################################################################################
###################################################################################
#### Get the Sorting order for users  #############################################
###################################################################################
###################################################################################


# 
#    
# 
# 
#    y<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],
#                 by=list(user_id=x$user_id, proto=x$proto, isp_id=x$isp_id, 
#                         operating_system=x$operating_system, 
#                         technology=x$technology, 
#                         service=x$service), 
#                 FUN=sum)
#    z<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],
#                 by=list(user_id=x$user_id, proto=x$proto, isp_id=x$isp_id, 
#                         operating_system=x$operating_system, 
#                         technology=x$technology, 
#                         service=x$service),
#                 FUN=length)   
#    y$num_flows <- z$orig_pkts;
#    print("Done")
#    y
# }
# 
# createAndSaveConnMeta <- function () {
#   fName <- paste(broAggDir, "/conn.log.info", sep="");
#   print(fName)
#   connData <- readConnData(fName)  
#   connMeta <- computeAggregateConnMeta(connData) 
#   fName <- paste(resultsDir, "/conn_meta.txt", sep="");
#   print(paste("Writing Meta in", fName))
#   write.table(connMeta, fName, sep="\t", quote=F, col.names=c(colnames(connMeta)), row.names=FALSE)
#   connMeta
# }
# 
# getConnMeta <- function() 
# {
#   fName <- paste(resultsDir, "/conn_meta.txt", sep="");
#   connMeta <- readTable(fName)
#   connMeta
# }
# 
# groupProtoServices <- function (x)  {
#   x[((x$proto == "tcp") & (x$service != "http") & (x$service != "ssl")),]$service="other"
#   x[(x$proto == "udp"),]$service="-"
#   x[((x$proto != "tcp") & (x$proto != "udp")),]$proto="other"
#   
#   x$tot_pkts <- x$orig_pkts+x$resp_pkts
#   x$tot_bytes <- x$orig_ip_bytes + x$resp_ip_bytes  
#   x
# }
# 
# getDeviceStats <- function (connMeta, fun, funname)  {
#   x <- groupProtoServices(connMeta)
#   y<-aggregate(x[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(proto=x$proto, service=x$service, operating_system=x$operating_system), 
#                FUN=fun)  
#   z<-aggregate(y[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(operating_system=y$operating_system), 
#                FUN=sum)
#   z <- data.frame(operating_system=z$operating_system, sum_total_bytes=z$tot_bytes, sum_total_pkts=z$tot_pkts, sum_total_flows=z$num_flows,
#                   stringsAsFactors=FALSE)
#   osStats = merge(x=y, y=z, by="operating_system")
#   osStats$frac_bytes <- (osStats$tot_bytes)/(osStats$sum_total_bytes)
#   osStats$frac_flows <- (osStats$num_flows)/(osStats$sum_total_flows)
#   dumpStats <- data.frame(os=osStats$operating_system, 
#                           proto=osStats$proto,
#                           service=osStats$service,
#                           bytes=osStats$frac_bytes*100, 
#                           flows=osStats$frac_flows*100)
#   fName <- paste(resultsDir, "/os_stats_", funname, ".txt", sep="");
#   write.table(dumpStats, fName, sep="\t", quote=F, col.names=c(colnames(dumpStats)), row.names=FALSE)
#   dumpStats  
# }
#   
# getTechnologyStats <- function(connMeta, fun, funname) {
#   x <- groupProtoServices(connMeta)
#   y<-aggregate(x[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(proto=x$proto, service=x$service, technology=x$technology), 
#                FUN=fun)  
#   z<-aggregate(y[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(technology=y$technology), 
#                FUN=sum)
#   z <- data.frame(technology=z$technology, sum_total_bytes=z$tot_bytes, sum_total_pkts=z$tot_pkts, sum_total_flows=z$num_flows,
#                   stringsAsFactors=FALSE)
#   techStats = merge(x=y, y=z, by="technology")
#   techStats$frac_bytes <- (techStats$tot_bytes)/(techStats$sum_total_bytes)
#   techStats$frac_flows <- (techStats$num_flows)/(techStats$sum_total_flows)
#   dumpStats <- data.frame(tech=techStats$technology, 
#                           proto=techStats$proto,
#                           service=techStats$service,
#                           bytes=techStats$frac_bytes*100, 
#                           flows=techStats$frac_flows*100)
#   fName <- paste(resultsDir, "/technology_stats", funname, ".txt", sep="");
#   write.table(dumpStats, fName, sep="\t", quote=F, col.names=c(colnames(dumpStats)), row.names=FALSE)
#   dumpStats  
# }
# 
# getUDPStats <- function (connMeta, fun, funname) {
#    
#   x <- connMeta[connMeta$proto=="udp", ]
#   x[(x$service != "dns"), ]$service <- "other"
#  
#   x$tot_pkts <- x$orig_pkts+x$resp_pkts
#   x$tot_bytes <- x$orig_ip_bytes + x$resp_ip_bytes
#   y<-aggregate(x[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(proto=x$proto, service=x$service, technology=x$technology), 
#                FUN=fun)  
#   z<-aggregate(y[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(technology=y$technology), 
#                FUN=sum)
#   z <- data.frame(technology=z$technology, sum_total_bytes=z$tot_bytes, sum_total_pkts=z$tot_pkts, sum_total_flows=z$num_flows,
#                   stringsAsFactors=FALSE)
#   deviceStats = merge(x=y, y=z, by="technology")
#   deviceStats$frac_bytes <- (deviceStats$tot_bytes)/(deviceStats$sum_total_bytes)
#   deviceStats$frac_flows <- (deviceStats$num_flows)/(deviceStats$sum_total_flows)
#   dumpStats <- data.frame(tech=deviceStats$technology, 
#                           proto=deviceStats$proto,
#                           service=deviceStats$service,
#                           bytes=deviceStats$frac_bytes*100, 
#                           flows=deviceStats$frac_flows*100)
#   fName <- paste(resultsDir, "/technology_udp_stats", funname, ".txt", sep="");
#   write.table(dumpStats, fName, sep="\t", quote=F, col.names=c(colnames(dumpStats)), row.names=FALSE)
#   
#   y<-aggregate(x[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(proto=x$proto, service=x$service, operating_system=x$operating_system), 
#                FUN=fun)  
#   z<-aggregate(y[c("tot_bytes", "tot_pkts", "num_flows")],
#                by=list(operating_system=y$operating_system), 
#                FUN=sum)
#   z <- data.frame(operating_system=z$operating_system, sum_total_bytes=z$tot_bytes, sum_total_pkts=z$tot_pkts, sum_total_flows=z$num_flows,
#                   stringsAsFactors=FALSE)
#   deviceStats = merge(x=y, y=z, by="operating_system")
#   deviceStats$frac_bytes <- (deviceStats$tot_bytes)/(deviceStats$sum_total_bytes)
#   deviceStats$frac_flows <- (deviceStats$num_flows)/(deviceStats$sum_total_flows)
#   dumpStats <- data.frame(os=deviceStats$operating_system, 
#                           proto=deviceStats$proto,
#                           service=deviceStats$service,
#                           bytes=deviceStats$frac_bytes*100, 
#                           flows=deviceStats$frac_flows*100)
#   fName <- paste(resultsDir, "/os_udp_stats_", funname, ".txt", sep="");
#   write.table(dumpStats, fName, sep="\t", quote=F, col.names=c(colnames(dumpStats)), row.names=FALSE)
#   dumpStats  
# }
# 
# #connMeta <- createAndSaveConnMeta()
# connData <- readConnData(fName)
# connData <- labelProtoService()
# connMeta <- getConnMeta()
# 
# print("for OS")
# deviceStats <- getDeviceStats(connMeta, median, "median")
# print("Checks")
# sum(deviceStats[deviceStats$os=='a',]$bytes)
# sum(deviceStats[deviceStats$os=='a',]$flows)
# sum(deviceStats[deviceStats$os!='a',]$bytes)
# sum(deviceStats[deviceStats$os!='a',]$flows)
# print("Now for technology")
# techStats <- getTechnologyStats(connMeta, median , "median")
# print("Checks")
# sum(techStats[techStats$tech=='w',]$bytes)
# sum(techStats[techStats$tech=='w',]$flows)
# sum(techStats[techStats$tech=='w',]$bytes)
# sum(techStats[techStats$tech!='w',]$bytes)
# deviceStats <- getDeviceStats(connMeta, sum, "cumul")
# print("Checks")
# sum(deviceStats[deviceStats$os=='a',]$bytes)
# sum(deviceStats[deviceStats$os=='a',]$flows)
# sum(deviceStats[deviceStats$os!='a',]$bytes)
# sum(deviceStats[deviceStats$os!='a',]$flows)
# print("Now for technology")
# techStats <- getTechnologyStats(connMeta, sum , "cumul")
# print("Checks")
# sum(techStats[techStats$tech=='w',]$bytes)
# sum(techStats[techStats$tech=='w',]$flows)
# sum(techStats[techStats$tech=='w',]$bytes)
# sum(techStats[techStats$tech!='w',]$bytes)
# udpStats <- getUDPStats(connMeta, sum , "cumul")
# udpStats <- getUDPStats(connMeta, median , "median")
# userTechShare <- getUserTechShare (connMeta)
