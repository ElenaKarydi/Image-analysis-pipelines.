//////////////////////////////////////////////////////////////////////////////////////
/* The macro takes as input a whole LIF file of xyzc 1024x1024,
 *  12bit, 3 color channels (DAPI/Hoechst, Red, Green) images and returns a table 
 *  with the number of local maxima detected in every nucleus in the channel of 
 *  choice, along with projections of every FOV and the outlines of the detection. 
 *  The output folders created are "IdentifiedMaxima", "InitialMasks", "Nuclei" and
 *  "UnfilteredFoci" which contain the following:
 *  
 *  -"IdentifiedMaxima": contains a subfolder "FociMasks" with binary images of point 
 *  selection of the local maxima and a series of zip folders of the ROIs that the user
 *  can open through ROI Manager in ImageJ/FIji.
 *  -"InitialMasks": contains binary masks of the nuclei before watershed and before
 *  removing the nuclei touching the borders of the image
 *  -"Nuclei": contains 8bit images of maximal projections of the channel representing 
 *  the nuclei (DAPI/Hoechst)
 *  -"UnfilteredFoci":  contains 8bit images of maximal projections of the channel 
 *  depicting the foci
 *  
 *  
 *  The user determines the seuquence of aqcuisition of the 
 *  color channels, alongside with some steps of image processing.
 */

/* If the vesrion of IJ is previous than 1.53d get input and output
 *  path without using dialog box*/
//output_path = getDirectory("Choose the output folder");
//input_path = File.openDialog("Select the .lif file");

//macro build by Ourania Preza
//version 1.1
/////////////////////////////////////////////////////////////////////////////////////

// Create complex dialog box to insert all inputs needed
Dialog.create("Insert the variables");
Dialog.addDirectory("Choose the output folder","");
Dialog.addFile("Select the .lif file", "");
Dialog.addMessage("Size of nuclei, in micron^2\n",15,"#772288");
Dialog.addNumber("Min", 100);
Dialog.addToSameRow();
Dialog.addNumber("Max", "Infinity");
Dialog.addMessage("Set the numbers corresponding to the channels (1-3)",15,"#772288");
Dialog.addNumber("DAPI", "");
Dialog.addToSameRow();
Dialog.addNumber("RFP", "");
Dialog.addToSameRow();
Dialog.addNumber("GFP", "");
items = newArray("RFP","GFP");
Dialog.addRadioButtonGroup("Select the foci channel to be analyzed", items, 1, 2, "GFP");
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
Dialog.addMessage("Foci pre-process\n",15,"#772288");
Dialog.addNumber("Sigma of blurring", 1.5, 1, 0, "");
Dialog.addNumber("Radius of subtracting background", 3);
Dialog.addToSameRow();
Dialog.addMessage("Set it a bit larger than your foci diameter");
Dialog.addNumber("Prominence", 200);
Dialog.addToSameRow();
Dialog.addMessage("The higher the prominence, the stringent the local maxima detetction");
Dialog.show();

output_path = Dialog.getString();
input_path = Dialog.getString();
minSize = Dialog.getNumber();
maxSize = Dialog.getNumber();
DAPI = Dialog.getNumber();
RFP = Dialog.getNumber();
GFP = Dialog.getNumber();
FocChan = Dialog.getRadioButton();
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
focisigma = Dialog.getNumber();
focirollball = Dialog.getNumber();
prominence = Dialog.getNumber();

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
nuclei_path = output_path + "Nuclei";
unfiltered_path = output_path + "UnfilteredFoci";
identified_path = output_path + "IdentifiedMaxima";
if (File.exists(nuclei_path)==0){
File.makeDirectory(nuclei_path);
}
if (File.exists(unfiltered_path)==0){
File.makeDirectory(unfiltered_path);
}
if (File.exists(identified_path)==0){
File.makeDirectory(identified_path);
}
if (File.exists(output_path+"/InitialMasks")==0){
File.makeDirectory(output_path+"/InitialMasks");
}
if (File.exists(identified_path+"/FociMasks")==0){
File.makeDirectory(identified_path+"/FociMasks");
}

// Only required if you want to retrieve the number of series in the LIF file
run("Bio-Formats Macro Extensions");
Ext.setId(input_path);
Ext.getSeriesCount(NbSeries);


