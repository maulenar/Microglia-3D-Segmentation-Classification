function [separatedLabelVolume, separationTable] = ...
    separateMicroglia3D(labelVolume, somaMask)
% Separate merged microglia using soma-guided 3D geodesic region growing
%
% Objects with 0 or 1 soma are kept unchanged
% Objects with 2 or more somas are divided so that each soma becomes one output cell

% The growing is restricted to the original segmented object
% Therefore regions can only spread through foreground voxels
%
% Inputs:
% labelVolume - original labeled 3D segmentation
% somaMask - logical 3D mask of detected soma candidates
%
% Outputs:
% separatedLabelVolume - labeled 3D volume after separation
% separationTable - summary for each original object

%% Check inputs

if isempty(labelVolume)
    error('The label volume is empty.');
end

if isempty(somaMask)
    error('The soma mask is empty.');
end

if ~isequal(size(labelVolume), size(somaMask))
    error('labelVolume and somaMask must have the same size.');
end


%% Find original objects

objectLabels = unique(labelVolume);
objectLabels(objectLabels == 0) = [];

numberOfObjects = numel(objectLabels);

%% Prepare output

separatedLabelVolume = zeros( ...
    size(labelVolume), ...
    'uint32');

nextLabel = 1;

%% Prepare summary table

objectID = zeros(numberOfObjects,1);
numberOfSomas = zeros(numberOfObjects,1);
numberOfOutputObjects = zeros(numberOfObjects,1);
status = strings(numberOfObjects,1);


%% Define 3D neighbourhood

neighbourhood = true(3,3,3);

%% Process each original object

for objectIndex = 1:numberOfObjects

    currentLabel = objectLabels(objectIndex);

    objectMask = ...
        labelVolume == currentLabel;

    currentSomaMask = ...
        somaMask & objectMask;


    %% Find soma components

    somaComponents = bwconncomp( ...
        currentSomaMask, ...
        26);

    currentNumberOfSomas = ...
        somaComponents.NumObjects;


    objectID(objectIndex) = currentLabel;
    numberOfSomas(objectIndex) = currentNumberOfSomas;

    %% Keep objects with zero or one soma unchanged

    if currentNumberOfSomas <= 1

        separatedLabelVolume(objectMask) = nextLabel;

        numberOfOutputObjects(objectIndex) = 1;

        if currentNumberOfSomas == 0
            status(objectIndex) = ...
                "Kept unchanged - no soma";
        else
            status(objectIndex) = ...
                "Kept unchanged - single soma";
        end

        nextLabel = nextLabel + 1;

        continue;
    end


    %% Crop the current object
    %
    % Processing only the object's bounding box keeps the separation
    % faster than working on the complete image stack

    [rowIndex, columnIndex, sliceIndex] = ...
        ind2sub( ...
        size(objectMask), ...
        find(objectMask));

    rowRange = ...
        min(rowIndex):max(rowIndex);

    columnRange = ...
        min(columnIndex):max(columnIndex);

    sliceRange = ...
        min(sliceIndex):max(sliceIndex);

    croppedObject = ...
        objectMask( ...
        rowRange, ...
        columnRange, ...
        sliceRange);

    croppedSomaMask = ...
        currentSomaMask( ...
        rowRange, ...
        columnRange, ...
        sliceRange);

    %% Label soma markers

    croppedSomaComponents = bwconncomp( ...
        croppedSomaMask, ...
        26);

    regionLabels = zeros( ...
        size(croppedObject), ...
        'uint16');

    for somaIndex = 1:currentNumberOfSomas

        regionLabels( ...
            croppedSomaComponents.PixelIdxList{somaIndex}) = ...
            somaIndex;

    end

    %% Grow soma regions through the 3D object
    %
    % Each soma grows only through foreground voxels
    % If two regions reach the same voxel at the same iteration,
    % the lower-numbered soma keeps that voxel
    %
    % This produces one region for each detected soma

    unassignedMask = ...
        croppedObject & ...
        regionLabels == 0;

    previousUnassignedCount = inf;


    while any(unassignedMask(:))

        currentUnassignedCount = ...
            nnz(unassignedMask);

        if currentUnassignedCount == previousUnassignedCount
            break;
        end

        previousUnassignedCount = ...
            currentUnassignedCount;


        for somaIndex = 1:currentNumberOfSomas

            currentRegion = ...
                regionLabels == somaIndex;

            grownRegion = imdilate( ...
                currentRegion, ...
                neighbourhood);

            newVoxels = ...
                grownRegion & ...
                unassignedMask & ...
                croppedObject;

            regionLabels(newVoxels) = ...
                somaIndex;

            unassignedMask(newVoxels) = ...
                false;

        end

    end


    %% Assign any remaining foreground
    %
    % Normally every connected foreground voxel should be reached
    % If any voxels remain, keep them with the first soma region

    remainingVoxels = ...
        croppedObject & ...
        regionLabels == 0;

    if any(remainingVoxels(:))

        regionLabels(remainingVoxels) = 1;

    end

    %% Copy separated regions to the output

    outputCount = 0;

    for somaIndex = 1:currentNumberOfSomas

        currentRegion = ...
            regionLabels == somaIndex;

        if ~any(currentRegion(:))
            continue;
        end

        temporaryMask = false( ...
            size(labelVolume));

        temporaryMask( ...
            rowRange, ...
            columnRange, ...
            sliceRange) = ...
            currentRegion;

        separatedLabelVolume(temporaryMask) = ...
            nextLabel;

        nextLabel = nextLabel + 1;
        outputCount = outputCount + 1;

    end


    numberOfOutputObjects(objectIndex) = ...
        outputCount;

    status(objectIndex) = ...
        "Separated by soma-guided 3D growing";

end


%% Create summary table

separationTable = table( ...
    objectID, ...
    numberOfSomas, ...
    numberOfOutputObjects, ...
    status);

%% Display summary

fprintf('\nSoma-guided 3D separation results:\n');

disp(separationTable);

finalLabels = unique( ...
    separatedLabelVolume);

finalLabels(finalLabels == 0) = [];

fprintf( ...
    'Original object count: %d\n', ...
    numberOfObjects);

fprintf( ...
    'Object count after separation: %d\n', ...
    numel(finalLabels));


end
