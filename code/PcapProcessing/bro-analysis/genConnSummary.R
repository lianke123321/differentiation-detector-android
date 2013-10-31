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
labelProtoService <- function() {
  # Remove the ones with unknowns
   connData <- connData[connData$isp_id!=-1, ]
   print("Processing Meta")
   # POST PROCESSING BASED ON PORT VALUES   
   connData[(connData$proto=="tcp" 
      & (connData$id.resp_p==443 | connData$id.resp_p==5228 | connData$id.resp_p == 5900 |
           connData$id.resp_p== 8883 | connData$id.resp_p==5222 |  
           connData$id.resp_p == 1237 | connData$id.resp_p == 993 | 
           connData$id.resp_p == 995| connData$id.resp_p == 7275)),]$service = "ssl"
   
   connData[(connData$proto=="tcp" 
      & (connData$id.orig_p == 443 | connData$id.orig_p == 5228 | connData$id.orig_p == 5900 |
           connData$id.orig_p == 8883 | connData$id.orig_p ==5222 | 
           connData$id.orig_p == 1237 | connData$id.orig_p == 993 | 
           connData$id.orig_p == 995 | connData$id.orig_p == 7275)),]$service = "ssl"
   
   #TODO:: What about VNC??      
   connData[(connData$proto=="tcp")
     &(connData$id.resp_p==5223|connData$id.orig_p==5223 |
                         connData$id.orig_p == 443) 
     & (connData$operating_system=="i"),]$service="ssl"   
   # added 443 to ensure that this command does not return error
   connData[(connData$proto=="udp")&((connData$id.orig_p ==53) | (connData$id.resp_p==53)), ]$service <- "dns"
   # 5228 gtalk android
   # 8882 mqtt ssl 
   connData[(connData$proto=="tcp" & (connData$id.orig_p == 80 | connData$id.resp_p == 80 )),]$service = "http"
   
   connData[((connData$proto == "tcp") & (connData$service != "http") & (connData$service != "ssl")),]$service="other"
   connData[((connData$proto == "udp") & (connData$service != "dns")),]$service="other" 
   connData[((connData$proto != "tcp") & (connData$proto != "udp")),]$proto="other"   
   connData[(connData$proto == "other"),]$service="other"

   connData$tot_pkts <- connData$orig_pkts+connData$resp_pkts
   connData$tot_bytes <- connData$orig_ip_bytes + connData$resp_ip_bytes  
   connData
}



fName <- paste(broAggDir, "/conn.log.info", sep="");
print(fName)
connData <- readConnData(fName) 
connData <- labelProtoService()
connData$num_flows <- 1
# Compute and save summary
y<-aggregate(connData[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes", "num_flows")],
               by=list(user_id=connData$user_id, proto=connData$proto, service=connData$service, 
                       isp_id=connData$isp_id, operating_system=connData$operating_system, 
                       technology=connData$technology), 
               FUN=sum)
fName <- paste(broAggDir, "/summary.conn.log.info", sep="");
print(paste("Writing Meta in", fName))
write.table(y, fName, sep="\t", quote=F, col.names=c(colnames(y)), row.names=FALSE)

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