// Create table to get results in excel
Table.create("FociPerNucleus");

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
		
		/*selectImage("C1-" + title);
		rename("GFP");
		selectImage("C2-" + title);
		rename("RFP");
		close("RFP");
		selectImage("C3-" + title);
		rename("DAPI");
		*/
		selectImage("C"+GFP+"-" + title);
		if(FocChan!="GFP"){
			close();
		}
		else {
			rename("GFP");
		}
		selectImage("C"+RFP+"-" + title);
		if(FocChan!="RFP"){
			close();
		}
		else {
			rename("RFP");
		}
		selectImage("C"+DAPI+"-" + title);
		rename("DAPI");

		
		//// Filter nuclei channel in 3D and segment in 2D////
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
		saveAs("Tiff", ""+output_path+"/InitialMasks/Mask_"+d2s(s+1,0)+".tif");
		
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
		
		////Find Maxima in each nucleus////
		selectImage(FocChan);
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Max Intensity]");
		run("8-bit");
		saveAs("Tiff", ""+unfiltered_path+"/MAX_"+FocChan+"_"+d2s(s+1,0)+".tif");
		close();
		close();
		selectImage(FocChan);
		// Pre-process foci channel with slightly bluriing with a kernel the size of the expected foci
		run("Gaussian Blur 3D...", "x="+focisigma+" y="+focisigma+" z=0.5");
		// Subtract background in foci channel with a rolling ball the size of the expected nuclei
		run("Subtract Background...", "rolling="+d2s(focirollball,0)+" stack");
		run("Z Project...", "projection=[Max Intensity]");
		//run("Invert");
		run("Find Maxima...", "prominence="+d2s(prominence,1)+" output=[Point Selection]");
		run("Create Mask");
		imageCalculator("AND create", "FinalNucMask","Mask");
		saveAs("Tiff", ""+identified_path+"/FociMasks/"+FocChan+"_Foci_"+d2s(s+1,0)+".tif");
		rename("Foci");
		close(FocChan);
		selectImage("Foci");
		// Foci Counter wo for loop //
		run("Divide...", "value=255");
		run("Set Measurements...", "integrated redirect=None decimal=0");
		// Count total #foci per image
		selectWindow("Foci");
		run("Select All");
		run("Measure");
		selectWindow("Results");
		TotFoci = Table.get("RawIntDen",0);
		print("TotFoci: "+TotFoci);
		run("Clear Results");
		// Count #foci per nucleus
		roiManager("Deselect");
		roiManager("multi-measure measure_all");
	
		///Visualize the outlines of the detected foci///run("Clear Results");
		// Depending on #foci per image protect code from crushing in case of 0 foci
		if(TotFoci!=0){
			selectImage("Foci");
			setThreshold(1, 255);
			run("Create Selection");
			run("Enlarge...", "enlarge=2 pixel");
			roiManager("Add");
			roiManager("Set Color", "magenta");
			roiManager("Deselect");
		}
		
		//Return the results to the FociPerNucleus table
		selectWindow("FociPerNucleus");
		irow = Table.size;
		for(i=0; i<nRois; i++){
			selectWindow("Results");
			FociCount = d2s(Table.get("RawIntDen",i),0);
			selectWindow("FociPerNucleus");
			//Table.set("Image",irow+i,1);
			Table.set("Image",irow+i,d2s(s+1,0));
			Table.set("Nucleus",d2s(irow+i,0),d2s(i+1,0));
			Table.set("FociCount",d2s(irow+i,0),FociCount);
	
			//Color code the outlines of nucleus depending on number of foci
			if (FociCount < 5){
				roiManager("Select", i);
				RoiManager.setPosition(0);
				roiManager("Set Color", "white");
				roiManager("Set Line Width", 0);
				}
			else (FociCount >= 10){
				roiManager("Select", i);
				RoiManager.setPosition(0);
				roiManager("Set Color", "red");
				roiManager("Set Line Width", 0);
				}
			}
		roiManager("Update");
		//roiManager("Save", "C:/Users/p_our/Desktop/Find_Maxima_macro_results/IdentifiedMaxima/Foci_GFP_1.zip");
		roiManager("Save", ""+identified_path+"/Foci_GFP_"+d2s(s+1,0)+".zip");
	
	}
}
setBatchMode("exit & display");
Table.update;
selectWindow("FociPerNucleus");
Table.save(output_path+"/FociPerNucleus.tsv");
close("FociPerNucleus");
close("Results");
roiManager("reset");
close("ROI Manager");
close("Summary");
close("Log");
run("Close All");