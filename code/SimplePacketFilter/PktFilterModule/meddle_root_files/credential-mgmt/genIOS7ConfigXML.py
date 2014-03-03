import subprocess
import sys
import string
import base64
import uuid

# Write the xml File if you have the p12Name
# xmlName name of the xmlfile
# p12Name the name of the p12Name
# clientName the client name
# clientPass the client password
# serverName the hostname of the server
# caCert the certficate file
# orgName the name of the organization generating this file
# connDispName the name that will be shown on the screen of the iOS device

def dumpConfXML(xmlPath, p12Path, clientName, clientPassword, serverHostName, caCertPath, orgName, connDisplayName, caName):
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
        
        templateString = string.Template("""<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            <key>PayloadContent</key>
            <array>
			<dict>
            <key>IPSec</key>
            <dict>
            <key>AuthenticationMethod</key>
            <string>Certificate</string>
            <key>OnDemandEnabled</key>
            <integer>1</integer>
            
            <key>OnDemandRules</key>
            <array>
                <dict>
                    <key>Action</key>
                    <string>EvaluateConnection</string>
                    <key>ActionParameters</key>
                    <array>
                        <dict>
                        <key>Domains</key>
                        <array>
                        <string>trip.meddle.mobi</string>
                        </array>
                        <key>DomainAction</key>
                        <string>NeverConnect</string>
                        </dict>
                    </array>
                    <key>URLStringProbe</key>
                    <string>http://trip.meddle.mobi/nosuchpage.html</string>
                </dict>
                <dict>
                    <key>Action</key>
                    <string>Connect</string>
                    <key>InterfaceTypeMatch</key>
                    <string>WiFi</string>
                    <key>URLStringProbe</key>
                    <string>https://www.apple.com</string>
                </dict>
                <dict>
                    <key>Action</key>
                    <string>Connect</string>
                    <key>InterfaceTypeMatch</key>
                    <string>Cellular</string>
                    <key>URLStringProbe</key>
                    <string>https://www.apple.com</string>
                </dict>
                <dict>
                    <key>Action</key>
                    <string>Connect</string>
                    <key>DNSDomainMatch</key>
                    <array>
                        <string>a</string>
                        <string>b</string>
                        <string>c</string>
                        <string>d</string>
                        <string>e</string>
                        <string>f</string>
                        <string>g</string>
                        <string>h</string>
                        <string>i</string>
                        <string>j</string>
                        <string>k</string>
                        <string>l</string>
                        <string>m</string>
                        <string>n</string>
                        <string>o</string>
                        <string>p</string>
                        <string>q</string>
                        <string>r</string>
                        <string>s</string>
                        <string>t</string>
                        <string>u</string>
                        <string>v</string>
                        <string>w</string>
                        <string>x</string>
                        <string>y</string>
                        <string>z</string>
                        <string>0</string>
                        <string>1</string>
                        <string>2</string>
                        <string>3</string>
                        <string>4</string>
                        <string>5</string>
                        <string>6</string>
                        <string>7</string>
                        <string>8</string>
                        <string>9</string>
                    </array>
                    <key>URLStringProbe</key>
                    <string>https://www.apple.com</string>
                </dict>
                <dict>
                    <key>Action</key>
                    <string>Disconnect</string>
                </dict>
            </array>
            <key>PayloadCertificateUUID</key>
            <string>9D88D0FC-93AD-4239-8ECA-4778F65A635D</string>
            <key>PromptForVPNPIN</key>
            <false />
            <key>RemoteAddress</key>
            <string>${serverHostName}</string>
            <key>XAuthEnabled</key>
            <integer>1</integer>
            <key>XAuthName</key>
            <string>${clientName}</string>
            <key>XAuthPassword</key>
            <string>${clientPassword}</string>
            </dict>
            <key>IPv4</key>
            <dict>
            <key>OverridePrimary</key>
            <integer>1</integer>
            </dict>
            <key>OverridePrimary</key>
            <integer>1</integer>
            <key>PayloadDescription</key>
            <string>ConfiguresVPNsettings,includingauthentication.</string>
            <key>PayloadDisplayName</key>
            <string>${connDisplayName}</string>
            <key>PayloadIdentifier</key>
            <string>${connDisplayName}</string>
            <key>PayloadOrganization</key>
            <string>${orgName}</string>
            <key>PayloadType</key>
            <string>com.apple.vpn.managed</string>
            <key>PayloadUUID</key>
            <string>793833B1-AA94-4172-B15C-06B2EEB696AF</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>Proxies</key>
            <dict />
            <key>UserDefinedName</key>
            <string>${connDisplayName}</string>
            <key>VPNType</key>
            <string>IPSec</string>
			</dict>
			<dict>
            <key>PayloadCertificateFileName</key>
            <string>${p12Name}</string>
            <key>PayloadContent</key>
            <data>${base64p12}</data>
            <key>PayloadDescription</key>
            <string>Providesdeviceauthentication(certificateoridentity).</string>
            <key>PayloadDisplayName</key>
            <string>${p12Name}</string>
            <key>PayloadIdentifier</key>
            <string>${connDisplayName}</string>
            <key>PayloadOrganization</key>
            <string>${orgName}</string>
            <key>PayloadType</key>
            <string>com.apple.security.pkcs12</string>
            <key>PayloadUUID</key>
            <string>9D88D0FC-93AD-4239-8ECA-4778F65A635D</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
			</dict>
			<dict>
            <key>PayloadCertificateFileName</key>
            <string>${caCertName}</string>
            <key>PayloadContent</key>
            <data>${base64caCert}</data>
            <key>PayloadDescription</key>
            <string>Providesdeviceauthentication(certificateoridentity).</string>
            <key>PayloadDisplayName</key>
            <string>${caName}</string>
            <key>PayloadIdentifier</key>
            <string>${connDisplayName} credentials</string>
            <key>PayloadOrganization</key>
            <string>${orgName}</string>
            <key>PayloadType</key>
            <string>com.apple.security.root</string>
            <key>PayloadUUID</key>
            <string>E3E02F85-57AE-476D-86B5-F2AE7BF45D09</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
			</dict>
            </array>
            <key>PayloadDescription</key>
            <string>${connDisplayName}</string>
            <key>PayloadDisplayName</key>
            <string>${connDisplayName}</string>
            <key>PayloadIdentifier</key>
            <string>${connDisplayName}</string>
            <key>PayloadOrganization</key>
            <string>${orgName}</string>
            <key>PayloadRemovalDisallowed</key>
            <false />
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>${uid}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            </dict>
        </plist>""")

        substDict = dict(serverHostName=serverHostName, clientName=clientName, clientPassword=clientPassword,
                         connDisplayName=connDisplayName, orgName=orgName, p12Name=p12Name, base64p12=base64p12,
                         caCertName=caCertName, base64caCert=base64caCert, caName=caName, uid=str(uuid.uuid4()))
        dumpStr = templateString.safe_substitute(substDict)
        fpxml.write(dumpStr)
        print "Created" + xmlPath
        return 0
    return 1

if __name__ == "__main__":
    if len(sys.argv) != 9:
        print "Argument invalid:"+str(sys.argv)
        print "sys.argv[0] <clientName> <password> <orgName> <connDisplayName> <caName> <serverHostName> <caCertPath> <clientCertPath>"
        exit(-1)
        
    # Check for the encoding
    # orgName="University of Washington CSE"
    # connDisplayName="Meddle VPN"
    # caName="Meddle CA"
    # serverHostName="meddle.cs.washington.edu"
    # caCertPath ="./ServerKeys/MeddleCACert.pem"

    clientName = sys.argv[1]
    clientPassword = sys.argv[2]
    orgName = sys.argv[3]
    connDisplayName = sys.argv[4]
    caName = sys.argv[5]
    serverHostName = sys.argv[6]
    caCertPath = sys.argv[7]
    clientCertPath = sys.argv[8]
    
    dumpConfXML(p12Path=str(clientCertPath)+str(clientName)+".p12",
                clientName=clientName, clientPassword=clientPassword, serverHostName=serverHostName,
                caCertPath=caCertPath, orgName=orgName, connDisplayName=connDisplayName, caName=caName,
                xmlPath=str(clientCertPath)+str(clientName)+"-ios7.mobileconfig")
