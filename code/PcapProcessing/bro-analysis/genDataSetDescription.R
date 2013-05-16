baseDir<-"/home/arao/proj-work/meddle/projects/bro-test/"
scriptsDir<-paste(baseDir, "/analysis-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/test-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "paperData/", sep="");

source (paste(scriptsDir, "/readLogFiles.R", sep=""))

getActiveUserIDs <- function(connData) {
  unique(connData$user_id)
}

getDeviceSummary <- function(activeUserInfo) {   
  activeUserInfo$count <- 1
  deviceCounts <- aggregate(activeUserInfo[c("count")], 
                        by=list(device_type =activeUserInfo$device_type,
                                operating_system_name=activeUserInfo$operating_system_name),
                        FUN=length)
  print(paste("Total of active devices", sum(deviceCounts$count)))
  print("Description of Devices");
  print(deviceCounts)
}

annotateLocalTime <- function(connData) {
  # Convert the time stamps to date time
  # For each user group by the day, hour, on which at least one packet was seen

  # This takes too much time 
  #connData$ts_date <- mapply(x=as.numeric(connData$ts), y=connData$time_zone, function(x,y) {z<-as.POSIXlt(x, tz=y, origin = "1970-01-01"); z})
  
  unique_tz <- unique(connData$time_zone)
  i<-1
  connData$ts_date <- as.POSIXlt(0, tz="America/Los_Angeles", origin = "1970-01-01")
  for(i in 1:length(unique_tz)) {    
    tz_rows <- grep(unique_tz[i], connData$time_zone)
    print(paste(unique_tz[i], length(tz_rows)))
    connData[tz_rows, ]$ts_date <- as.POSIXlt(connData[tz_rows, ]$ts, tz=unique_tz[i], origin = "1970-01-01");
  }
  connData  
}
  
getUsageStats <- function(connData) {    
  activeUserIds<- getActiveUserIDs(connData)
  connData$count <- 1;
  connData$yday <- connData$ts_date$yday
  connData$hour <- connData$ts_date$hour
  connData$year <- connData$ts_date$year
  # Filter days after November 1  
  usageStats <- aggregate(connData[c("count")], 
                          by=list(user_id=connData$user_id, year=connData$year, 
                                  yday=connData$yday, hour=connData$hour),
                          FUN=length)
  hoursPerDay <- aggregate(usageStats[c("hour")],
                           by=list(user_id=usageStats$user_id, year=usageStats$year,
                                   yday=usageStats$yday),
                           FUN=length)
  usersWithAllHours <- unique(hoursPerDay[hoursPerDay$hour==24,]$user_id)
  print(paste(length(usersWithAllHours), "of", length(activeUserIds), "have been monitored for at least one 24 hour cycle"))
  print("Summary stats for hours per day")
  print(summary(hoursPerDay$hour))
  # now get the number of days for each user.
  daysPerUser <- aggregate(connData[c("count")],
                           by=list(user_id=connData$user_id, 
                                   year=connData$year, yday=connData$yday),
                           FUN=length)
  daysPerUser <- aggregate(daysPerUser[c("yday")],
                           by=list(user_id=daysPerUser$user_id),
                           FUN=length)
  print("Summary of days per user")
  print(summary(daysPerUser$yday))
  usageDays <- aggregate(connData[c("count")],
                         by=list(year=connData$year, yday=connData$yday),
                         FUN=length)
  usageDays <- aggregate(connData[c("count")],
                         by=list(year=connData$year, yday=connData$yday),
                         FUN=length)  
  print(paste("Total number of days in which we observed at least one packet: ", nrow(usageDays)))
  print("Statistics on the number of flows handled per day (across all users)")
  print(summary(usageDays$count))
  
  # Now dumping the isp stats  
  ispStats <- aggregate(connData[c("count")],
                        by=list(user_id=connData$user_id, 
                                isp_id=connData$isp_id,
                                technology=connData$technology),                                  
                        FUN=length)
  cellStats <- ispStats[ispStats$technology=="c", ]
  cellStats <- aggregate(cellStats[c("isp_id")],
                         by=list(user_id=cellStats$user_id),
                         FUN=length)
  print("Summary of number of cellular ISPs from each user")
  print(summary(cellStats$isp_id))
  
  wifiStats <- ispStats[ispStats$technology=="w", ]
  wifiStats <- aggregate(wifiStats[c("isp_id")],
                         by=list(user_id=wifiStats$user_id),
                         FUN=length)
  print("Summary of number of wifi ISPs from each user")  
  print(summary(wifiStats$isp_id))
  
  print(paste("Number of unique ISPs:", length(unique(connData$isp_id))))
}

fName <- paste(broAggDir, "/conn.log.info", sep="")
connData <- readConnData(fName)
connData<- connData[connData$ts > 1351727700, ]
fName <- paste(miscDataDir, "/userInfo.txt", sep="");
userInfo <- readTable(fName)
activeUserIds <- getActiveUserIDs(connData)
activeUserInfo <- userInfo;
#TODO: Uncomment this line
#activeUsers <- userInfo[userInfo$user_id %in% activeUserIds, ]
getDeviceSummary(activeUserInfo)
connData <- annotateLocalTime(connData)
getUsageStats(connData)
