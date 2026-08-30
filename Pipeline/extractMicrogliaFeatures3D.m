function featureTable = extractMicrogliaFeatures3D( ...
    labelVolume, somaMask, xVoxelSize, yVoxelSize, zVoxelSize)
% Extract simple 3D morphology measurements
%
% One row is created for each labeled 3D object
%
% Inputs:
% labelVolume - labeled 3D segmentation volume
% somaMask - logical 3D soma mask
% xVoxelSize  - X voxel size in micrometers
% yVoxelSize  - Y voxel size in micrometers
% zVoxelSize  - Z voxel size in micrometers
%
% Output:
% featureTable - table containing one row per 3D object
%
% The measurements are calculated in physical units wherever possible
% Objects containing more than one soma are flagged as possible merged cells


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

if xVoxelSize <= 0 || yVoxelSize <= 0 || zVoxelSize <= 0
    error('Voxel sizes must be greater than zero.');
end

%% Find object labels

objectLabels = unique(labelVolume);
objectLabels(objectLabels == 0) = [];

numberOfObjects = numel(objectLabels);

%% Calculate physical voxel volume

voxelVolume_um3 = ...
    xVoxelSize * ...
    yVoxelSize * ...
    zVoxelSize;

%% Preallocate feature arrays

ObjectID = zeros(numberOfObjects,1);

Volume_um3 = zeros(numberOfObjects,1);
SurfaceArea_um2 = nan(numberOfObjects,1);
EquivalentDiameter_um = zeros(numberOfObjects,1);
Sphericity = nan(numberOfObjects,1);

MajorAxisLength_um = nan(numberOfObjects,1);
IntermediateAxisLength_um = nan(numberOfObjects,1);
MinorAxisLength_um = nan(numberOfObjects,1);

Elongation = nan(numberOfObjects,1);
Flatness = nan(numberOfObjects,1);

BoundingBoxX_um = zeros(numberOfObjects,1);
BoundingBoxY_um = zeros(numberOfObjects,1);
BoundingBoxZ_um = zeros(numberOfObjects,1);

CentroidX_um = zeros(numberOfObjects,1);
CentroidY_um = zeros(numberOfObjects,1);
CentroidZ_um = zeros(numberOfObjects,1);

SomaVolume_um3 = zeros(numberOfObjects,1);
SomaCellVolumeRatio = zeros(numberOfObjects,1);
NumberOfSomas = zeros(numberOfObjects,1);
PossibleMerged = false(numberOfObjects,1);


%% Process each object

