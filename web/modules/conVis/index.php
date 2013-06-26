<?php
error_reporting(E_ALL);
ini_set('display_errors', '1');
?>


<!doctype html>
<!--[if lt IE 7]> <html class="no-js lt-ie9 lt-ie8 lt-ie7" lang="en"> <![endif]-->
<!--[if IE 7]>    <html class="no-js lt-ie9 lt-ie8" lang="en"> <![endif]-->
<!--[if IE 8]>    <html class="no-js lt-ie9" lang="en"> <![endif]-->
<!--[if gt IE 8]><!--> <html class="no-js" lang="en-US" dir="ltr"> <!--<![endif]-->
  <head>
	<link href="index.css" rel="stylesheet" type="text/css">
  </head>

  <body>
	<div id="wrapper">
		<div style="width:200px; position:absolute; top:0; left:20px;">
		<h1>Meddle - Connection Visualization<h1>
		<h3>Meddle makes it easy to see who your apps are talking to:</h3>
		<ul style="color: rgb(51,51,51); padding:0 0 0 15px;">
			<li>Each circle with a shadow is an app</li>
			<li>All other nodes are web services</li>
			<li>Lines show the connections each app makes</li>
			<li>Red circles are sites known to track users</li>
			<li>Size shows how often each app or site is used</li>
		</ul>
		<h3>Explore the graph:</h3>
		<ul style="color: rgb(51,51,51); padding:0 0 0 15px;">
			<li>Drag an empty part of the graph to move</li>
			<li>Scroll the mouse wheel to zoom</li>
			<li>Click a link to ban it</li>
			<li>Hover to show only direct connections</li>
		</ul>
		<h5>Best viewed in Google Chrome</h5>
		</div>
		<div id="chooserButton" style="position:fixed; top:0; right:10px;">
			<?php /* This should show the chooser with showChooser() but at the 
			moment, I dont know how to clear the graph other than refreshing the 
			page*/ ?>
		<button type="button" onclick="location.reload()">Pick Data Set</button>
		</div>
		<div id="linkInfo" class="hidden">
		</div>
		<div id="chart"><!-- The d3 layout graph will go inside this div -->
			<svg height="1000px" width="100%" style="opacity: 1;">
				<g id="viewport">
						<defs>
							<!--<marker id="Triangle" viewBox="0 0 10 10" refX="30" refY="5" markerUnits="strokeWidth" markerWidth="8" markerHeight="6" orient="auto">
								<path d="M 0 0 L 10 5 L 0 10 z"></path>
							</marker>-->
							<radialGradient id="glow-gradient" cx="50%" cy="50%" r="50%" fx="50%" fy="50%">
								<stop offset="0%" style="stop-color:rgb(200, 240, 255);stop-opacity:1"></stop>
								<stop offset="100%" style="stop-color:rgb(0,0,0);stop-opacity:0"></stop>
							</radialGradient>
						</defs>
						<g class="links"></g>
						<g class="nodes"></g>
						<path id="domain-label"></path>
						<text id="domain-label-text"></path>
				</g>
			</svg>
		</div>
	</div>
	<script src="script/d3.v3.min.js"></script>
	<script src="script/jquery-1.9.1.js"></script>
	<script src="script/jquery-ui-1.10.3.custom.js"></script>
	<script src="script/jquery.mousewheel.js"></script>
	<script src="script/jQDateRangeSlider-withRuler-min.js"></script>
	<script src="script/graphrunner.js"></script>
	<script src="script/svgpan.js"></script>
	<script src="script/sorttable.js"></script>
	<script id="chooserModel" type="text/plain">
		<!-- Chooser model to be shown by jScript -->
		<div id="chooserWrapper">
			<div id="chooser">
				<div id="chooserTitle">
					<img src="img/xClose.png" onclick="hideChooser()" />
					<h2>Choose data:</h2>
				</div>
				<div id="chooserBody">
					<div id="step1" class="step">
						<div class="stepHeader">
							<div class="stepNum">1</div>
							<h3>Select device and domain name detail</h3>
						</div>
						<div class="stepBody">
							<select id="selectDevice" onchange="changeDevice()">
							</select>
							<select id="subDomainDepth">
								<option value="1">Top Level Domain - "com"</option>
								<option value="2" selected>Domain - "google.com"</option>
								<option value="3">Sub Domains - "maps.google.com"</option>
								<option value="0">Unlimited</option>
							</select>
						</div>
					</div>

					<div id="step2" class="step">
						<div class="stepHeader">
							<div class="stepNum">2</div>
							<h3>Show data in the following range</h3>
						</div>
						<div class="stepBody">
							<div id="sliderContainer">
								<div id="slider" onmouseup="changeRange()">Select a device.</div>
							</div>
						</div>
					</div>

					<div id="step3" class="step">
						<div class="stepHeader">
							<div class="stepNum">3</div>
							<h3>Pick apps to show</h3>
						</div>
						<div class="stepBody">
							<div id="appListWrapper">
							<table id="appList" class="sortable">
								<thead>
									<tr>
										<th>App Name</th>
										<th class="sorttable_numeric">Requests Captured</th>
										<th class="sorttable_nosort"><input type="checkbox" id="checkAll" onclick="checkAll()" checked></input></th>
									</tr>
								</thead>
								<tbody>
								</tbody>
							</table>
							</div>
						</div>
					</div>

					<div id="step4" class="step">
						<div class="stepHeader">
							<div class="stepNum">4</div>
							<h3>Visualize</h3>
						</div>
						<div id="chooserSubmit" class="stepBody">
							<button type="button" onclick="makeGraph(); hideChooser();">Graph</button>
						</div>
					</div>


				</div>
			</div>
		</div>
		<!-- End of Chooser -->
	</script>

	<script type="text/javascript">
		var graph = null;
		var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"];
		var data = null;

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
				if(graph != null){
					graph.update(data);
				} else {
					console.log("Graph is null.");
				}
			}
		}

		function showChooser(){
			if($('#chooserWrapper').length == 0){
				$('body').append($('#chooserModel').text());

				jQuery.getJSON("action.php?action=getDevices", function(obj){
					if(obj.fail){
						alert("An error occurred while fetching your data. Please try again later.");
						console.log(obj);
						return;
					}

					obj.forEach(function(device){
						var name = device.charAt(0).toUpperCase() + device.slice(1);
						$('#selectDevice').append('<option value="'+device+'">'+name+'</option>');
					})
					changeDevice();
					$('#chooser').show(0);
					//$('#chooserWrapper').animate({background:"rgba(51,51,51,0.3)"});				
				});
			}
		}

		function hideChooser(){
			$('#chooser').hide(0, function(){
				$('#chooserWrapper').remove();
			});
		}

		function checkAll(){
			$('#appList tbody input[type=checkbox]').prop('checked', $('#checkAll').prop('checked'));
		}

		function changeDevice(){
			$('#slider').html('Select a device.');
			var device = $('#selectDevice')[0].value;
			jQuery.getJSON("action.php?action=getRange&device="+device, function(obj){
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
					defaultValues: {min: lastWeek, max: endDate},
					formatter: function(val){
					    var days = val.getDate(),
					    month = val.getMonth(),
					    year = val.getFullYear(),
					    hour = val.getHours(),
					    minute = val.getMinutes();
					    zero = '';
					    if(minute < 10)
					    	zero = '0';
					    return months[month] +" "+ days +" "+ year + " - " + hour + ":" +zero+ minute;
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
			var device = $('#selectDevice')[0].value;
			var subDomainDepth = $('#subDomainDepth')[0].value;
			jQuery.getJSON("action.php?action=getData&device="+device+"&min="+(range.min.getTime()/1000)+"&max="+(range.max.getTime()/1000)+"&subdomainDepth="+subDomainDepth, function(obj){
				if(obj.fail){
					alert("Could not complete action. Please try again later.");
					console.log(obj);
					return;
				}
				data = obj;

				var appList = $('#appList tbody');
				appList.html('');
				jQuery.each(obj['apps'], function(index, app){
					appList.append('<tr><td>'+app['name']+'</td><td>'+app['uses']+'</td><td><input type="checkbox" value="'+index+'" checked></input></td></tr>');
				})
			});
		}
		

		// Here on is Mozilla's
		$(window).ready(function() {
			$(window).resize(function(){
				$("svg").attr("height", window.innerHeight);
				$("svg").attr("width", window.innerWidth);
			})


			$("svg").attr("height", window.innerHeight);
			$("svg").attr("width", window.innerWidth);

			// get list of known trackers from trackers.json file hosted on website:
			jQuery.getJSON("trackers.json", function(trackers) {
				var runner = ConVis.Runner({
					width: window.innerWidth,
					height: window.innerHeight,
					trackers: trackers,
					hideFavicons: false
				});
				graph = runner.graph;
			});

			showChooser();
		});
	</script>
  </body>
</html>

