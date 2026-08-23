roiManager("Select All");
run("Set Measurements...", "centroid redirect=None decimal=3");
roiManager("measure");
roiManager("show all");
for(i=0; i<nResults; i++){
	
	roiManager("select", i);
	run("Interpolate", "interval=1");
	getSelectionCoordinates(xpoints, ypoints);
	
	x_ctr = newArray(nResults);
	y_ctr = newArray(nResults);
	x_ctr[i] = getResult("X", i);
	y_ctr[i] = getResult("Y", i);
	
	y_diff = newArray(ypoints.length);
	x_diff = newArray(xpoints.length);
	theta = newArray(xpoints.length);
	distance_xy = newArray(xpoints.length);
	
	for (j = 0; j < xpoints.length; j++) {	
		y_diff[j] = ypoints[j]-y_ctr;
		x_diff[j] = xpoints[j]-x_ctr;
		distance_xy[j] = sqrt(Math.sqr(y_diff[j])+Math.sqr(x_diff[j]));
		theta[j] = (180/PI) * atan2(y_diff[j], x_diff[j]);
		if (theta[j] < 0){
			theta[j] = theta[j] + 360;		
		}
	}
	Array.sort(theta, distance_xy);
	Array.resample(theta, 720);
	Array.resample(distance_xy,720);
	Plot.create("Invasion Radial Distance", "Theta", "Distance");
	Plot.add("dot", theta, distance_xy);
	Plot.setLimitsToFit();
	Plot.show();
}
close("results");
