authTokenPlaceholder="AUTHTOKENPLACEHOLDER"
CONVISURLTEMPLATE="http://SERVER_HOST_FILLER:SERVER_PORT_FILLER/dyn/viewGraph?auth=AUTHTOKENPLACEHOLDER&qt=3"
CONVISTEMPLATE="""
<html class="no-js" lang="en-US" dir="ltr">  
  <head>
  <meta charset="utf-8" />

  <!-- Always force latest IE rendering engine (even in intranet) & Chrome Frame 
       Remove this if you use the .htaccess -->
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />

  <title>Meddle: Take Control of Your Mobile Traffic</title>
  <meta name="description" content="" />
  <meta name="author" content="choffnes" />
  <link href="/css/bootstrap.min.css" rel="stylesheet" media="screen">
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
  
  
  <link href="/css/convis.css" rel="stylesheet" type="text/css">
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
              <li class="active"><a href="index.html">Home</a></li>
              <li><a href="about.html">About</a></li>              
              <li><a href="contact.html">Contact</a></li>
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>
    
    <div class="container-fluid">
      <div class="row-fluid">
        <div class="span3">        
          <div class="well sidebar-nav">        
            <ul class="nav nav-list">
              <li class="nav-header">Meddle - Connection Visualization</li>
              <li>Each circle with an android icon is an app</li>
              <li>Red circles are sites known to track users</li>
              <li>A line between an app and a tracker shows that the app contacted the tracker</li>
              <li>Size of an app shows how many flows originate from the app </li>
              <li>Size of a tracker shows how many flows contacted the tracker </li>	      
            </ul>
          </div>
	</div>
      </div>
    </div>
	  <script src="/js/d3.v3.min.js"></script>
	  <script src="/js/jquery-1.9.1.js"></script>
	  <script src="/js/jquery-ui-1.10.3.custom.js"></script>
	  <script src="/js/jquery.mousewheel.js"></script>
	  <script src="/js/jQDateRangeSlider-withRuler-min.js"></script>
	  <script src="/js/graphrunner.js"></script>
	  <script src="/js/svgpan.js"></script>
	  <script src="/js/sorttable.js"></script>
	  <script id="chooserScipt" type="text/plain">
	    <div id="chooserWrapper" class="container-fluid">
	      <div id="chooser" class="row-fluid">
		<div id="chooserBody" class="span5">                  
                  <h4>Show data in the following range</h4>
                  <div id="sliderContainer">
		    <div id="slider" onmouseup="changeRange()">Select a device.</div>
                  </div>
                  <h4>Select App</h4>
                  <div id="appListWrapper">
		    <table id="appList" class="table table-bordered sortable">
		      <thead bgcolor="lightgray">
			<tr>
                          <th>App</th>
                          <th class="sorttable_numeric"># Trackers</th>
                          <th class="sorttable_nosort"><input type="checkbox" id="checkAll" onclick="checkAll()" checked> All</input></th>
			  <!-- <th class="sorttable_nosort">Select </th> -->
			</tr>
		      </thead>
		      <tbody>
		      </tbody>
		    </table>
                  </div>		    		  
		  <div id="chooserSubmit" class="stepBody">
                    <button class="btn btn-large  btn-primary" onclick="hideChooser(); showGraph();">Show Graph</button>
		  </div>
		</div>
	      </div>
	    </div>
	  </script>
	  <script id="graphScript" type="text/plain">
	    <div id="graphWrapper" class="container-fluid">
	      <div id="graphMain" class="row-fluid">
		<div id="graphBody">		  
		  <h4>Explore the graph:</h4>
		  <div id="chooserReload" class="stepBody">
                    <button class="btn btn-normal btn-primary" onclick="location.reload()">Change Parameters</button>
		  </div>	      		      		  
		  <div id="chart"><!-- The d3 layout graph will go inside this div -->
		    <svg height="80%" width="100%" style="opacity: 1;">
		      <g id="viewport">
			<defs>
			  <radialGradient id="glow-gradient" cx="50%" cy="50%" r="50%" fx="50%" fy="50%">
			    <stop offset="0%" style="stop-color:rgb(200, 240, 255);stop-opacity:1"></stop>
			    <stop offset="100%" style="stop-color:rgb(0,0,0);stop-opacity:0"></stop>
			  </radialGradient>
			</defs>
			<g class="links"></g>
			<g class="nodes"></g>
			<path id="domain-label"></path>
			<text id="domain-label-text"></text>
		      </g>
		    </svg>
		  </div>
		</div>
	      </div>
	    </div>	    
	  </script>  
	  <script type="text/javascript">
        var graph = null;
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"];
        var data = null;
        var runner = null;

        function showChooser(){
           $('body').append($('#chooserScipt').text());
           $('#chooser').show(0);        
           changeDevice();      
        }
        
        function hideChooser(){
            $('#chooser').hide(0, function(){
                $('#chooserScipt').remove();
            });
        }
	
        function showGraph(){	
           $('body').append($('#graphScript').text());
           $('#graphMain').show(0);
	   if (runner == null) {
                runner = ConVis.Runner({width: window.innerWidth,
                                        height: window.innerHeight,
                                        hideFavicons: false
                                      });
	        graph = runner.graph;		
	   }
	   makeGraph();
        }
	
        function hideGraph(){
            $('#graphMain').hide(0, function(){
                $('#graphScript').remove();
            });
        }        
	

        function makeGraph(){
            if(data == null){
                alert("Select some data before trying to graph.");
            } else {
                data.maxUses = 1;
                $('#appList tbody input[type=checkbox]').each(function(index, checkbox){
                    if(!checkbox.checked){
                        delete data['apps'][checkbox.value]
                    } else {
                        if(data['apps'][checkbox.value].uses > data.maxUses)
                            data.maxUses = data['apps'][checkbox.value].uses;
                    }
                });
                if(graph != null) {
                    graph.update(data);
                } else {
                    console.log("Graph is null.");
                }
            }
        }
        
        function checkAll(){
            $('#appList tbody input[type=checkbox]').prop('checked', $('#checkAll').prop('checked'));
        }

        function changeDevice(){
            jQuery.getJSON("/dyn/viewGraph?auth=AUTHTOKENPLACEHOLDER&qt=1", function(obj) {
                console.log(obj)
                $('#slider').html('');

                if(obj.fail){
                    $('#slider').html("Could not get data for device. Please try again later.");
                    console.log(obj);
                    return;
                }

                var startDate = new Date(obj.min * 1000);
                var endDate = new Date(obj.max * 1000);
                var lastWeek = new Date(obj.max * 1000);
                lastWeek.setDate(lastWeek.getDate() - 7);

                $("#slider").dateRangeSlider({
                    bounds: {min: startDate, max: endDate},
                    defaultValues: {min: startDate, max: endDate},
                    formatter: function(val){
                        var days = val.getDate(),
                        month = val.getMonth(),
                        year = val.getFullYear();
                        //hour = val.getHours(),
                        //minute = val.getMinutes();
                        //zero = '';
                        //if(minute < 10)
                        //    zero = '0';
                        return months[month] +" "+ days;
                        //return months[month] +" "+ days +" "+ year + " - " + hour + ":" +zero+ minute;
                    },
                    scales: [{
                        first: function(value){ return value; },
                        end: function(value) {return value; },
                        next: function(value){
                            var next = new Date(value);
                            return new Date(next.setMonth(value.getMonth() + 1));
                        },
                        label: function(value){
                            return months[value.getMonth()];
                        },
                        format: function(tickContainer, tickStart, tickEnd){
                            tickContainer.addClass("myCustomClass");
                        }
                    }],
                    //range: {min: {days: 0}, max: {days: 14}},
                });
                changeRange();
            });
        }

        function changeRange(){
            var range = $('#slider').dateRangeSlider("values");
            jQuery.getJSON("/dyn/viewGraph?auth=AUTHTOKENPLACEHOLDER&qt=2&min="+(range.min.getTime()/1000)+"&max="+(range.max.getTime()/1000), function(obj){
                if(obj.fail){
                    alert("Could not complete action. Please try again later.");
                    console.log(obj);
                    return;
                }
                data = obj;

                var appList = $('#appList tbody');
                appList.html('');
                jQuery.each(obj['apps'], function(index, app){
                    appList.append('<tr><td>'+app['name']+'</td><td>'+app['uses']+'</td><td><input class="appcheckbox" type="checkbox" value="'+index+'" checked></input></td></tr>');
                })
            });
        }
        
        // Here on is Mozilla's
        $(window).ready(function() {
            //$(window).resize(function(){
            //    $("svg").attr("height", window.innerHeight);
            //    $("svg").attr("width", window.innerWidth);
            //})
            //$("svg").attr("height", window.innerHeight);
            //$("svg").attr("width", window.innerWidth);
             <!-- runner = ConVis.Runner({width: window.innerWidth, -->
             <!--                        height: window.innerHeight, -->
             <!--                        hideFavicons: false -->
             <!--                       }); -->
             <!--  graph = runner.graph; -->
              showChooser();
                                    
//            $('#appList').on('change', '.appcheckbox', function(e) {
//                // alert($(this).val() + ' is now ' + $(this).is(':checked'));
//            });                                    
        });
         </script>
         <script src="/js/bootstrap.min.js"></script>
  </body>
</html>
"""
