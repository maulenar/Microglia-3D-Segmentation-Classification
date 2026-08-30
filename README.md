# 3D Microglia Segmentation and Classification

MATLAB pipeline for 3D segmentation, morphological feature extraction, and machine-learning classification of microglia from microscopy image stacks.

This project was developed as part of an MSc research project at University College London (UCL).

## Overview

The pipeline analyses 3D microscopy image stacks and identifies individual microglia for subsequent morphological analysis and classification.

The main workflow is:

**Image loading → preprocessing → 3D segmentation → XY-border removal → soma detection → merged-cell separation → feature extraction → morphology classification**

The final classifier assigns each analysed microglial cell to one of three morphological classes:

- Amoeboid
- Activated
- Ramified

## Image Loading

`loadMicroglia3D.m` loads 3D microscopy data in:

- TIFF / TIF format
- LSM format

For TIFF stacks, the image slices are read directly in MATLAB.

Where available, X and Y voxel dimensions are obtained from TIFF resolution metadata and Z spacing is read from ImageJ metadata.

LSM images are loaded using Bio-Formats for MATLAB. The first channel and first time point are used.

The loader returns:

- 3D image stack
- X voxel size
- Y voxel size
- Z voxel size

If calibration information is unavailable from the image metadata, it remains undefined and must be supplied before physical measurements are calculated.

## Preprocessing

`preprocessMicroglia3D.m` prepares the 3D image before segmentation.

The preprocessing stages are:

1. Conversion to single precision.
2. Intensity normalisation using the 0.1th and 99.9th percentiles.
3. 3D Gaussian smoothing.
4. Slice-by-slice background estimation using morphological opening.
5. Background subtraction.
6. Rescaling of the corrected image.

The current development settings are:

- Gaussian sigma XY: `1.0`
- Gaussian sigma Z: `0.7`
- Background radius: `18 pixels`

## 3D Segmentation

`segmentMicroglia3D.m` performs Otsu-based hysteresis segmentation directly on the 3D image volume.

An Otsu threshold is calculated from positive voxels in the preprocessed image.

Two thresholds are then calculated:

- Low threshold = Otsu threshold × low-threshold multiplier
- High threshold = Otsu threshold × high-threshold multiplier

The high-threshold regions are reconstructed through the low-threshold mask using 26-connected 3D morphological reconstruction.

Small objects are then removed using a minimum physical object volume.

The voxel volume is calculated as:

`X voxel size × Y voxel size × Z voxel size`

This allows the minimum object volume in µm³ to be converted into the corresponding number of voxels.

The current development settings are:

- Low threshold multiplier: `0.7`
- High threshold multiplier: `1.15`
- Minimum object volume: `200 µm³`

## XY-Border Removal

`removeXYBorderObjects3D.m` removes segmented objects that touch the lateral X or Y image boundaries.

Objects touching the first or last Z slice are retained.

This is used to remove partially visible cells at the lateral image boundaries before morphological analysis.

## Soma Detection

`detectMicrogliaSomas3D.m` identifies soma candidates inside each segmented object.

Soma detection is based on the distance from each foreground pixel to the edge of the segmented object.

For each XY slice:

1. A distance transform is calculated.
2. The distance is converted into physical units using the X and Y voxel dimensions.
3. Regions that are sufficiently far from the object boundary are treated as soma-core candidates.
4. Small soma candidates are removed using a minimum soma volume.

The current development settings are:

- Soma core radius: `1.5 µm`
- Minimum soma volume: `100 µm³`

Each segmented object can therefore contain:

- No detected soma
- One detected soma
- Multiple detected somas

Objects containing multiple soma candidates are treated as possible merged microglia.

## Separation of Merged Cells

`separateMicroglia3D.m` attempts to separate segmented objects containing more than one detected soma.

The method uses soma-guided 3D geodesic region growing.

Objects containing zero or one soma are retained unchanged.

For objects containing two or more soma candidates, each soma acts as a marker and the regions grow through the original segmented foreground using a 26-connected neighbourhood.

The growth is restricted to the original object mask, so separated regions cannot extend outside the original segmentation.

Each resulting region is assigned a new object label and treated as an individual cell.

## Morphological Feature Extraction

`extractMicrogliaFeatures3D.m` calculates 3D morphological measurements for each final segmented object.

One row of the feature table corresponds to one microglial object.

The extracted measurements include:

- Object ID
- Volume
- Surface area
- Equivalent diameter
- Sphericity
- Major axis length
- Intermediate axis length
- Minor axis length
- Elongation
- Flatness
- X bounding-box dimension
- Y bounding-box dimension
- Z bounding-box dimension
- X centroid coordinate
- Y centroid coordinate
- Z centroid coordinate
- Soma volume
- Soma-to-cell volume ratio
- Number of detected somas
- Possible merged-cell flag

Physical measurements are calculated using the supplied X, Y and Z voxel calibration.

## Training Data Labelling

`labelMicrogliaTrainingData.m` was developed to manually assign morphology labels to segmented cells for machine-learning training.

Available labels are:

1. Amoeboid
2. Activated
3. Ramified
4. Exclude

The labelling tool provides multiple views of each segmented cell, including:

- XY view
- XZ view
- YZ view
- 3D view

The function also records whether an object was produced by the merged-cell separation stage.

Labels are saved after each annotation, and existing labelling sessions can be resumed.

The labelled objects from multiple image stacks are stored in a common dataset.

## Dataset Splitting

`assignMicrogliaDatasetSplit.m` assigns labelled objects to:

- Training
- Validation
- Test

The split is performed according to the source image rather than randomly assigning individual cells.

This ensures that cells originating from the same microscopy stack remain within the same dataset subset.

The independent Test set is kept separate during model development.

