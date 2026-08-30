function [somaMask, somaTable] = detectMicrogliaSomas3D(labelVolume, xVoxelSize, yVoxelSize, zVoxelSize, settings)
% Detect soma candidates inside segmented cells
%
% Inputs:
% labelVolume - labeled 3D segmentation
% xVoxelSize, yVoxelSize, zVoxelSize - voxel sizes in micrometers
% settings.somaCoreRadius_um
% settings.minimumSomaVolume_um3
%
% Outputs:
% somaMask - logical 3D mask of all soma candidates
% somaTable - number of soma candidates found in each object

%% Read settings
somaCoreRadius_um = settings.somaCoreRadius_um;
minimumSomaVolume_um3 = settings.minimumSomaVolume_um3;

%% Check input
if isempty(labelVolume)
    error('The label volume is empty.');
end

if ndims(labelVolume) ~= 3
    error('The label volume must be 3D.');
end

%% Calculate minimum soma size
voxelVolume_um3 = xVoxelSize * yVoxelSize * zVoxelSize;

minimumSomaVoxels = round( ...
    minimumSomaVolume_um3 / voxelVolume_um3);

minimumSomaVoxels = max(1, minimumSomaVoxels);

%% Find object labels
objectLabels = unique(labelVolume);
objectLabels(objectLabels == 0) = [];

numberOfObjects = numel(objectLabels);

%% Prepare outputs
somaMask = false(size(labelVolume));

objectID = zeros(numberOfObjects,1);
numberOfSomas = zeros(numberOfObjects,1);
status = strings(numberOfObjects,1);

%% Process each segmented object
for objectIndex = 1:numberOfObjects

    currentLabel = objectLabels(objectIndex);
    objectMask = labelVolume == currentLabel;

    currentSomaMask = false(size(objectMask));

    % Detect thick regions slice by slice
    % Thin branches have small distance-to-edge values
    % Soma regions have larger distance-to-edge values
    for z = 1:size(objectMask,3)

        currentSlice = objectMask(:,:,z);

        if ~any(currentSlice,'all')
            continue;
        end

        distanceMap = bwdist(~currentSlice);

        distanceMap_um = ...
            distanceMap * mean([xVoxelSize yVoxelSize]);

        currentSomaMask(:,:,z) = ...
            distanceMap_um >= somaCoreRadius_um;
    end

    % Remove small soma regions
    currentSomaMask = bwareaopen( ...
        currentSomaMask, ...
        minimumSomaVoxels, ...
        26);

    somaComponents = bwconncomp( ...
        currentSomaMask, ...
        26);

    currentNumberOfSomas = somaComponents.NumObjects;

    somaMask = somaMask | currentSomaMask;

    objectID(objectIndex) = currentLabel;
    numberOfSomas(objectIndex) = currentNumberOfSomas;

    if currentNumberOfSomas == 0
        status(objectIndex) = "No soma detected";
    elseif currentNumberOfSomas == 1
        status(objectIndex) = "Single soma";
    else
        status(objectIndex) = "Possible merged cells";
    end
end



%% Create results table
somaTable = table(objectID, numberOfSomas, status);

%% Display summary
fprintf('\nSoma detection results:\n');
disp(somaTable);

fprintf('Soma core radius: %.2f um\n', somaCoreRadius_um);
fprintf('Minimum soma volume: %.2f um^3\n', minimumSomaVolume_um3);
fprintf('Minimum soma size: %d voxels\n', minimumSomaVoxels);

end
