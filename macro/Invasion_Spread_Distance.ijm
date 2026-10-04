roiManager("Select All");
run("Set Measurements...", "area centroid redirect=None decimal=3");
roiManager("measure");
roiManager("show all");

getPixelSize(unit, pixelWidth, pixelHeight)
px = parseFloat(pixelWidth);
py = parseFloat(pixelHeight);
n_samp = 360;

if(nResults==1){
	//	ROI 1 only
	roiManager("select", 0);
	run("Interpolate", "interval=1");
	getSelectionCoordinates(x, y);
	
	x_ctr = getResult("X", 0)/px;
	y_ctr = getResult("Y", 0)/py;
	
	roi = ThetaDist(x, y, x_ctr, y_ctr);
	theta = Array.slice(roi, 0, roi.length/2);
	dist = Array.slice(roi, roi.length/2, roi.length);
	
	n = Math.ceil(theta.length/n_samp);
	resamp = Resamp(theta, dist, n);
	theta_resamp = Array.slice(resamp, 0, resamp.length/2);
	dist_resamp = Array.slice(resamp, resamp.length/2, resamp.length);
	
	Array.getStatistics(dist_resamp, min, max_d1, mean_d1, stdDev);
	x_seq = Array.getSequence(360);
	dist_mean = newArray(360);
	Array.fill(dist_mean, mean_d1);
	yMax = max_d1 + 50;
	
	Plot.create("Invasion Radial Distance", "Angle in deg ", "Distance" + " in " + unit, theta_resamp, dist_resamp);
	Plot.setColor("red");
	Plot.add("dot", x_seq, dist_mean);
	Plot.setLimits(0, 360, 0, yMax);
	Plot.show();
}

else{
	x_ctr = newArray(nResults/2);
	y_ctr = newArray(nResults/2);
	
	for(i=0; i<nResults; i=i+2){
		
		roi_1_area = getResult("Area", i);
		roi_2_area = getResult("Area", i+1);
		
		if(roi_1_area>roi_2_area){
			x_ctr[floor(i/2)] = getResult("X", i+1)/px;
			y_ctr[floor(i/2)] = getResult("Y", i+1)/py;
			a = i; b = i+1;
		}
		else {
			x_ctr[floor(i/2)] = getResult("X", i)/px;
			y_ctr[floor(i/2)] = getResult("Y", i)/py;
			a = i+1; b = i;
		}
		
	//	ROI 1 - Large Area ROI
		roiManager("select", a);
		run("Interpolate", "interval=1");
		getSelectionCoordinates(x_i, y_i);
		
		roi_i = ThetaDist(x_i, y_i, x_ctr[floor(i/2)], y_ctr[floor(i/2)]);
		theta_i = Array.slice(roi_i, 0, roi_i.length/2);
		dist_i = Array.slice(roi_i, roi_i.length/2, roi_i.length);
		
		n_i = Math.ceil(theta_i.length/n_samp);
		resamp_i = Resamp(theta_i, dist_i, n_i);
		theta_resamp_i = Array.slice(resamp_i, 0, resamp_i.length/2);
		dist_resamp_i = Array.slice(resamp_i, resamp_i.length/2, resamp_i.length);
		
	//	ROI 2 - Small Area ROI
		roiManager("select", b);
		run("Interpolate", "interval=1");
		getSelectionCoordinates(x_ii, y_ii);
		
		roi_ii = ThetaDist(x_ii, y_ii, x_ctr[floor(i/2)], y_ctr[floor(i/2)]);
		theta_ii = Array.slice(roi_ii, 0, roi_ii.length/2);
		dist_ii = Array.slice(roi_ii, roi_ii.length/2, roi_ii.length);
		
		n_ii = Math.ceil(theta_ii.length/n_samp);
		resamp_ii = Resamp(theta_ii, dist_ii, n_ii);
		theta_resamp_ii = Array.slice(resamp_ii, 0, resamp_ii.length/2);
		dist_resamp_ii = Array.slice(resamp_ii, resamp_ii.length/2, resamp_ii.length);
		
		
	//	Plotting
		Array.getStatistics(dist_resamp_i, min, max_di, mean_di, stdDev);
		Array.getStatistics(dist_resamp_ii, min, max_dii, mean_dii, stdDev);
		x_seq = Array.getSequence(360);
		dist_i_mean = newArray(360);
		Array.fill(dist_i_mean, mean_di);
		dist_ii_mean = newArray(360);
		Array.fill(dist_ii_mean, mean_dii);
		if (max_di > max_dii) yMax = max_di + 50; else yMax = max_dii + 50;
		
		Plot.create("Invasion Radial Distance", "Angle in deg ", "Distance" + " in " + unit, theta_resamp_i, dist_resamp_i);
		Plot.add("dot", x_seq, dist_i_mean);
		Plot.setColor("blue");
		Plot.add("line", theta_resamp_ii, dist_resamp_ii);
		Plot.add("dot", x_seq, dist_ii_mean);
		Plot.setColor("black");
		Plot.setLimits(0, 360, 0, yMax);
		Plot.show();
	}
}
close("results");

// Function for measuring distance and angle
function ThetaDist(x, y, x_ctr, y_ctr) {
	y_diff = newArray(y.length);
	x_diff = newArray(x.length);
	theta = newArray(x.length);
	distance_xy = newArray(x.length);
	
	for (j = 0; j < x.length; j++) {	
		y_diff[j] = py*(y[j]-y_ctr);
		x_diff[j] = px*(x[j]-x_ctr);
		distance_xy[j] = sqrt(Math.sqr(y_diff[j])+Math.sqr(x_diff[j]));
		theta[j] = (180/PI) * atan2(y_diff[j], x_diff[j]);
		if (theta[j] < 0){
			theta[j] = theta[j] + 360;
		}
	}
	Array.sort(theta, distance_xy);
	return Array.concat(theta, distance_xy);
}

// Function for resampling data to n_samp bins
function Resamp(theta, dist, N) {
	k = 0;
	x_samp = floor(theta.length/N);
	y_samp = floor(dist.length/N);
	theta_resamp = newArray(x_samp);
	dist_resamp = newArray(y_samp);
	
	for (z = 0; z + N < theta.length; z=z+N) {
		
		theta_slice = newArray(N);
		dist_slice = newArray(N);
		
		theta_slice = Array.slice(theta,z,z+N);
		dist_slice = Array.slice(dist,z,z+N);
		
		Array.getStatistics(theta_slice, min, max, mean_th, stdDev);
		theta_resamp[k] = mean_th;
		Array.getStatistics(dist_slice, min, max, mean_dt, stdDev);
		dist_resamp[k] = mean_dt;
		k++;	
	}
	return Array.concat(theta_resamp, dist_resamp);
}