# Image-analysis-pipelines

This repository contains the image analysis pipelines used in the paper:

> **"FANCD2 restrains fork progression and prevents fragility at early origins upon re-replication"**

The pipelines are implemented as **Fiji (ImageJ) and CellProfiler macros** and are provided below.

---

## Contents

### a. Nuclear Intensity Measurement
* **File:** `Nuclear_intensities_v1.2.ijm`
* **Description:** Fiji macro for measuring nuclear intensities.

### b. Foci Quantification per Nucleus
* **File:** `Find_Maxima_3D_filtering_2D_mask.ijm`
* **Description:** Fiji macro for measuring the number of foci per nucleus.

### c. Colocalizing Foci Analysis
* **File:** `colocalization_pipeline.cppipe`
* **Description:** CellProfiler pipeline for measuring colocalizing foci.

---

## Requirements

* Fiji / ImageJ (for `.ijm` macros)
* CellProfiler (for `.cppipe` pipeline)

## Usage

Each macro can be opened and executed directly in Fiji. Please refer to the comments within each macro for parameter explanations and usage instructions.
