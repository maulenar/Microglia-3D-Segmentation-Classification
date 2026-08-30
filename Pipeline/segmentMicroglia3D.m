function [labelVolume, binaryMask, thresholdInfo] = ...
    segmentMicroglia3D(preprocessedStack, settings)
% Segment a preprocessed 3D stack using
% Otsu-based hysteresis thresholding.

%% Read settings
lowThresholdMultiplier = settings.lowThresholdMultiplier;
highThresholdMultiplier = settings.highThresholdMultiplier;
minimumObjectVolume_um3 = settings.minimumObjectVolume_um3;
xVoxelSize = settings.xVoxelSize;
yVoxelSize = settings.yVoxelSize;
zVoxelSize = settings.zVoxelSize;

%% Check input
if isempty(preprocessedStack)
    error('The preprocessed image stack is empty.');
end

if ndims(preprocessedStack) ~= 3
    error('The input must be a 3D image stack.');
end

%% Get positive voxels
positivePixels = preprocessedStack(preprocessedStack > 0);

if isempty(positivePixels)
    error('No positive pixels remain after preprocessing.');
end

%% Calculate Otsu threshold
otsuThreshold = graythresh(positivePixels);

%% Calculate hysteresis thresholds
lowThreshold = otsuThreshold * lowThresholdMultiplier;
highThreshold = otsuThreshold * highThresholdMultiplier;

lowThreshold = max(0, min(lowThreshold, 1));
highThreshold = max(0, min(highThreshold, 1));

if highThreshold < lowThreshold
    error('High threshold must be greater than or equal to low threshold.');
end

%% Create low and high masks
highMask = preprocessedStack >= highThreshold;
lowMask = preprocessedStack >= lowThreshold;


%% Apply hysteresis reconstruction
binaryMask = imreconstruct(highMask, lowMask, 26);

%% Remove small 3D objects
voxelVolume_um3 = xVoxelSize * yVoxelSize * zVoxelSize;

minimumObjectVoxels = round( ...
    minimumObjectVolume_um3 / voxelVolume_um3);

minimumObjectVoxels = max(1, minimumObjectVoxels);

binaryMask = bwareaopen( ...
    binaryMask, ...
    minimumObjectVoxels, ...
    26);

%% Label connected 3D objects
connectedObjects = bwconncomp(binaryMask, 26);
labelVolume = labelmatrix(connectedObjects);

%% Save threshold information
thresholdInfo.otsuThreshold = otsuThreshold;
thresholdInfo.lowThreshold = lowThreshold;
thresholdInfo.highThreshold = highThreshold;
thresholdInfo.lowThresholdMultiplier = lowThresholdMultiplier;
thresholdInfo.highThresholdMultiplier = highThresholdMultiplier;
thresholdInfo.minimumObjectVolume_um3 = minimumObjectVolume_um3;
thresholdInfo.minimumObjectVoxels = minimumObjectVoxels;
thresholdInfo.voxelVolume_um3 = voxelVolume_um3;
thresholdInfo.numberOfObjects = connectedObjects.NumObjects;


%% Display summary
fprintf('\nSegmentation thresholds:\n');
fprintf('Otsu threshold: %.4f\n', otsuThreshold);
fprintf('Low threshold: %.4f\n', lowThreshold);
fprintf('High threshold: %.4f\n', highThreshold);

fprintf('\nMinimum object filtering:\n');
fprintf('Voxel volume: %.4f um^3\n', voxelVolume_um3);
fprintf('Minimum object volume: %.2f um^3\n', minimumObjectVolume_um3);
fprintf('Minimum object size: %d voxels\n', minimumObjectVoxels);
fprintf('\nDetected 3D objects: %d\n', connectedObjects.NumObjects);

end
