library(bitops)

getIPFromString <- function (ipString) {
  # Convert the ip from dotted form to integer
  ipBits <- unlist(strsplit(ipString, "\\."))
  x <- bitOr(bitOr(bitShiftL(ipBits[1],24), bitShiftL(ipBits[2], 16)), bitOr(bitShiftL(ipBits[3], 8), bitShiftL(ipBits[4],0)))
}

getIPMaskFromSlash <- function(slash) {
  # Generate the bitmask from the / number , for example FF FF FF 00 -> /24 
  x <- bitFlip(0, bitWidth=32) - bitFlip(0, bitWidth=(32 - as.numeric(slash)))
}

annotateIPNetworkSubnetMask <- function (ipInfo) {
  IPNetwork <- rep(0, nrow(ipInfo))
  IPMask <- rep(0, nrow(ipInfo))
  for (i in 1:nrow(ipInfo)) {
    entry <- ipInfo[i,]
    strPrefix <- entry$ip_prefix;
    strPrefix <- unlist(strsplit(strPrefix, "/"))
    IPNetwork[i] <- getIPFromString(strPrefix[1])
    IPMask[i] <- getIPMaskFromSlash(strPrefix[2])
  }
  ipInfo$ip_network <- IPNetwork
  ipInfo$ip_subnet <- IPMask
  ipInfo
}
