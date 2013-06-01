/** 
 *  SVGPan library 1.2.2
 * ======================
 *
 * Given an unique existing element with id "viewport" (or when missing, the 
 * first g-element), including the the library into any SVG adds the following 
 * capabilities:
 *
 *  - Mouse panning
 *  - Mouse zooming (using the wheel)
 *  - Object dragging
 *
 * You can configure the behaviour of the pan/zoom/drag with the variables
 * listed in the CONFIGURATION section of this file.
 *
 * Known issues:
 *
 *  - Zooming (while panning) on Safari has still some issues
 *
 * Releases:
 *
 * 1.2.2, Tue Aug 30 17:21:56 CEST 2011, Andrea Leofreddi
 *	- Fixed viewBox on root tag (#7)
 *	- Improved zoom speed (#2)
 *
 * 1.2.1, Mon Jul  4 00:33:18 CEST 2011, Andrea Leofreddi
 *	- Fixed a regression with mouse wheel (now working on Firefox 5)
 *	- Working with viewBox attribute (#4)
 *	- Added "use strict;" and fixed resulting warnings (#5)
 *	- Added configuration variables, dragging is disabled by default (#3)
 *
 * 1.2, Sat Mar 20 08:42:50 GMT 2010, Zeng Xiaohui
 *	Fixed a bug with browser mouse handler interaction
 *
 * 1.1, Wed Feb  3 17:39:33 GMT 2010, Zeng Xiaohui
 *	Updated the zoom code to support the mouse wheel on Safari/Chrome
 *
 * 1.0, Andrea Leofreddi
 *	First release
 *
 * This code is licensed under the following BSD license:
 *
 * Copyright 2009-2010 Andrea Leofreddi <a.leofreddi@itcharm.com>. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are
 * permitted provided that the following conditions are met:
 * 
 *    1. Redistributions of source code must retain the above copyright notice, this list of
 *       conditions and the following disclaimer.
 * 
 *    2. Redistributions in binary form must reproduce the above copyright notice, this list
 *       of conditions and the following disclaimer in the documentation and/or other materials
 *       provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY Andrea Leofreddi ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Andrea Leofreddi OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * The views and conclusions contained in the software and documentation are those of the
 * authors and should not be interpreted as representing official policies, either expressed
 * or implied, of Andrea Leofreddi.
 */

/// CONFIGURATION 
/// ====>

var enablePan = 1; // 1 or 0: enable or disable panning (default enabled)
var enableZoom = 1; // 1 or 0: enable or disable zooming (default enabled)
var enableDrag = 0; // 1 or 0: enable or disable dragging (default disabled)
var zoomScale = 0.2; // Zoom sensitivity

/// <====
/// END OF CONFIGURATION 

/**
 * Register handlers
 */
var svg = $('svg')[0];

$(window).on("mouseup.svgpan", handleMouseUp)
			.on("mousedown.svgpan", handleMouseDown)
			.on("mousemove.svgpan", handleMouseMove);
			//.on("mousewheel.svgpan", handleMouseWheel);

$("#chart").mousewheel(handleMouseWheel);

var view = $('#viewport')[0];

var state = 'none', stateTarget, stateOrigin, stateTf, mouseLoc;

/**
 * Instance an SVGPoint object with given event coordinates.
 */
function getEventPoint(evt) {
	if(evt.originalEvent)
		evt = evt.originalEvent;
	var p = svg.createSVGPoint();
	p.x = evt.clientX;
	p.y = evt.clientY;
	return p;
}

/**
 * Sets the current transform matrix of an element.
 */
function setCTM(element, matrix) {
	var s = "matrix(" + matrix.a + "," + matrix.b + "," + matrix.c + "," + matrix.d + "," + matrix.e + "," + matrix.f + ")";
	$(element).attr("transform", s);
}

/**
 * Handle mouse wheel event.
 */
function handleMouseWheel(evt) {
	if(!enableZoom)
		return;

	if(evt.preventDefault)
		evt.preventDefault();
	evt.returnValue = false;

	var delta;
	if(evt.originalEvent.wheelDelta)
		delta = evt.originalEvent.wheelDelta / 360; // Chrome/Safari
	else
		delta = evt.originalEvent.detail / -9; // Mozilla

	var z = Math.pow(1 + zoomScale, delta);

	var p = getEventPoint(evt);
	p = p.matrixTransform(view.getCTM().inverse());

	// Compute new scale matrix in current mouse position
	var k = svg.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y);

  	setCTM(view, view.getCTM().multiply(k));

  	var scalar = view.getCTM().a;
  	var lineScale = scalar > 1.5 ? (.1 + .9/(scalar)) : 1/(scalar-3) + 1.37;
  	$('.nozoom').attr("transform", "scale("+lineScale+")");
  	$('.link').attr("style", "stroke-width: "+ lineScale+ " !important;");
  	$('.clickable').attr("style", "stroke-width: "+(10*lineScale)+" !important;");


	if(typeof(stateTf) == "undefined")
		stateTf = view.getCTM().inverse();

	stateTf = stateTf.multiply(k.inverse());

	return false;
}

/**
 * Handle mouse move event.
 */
function handleMouseMove(evt) {
	var panning = state == 'pan'
	d3.select('body').classed("noselect", panning)
	if(panning) {
		var p = getEventPoint(evt).matrixTransform(stateTf);
		setCTM(view, stateTf.inverse().translate(p.x - stateOrigin.x, p.y - stateOrigin.y));
	}
}

/**
 * Handle click event.
 */
function handleMouseDown(evt) {
	if(
		evt.target.tagName == "svg" // Pan anyway when drag is disabled and the user clicked on an element 
	){
		state = 'pan';
		stateTf = view.getCTM().inverse();
		stateOrigin = getEventPoint(evt).matrixTransform(stateTf);
	}
}

/**
 * Handle mouse button release event.
 */
function handleMouseUp(evt) {
	state = '';
}

