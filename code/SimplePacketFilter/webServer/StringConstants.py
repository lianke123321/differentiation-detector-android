
STATICPATH="/data/webPages"
PAGE_DYNPATH="/dyn/"
PAGE_SERVER_URL = "http://10.11.101.101"
PAGE_UPDATECONFIGS=PAGE_DYNPATH+"updateConfigs"
PAGE_VIEWCONFIGS=PAGE_DYNPATH+"viewConfigs"
PAGE_STATIC_EXPR="^(dyn.*)"
SIGNAL_CONFIG_COMMAND_PATH = "/data/usr/sbin/SignalConfigChange"
STR_TITLE="Meddle"
STR_CAPTCHA_PRIV_KEY = "6LdcvNgSAAAAACIFHFCDgz0wk91qd7o01vWzS1pj"
CFG_ADS_GRP= "cfg_ads"
CFG_ADS_GRP_ENABLE_STR = "enable"
CFG_ADS_GRP_DISABLE_STR = "disable"
PRIV_NETWORK = "10.11."

CFG_SUBMIT_ID="submitID"

DB_HOSTNAME = "sounder.cs.washington.edu"
DB_USER = "meddle"
DB_PASSWORD = "q@847#$6&4@RfbvD"
DB_DBNAME = "MeddleDB"

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



TEMPLATE_PAGE_HEADER = """<head>
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
              <li class="active"><a href="http://meddle.cs.washington.edu/">Home</a></li>
              <li><a href="http://meddle.cs.washington.edu/about.html">About</a></li>
              <li><a href="http://meddle.cs.washington.edu/contact.html">Contact</a></li>
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>
"""
#TEMPLATE_PAGE_FOOTER="""<br/><a href="http://meddle.cs.washington.edu/"> Click here to go back to meddle</a> </body>"""
TEMPLATE_PAGE_FOOTER="""<footer>
     <p>&copy; Copyright 2012 by David Choffnes, University of Washington.</p>
    </footer>
  </div>
  <script src="http://code.jquery.com/jquery-latest.js"></script>
  <script src="js/bootstrap.min.js"></script><br/></body>"""
