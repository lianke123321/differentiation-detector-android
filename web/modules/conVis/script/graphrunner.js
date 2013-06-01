var ConVis = (function(jQuery, d3) {
	//TODO Unused at the moment
	if (!String.prototype.format) {
	  String.prototype.format = function() {
	    var args = arguments;
	    return this.replace(/{(\d+)}/g, function(match, number) { 
	      return typeof args[number] != 'undefined'
	        ? args[number]
	        : match
	      ;
	    });
	  };
	}

	// Keep track of whether we're dragging or not, so we can
	// ignore mousover/mouseout events when a drag is in progress:*/
	var isNodeBeingDragged = false;
	window.addEventListener("mousedown", function(e) {
		if ($(e.target).closest("g.node") != null)
			isNodeBeingDragged = true;
	}, true);
	window.addEventListener("mouseup", function(e) {
		isNodeBeingDragged = false;
	}, true);

	function Runner(options) {
		var trackers = options.trackers;
		// Do this once so it doesnt have to be done later
		for (var i = 0; i < trackers.length; i++)
			trackers[trackers[i].domain] = trackers[i];



		var vis = d3.select("#chart svg");
		
		//TODO start here
		/*function redraw(){
			if(d3.event){
				projection.translate(d3.event.translate)
				.scale(d3.event.scale);
			}

			svg.selectAll("circle").attr("d")
		}
		this.x = d3.scale.linear()
	      .domain([this.options.xmin, this.options.xmax])
	      .range([0, this.size.width]);
	    this.y = d3.scale.linear()
	      .domain([this.options.xmin, this.options.xmax])
	      .range([0, this.size.width]);
		vis.call(d3.behavior.zoom().x(this.x).y(this.y).on("zoom", this.redraw()));*/
		var SVG_WIDTH = options.width;
		var SVG_HEIGHT = options.height;
		var hideFavicons = options.hideFavicons;
		var scale = d3.scale.log().clamp(true).range([12, 38]);
		var phone = null;

		/*function setDomainLink(target, d) {
			target.removeClass("tracker").removeClass("site");
			if (d.trackerInfo) {
				var TRACKER_INFO = "http://www.privacychoice.org/companies/index/";
				var trackerId = d.trackerInfo.network_id;
				target.attr("href", TRACKER_INFO + trackerId);
				target.addClass("tracker");
			} else {
				target.attr("href", "http://" + d.name);
				target.addClass("site");
			}
		}*/

		function faviconURL(d) {
			if(d.isApp) {
				if(phone = "Android")
					return "img/android.ico";
				else if(phone = "Apple")
					return "img/apple.ico";
				else
					return "img/generic.ico";
			} else {
				return 'http://' + d.name + '/favicon.ico';
			}
		}

		function radius(d) {
			return scale(d.isApp ? d.uses : d.hits);
		}

		function drawNodes(nodes, forceGraph) {
			// Represent each site as a node consisting of an svg group <g>
			// containing a <circle> and an <image>, where the image shows
			// the favicon; circle size shows number of links, color shows
			// type of site.

			

			function selectArcs(d) {
				return vis.selectAll("line.to-" + d.index +
														 ",line.from-" + d.index);
			}

			function getClassForSite(d) {
				if (d.isApp == true)
					return "app";
				if (d.trackerInfo)
					return "tracker";
				return "host";
			}

			function getConnectedDomains(d) {
				var connectedDomains = [d.name];
				findReferringDomains(d).forEach( function(e) {
					connectedDomains.push(e.name);
				});
				vis.selectAll("line.from-" + d.index).each(function(e) {
					connectedDomains.push(e.target.name);
				});

				return connectedDomains;
			}

			// For each node, create svg group <g> to hold circle, image, and title
			var gs = vis.select("g.nodes").selectAll("g.node").data(nodes)
				.enter().append("svg:g")
					.attr("class", "node")
					.attr("id", function(d){return "node"+d.index})
					.attr("transform", function(d) {
						// <g> doesn't take x or y attributes but it can be positioned with a transformation
						return "translate(" + d.x + "," + d.y + ")";
					})
					.on("mouseover", function(d) {
						if (isNodeBeingDragged)
							return;
						// Hide all lines except the ones going in or out of this node;
						// make those ones bold and show the triangles on the ends
						vis.selectAll("line").classed("hidden", true);
						selectArcs(d).classed("hidden", false).classed("bold", true);
						
						// Show the label
						d3.select("#node"+d.index+" path").classed("hidden", false);
						d3.select("#node"+d.index+" text").classed("hidden", false);

						// Make directly-connected nodes opaque, the rest translucent:
						var subGraph = getConnectedDomains(d);
						d3.selectAll("g.node").classed("unrelated-domain", function(d) {
								return (subGraph.indexOf(d.name) == -1);
						});
					})
					.on("mouseout", function(d) {
						if (isNodeBeingDragged)
							return;
						vis.selectAll("line").classed("hidden", false);
						selectArcs(d).attr("marker-end", null).classed("bold", false);
						d3.selectAll(".unrelated-domain").classed("unrelated-domain", false);
						
						// Hide label
						d3.select("#node"+d.index+" path").classed("hidden", true);
						d3.select("#node"+d.index+" text").classed("hidden", true);
					})
				.call(forceGraph.drag).append("svg:g")
				.attr("class", "nozoom");

			// glow if site is visited
			gs.append("svg:circle")
				.attr("cx", "0")
				.attr("cy", "0")
				.attr("r", function(d){ return 1.5*radius(d) })
				.attr("class", "glow")
				.attr("fill", "url(#glow-gradient)")
				.classed("hidden", function(d) {
								return !d.isApp;
							});

			gs.append("svg:circle")
					.attr("cx", "0")
					.attr("cy", "0")
					.attr("r", radius)
					.attr("class", function(d) {
								return "node round-border " + getClassForSite(d);
								});

			gs.append("svg:image")
					.attr("class", "node")
					.attr("width", radius)
					.attr("height", radius)
					.attr("x", function(d){ return -(radius(d)/2) }) // offset to make 16x16 favicon appear centered
					.attr("y", function(d){ return -(radius(d)/2) })
					.attr("xlink:href", faviconURL);

			
			var labelPadding = 5;

			

			gs.append("svg:text")
				.attr("x", function(d){ return radius(d) + labelPadding })
				.attr("y", "4")
				.text(function(d){return d.name});

			gs.insert("svg:path", ":last-child")
				.attr("d", function(d){
					var r = radius(d); // radius of circles
					var h = 10; // Half the height of the text popout  (Cant be greater than min radius in scale)
					var trigInset = r - Math.sqrt(r*r - h*h); // The leftward displacement of the label top due to the circle
					var pathStartX = r - trigInset;
					var pathStartY = -h;
					var text = d3.select("#node"+d.index+" text");
					var labelWidth = text[0][0].getBoundingClientRect().width + labelPadding;
					text.classed("hidden", true);

					return "M " + pathStartX + " " + pathStartY + " l " + labelWidth + " 0 "
							+ "a "+ h +" "+ h +" 0 0 1 0 "+ h*2 +" l " + (-labelWidth) + " 0 " + "a "+ r +" "+ r +" 0 0 0 0 "+ (-h*2);

				})
				.attr("class", function(d){ return "round-border " + getClassForSite(d)})
				.classed("hidden", true);
		}

		function drawLinks(links) {
			var enter = vis.select("g.links").selectAll("g.link")
					.data(links).enter().append("svg:g")
					.attr("class", function(d){ return 'from-'+ d.source.index +' to-'+ d.target.index; });

					enter.append("svg:line").attr("class", function(d){ return 'link from-'+ d.source.index +' to-'+ d.target.index; })
						.attr("x1", function(d){ return d.source.x; })
						.attr("y1", function(d){ return d.source.y; })
						.attr("x2", function(d){ return d.target.x; })
						.attr("x2", function(d){ return d.target.y; })
						//Figure this one out
						.classed("banned", function(d){ return d.source.banned ? d.source.banned[d.target.name] : false });
					enter.append("svg:line").attr("class", "clickable no-stroke")
						.attr("x1", function(d){ return d.source.x; })
						.attr("y1", function(d){ return d.source.y; })
						.attr("x2", function(d){ return d.target.x; })
						.attr("x2", function(d){ return d.target.y; })
						.on("click", destroyLink)
						.on("mouseover", highlight)
						.on("mouseout", unhighlight);/*
						.attr("onmouseover", "$(this).attr(\"class\", \"clickable\")")
						.attr("onmouseout", "$(this).attr(\"class\", \"clickable no-stroke\")");*/
		}

		function highlight(d, i){
			console.log(".from-" + d.source.index + ".to-" + d.target.index+" .clickable");
			$(".from-" + d.source.index + ".to-" + d.target.index+" .clickable").attr("class", "clickable");
			$('#linkInfo').attr("class", "").html("Link from <b>"+d.source.name+"</b> to <b>"+d.target.name+"</b>.");
		}

		function unhighlight(d, i){
			$(".from-" + d.source.index + ".to-" + d.target.index+" .clickable").attr("class", "clickable no-stroke");
			$('#linkInfo').attr("class", "hidden").html("");
		}

		function destroyLink(d, i){
			req = new XMLHttpRequest();
			req.open("POST", "action.php?action=banLink", true);
			req.onreadystatechange=function(){
					if (req.readyState==4){
						if (req.status==200){
							console.log(req.responseText);
							obj = jQuery.parseJSON(req.responseText);
							if(!obj.fail){
								d3.select('.link.from-'+ d.source.index +'.to-' + d.target.index)
								.classed("banned", function(){ return obj.success == "banned"; });
							} else {
								alert("Could not add to block list. Please try again later.");
								console.log(obj);
							}
						}else{
							alert("Could not contact server. Please try again later.");
						}
					};
				};
			req.setRequestHeader("Content-type","application/x-www-form-urlencoded");
			req.send("obj="+JSON.stringify(d));
		}


		function draw(json) {
			var forceGraph = d3.layout.force()
					.charge(function(d){ return -20 * radius(d) })
					.distance(120)
					.friction(0.9)
					.nodes(json.nodes)
					.links(json.links)
					.size([SVG_WIDTH, SVG_HEIGHT])
					.start();

			d3.behavior.zoom();

			drawLinks(json.links);
			drawNodes(json.nodes, forceGraph);

			vis.style("opacity", 1e-6)
				.transition()
					.duration(1000)
					.style("opacity", 1);

			forceGraph.on("tick", function() {
				 vis.selectAll(".links line")
						.attr("x1", function(d) { return d.source.x; })
						.attr("y1", function(d) { return d.source.y; })
						.attr("x2", function(d) { return d.target.x; })
						.attr("y2", function(d) { return d.target.y; });

				 vis.selectAll("g.node").attr("transform", function(d) {
						return "translate(" + d.x + "," + d.y + ")";
				 });
			});

			return {
				vis: vis,
				forceGraph: forceGraph
			};
		}

		function selectReferringLinks(d) {
			return vis.selectAll("line.to-" + d.index);
		}

		function findReferringDomains(d, list, domain) {
			if (!list) {
				list = [];
				domain = d.name;
			}

			selectReferringLinks(d).each(function(d) {
				if (list.indexOf(d.source) == -1 &&
						d.source.name != domain) {
					list.push(d.source);
					findReferringDomains(d.source, list, domain);
				}
			});

			return list;
		}

		function CollusionGraph(trackers) {
			var nodes = [];
			var links = [];
			var nodeIds = {};

			function getNodeId(json) {
				var index = json.isApp ? "appId"+json.appId : json.name;
				if (!(index in nodeIds)) {
					nodeIds[index] = nodes.length;
					if(index in trackers)
						json.trackerInfo = trackers[index];
					nodes.push(json);
				}
				return nodeIds[index];
			}

			function addLink(app, host) {
				var fromId = getNodeId(app);
				var toId = getNodeId(host);
				var link = vis.select("line.to-" + toId + ".from-" + fromId);
				if (!link[0][0])
					links.push({source: fromId, target: toId});
			}

			var drawing = draw({nodes: nodes, links: links});

			return {
				update: function(json) {
					phone = json.phone;
					scale.domain([1, json.maxUses]);
					drawing.forceGraph.stop();

					for (var app in json['apps']){
						var tempApp = json['apps'][app];
						tempApp.isApp = true;
						tempApp.appId = app;
						for (var host in json['apps'][app].contacts){
							var temp = json['apps'][app].contacts[host];
							temp.name = host;
							addLink(json['apps'][app], temp);
						}
					}
					for (var n = 0; n < nodes.length; n++) {
						///* Initialize nodes near the center.
						// * Note that initializing them all exactly at center causes there to be zero distance,
						// * which makes the repulsive force explode!! So add some random factor.
						if(nodes[n].x == undefined){
							nodes[n].x = nodes[n].px = SVG_WIDTH / 2 + Math.floor( Math.random() * 50 ) ;
							nodes[n].y = nodes[n].py = SVG_HEIGHT / 2 + Math.floor( Math.random() * 50 );
						}
					}

					drawing.forceGraph.nodes(nodes);
					drawing.forceGraph.links(links);
					drawing.forceGraph.start();
					drawLinks(links);
					drawNodes(nodes, drawing.forceGraph);
				}
			};
		}

		function makeBufferedGraphUpdate(graph) {
			var timeoutID = null;

			return function(json) {
				if (timeoutID !== null)
				 clearTimeout(timeoutID);
				timeoutID = setTimeout(function() {
					timeoutID = null;

					graph.update(json);
				}, 250);
			};
		}

		var graph = CollusionGraph(trackers);

		var self = {
			graph: graph,
			width: SVG_WIDTH,
			height: SVG_HEIGHT,
			updateGraph: makeBufferedGraphUpdate(graph)
		};

		return self;
	}

	var GraphRunner = {
		Runner: Runner
	};

	return GraphRunner;
})(jQuery, d3);

