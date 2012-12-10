overHeadsDir="/Users/ashwin/proj-work/meddle/meddle-data/overheads"

fName<-paste(overHeadsDir,"/bytes-ethernet",sep="");


ethernetBytes <- read.table(fName, header=FALSE, quote="", sep="|");
ethernetBytes$V1 <- as.POSIXlt(ethernetBytes$V1, format="%b %d, %Y %H:%M:%S")
ethernetBytes <- ethernetBytes[order(ethernetBytes$V1),]
ethernetBytes$V3 <- cumsum(as.numeric(ethernetBytes$V2))

fName<-paste(overHeadsDir,"/bytes-tunnel",sep="");
tunnelBytes <- read.table(fName, header=FALSE, quote="", sep="|");
tunnelBytes$V1 <- as.POSIXlt(tunnelBytes$V1, format="%b %d, %Y %H:%M:%S")
tunnelBytes <- tunnelBytes[order(tunnelBytes$V1),]
tunnelBytes$V3 <- cumsum(as.numeric(tunnelBytes$V2))

write.table(ethernetBytes, paste(overHeadsDir,"/ethernetBytesOverhead.txt", sep=""), 
            row.names=FALSE, col.names=FALSE, quote=FALSE)

#TODO: Filter based on time later.
sampleLength <- min(nrow(ethernetBytes), nrow(tunnelBytes))
overheads <- ethernetBytes[1:sampleLength,]$V3/tunnelBytes[1:sampleLength,]$V3
overheads[is.na(overheads)] <- -1;
overheads <- overheads[overheads>=0];
pdf(paste(overHeadsDir,"/overheads.pdf",sep=""))
plot(ecdf(overheads))
dev.off()

#fName<-paste(overHeadsDir,"/abc.txt",sep="");
#ethernetBytes <- read.table(fName, header=FALSE, quote="", sep="|",stringsAsFactors=FALSE);


