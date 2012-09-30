from StringConstants import *

class UserConfigs:
    userName = ""
    userID = ""
    filterAds = ""
    
    def __init__(self, uname, uid, filtAds):
        self.userName = uname
        self.uid = uid
        self.filterAds = filtAds
        return
    
    def __htmlAds(self):
        adStr = "<ul>Ad Filtering"
        enabled = ""
        disabled = ""
        if self.filterAds == 1:
            enabled = "checked"            
        else:            
            disabled = "checked"        
        adStr += """ <li> <input type="radio" name="""+str(CONFIG_ADS_GROUP)+""" value="enable" """+str(enabled) + """> Enable Ad Filtering</li>"""
        adStr += """ <li> <input type="radio" name="""+str(CONFIG_ADS_GROUP)+""" value="disable" """+str(disabled) +"""> Enable Ad Filtering</li>"""
        adStr += "</ul>"        
        return    
    
    def htmlifyConfigs(self):
        configStr = self.__htmlAds()
        return configStr
                   
    
    
   
class DisplayUserConfigs:
    def __init__(self):
        
        return None
    
    def __header(self):        
        hstr = """<!--Force IE6 into quirks mode with this comment tag-->
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title> """ +str(PAGE_TITLE)+"""</title>
</head>
<body>
"""
        return hstr;       
    
    def __footer(self):
        fstr ="""</body> """        
        
    def displayConfigs(self, userConfig):
        page = ""
        page += self.__header()
        page += """<form name="input" action="userConfigs" method="get">"""
        page += userConfigs.htmlifyConfigs()
        page += """<input type="submit" value="Submit"></form>"""
        page += self.__footer()
        return page
    
 if __name__ == "__main__":
          