Dialog.create("ROI Centering");
Dialog.addMessage("This gets parameters required for centering your ROIs");

Dialog.addNumber("X-width", 800);
Dialog.addNumber("Y-width", 800);
Dialog.addChoice("Type:", newArray("8-bit", "16-bit", "32-bit"));
Dialog.addChoice("Type:", newArray("black", "white", "ramp"));

Dialog.show();

x_width = Dialog.getNumber();
y_width = Dialog.getNumber();
array_type = Dialog.getChoice();
image_color = Dialog.getChoice();
z_width = 1;

inputdir = getDirectory("Choose a folder containing only ROI files");

filelist = getFileList(inputdir);

for(i=0; i<filelist.length; i++){
	if(matches(filelist[i], "(?i).*(zip|roi)$")){
		roiManager("open", inputdir + "/" + filelist[i]);
		}
}

newImage("RoI_Centred", array_type+image_color, x_width, y_width, z_width);

roiManager("Select All");
run("Set Measurements...", "centroid redirect=None decimal=3");
roiManager("measure");
for(i=0; i<nResults; i++){
	roiManager("select", i);
	x = getResult("X", i);
	y = getResult("Y", i);
	x_tran = (x_width/2)-x;
	y_tran = (y_width/2)-y;
	RoiManager.translate(x_tran,y_tran);
}
roiManager("show all");
run("Close")