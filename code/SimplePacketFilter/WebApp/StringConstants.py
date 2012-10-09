STR_TITLE="Meddle"

PAGE_UPDATECONFIGS="updateConfigs"

CFG_ADS_GRP= "cfg_ads"
CFG_ADS_GRP_ENABLE_STR = "enable"
CFG_ADS_GRP_DISABLE_STR = "disable"
PRIV_NETWORK = "192.168.0"

CFG_SUBMIT_ID="submitID"

DB_HOSTNAME = "localhost"
DB_USER = "meddle"
DB_PASSWORD = "meddle"
DB_DBNAME = "MeddleDB"

CFG_SUBMIT_STR = "Save Settings"
TEMPLATE_PAGE_HEADER = """<!--Force IE6 into quirks mode with this comment tag-->
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title> """ +str(STR_TITLE)+"""</title>
<style type="text/css">
body {
font-size: 2em;
}
select,input {
font-size: 1.25em;
}
</style>
"""

TEMPLATE_PAGE_FOOTER="""</body> """
