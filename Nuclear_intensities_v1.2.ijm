//////////////////////////////////////////////////////////////////////////////////
/* The macro takes as input a whole LIF file of xyzc 1024x1024 12bit images and 
 *  returns a table with the nuclear measurements of Area, Mean intensity and 
 *  Integrated density of every nucleus in the channel of choice, along with 
 *  2 folders "NucleiMasks" and "MasksOfInterest" which contain
 *  projections of every FOV and the outlines of the detection, in the channel
 *  representing the nuclei (DAPI/Hoechst) and the channel of interest respectively. 
 *  
 *  
 *  The images must consist of 3 color channels (DAPI/Hoechst, Red, Green)
 *  and the user determines the seuquence of aqcuisition of the 
 *  color channels, alongside with some steps of image processing.
 */

/* If the vesrion of IJ is previous than 1.53d get input and output
 *  path without using dialog box*/
//output_path = getDirectory("Choose the output folder");
//input_path = File.openDialog("Select the .lif file");

//macro developed by Ourania Preza
//version 1.2
//////////////////////////////////////////////////////////////////////////////////
 
// Create complex dialog box to insert all inputs needed
Dialog.create("Insert the variables");
Dialog.addDirectory("Choose the output folder","");
Dialog.addFile("Select the .lif file", "");
Dialog.addMessage("Size of nuclei, in micron^2\n",15,"#772288");
Dialog.addNumber("Min size of nucleus", 100);
Dialog.addToSameRow();
Dialog.addNumber("Max size of nucleus", "Infinity");
Dialog.addMessage("Set the numbers corresponding to the channels (1-3)",15,"#772288");
Dialog.addNumber("DAPI", "");
Dialog.addToSameRow();
Dialog.addNumber("RFP", "");
Dialog.addToSameRow();
Dialog.addNumber("GFP", "");
items = newArray("RFP","GFP");
Dialog.addRadioButtonGroup("Select the color channel to be analyzed", items, 1, 2, "GFP");
Dialog.addMessage("All the radii asked below should be set according to pixel size of the objects\n",15,"#992233");
Dialog.addMessage("Nucleus pre-process",15,"#772288");
items2 = newArray("Gaussian", "Median");
Dialog.addChoice("Choose the blurring method", items2, "Median");
Dialog.addToSameRow();
Dialog.addNumber("Sigma", 8);
Dialog.addToSameRow();
Dialog.addMessage("The higher the sigma value, the harsher the blurring");
Dialog.addCheckbox("Subtract Background on Nuclear Channel?", 1);
Dialog.addToSameRow();
Dialog.addNumber("Radius", 200);
Dialog.addToSameRow();
Dialog.addMessage("Set it a bit larger than your cells diameter");
Dialog.addMessage("Nucleus thresholding (check only 1/3)\n",15,"#772288");
Dialog.addCheckbox("Global auto threshold", 0);
Dialog.addCheckbox("Global fixed threshold", 0);
Dialog.addToSameRow();
Dialog.addNumber("thr=", 250);
Dialog.addCheckbox("Mean auto local threshold", 1);
Dialog.addToSameRow();
Dialog.addNumber("Radius", 75);
Dialog.addToSameRow();
Dialog.addNumber("thr = mean-C, define \"C\"", -3);
Dialog.show();

output_path = Dialog.getString();
input_path = Dialog.getString();
minSize = Dialog.getNumber();
maxSize = Dialog.getNumber();
DAPI = Dialog.getNumber();
RFP = Dialog.getNumber();
GFP = Dialog.getNumber();
IntChan = Dialog.getRadioButton();
blur = Dialog.getChoice();
sigmagauss = Dialog.getNumber();
subtract = Dialog.getCheckbox();
nucrollball = Dialog.getNumber();
GlobalAuto = Dialog.getCheckbox();
GlobalFixed = Dialog.getCheckbox();
FixedThr = Dialog.getNumber();
LocalAuto = Dialog.getCheckbox();
radius = Dialog.getNumber();
constant = Dialog.getNumber();

if(blur == "Gaussian"){
	gaussblur = 1;
	medianblur = 0;
}
else{
	gaussblur = 0;
	medianblur = 1;
}
sigmamedian = sigmagauss; 


ScaleFactor = 0.25;


//Create result sub-folders in the output folder
nuclei_path = output_path + "NucleiMasks";
measure_path = output_path + "MasksOfInterest";
if (File.exists(nuclei_path)==0){
File.makeDirectory(nuclei_path);
}
if (File.exists(measure_path)==0){
File.makeDirectory(measure_path);
}

// Only required if you want to retrieve the number of series in the LIF file
run("Bio-Formats Macro Extensions");
Ext.setId(input_path);
Ext.getSeriesCount(NbSeries);


//Create table to get results in excel
Table.create("NuclearIntensities");

run("ROI Manager...");
setBatchMode(true);

