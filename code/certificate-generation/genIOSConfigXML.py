import subprocess
import sys
import string
import base64

def genP12File(clientName, clientPass, p12Name, caName, caCert, caKey, DNstr):
     # the number of arguments depend on the p12 script being used
     # returns 0 on creating a file of name p12Name
    
    return 0

# ipSecCertPath="/home/arao/etc/ipsec.d/"
# caCert="${ipSecCertPath}/cacerts/caCert.pem"
# caKey="${ipSecCertPath}/private/caKey.pem"
# DNstr="C=US, O=snowmane, CN=${clientName}"
# caName="snowmane CA" # The name used in the certificate
# CERTPATH="./"
# p12File="${CERTPATH}/${clientName}.p12"

def dumpConfXML(xmlPath, p12Path, clientName, clientPassword, serverHostName, caCertPath, orgName, connDisplayName, caName):
    # Write the xml File if you have the p12Name
    # xmlName name of the xmlfile
    # p12Name the name of the p12Name
    # clientName the client name
    # clientPass the client password
    # serverName the hostname of the server
    # caCert the certficate file
    # orgName the name of the organization generating this file
    # connDispName the name that will be shown on the screen of the iOS device
    caCertName=caCertPath.split("/")[-1]
    p12Name=p12Path.split("/")[-1]
    #print caCertName, p12Name
    with open(p12Path, "r") as fp12, open(caCertPath,"r") as fpcert, open(xmlPath, "w") as fpxml:
        temp = fp12.read()
        base64p12 = base64.standard_b64encode(temp);
        #print base64p12
        
        caLines = fpcert.readlines()
        
        base64caCert = ''.join(elem for elem in caLines[1:-1])
        base64caCert = ''.join(elem for elem in base64caCert.splitlines())
        #print base64caCert
        
        templateString = string.Template("""<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>PayloadContent</key><array><dict><key>IPSec</key><dict><key>AuthenticationMethod</key><string>Certificate</string><key>OnDemandEnabled</key><integer>1</integer><key>OnDemandMatchDomainsAlways</key><array><string>a</string><string>b</string><string>c</string><string>d</string><string>e</string><string>f</string><string>g</string><string>h</string><string>i</string><string>j</string><string>k</string><string>l</string><string>m</string><string>n</string><string>o</string><string>p</string><string>q</string><string>r</string><string>s</string><string>t</string><string>u</string><string>v</string><string>w</string><string>x</string><string>y</string><string>z</string><string>0</string><string>1</string><string>2</string><string>3</string><string>4</string><string>5</string><string>6</string><string>7</string><string>8</string><string>9</string></array><key>OnDemandMatchDomainsNever</key><array/><key>OnDemandMatchDomainsOnRetry</key><array/><key>PayloadCertificateUUID</key><string>9D88D0FC-93AD-4239-8ECA-4778F65A635D</string><key>PromptForVPNPIN</key><true/><key>RemoteAddress</key><string>${serverHostName}</string><key>XAuthEnabled</key><integer>1</integer><key>XAuthName</key><string>${clientName}</string><key>XAuthPassword</key><string>${clientPassword}</string></dict><key>IPv4</key><dict><key>OverridePrimary</key><integer>0</integer></dict><key>PayloadDescription</key><string>ConfiguresVPNsettings,includingauthentication.</string><key>PayloadDisplayName</key><string>${connDisplayName}</string><key>PayloadIdentifier</key><string>${connDisplayName}</string><key>PayloadOrganization</key><string>${orgName}</string><key>PayloadType</key><string>com.apple.vpn.managed</string><key>PayloadUUID</key><string>793833B1-AA94-4172-B15C-06B2EEB696AF</string><key>PayloadVersion</key><integer>1</integer><key>Proxies</key><dict/><key>UserDefinedName</key><string>${connDisplayName}</string><key>VPNType</key><string>IPSec</string></dict><dict><key>PayloadCertificateFileName</key><string>${p12Name}</string><key>PayloadContent</key><data>${base64p12}</data><key>PayloadDescription</key><string>Providesdeviceauthentication(certificateoridentity).</string><key>PayloadDisplayName</key><string>${p12Name}</string><key>PayloadIdentifier</key><string>${connDisplayName}</string><key>PayloadOrganization</key><string>${orgName}s</string><key>PayloadType</key><string>com.apple.security.pkcs12</string><key>PayloadUUID</key><string>9D88D0FC-93AD-4239-8ECA-4778F65A635D</string><key>PayloadVersion</key><integer>1</integer></dict><dict><key>PayloadCertificateFileName</key><string>${caCertName}</string><key>PayloadContent</key><data>${base64caCert}</data><key>PayloadDescription</key><string>Providesdeviceauthentication(certificateoridentity).</string><key>PayloadDisplayName</key><string>${caName}</string><key>PayloadIdentifier</key><string>${connDisplayName}s\.credential</string><key>PayloadOrganization</key><string>${orgName}</string><key>PayloadType</key><string>com.apple.security.root</string><key>PayloadUUID</key><string>E3E02F85-57AE-476D-86B5-F2AE7BF45D09</string><key>PayloadVersion</key><integer>1</integer></dict></array><key>PayloadDescription</key><string>${connDisplayName}</string><key>PayloadDisplayName</key><string>${connDisplayName}</string><key>PayloadIdentifier</key><string>${connDisplayName}</string><key>PayloadOrganization</key><string>${orgName}</string><key>PayloadRemovalDisallowed</key><false/><key>PayloadType</key><string>Configuration</string><key>PayloadUUID</key><string>25D3DE60-FE5C-4576-877F-0AF58C1F12D3</string><key>PayloadVersion</key><integer>1</integer></dict></plist>""")
        substDict = dict(serverHostName=serverHostName, clientName=clientName, clientPassword=clientPassword,
                         connDisplayName=connDisplayName, orgName=orgName, p12Name=p12Name, base64p12=base64p12,
                         caCertName=caCertName, base64caCert=base64caCert, caName=caName)
        dumpStr = templateString.safe_substitute(substDict)
        fpxml.write(dumpStr)
        return 0
    return 1

if __name__ == "__main__":
    #if len(sys.argv) != 3:
    #    print "sys.argv[0] <clientName> <password>"
    #    exit(-1)
    # Check for the encoding
    #clientName = sys.argv[0]
    #clientPass = sys.argv[1]
    
    dumpConfXML(p12Path="./dave1.p12", clientName="dave1", clientPassword="newsecret", serverHostName="snowmane.cs.washington.edu", caCertPath="./caCert.pem", orgName="University of Washington CSE", connDisplayName="Meddle VPN", caName="snowmane CA", xmlPath="./dave1.mobileconfig")    