for objectIndex = 1:numberOfObjects

    currentLabel = objectLabels(objectIndex);

    currentObjectMask = ...
        labelVolume == currentLabel;

    currentIndices = ...
        find(currentObjectMask);

    [rows, columns, slices] = ...
        ind2sub( ...
        size(labelVolume), ...
        currentIndices);

    %% Object ID

    ObjectID(objectIndex) = ...
        currentLabel;

    %% Volume

    numberOfVoxels = ...
        numel(currentIndices);

    currentVolume_um3 = ...
        numberOfVoxels * ...
        voxelVolume_um3;

    Volume_um3(objectIndex) = ...
        currentVolume_um3;

    %% Equivalent sphere diameter
    %
    % Diameter of a sphere with the same volume

    EquivalentDiameter_um(objectIndex) = ...
        2 * ...
        ((3 * currentVolume_um3) / ...
        (4 * pi))^(1/3);

    %% Bounding box size

    BoundingBoxX_um(objectIndex) = ...
        (max(columns) - min(columns) + 1) * ...
        xVoxelSize;

    BoundingBoxY_um(objectIndex) = ...
        (max(rows) - min(rows) + 1) * ...
        yVoxelSize;

    BoundingBoxZ_um(objectIndex) = ...
        (max(slices) - min(slices) + 1) * ...
        zVoxelSize;

    %% Centroid
    %
    % MATLAB array dimensions are: row = Y, column = X, slice = Z

    xCoordinates = ...
        double(columns) * xVoxelSize;

    yCoordinates = ...
        double(rows) * yVoxelSize;

    zCoordinates = ...
        double(slices) * zVoxelSize;

    CentroidX_um(objectIndex) = ...
        mean(xCoordinates);

    CentroidY_um(objectIndex) = ...
        mean(yCoordinates);

    CentroidZ_um(objectIndex) = ...
        mean(zCoordinates);

    %% Principal axis lengths
    %
    % The object voxels are converted to physical XYZ coordinates
    % Principal component analysis is then used to find the main
    % directions of the object
    %
    % Length is measured as the full range of the object after
    % projection onto each principal direction

    physicalCoordinates = ...
        [xCoordinates ...
         yCoordinates ...
         zCoordinates];

    if size(physicalCoordinates,1) >= 3

        centredCoordinates = ...
            physicalCoordinates - ...
            mean(physicalCoordinates,1);

        covarianceMatrix = ...
            cov(centredCoordinates);

        [eigenVectors, eigenValuesMatrix] = ...
            eig(covarianceMatrix);

        eigenValues = ...
            diag(eigenValuesMatrix);

        [~, sortOrder] = ...
            sort(eigenValues, 'descend');

        eigenVectors = ...
            eigenVectors(:,sortOrder);

        projectedCoordinates = ...
            centredCoordinates * ...
            eigenVectors;

        axisLengths = ...
            max(projectedCoordinates,[],1) - ...
            min(projectedCoordinates,[],1);

        % Sort the measured physical lengths themselves
        % PCA eigenvectors are ordered by variance, but the full
        % projection ranges are not guaranteed to remain in that order
        axisLengths = ...
            sort(axisLengths, 'descend');

        MajorAxisLength_um(objectIndex) = ...
            axisLengths(1);

        IntermediateAxisLength_um(objectIndex) = ...
            axisLengths(2);

        MinorAxisLength_um(objectIndex) = ...
            axisLengths(3);


        %% Elongation and flatness

        if axisLengths(2) > 0

            Elongation(objectIndex) = ...
                axisLengths(1) / ...
                axisLengths(2);

        end

        if axisLengths(3) > 0

            Flatness(objectIndex) = ...
                axisLengths(2) / ...
                axisLengths(3);

        end

    end


    %% Surface area
    %
    % A tight crop is used so that isosurface does not process the
    % complete image stack

    rowMin = max(1, min(rows) - 1);
    rowMax = min(size(labelVolume,1), max(rows) + 1);

    columnMin = max(1, min(columns) - 1);
    columnMax = min(size(labelVolume,2), max(columns) + 1);

    sliceMin = max(1, min(slices) - 1);
    sliceMax = min(size(labelVolume,3), max(slices) + 1);

    croppedMask = ...
        currentObjectMask( ...
        rowMin:rowMax, ...
        columnMin:columnMax, ...
        sliceMin:sliceMax);

    surfaceData = ...
        isosurface( ...
        croppedMask, ...
        0.5);

    if ~isempty(surfaceData.faces)

        vertices = ...
            surfaceData.vertices;

        % isosurface returns:
        % column direction as X,
        % row direction as Y,
        % slice direction as Z

        vertices(:,1) = ...
            vertices(:,1) * xVoxelSize;

        vertices(:,2) = ...
            vertices(:,2) * yVoxelSize;

        vertices(:,3) = ...
            vertices(:,3) * zVoxelSize;

        faces = ...
            surfaceData.faces;

        point1 = ...
            vertices(faces(:,1),:);

        point2 = ...
            vertices(faces(:,2),:);

        point3 = ...
            vertices(faces(:,3),:);

        triangleVector1 = ...
            point2 - point1;

        triangleVector2 = ...
            point3 - point1;

        triangleCrossProduct = ...
            cross( ...
            triangleVector1, ...
            triangleVector2, ...
            2);

        triangleAreas = ...
            0.5 * ...
            sqrt( ...
            sum( ...
            triangleCrossProduct.^2, ...
            2));

        currentSurfaceArea_um2 = ...
            sum(triangleAreas);

        SurfaceArea_um2(objectIndex) = ...
            currentSurfaceArea_um2;


        %% Sphericity
        %
        % Sphericity = 1 for a perfect sphere
        % Lower values represent less spherical shapes

        if currentSurfaceArea_um2 > 0

            Sphericity(objectIndex) = ...
                (pi^(1/3) * ...
                (6 * currentVolume_um3)^(2/3)) / ...
                currentSurfaceArea_um2;

        end

    end


    %% Soma features

    currentSomaMask = ...
        somaMask & ...
        currentObjectMask;

    somaComponents = ...
        bwconncomp( ...
        currentSomaMask, ...
        26);

    NumberOfSomas(objectIndex) = ...
        somaComponents.NumObjects;

    currentSomaVolume_um3 = ...
        nnz(currentSomaMask) * ...
        voxelVolume_um3;

    SomaVolume_um3(objectIndex) = ...
        currentSomaVolume_um3;

    if currentVolume_um3 > 0

        SomaCellVolumeRatio(objectIndex) = ...
            currentSomaVolume_um3 / ...
            currentVolume_um3;

    end

    %% Possible merged-cell flag

    PossibleMerged(objectIndex) = ...
        NumberOfSomas(objectIndex) > 1;

end


%% Create output table

featureTable = table( ...
    ObjectID, ...
    Volume_um3, ...
    SurfaceArea_um2, ...
    EquivalentDiameter_um, ...
    Sphericity, ...
    MajorAxisLength_um, ...
    IntermediateAxisLength_um, ...
    MinorAxisLength_um, ...
    Elongation, ...
    Flatness, ...
    BoundingBoxX_um, ...
    BoundingBoxY_um, ...
    BoundingBoxZ_um, ...
    CentroidX_um, ...
    CentroidY_um, ...
    CentroidZ_um, ...
    SomaVolume_um3, ...
    SomaCellVolumeRatio, ...
    NumberOfSomas, ...
    PossibleMerged);


%% Display summary

fprintf('\n3D microglia feature extraction complete.\n');
fprintf('Objects measured: %d\n', numberOfObjects);
fprintf('Possible merged objects: %d\n', nnz(PossibleMerged));

disp(featureTable);

end