// Open the series in the file sequentially and analyze
for(s=0;s<NbSeries;s++){
	
	//Clean-up previous results
	roiManager("reset");
	run("Close All");
	run("Clear Results");
	print("\\Clear");
	

	run("Bio-Formats", "open=["+input_path+"] autoscale color_mode=Default crop specify_range view=Hyperstack stack_order=XYCZT series_"+d2s(s+1,0));
	
	getDimensions(width, height, channels, slices, frames);
	// Protect code from crushing in case an image is not acquired with at least 2 channels and z-stack
	if (channels!=1 || slices!=1) {
		
		title = getTitle();
		
		run("Split Channels");
		
		selectImage("C"+GFP+"-" + title);
		if(IntChan!="GFP"){
			close();
		}
		else {
			rename("GFP");
		}
		selectImage("C"+RFP+"-" + title);
		if(IntChan!="RFP"){
			close();
		}
		else {
			rename("RFP");
		}
		selectImage("C"+DAPI+"-" + title);
		rename("DAPI");
		
		
		//filter nuclei channel in 3D and segment in 2D
		selectImage("DAPI");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Max Intensity]");
		setMinAndMax(0, 4095);
		run("8-bit");
		close("DAPI-1");
		selectImage("DAPI");
		// Pre-process with Gaussian Blur or Median Blur (user-options)
		if (gaussblur == 1 || (gaussblur == 0 && medianblur == 0)){
			// Downscale image in order to speed-up code in batch processing
			run("Scale...", "x="+ScaleFactor+" y="+ScaleFactor+" width="+(1024*ScaleFactor)+" height="+(1024*ScaleFactor)+" interpolation=Bilinear  average process create");
			run("Gaussian Blur...", "sigma="+d2s(sigmagauss*ScaleFactor,0)+" stack");
			run("Z Project...", "projection=[Max Intensity]");
		}
		else if (medianblur == 1){
			run("Scale...", "x="+ScaleFactor+" y="+ScaleFactor+" width="+(1024*ScaleFactor)+" height="+(1024*ScaleFactor)+" interpolation=Bilinear  average process create");
			run("Z Project...", "projection=[Max Intensity]");
			run("Median...", "radius="+ d2s(sigmamedian*ScaleFactor,0));
		}
		// Subtract background if selected in user-options
		if (subtract == 1) {
			run("Subtract Background...", "rolling="+ d2s(nucrollball*ScaleFactor,0));
		}
		// Threshold with Global Auto, Global Fixed or Local mean method (user-options)
		if (GlobalAuto == 1 || (GlobalAuto == 0 && GlobalFixed == 0 && LocalAuto == 0)){
			setAutoThreshold("Default dark");
			//run("Threshold...");
			//setAutoThreshold("Otsu dark");
			setAutoThreshold("Huang dark");
			setOption("BlackBackground", false);
		}
		else if (GlobalFixed == 1){
			setThreshold(FixedThr, 4095);
		}
		else if (LocalAuto == 1){
			setMinAndMax(0, 4095);
			run("8-bit");
			run("Auto Local Threshold", "method=Mean radius="+radius+" parameter_1="+constant+" parameter_2=0 white");
		}
		run("Convert to Mask");
		run("Fill Holes"); 
		// Rescale back to original image size before define ROIs
		run("Scale...", "x="+(1/ScaleFactor)+" y="+(1/ScaleFactor)+" width=1024 height=1024 interpolation=None average create");
		// Blur the upscaled mask in order to smooth its boundaries
		run("Gaussian Blur...", "sigma=8");
		setThreshold(80, 255);
		setOption("BlackBackground", false);
		run("Convert to Mask");
		// Descriminate touching cells
		run("Watershed");
		
		// Define nuclei ROIs depending on nuclei size range (user-options)
		run("Analyze Particles...", "size="+d2s(minSize,0)+"-"+d2s(maxSize,0)+" circularity=0.20-1.00 show=Masks exclude summarize add");
		rename("FinalNucMask");
		roiManager("Show None");
		close("DAPI");
		selectImage("MAX_DAPI-1");
		roiManager("show all with labels");
		saveAs("Tiff", ""+nuclei_path+"/MAX_DAPI_"+d2s(s+1,0)+".tif");
		close("MAX_DAPI_"+d2s(s+1,0));
		
		
		nRois = roiManager("count");
		
		// Save Max projections of channel of interest with the nuclear boundaries
		selectImage(IntChan);
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Max Intensity]");
		setMinAndMax(0, 4095);
		run("8-bit");
		roiManager("show all with labels");
		saveAs("Tiff", ""+measure_path+"/MAX_"+IntChan+"_"+d2s(s+1,0)+".tif");
		close(""+IntChan+"-1");
		close("MAX"+IntChan+"-1");
		
		// Measure the intensities of the channel of interest (user-options)
		if(nRois != 0){
			run("Set Measurements...", "area mean standard integrated median redirect=None decimal=0");
			
	
			selectImage(IntChan);
			
			run("Duplicate...", "duplicate");
			
			run("Z Project...", "projection=[Sum Slices]");
			roiManager("Deselect");
			roiManager("multi-measure measure_all");
			close("SUM_"+IntChan+"");
			//Return the results to the FociPerNucleus table
			selectWindow("NuclearIntensities");
			irow = Table.size;
			for(i=0; i<nRois; i++){
				selectWindow("Results");
				Area = Table.get("Area",i);
				Mean = Table.get("Mean",i);
				Std = Table.get("StdDev",i);
				IntDen = Table.get("IntDen",i);
				Median = Table.get("Median",i);
				selectWindow("NuclearIntensities");
				Table.set("Image",(irow+i),s+1);
				Table.set("Nucleus",(irow+i),round(i+1));
				Table.set("Area",(irow+i),Area);
				Table.set("Mean",(irow+i),Mean);
				Table.set("StdDev",(irow+i),Std);
				Table.set("IntDen",(irow+i),IntDen);
				Table.set("Median",(irow+i),Median);
			}
		}
	}
}
setBatchMode("exit & display");
Table.update;
selectWindow("NuclearIntensities");
Table.save(output_path+"/NuclearIntensities.tsv");
close("NuclearIntensities");
close("Results");
close("Log");
close("ROI Manager");
close("Summary");
run("Close All");