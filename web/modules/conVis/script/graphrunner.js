var GraphRunner = (function(jQuery, d3) {
	/* Keep track of whether we're dragging or not, so we can
	 * ignore mousover/mouseout events when a drag is in progress:*/
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
		var SVG_WIDTH = options.width;
		var SVG_HEIGHT = options.height;
		var hideFavicons = options.hideFavicons;
		var scale = d3.scale.log().clamp(true).range([12, 38]);

		var vis = d3.select("#chart svg");

		function setDomainLink(target, d) {
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
		}

		function faviconURL(d) {
			if(d.json.type.indexOf("appAndroid") >= 0)
				return "img/android.ico";
			else if(d.json.type.indexOf("appApple") >= 0)
				return "img/apple.ico";
			else if(d.json.type.indexOf("phoneAndroid") >= 0)
				return "img/androidPhone.ico";
			else if(d.json.type.indexOf("phoneApple") >= 0)
				return "img/applePhone.ico";
			else{
				return 'http://' + d.name + '/favicon.ico';
				}
		}

		function showDomainInfo(d) {
			/*var className = d.name.replace(/\./g, '-dot-');
			var info = $("#domain-infos").find("." + className);

			$("#domain-infos .info").hide();

			// TODO Why do we clone the div instead of just clearing the one and adding to it?
			// Oh, I see, we create a clone for each domain and then re-use it if it's already
			// created. An optimization?
			if (!info.length) {
				info = $("#templates .info").clone();
				info.addClass(className);
				info.find(".domain").text(d.name);
				var img = $('<img>');
				if (d.trackerInfo) {
					var TRACKER_LOGO = "http://images.privacychoice.org/images/network/";
					var trackerId = d.trackerInfo.network_id;
					info.find("h2.domain").empty();
					img.attr("src", TRACKER_LOGO + trackerId + ".jpg").addClass("tracker");
				} else {
					img.attr("src", faviconURL(d)).addClass("favicon");
				}
				setDomainLink(info.find("a.domain"), d);
				info.find("h2.domain").prepend(img);
				img.error(function() { img.remove(); });
				$("#domain-infos").append(info);
			}

			// List referrers, if any (sites that set cookies read by this site)
			var referrers = info.find(".referrers");
			var domains = findReferringDomains(d);
			if (domains.length) {
				var list = referrers.find("ul");
				list.empty();
				domains.forEach(function(d) {
					var item = $('<li><a></a></li>');
					setDomainLink(item.find("a").text(d.name), d);
					list.append(item);
				});
				referrers.show();
			} else {
				referrers.hide();
			}

			// List referees, if any (sites that read cookies set by this site)
			var referrees = info.find(".referrees");
			domains = [];
			vis.selectAll("line.from-" + d.index).each(function(e) {
				domains.push(e.target);
			});
			if (domains.length) {
				var list = referrees.find("ul");
				list.empty();
				domains.forEach(function(d) {
					var item = $('<li><a></a></li>');
					setDomainLink(item.find("a").text(d.name), d);
					list.append(item);
				});
				referrees.show();
			} else {
				referrees.hide();
			}

			info.show();*/
		}

		function createNodes(nodes, force) {

			/* Represent each site as a node consisting of an svg group <g>
			 * containing a <circle> and an <image>, where the image shows
			 * the favicon; circle size shows number of links, color shows
			 * type of site. */

			function getReferringLinkCount(d) {
				return selectReferringLinks(d)[0].length;
			}

			function radius(d) {
				return scale(d.json.hits);
			}

			function selectArcs(d) {
				return vis.selectAll("line.to-" + d.index +
														 ",line.from-" + d.index);
			}

			function getClassForSite(d) {
				if (d.json.visited == true) {
					return "visited";
				}
				if (d.trackerInfo) {
					return "tracker";
				} else {
					return "site";
				}
			}
			
			function textWidth(string, id) {
				var o = $('<div>' + string + '</div>')
									.attr('id', id)
						      .css({'position': 'absolute', 'float': 'left', 'white-space': 'nowrap', 'visibility': 'hidden'})
						      .appendTo($('body')),
						w = o.width();
				o.remove();
				return w;
			}

			function showPopupLabel(d) {
				/* Show popup label to display domain name next to the circle.
				 * The popup label is defined as a path so that it can be shaped not to overlap its circle
				 * Cutout circle on left end, rounded right end, length dependent on length of text.
				 * Get ready for some crazy math and string composition! */
				 
				var r = radius(d); // radius of circles
				var h = 10; // Half the height of the text popout  (Cant be greater than min radius in scale)
				var trigInset = r - Math.sqrt(r*r - h*h); // The leftward displacement of the label top due to the circle
				var pathStartX = d.x + r - trigInset;
				var pathStartY = d.y - h;
				var labelPadding = 5;
				var labelWidth = textWidth(d.name, "#domain-label-text") + (1.5 * labelPadding);
				
				d3.select("#domain-label").classed("hidden", false)
				.attr("d", "M " + pathStartX + " " + pathStartY + " l " + labelWidth + " 0 "
							+ "a "+ h +" "+ h +" 0 0 1 0 "+ h*2 +" l " + (-labelWidth) + " 0 " + "a "+ r +" "+ r +" 0 0 0 0 "+ (-h*2))
				.attr("class", "round-border " + getClassForSite(d));
				d3.select("#domain-label-text").classed("hidden", false)
					.attr("x", d.x + r + labelPadding)
					.attr("y", d.y + 4)
					.text(d.name);
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

			var node = vis.select("g.nodes").selectAll("g.node")
					.data(nodes);

			node.transition()
					.duration(1000)
					.attr("r", radius);

			// For each node, create svg group <g> to hold circle, image, and title
			var gs = node.enter().append("svg:g")
					.attr("class", "node")
					.attr("transform", function(d) {
						// <g> doesn't take x or y attributes but it can be positioned with a transformation
						return "translate(" + d.x + "," + d.y + ")";
					})
					.on("mouseover", function(d) {
						if (isNodeBeingDragged)
							return;
						/* Hide all lines except the ones going in or out of this node;
						 * make those ones bold and show the triangles on the ends */
						vis.selectAll("line").classed("hidden", true);
						selectArcs(d).attr("marker-end", "url(#Triangle)").classed("hidden", false).classed("bold", true);
						showDomainInfo(d);
						showPopupLabel(d);

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
						d3.selectAll("g.node").classed("unrelated-domain", false);
						d3.select("#domain-label").classed("hidden", true);
						d3.select("#domain-label-text").classed("hidden", true);
					})
				.call(force.drag);


			// glow if site is visited
			gs.append("svg:circle")
				.attr("cx", "0")
				.attr("cy", "0")
				.attr("r", function(d){ return 1.5*radius(d) })
				.attr("class", "glow")
				.attr("fill", "url(#glow-gradient)")
				.classed("hidden", function(d) {
								return !d.json.visited;
							});

			gs.append("svg:circle")
					.attr("cx", "0")
					.attr("cy", "0")
					.attr("r", function(d){ return radius(d) })
					.attr("class", function(d) {
								return "node round-border " + getClassForSite(d);
								});

			if (!hideFavicons) {
				// If hiding favicons ("TED mode"), show initial letter of domain instead of favicon
				
				gs.append("svg:image")
					.attr("class", "node")
					.attr("width", function(d){ return radius(d) })
					.attr("height", function(d){ return radius(d) })
					.attr("x", function(d){ return -(radius(d)/2) }) // offset to make 16x16 favicon appear centered
					.attr("y", function(d){ return -(radius(d)/2) })
					.attr("xlink:href", faviconURL);
			}

			return node;
		}

		function createLinks(links) {
			var enter = vis.select("g.links").selectAll("g.link")
					.data(links).enter();

					enter.append("svg:line").attr("class", function(d){ return 'link from-'+ d.source.index +' to-'+ d.target.index; })
						.attr("x1", function(d){ return d.source.x; })
						.attr("y1", function(d){ return d.source.y; })
						.attr("x2", function(d){ return d.target.x; })
						.attr("x2", function(d){ return d.target.y; })
					enter.append("svg:line").attr("class", "clickable")
						.attr("x1", function(d){ return d.source.x; })
						.attr("y1", function(d){ return d.source.y; })
						.attr("x2", function(d){ return d.target.x; })
						.attr("x2", function(d){ return d.target.y; })
						.on("click", destroyLink)
						.attr("onmouseover", "$(this).attr(\"style\", \"stroke: rgb(255,140,140)\")")
						.attr("onmouseout", "$(this).attr(\"style\", \"\")");
		}

		function draw(json) {
			var force = d3.layout.force()
					.charge(function(d){ return -20 * scale(d.json.hits) } /*-500*/)
					.distance(120)
					.friction(0.9)
					.nodes(json.nodes)
					.links(json.links)
					.size([SVG_WIDTH, SVG_HEIGHT])
					.start();

			createLinks(json.links);
			createNodes(json.nodes, force);

			vis.style("opacity", 1e-6)
				.transition()
					.duration(1000)
					.style("opacity", 1);

			force.on("tick", function() {
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
				force: force
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
			var domainIds = {};

			function getNodeId(json) {
				if (!(json.shortname in domainIds)) {
					domainIds[json.shortname] = nodes.length;
					var trackerInfo = null;
					if(json.shortname in trackers)
						trackerInfo = trackers[json.shortname];
					nodes.push({
						name: json.shortname,
						trackerInfo: trackerInfo,
						json: json
					});
				}
				return domainIds[json.shortname];
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
				data: null,
				update: function(json) {
					this.data = json;
					scale.domain([1, json.maxHits]);
					drawing.force.stop();

					for (var app in json['apps'])
						for (var request in json['apps'][app].requests)
							addLink(json['apps'][app], json['apps'][app].requests[request]);
					for (var n = 0; n < nodes.length; n++) {
						if (json[nodes[n].name]) {
							nodes[n].wasVisited = json[nodes[n].name].visited;
						} else {
							nodes[n].wasVisited = false;
						}

						/* For nodes that don't already have a position, initialize them near the center.
						 * This way the graph will start from center. If it already has a position, leave it.
						 * Note that initializing them all exactly at center causes there to be zero distance,
						 * which makes the repulsive force explode!! So add some random factor. */
						if (typeof nodes[n].x == "undefined") {
							nodes[n].x = nodes[n].px = SVG_WIDTH / 2 + Math.floor( Math.random() * 50 ) ;
							nodes[n].y = nodes[n].py = SVG_HEIGHT / 2 + Math.floor( Math.random() * 50 );
						}
					}

					drawing.force.nodes(nodes);
					drawing.force.links(links);
					drawing.force.start();
					createLinks(links);
					createNodes(nodes, drawing.force);
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

function destroyLink(d, i){
	alert("This is only a demo, but if this was your data, clicking a link would ban future connections between " + d.source.name + " and " + d.target.name);
	/*req = new XMLHttpRequest();
	req.open("POST", "action.php", true);
	req.onreadystatechange=function(){
			if (req.readyState==4){
				if (req.status==200){
					console.log(req.responseText);
				}else{
					
				}
			};
		};
	req.setRequestHeader("Content-type","application/x-www-form-urlencoded");
	req.send("obj="+JSON.stringify(d));*/
}