`prepareMicrogliaMLDataset.m` then removes objects labelled as `Exclude` and prepares the predictor matrices and class labels.

## Machine-Learning Features

Nine morphological measurements are used as predictor variables:

1. Volume
2. Surface area
3. Equivalent diameter
4. Sphericity
5. Major axis length
6. Intermediate axis length
7. Minor axis length
8. Elongation
9. Flatness

The three target classes are:

- Amoeboid
- Activated
- Ramified

## Classifier Training

`trainMicrogliaClassifier.m` trains the final morphology classifier.

The classifier is a Bagged Trees ensemble with:

- Number of trees: `100`
- Minimum leaf size: `1`
- Predictor variables: `9`

A fixed random seed is used to make training reproducible.

The classifier is trained using the Training dataset and evaluated using the Validation dataset.

The Test dataset is not used during classifier training or model selection.

The trained classifier is saved as:

`Microglia_Classifier.mat`

## Final Classifier Testing

`testMicrogliaClassifier.m` performs the final evaluation of the frozen classifier using the previously unused Test dataset.

The final Test dataset contained 39 labelled cells.

The final results were:

- Overall accuracy: `84.6%`
- Balanced accuracy: `82.5%`
- Macro F1 score: `0.8247`
- Correct classifications: `33 / 39`
- Incorrect classifications: `6 / 39`

Per-class F1 scores were:

- Amoeboid: `0.800`
- Activated: `0.769`
- Ramified: `0.905`

The following result files are included:

- `Microglia_Final_Test_Summary.csv`
- `Microglia_Final_Test_PerClass.csv`
- `Microglia_Final_Test_Predictions.csv`

## Classification of New Image Stacks

`classifyMicroglia3D.m` applies the previously trained classifier to a feature table generated from a new segmented image stack.

The function:

1. Loads `Microglia_Classifier.mat`.
2. Checks that all required predictor features are available.
3. Applies the trained classifier.
4. Adds a `PredictedMorphology` column to the feature table.

The classifier is not retrained when analysing a new image stack.

Predicted classes are:

- Amoeboid
- Activated
- Ramified

## Pipeline Test Scripts

Two development scripts are included.

`testMicroglia3DPipeline.m` demonstrates the segmentation and feature-extraction workflow:

**load → preprocess → segment → XY-border removal → soma detection → separation → feature extraction**

`testMicroglia3DPipeline_classification.m` extends this workflow by applying the trained morphology classifier:

**load → preprocess → segment → XY-border removal → soma detection → separation → feature extraction → classification**

These scripts can be used to inspect intermediate processing stages and visualise the segmented microglia.

## Main Files

- `loadMicroglia3D.m`  
  Loads TIFF and LSM image stacks and reads available voxel calibration.

- `preprocessMicroglia3D.m`  
  Performs normalisation, 3D Gaussian smoothing and background subtraction.

- `segmentMicroglia3D.m`  
  Performs Otsu-based 3D hysteresis segmentation and minimum-volume filtering.

- `removeXYBorderObjects3D.m`  
  Removes objects touching X or Y image boundaries.

- `detectMicrogliaSomas3D.m`  
  Detects soma-core candidates within segmented objects.

- `separateMicroglia3D.m`  
  Separates possible merged cells using soma-guided 3D geodesic region growing.

- `extractMicrogliaFeatures3D.m`  
  Extracts 3D morphological measurements.

- `labelMicrogliaTrainingData.m`  
  Provides manual morphology labelling for classifier development.

- `assignMicrogliaDatasetSplit.m`  
  Assigns source images to Training, Validation and Test subsets.

- `prepareMicrogliaMLDataset.m`  
  Prepares the nine predictor features and class labels.

- `trainMicrogliaClassifier.m`  
  Trains and validates the Bagged Trees classifier.

- `testMicrogliaClassifier.m`  
  Performs the final independent Test-set evaluation.

- `classifyMicroglia3D.m`  
  Applies the trained model to newly extracted feature tables.

- `Microglia_Classifier.mat`  
  Saved trained Bagged Trees classifier.

## Example Image

The repository currently includes one example 3D microscopy stack:

`TrialControlZip.tif`

This image originates from the example control dataset supplied with the 3DMorph software and is included for demonstration and testing of the pipeline.

If this image is used, please cite the original 3DMorph publication:

York, E. M., LeDue, J. M., Bernier, L.-P., & MacVicar, B. A. (2018).  
**3DMorph Automatic Analysis of Microglial Morphology in Three Dimensions from Ex Vivo and In Vivo Imaging.**  
*eNeuro, 5*(6), ENEURO.0266-18.2018.

DOI: 10.1523/ENEURO.0266-18.2018

3DMorph repository:

https://github.com/ElisaYork/3DMorph

## Requirements

- MATLAB
- Image Processing Toolbox
- Statistics and Machine Learning Toolbox
- Bio-Formats for MATLAB for LSM image loading

## Running the Example Pipeline

To run the development pipeline:

1. Place a supported 3D microscopy stack in the MATLAB working folder.
2. Open `testMicroglia3DPipeline_classification.m`.
3. Change the `filename` variable to the required image stack.
4. Check the X, Y and Z voxel calibration.
5. Adjust segmentation settings if required.
6. Run the script.

The script will perform segmentation, merged-cell separation, feature extraction and morphology classification, while displaying intermediate and final visualisations.

## Notes

Segmentation results depend on image quality, voxel calibration and the selected segmentation parameters.

Changing the segmentation parameters can alter the geometry of the extracted objects and therefore the morphological measurements supplied to the classifier.

The provided classifier was trained using objects generated by this segmentation pipeline.

## Author

Aruzhan Maulen

MSc Project  
University College London (UCL)