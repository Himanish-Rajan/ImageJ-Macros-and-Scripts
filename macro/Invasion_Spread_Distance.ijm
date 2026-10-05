roiManager("Select All");
run("Set Measurements...", "area centroid redirect=None decimal=3");
roiManager("measure");
roiManager("show all");

getPixelSize(unit, pixelWidth, pixelHeight)
px = parseFloat(pixelWidth);
py = parseFloat(pixelHeight);
N = 1;

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
	
	dist_raw = Resamp(theta, dist, N);
	
	theta_resamp = Array.slice(dist_raw , 0, dist_raw.length/2);
	dist_resamp = Array.slice(dist_raw , dist_raw.length/2, dist_raw.length);
	
	Array.getStatistics(dist_resamp, min, max_d1, mean_d1, stdDev);
	dist_mean = newArray(dist_resamp.length);
	Array.fill(dist_mean, mean_d1);
	yMax = max_d1 + 50;
	
	Plot.create("Invasion Radial Distance", "Angle in deg ", "Distance" + " in " + unit, theta_resamp, dist_resamp);
	Plot.setColor("red");
	Plot.add("dot", theta_resamp, dist_mean);
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
		
		dist_resamp_raw_i = Resamp(theta_i, dist_i, N);
		Array.print(dist_resamp_raw_i);
		dist_resamp_i = Array.slice(dist_resamp_raw_i, dist_resamp_raw_i.length/2, dist_resamp_raw_i.length);
		theta_resamp = Array.slice(dist_resamp_raw_i, 0, dist_resamp_raw_i.length/2);
		
	//	ROI 2 - Small Area ROI
		roiManager("select", b);
		run("Interpolate", "interval=1");
		getSelectionCoordinates(x_ii, y_ii);
		
		roi_ii = ThetaDist(x_ii, y_ii, x_ctr[floor(i/2)], y_ctr[floor(i/2)]);
		theta_ii = Array.slice(roi_ii, 0, roi_ii.length/2);
		dist_ii = Array.slice(roi_ii, roi_ii.length/2, roi_ii.length);
		
		dist_resamp_raw_ii = Resamp(theta_ii, dist_ii, N);
		dist_resamp_ii = Array.slice(dist_resamp_raw_ii, dist_resamp_raw_ii.length/2, dist_resamp_raw_ii.length);
		
	//	Plotting
		Array.getStatistics(dist_resamp_i, min, max_di, mean_di, stdDev);
		Array.getStatistics(dist_resamp_ii, min, max_dii, mean_dii, stdDev);
		dist_i_mean = newArray(dist_resamp_i.length);
		Array.fill(dist_i_mean, mean_di);
		dist_ii_mean = newArray(dist_resamp_ii.length);
		Array.fill(dist_ii_mean, mean_dii);
		if (max_di > max_dii) yMax = max_di + 50; else yMax = max_dii + 50;
		
		Plot.create("Invasion Radial Distance", "Angle in deg ", "Distance" + " in " + unit, theta_resamp, dist_resamp_i);
		Plot.add("dot", theta_resamp, dist_i_mean);
		Plot.setColor("blue");
		Plot.add("line", theta_resamp, dist_resamp_ii);
		Plot.add("dot", theta_resamp, dist_ii_mean);
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

// Function for resampling data to N
function Resamp(theta, dist, SampSize) {
	k = 0;
	index_list = newArray(SampSize*360);
	theta_concat_precur = Array.getSequence(SampSize*360);
	theta_concat = newArray(SampSize*360);
	dist_resamp = newArray(SampSize*360);
	
	dist_new = Array.resample(dist,dist.length+SampSize*360);
	
	for(x=0; x<theta_concat_precur.length; x++){
		theta_concat[x] = theta_concat_precur[x]/SampSize;
	}
	
	theta_new = Array.concat(theta,theta_concat);
	Array.sort(theta_new);
	
	for(s=0; s<theta_new.length; s++){
		if(k==SampSize*360){continue}
		if(theta_new[s] == theta_concat[k]){
			index_list[k] = s;
			k++;
		}
	}
	
	for(m=0; m<index_list.length; m++){
		dist_resamp[m] = dist_new[index_list[m]];
	}
	
	return Array.concat(theta_concat,dist_resamp);
}
