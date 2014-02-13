import smtplib, os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from email.Utils import COMMASPACE, formatdate
from email import Encoders


ANDROIDMESSAGE = """Hi,
The attachment contains the credentials required by Meddle.

The installation instructions are available at
http://vpn.meddle.mobi/android.html

The password required during the installation of this certificate is
PASSWORD_TO_REPLACE

The VPN app (mentioned in Step 3) for Android devices is available at
http://vpn.meddle.mobi/apk/MeddleVPN.apk

The server name to be mentioned in Step 4 is
vpn.meddle.mobi

If there is any configuration problems please feel free to contact me.

Regards,
Ashwin
"""


IOSMESSAGE = """Hi,
The attachment contains the credentials required by Meddle.

The installation instructions are available at
http://vpn.meddle.mobi/ios.html

The password required during the installation of this certificate is
PASSWORD_TO_REPLACE

If there is any configuration problems please feel free to contact me.

Regards,
Ashwin
"""


class SendEmail:
    smtpObj = None

    def __init__(self):
        self.smtpObj = None

    def connectToServer(self, userName, password, host, port):
        self.smtpObj = smtplib.SMTP()
        self.smtpObj.connect(host,port)
        self.smtpObj.ehlo()        
        self.smtpObj.starttls()
        self.smtpObj.login(userName,password)
        return True

    def getMessageBody(self, deviceOS, installationPassword):
        message = ""
        if deviceOS.find("android") != -1:
            message = ANDROIDMESSAGE
        else:
            message = IOSMESSAGE
        message = message.replace("PASSWORD_TO_REPLACE", installationPassword)
        return message
        

    # NOTE no check for email validity done here.    
    def sendMail(self, sendFrom, sendTo, subject, deviceOS, sendCC, files, installationPassword):
        #Create Message
        msg = MIMEMultipart()        
        msg['From'] = sendFrom
        msg['To'] = sendTo
        msg['CC'] = COMMASPACE.join(sendCC)
        msg['Date'] = formatdate(localtime=True)        
        msg['Subject'] = subject        

        # Add Text
        msg.attach(MIMEText(self.getMessageBody(deviceOS,installationPassword)))                    

        for f in files:
            # Assuming all files are text files
            part = None                    
            if f.find("p12") != -1:
                print str(f)+str(" - mime - p12")                    
                part = MIMEApplication(open(f, 'rb').read(), "x-pkcs12")
            elif f.find("mobileconfig") != -1:
                part = MIMEApplication(open(f, 'r').read(), "xml")                    
            else:
                print str(f)+str(" - mime octet")                
                part = MIMEBase('application', "octet-stream")                    
                part = MIMEBase(open(f, 'rb').read())
                Encoders.encode_base64(part)                    
                 
            # Encode the payload using Base64            
            attach = 'attachment; filename="'+str(os.path.basename(f))+'"'
            part.add_header('Content-Disposition', attach)                    
            msg.attach(part)                    
        # Create a list of receivers    
        sendRecv = [sendTo] + sendCC    
        self.smtpObj.sendmail(sendFrom, sendRecv, msg.as_string())
        return True        

    def closeConn(self):
       self.smtpObj.close()
       return True
                    
if __name__ == "__main__":
    import sys
    if len(sys.argv) != 7:
        print "Argument invalid:"+str(sys.argv)
        print str(sys.argv[0]) +" <senderEmail> <senderPassword> <recipientEmail> <deviceOS> <configFiles> <installationPassword>"
        sys.exit(-1)
                    
    senderEmail = sys.argv[1]
    senderPassword = sys.argv[2]
    recipientEmail = sys.argv[3]
    deviceOS = sys.argv[4]
    configFiles = [sys.argv[5]]
    installationPassword = sys.argv[6]
    
    mailServerHost = "smtp.gmail.com"
    mailServerPort = 587
    mailCC = []
    subject = "Meddle Credentials for your device running "+str(deviceOS)
    
    s = SendEmail()
    s.connectToServer(senderEmail, senderPassword, mailServerHost, mailServerPort)    
    s.sendMail(senderEmail, recipientEmail, subject, deviceOS, mailCC, configFiles, installationPassword) 
