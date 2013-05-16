baseDir<-"/home/arao/proj-work/meddle/projects/bro-test/"
scriptsDir<-paste(baseDir, "/analysis-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/test-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");

source(paste(scriptsDir, "/readLogFiles.R", sep=""))

# The connData must be a info file that has the oper_sys information                  
computeAggregateConnMeta <- function(connData) {
   # Remove the ones with unknowns
   x <- connData[connData$isp_id!=-1, ]
   print("Processing Meta")
   # POST PROCESSING BASED ON PORT VALUES   
   x[(x$proto=="tcp" 
      & (x$id.resp_p==443 | x$id.resp_p==5228 | x$id.resp_p == 5900 |
           x$id.resp_p== 8883 | x$id.resp_p==5222 |  
           x$id.resp_p == 1237 | x$id.resp_p == 993 | 
           x$id.resp_p == 995| x$id.resp_p == 7275)),]$service = "ssl"
   
   x[(x$proto=="tcp" 
      & (x$id.orig_p == 443 | x$id.orig_p == 5228 | x$id.orig_p == 5900 |
           x$id.orig_p == 8883 | x$id.orig_p ==5222 | 
           x$id.orig_p == 1237 | x$id.orig_p == 993 | 
           x$id.orig_p == 995 | x$id.orig_p == 7275)),]$service = "ssl"
   
   #TODO:: What about VNC??      
   x[(x$proto=="tcp")
     &(x$id.resp_p==5223|x$id.orig_p==5223 |
                         x$id.orig_p == 443) 
     & (x$operating_system=="i"),]$service="ssl"   
   # added 443 to ensure that this command does not return error
   
   # 5228 gtalk android
   # 8882 mqtt ssl 
   x[(x$proto=="tcp" & (x$id.orig_p == 80 | x$id.resp_p == 80 )),]$service = "http"
   
   y<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],
                by=list(user_id=x$user_id, proto=x$proto, isp_id=x$isp_id, 
                        operating_system=x$operating_system, 
                        technology=x$technology, 
                        service=x$service), 
                FUN=sum)
   z<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],
                by=list(user_id=x$user_id, proto=x$proto, isp_id=x$isp_id, 
                        operating_system=x$operating_system, 
                        technology=x$technology, 
                        service=x$service),
                FUN=length)   
   y$num_flows <- z$orig_pkts;
   print("Done")
   y
}

createAndSaveConnMeta <- function () {
  fName <- paste(broAggDir, "/conn.log.info", sep="");
  print(fName)
  connData <- readConnData(fName)  
  connMeta <- computeAggregateConnMeta(connData) 
  fName <- paste(resultsDir, "/conn_meta.txt", sep="");
  print(paste("Writing Meta in", fName))
  write.table(connMeta, fName, sep="\t", quote=F, col.names=c(colnames(connMeta)), row.names=FALSE)
  connMeta
}

groupProtoServices <- function (x)  {
  x[((x$proto == "tcp") & (x$service != "http") & (x$service != "ssl")),]$service="other"
  x[(x$proto == "udp"),]$service="-"
  x[((x$proto != "tcp") & (x$proto != "udp")),]$proto="other"
  
  x$tot_pkts <- x$orig_pkts+x$resp_pkts
  x$tot_bytes <- x$orig_ip_bytes + x$resp_ip_bytes  
  x
}

getDeviceStats <- function (connMeta)  {
  x <- groupProtoServices(connMeta)
  y<-aggregate(x[c("tot_bytes", "tot_pkts", "num_flows")],
               by=list(proto=x$proto, service=x$service, operating_system=x$operating_system), 
               FUN=sum)  
  z<-aggregate(y[c("tot_bytes", "tot_pkts", "num_flows")],
               by=list(operating_system=y$operating_system), 
               FUN=sum)
  z <- data.frame(operating_system=z$operating_system, sum_total_bytes=z$tot_bytes, sum_total_pkts=z$tot_pkts, sum_total_flows=z$num_flows,
                  stringsAsFactors=FALSE)
  deviceStats = merge(x=y, y=z, by="operating_system")
  deviceStats$frac_bytes <- (deviceStats$tot_bytes)/(deviceStats$sum_total_bytes)
  deviceStats$frac_flows <- (deviceStats$num_flows)/(deviceStats$sum_total_flows)
  dumpStats <- data.frame(os=deviceStats$operating_system, 
                          proto=deviceStats$proto,
                          service=deviceStats$service,
                          bytes=deviceStats$frac_bytes*100, 
                          flows=deviceStats$frac_flows*100)
  fName <- paste(resultsDir, "/device_stats.txt", sep="");
  write.table(dumpStats, fName, sep="\t", quote=F, col.names=c(colnames(dumpStats)), row.names=FALSE)
  dumpStats  
}
  
getTechnologyStats <- function(connMeta) {
  x <- groupProtoServices(connMeta)
  y<-aggregate(x[c("tot_bytes", "tot_pkts", "num_flows")],
               by=list(proto=x$proto, service=x$service, technology=x$technology), 
               FUN=sum)  
  z<-aggregate(y[c("tot_bytes", "tot_pkts", "num_flows")],
               by=list(technology=y$technology), 
               FUN=sum)
  z <- data.frame(technology=z$technology, sum_total_bytes=z$tot_bytes, sum_total_pkts=z$tot_pkts, sum_total_flows=z$num_flows,
                  stringsAsFactors=FALSE)
  deviceStats = merge(x=y, y=z, by="technology")
  deviceStats$frac_bytes <- (deviceStats$tot_bytes)/(deviceStats$sum_total_bytes)
  deviceStats$frac_flows <- (deviceStats$num_flows)/(deviceStats$sum_total_flows)
  dumpStats <- data.frame(tech=deviceStats$technology, 
                          proto=deviceStats$proto,
                          service=deviceStats$service,
                          bytes=deviceStats$frac_bytes*100, 
                          flows=deviceStats$frac_flows*100)
  fName <- paste(resultsDir, "/technology_stats.txt", sep="");
  write.table(dumpStats, fName, sep="\t", quote=F, col.names=c(colnames(dumpStats)), row.names=FALSE)
  dumpStats  
}

connMeta <- createAndSaveConnMeta()
print("for OS")
deviceStats <- getDeviceStats(connMeta)
print("Checks")
sum(deviceStats[deviceStats$os=='a',]$bytes)
sum(deviceStats[deviceStats$os=='a',]$flows)
sum(deviceStats[deviceStats$os!='a',]$bytes)
sum(deviceStats[deviceStats$os!='a',]$flows)
print("Now for technology")
techStats <- getTechnologyStats(connMeta)
print("Checks")
sum(techStats[techStats$tech=='w',]$bytes)
sum(techStats[techStats$tech=='w',]$flows)
sum(techStats[techStats$tech=='w',]$bytes)
sum(techStats[techStats$tech!='w',]$bytes)

