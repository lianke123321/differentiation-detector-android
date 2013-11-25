
STATICPATH="/opt/meddle/WebPages"
PAGE_DYNPATH="/dyn/"
PAGE_UPDATECONFIGS=PAGE_DYNPATH+"updateConfigs"
PAGE_VIEWCONFIGS=PAGE_DYNPATH+"viewConfigs"
PAGE_VIEWGRAPH=PAGE_DYNPATH+"viewGraph"

VIEWGRAPH_QT_RANGE="1"
VIEWGRAPH_QT_GRAPH="2"

PAGE_STATIC_EXPR="^(dyn.*)"
STR_TITLE="Meddle"
STR_CAPTCHA_PRIV_KEY = "6LdcvNgSAAAAACIFHFCDgz0wk91qd7o01vWzS1pj"
CFG_ADS_GRP= "cfg_ads"
CFG_ADS_GRP_ENABLE_STR = "enable"
CFG_ADS_GRP_DISABLE_STR = "disable"
CFG_SUBMIT_ID="submitID"
CFG_SUBMIT_STR = "Save Settings"

#TEMPLATE_INTEREST_EMAIL_SUBMITTER = "STR_INTEREST_EMAIL"
#TEMPLATE_INTEREST_EMAIL_HANDLERS = "arao@cs.uw.edu, choffnes@cs.uw.edu"
#TEMPLATE_INTEREST_EMAIL_SENDER = "arao@cs.uw.edu"
#TEMPLATE_INTEREST_EMAIL_BODY = """From: """+TEMPLATE_INTEREST_EMAIL_SENDER+"""
#To: """+ TEMPLATE_INTEREST_EMAIL_HANDLERS + """
#Subject: Meddle Interest from address """ + TEMPLATE_INTEREST_EMAIL_SUBMITTER + """
#
#Please respond to this interest.
#"""

# They keys in the meddle.config file
MCFG_DB_PASSWD = "dbPassword"
MCFG_DB_NAME = "dbName"
MCFG_DB_USER = "dbUserName"
MCFG_DB_HOST = "dbServer"
MCFG_MSG_SRVIP = "msgSockIpAddress"
MCFG_MSG_SRVPORT = "msgSockPort"
MCFG_MSG_SIGPATH = "msgConfigChangePath"
MCFG_TUN_IPPREFIX = "tunClientIpNetPrefix"
MCFG_WEBPAGES_PATH = "webPagesStaticPath"
MCFG_WEBSRV_PORT = "webServerPort"
MCFG_WEBSRV_HOST = "webServerHost"
MCFG_IRB_URL = "webIrbUrl"

SERVER_HOST_FILLER = 'SERVER_HOST_FILLER'
SERVER_PORT_FILLER = 'SERVER_PORT_FILLER'
# TODO: Note I have not modified the strings SERVER_HOST/PORT_FILLER in TEMPLATES
TEMPLATE_PAGE_HEADER = """<!DOCTYPE html>
<html lang="en">
  <head>
  <meta charset="utf-8" />

  <!-- Always force latest IE rendering engine (even in intranet) & Chrome Frame 
       Remove this if you use the .htaccess -->
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />

  <title>Meddle: Take Control of Your Mobile Traffic</title>
  <meta name="description" content="" />
  <meta name="author" content="choffnes" />
  <link href="css/bootstrap.min.css" rel="stylesheet" media="screen">
  <style>
        body {
        padding-top: 40px;
        padding-bottom: 40px;
      }
      .sidebar-nav {
        padding: 9px 0;
      }
      .navbar-inner {
  background-color: #320142; /* fallback color, place your own */

  /* Gradients for modern browsers, replace as you see fit */
  background-image: -moz-linear-gradient(top, #320142, #63177c);
  background-image: -ms-linear-gradient(top, #320142, #63177c);
  background-image: -webkit-gradient(linear, 0 0, 0 100%, from(#320142), to(#63177c));
  background-image: -webkit-linear-gradient(top, #320142, #63177c);
  background-image: -o-linear-gradient(top, #320142, #63177c);
  background-image: linear-gradient(top, #320142, #63177c);
  background-repeat: repeat-x;

  /* IE8-9 gradient filter */
  filter: progid:DXImageTransform.Microsoft.gradient(startColorstr='#320142', endColorstr='#222222', GradientType=0);
}
</style>

  <meta name="viewport" content="width=device-width; initial-scale=1.0" />

  <!-- Replace favicon.ico & apple-touch-icon.png in the root of your domain and delete these references -->
  <link rel="shortcut icon" href="/favicon.ico" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  </head>
  <body>

      <div class="navbar navbar-inverse navbar-fixed-top">
      <div class="navbar-inner foo" style="background: #320142;">
        <div class="container-fluid">
          <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </a>
          <a class="brand" href="#">Meddle</a>
          <div class="nav-collapse collapse">
            <!--<p class="navbar-text pull-right">
              Logged in as <a href="#" class="navbar-link">Username</a>
            </p> -->
            <ul class="nav">
              <li class="active"><a href="http://SERVER_HOST_FILLER:SERVER_PORT_FILLER/index.html">Home</a></li>
              <li><a href="http://SERVER_HOST_FILLER:SERVER_PORT_FILLER/about.html">About</a></li>
              <li><a href="http://SERVER_HOST_FILLER:SERVER_PORT_FILLER/contact.html">Contact</a></li>
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>
"""

TEMPLATE_PAGE_FOOTER="""<footer>
     <p>&copy; Copyright 2012 by David Choffnes, University of Washington.</p>
    </footer>
  </div>
  <script src="http://code.jquery.com/jquery-latest.js"></script>
  <script src="js/bootstrap.min.js"></script><br/></body></html>"""
