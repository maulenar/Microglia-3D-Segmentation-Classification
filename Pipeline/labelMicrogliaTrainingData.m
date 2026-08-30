function labelledTable = labelMicrogliaTrainingData( ...
    imageStack, analysisLabelVolume, featureTable, filename, ...
    xVoxelSize, yVoxelSize, zVoxelSize, separationTable)
% Manually label segmented 3D microglia for machine-learning training

% Labels:
%   1 = Amoeboid
%   2 = Activated
%   3 = Ramified
%   4 = Exclude

% The function:
% - shows useful XY, XZ, YZ and 3D views
% - warns when an object was created by merged-cell separation
% - saves after every label
% - resumes existing labels
% - allows previous/next navigation and jumping to any object
% - stores all stacks in one master labeled dataset

%% Check inputs

if nargin < 8
    separationTable = table;
end

if isempty(imageStack) || isempty(analysisLabelVolume)
    error('Image stack and label volume must not be empty.');
end

if ~isequal(size(imageStack), size(analysisLabelVolume))
    error('imageStack and analysisLabelVolume must have the same size.');
end

if height(featureTable) == 0
    error('featureTable is empty.');
end



%% Prepare results folder

resultsFolder = 'Results_3D_Microglia';

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

masterFile = fullfile( ...
    resultsFolder, ...
    'Microglia_Labelled_Dataset.csv');

%% Source information

sourceFile = string(filename);
numberOfObjects = height(featureTable);

objectLabels = unique(analysisLabelVolume);
objectLabels(objectLabels == 0) = [];

if numel(objectLabels) ~= numberOfObjects
    error(['The number of labelled objects does not match the ' ...
        'number of rows in featureTable.']);
end

%% Build separation provenance

parentObjectID = featureTable.ObjectID;
wasSeparated = false(numberOfObjects,1);
separationPart = ones(numberOfObjects,1);
separationPartsTotal = ones(numberOfObjects,1);

if ~isempty(separationTable)

    finalObjectIndex = 1;

    for rowIndex = 1:height(separationTable)

        numberOfParts = ...
            separationTable.numberOfOutputObjects(rowIndex);

        if numberOfParts < 1
            continue;
        end

        finalIndices = ...
            finalObjectIndex:(finalObjectIndex + numberOfParts - 1);

        if finalIndices(end) > numberOfObjects
            warning(['Separation provenance could not be mapped ' ...
                'completely. Default provenance will be used.']);
            break;
        end

        parentObjectID(finalIndices) = ...
            separationTable.objectID(rowIndex);

        separationPartsTotal(finalIndices) = ...
            numberOfParts;

        separationPart(finalIndices) = ...
            (1:numberOfParts)';

        if numberOfParts > 1
            wasSeparated(finalIndices) = true;
        end

        finalObjectIndex = ...
            finalObjectIndex + numberOfParts;
    end
end

%% Prepare current stack table

morphologyLabel = strings(numberOfObjects,1);
datasetSplit = repmat("Unassigned", numberOfObjects,1);
sourceColumn = repmat(sourceFile, numberOfObjects,1);

labelledTable = featureTable;

labelledTable = addvars( ...
    labelledTable, ...
    sourceColumn, ...
    parentObjectID, ...
    wasSeparated, ...
    separationPart, ...
    separationPartsTotal, ...
    morphologyLabel, ...
    datasetSplit, ...
    'Before', 1, ...
    'NewVariableNames', { ...
    'SourceFile', ...
    'ParentObjectID', ...
    'WasSeparated', ...
    'SeparationPart', ...
    'SeparationPartsTotal', ...
    'MorphologyLabel', ...
    'DatasetSplit'});


%% Load existing labels if available

if isfile(masterFile)

    masterTable = readtable( ...
        masterFile, ...
        'TextType','string');

    requiredColumns = { ...
        'SourceFile', ...
        'ObjectID', ...
        'MorphologyLabel'};

    if all(ismember(requiredColumns, ...
            masterTable.Properties.VariableNames))

        for objectIndex = 1:numberOfObjects

            matchingRow = ...
                masterTable.SourceFile == sourceFile & ...
                masterTable.ObjectID == ...
                labelledTable.ObjectID(objectIndex);

            if any(matchingRow)
                labelledTable.MorphologyLabel(objectIndex) = ...
                    masterTable.MorphologyLabel( ...
                    find(matchingRow,1));
            end
        end
    end
end

%% Start at first unlabelled object

unlabelled = ...
    labelledTable.MorphologyLabel == "";

if any(unlabelled)
    currentIndex = find(unlabelled,1);
else
    currentIndex = 1;
    fprintf('\nAll objects in this stack already have labels.\n');
    fprintf('Review mode started at Object 1.\n');
end

%% Create labeling figure

figureNumber = 200;

% Open/reuse the labeling figure first, then set its properties
% Some MATLAB versions do not allow a numeric figure number together
% with parameter-value pairs in the same figure(...) call
figureHandle = figure(figureNumber);

set( ...
    figureHandle, ...
    'Name','3D Microglia Manual Labelling', ...
    'NumberTitle','off', ...
    'Color','w');


%% Labeling loop

keepLabelling = true;

while keepLabelling

    currentObjectID = ...
        labelledTable.ObjectID(currentIndex);

    objectMask = ...
        analysisLabelVolume == currentObjectID;

    displayCurrentObject( ...
        figureHandle, ...
        imageStack, ...
        objectMask, ...
        currentIndex, ...
        numberOfObjects, ...
        sourceFile, ...
        labelledTable.MorphologyLabel(currentIndex), ...
        labelledTable.ParentObjectID(currentIndex), ...
        labelledTable.WasSeparated(currentIndex), ...
        labelledTable.SeparationPart(currentIndex), ...
        labelledTable.SeparationPartsTotal(currentIndex), ...
        xVoxelSize, ...
        yVoxelSize, ...
        zVoxelSize);

    fprintf('\n----------------------------------------\n');
    fprintf('Object %d of %d\n', currentIndex, numberOfObjects);

    if labelledTable.WasSeparated(currentIndex)
        fprintf(['WARNING: created by separation from parent ' ...
            'object %d, part %d of %d.\n'], ...
            labelledTable.ParentObjectID(currentIndex), ...
            labelledTable.SeparationPart(currentIndex), ...
            labelledTable.SeparationPartsTotal(currentIndex));
    end

    currentLabel = ...
        labelledTable.MorphologyLabel(currentIndex);

    if currentLabel == ""
        fprintf('Current label: UNLABELLED\n');
    else
        fprintf('Current label: %s\n', currentLabel);
    end

    fprintf('\n1 = Amoeboid\n');
    fprintf('2 = Activated\n');
    fprintf('3 = Ramified\n');
    fprintf('4 = Exclude\n');
    fprintf('n = Next object\n');
    fprintf('p = Previous object\n');
    fprintf('j = Jump to object\n');
    fprintf('q = Save and finish\n');

    userChoice = lower(strtrim(input( ...
        'Choice: ', 's')));

    labelChanged = false;

    switch userChoice

        case '1'
            labelledTable.MorphologyLabel(currentIndex) = ...
                "Amoeboid";
            labelChanged = true;

        case '2'
            labelledTable.MorphologyLabel(currentIndex) = ...
                "Activated";
            labelChanged = true;

        case '3'
            labelledTable.MorphologyLabel(currentIndex) = ...
                "Ramified";
            labelChanged = true;

        case '4'
            labelledTable.MorphologyLabel(currentIndex) = ...
                "Exclude";
            labelChanged = true;

        case 'n'
            currentIndex = currentIndex + 1;

            if currentIndex > numberOfObjects
                currentIndex = 1;
                fprintf('\nReached the end. Returning to Object 1.\n');
            end

        case 'p'
            currentIndex = currentIndex - 1;

            if currentIndex < 1
                currentIndex = numberOfObjects;
            end

        case 'j'
            jumpIndex = input( ...
                sprintf('Jump to object number (1-%d): ', ...
                numberOfObjects));

            if isnumeric(jumpIndex) && ...
                    isscalar(jumpIndex) && ...
                    jumpIndex >= 1 && ...
                    jumpIndex <= numberOfObjects && ...
                    jumpIndex == round(jumpIndex)

                currentIndex = jumpIndex;
            else
                fprintf('Invalid object number.\n');
            end

        case 'q'
            saveMasterDataset(labelledTable, masterFile, sourceFile);
            keepLabelling = false;

        otherwise
            fprintf('Please choose 1, 2, 3, 4, n, p, j or q.\n');
    end

    if labelChanged

        saveMasterDataset( ...
            labelledTable, ...
            masterFile, ...
            sourceFile);

        currentIndex = currentIndex + 1;

        if currentIndex > numberOfObjects
            currentIndex = 1;
            fprintf(['\nAll objects reached. You can now review ' ...
                'from the beginning or press q to finish.\n']);
        end
    end
end


%% Close figure and print summary

if isvalid(figureHandle)
    close(figureHandle);
end

fprintf('\nLabels saved to:\n%s\n', masterFile);

fprintf('\nCurrent stack label summary:\n');
fprintf('Amoeboid:  %d\n', ...
    sum(labelledTable.MorphologyLabel == "Amoeboid"));
fprintf('Activated: %d\n', ...
    sum(labelledTable.MorphologyLabel == "Activated"));
fprintf('Ramified:  %d\n', ...
    sum(labelledTable.MorphologyLabel == "Ramified"));
fprintf('Exclude:   %d\n', ...
    sum(labelledTable.MorphologyLabel == "Exclude"));
fprintf('Unlabelled: %d\n', ...
    sum(labelledTable.MorphologyLabel == ""));

end

%% Local function: display current object

function displayCurrentObject( ...
    figureHandle, imageStack, objectMask, ...
    currentIndex, numberOfObjects, sourceFile, currentLabel, ...
    parentObjectID, wasSeparated, separationPart, ...
    separationPartsTotal, xVoxelSize, yVoxelSize, zVoxelSize)

figure(figureHandle);
clf(figureHandle);

% Find a tight crop around the current object
[row, col, slice] = ind2sub(size(objectMask), find(objectMask));

paddingXY = 20;
paddingZ = 3;

rowMin = max(min(row) - paddingXY, 1);
rowMax = min(max(row) + paddingXY, size(objectMask,1));
colMin = max(min(col) - paddingXY, 1);
colMax = min(max(col) + paddingXY, size(objectMask,2));
sliceMin = max(min(slice) - paddingZ, 1);
sliceMax = min(max(slice) + paddingZ, size(objectMask,3));

imageCrop = imageStack( ...
    rowMin:rowMax, ...
    colMin:colMax, ...
    sliceMin:sliceMax);

maskCrop = objectMask( ...
    rowMin:rowMax, ...
    colMin:colMax, ...
    sliceMin:sliceMax);

% Projections
xyImage = max(imageCrop, [], 3);
xyMask = max(maskCrop, [], 3);

xzImage = squeeze(max(imageCrop, [], 1))';
xzMask = squeeze(max(maskCrop, [], 1))';

yzImage = squeeze(max(imageCrop, [], 2))';
yzMask = squeeze(max(maskCrop, [], 2))';

layout = tiledlayout(2,3, ...
    'Padding','compact', ...
    'TileSpacing','compact');

% XY intensity MIP with boundary
nexttile;
xyOverlay = imoverlay( ...
    mat2gray(xyImage), ...
    bwperim(xyMask), ...
    [1 0 0]);
imshow(xyOverlay);
title('XY MIP + Cell Boundary');

% Segmented XY MIP
nexttile;
imshow(xyMask);
title('Segmented XY MIP');

% 3D object
axes3D = nexttile;
hold(axes3D,'on');
surfaceData = isosurface(maskCrop,0.5);

if ~isempty(surfaceData.vertices)
    vertices = surfaceData.vertices;
    vertices(:,1) = vertices(:,1) * xVoxelSize;
    vertices(:,2) = vertices(:,2) * yVoxelSize;
    vertices(:,3) = vertices(:,3) * zVoxelSize;

    patch(axes3D, ...
        'Faces',surfaceData.faces, ...
        'Vertices',vertices, ...
        'FaceColor',[0.6 0.6 0.6], ...
        'EdgeColor','none', ...
        'FaceAlpha',0.9);
end

xlabel(axes3D,'X (\mum)');
ylabel(axes3D,'Y (\mum)');
zlabel(axes3D,'Z (\mum)');
title(axes3D,'3D Cell - Rotate if Needed');
axis(axes3D,'equal');
axis(axes3D,'tight');
grid(axes3D,'on');
view(axes3D,3);
camlight(axes3D,'headlight');
lighting(axes3D,'gouraud');
rotate3d(figureHandle,'on');
hold(axes3D,'off');

% XZ MIP
axesXZ = nexttile;
imagesc(axesXZ, ...
    (0:size(xzImage,2)-1) * xVoxelSize, ...
    (0:size(xzImage,1)-1) * zVoxelSize, ...
    xzImage);
axis(axesXZ,'image');
axis(axesXZ,'tight');
colormap(axesXZ,'gray');
xlabel(axesXZ,'X (\mum)');
ylabel(axesXZ,'Z (\mum)');
title(axesXZ,'XZ MIP');

% YZ MIP
axesYZ = nexttile;
imagesc(axesYZ, ...
    (0:size(yzImage,2)-1) * yVoxelSize, ...
    (0:size(yzImage,1)-1) * zVoxelSize, ...
    yzImage);
axis(axesYZ,'image');
axis(axesYZ,'tight');
colormap(axesYZ,'gray');
xlabel(axesYZ,'Y (\mum)');
ylabel(axesYZ,'Z (\mum)');
title(axesYZ,'YZ MIP');

% Information panel
axesInfo = nexttile;
axis(axesInfo,'off');

if currentLabel == ""
    labelText = 'UNLABELLED';
else
    labelText = char(currentLabel);
end

infoText = { ...
    sprintf('Object %d / %d', currentIndex, numberOfObjects), ...
    sprintf('Current label: %s', labelText), ...
    '', ...
    '1  Amoeboid', ...
    '2  Activated', ...
    '3  Ramified', ...
    '4  Exclude', ...
    '', ...
    'n  Next', ...
    'p  Previous', ...
    'j  Jump', ...
    'q  Save and finish'};

if wasSeparated
    infoText = [ ...
        {sprintf('SEPARATED CELL: Parent %d, part %d/%d', ...
        parentObjectID, separationPart, separationPartsTotal)}, ...
        {''}, ...
        infoText];
end

text(axesInfo,0,1,infoText, ...
    'VerticalAlignment','top', ...
    'FontSize',11, ...
    'Interpreter','none');

title(layout, sprintf('%s', sourceFile), ...
    'Interpreter','none');

drawnow;

end


%% Local function: save or update master dataset

function saveMasterDataset(currentTable, masterFile, sourceFile)

if isfile(masterFile)

    masterTable = readtable( ...
        masterFile, ...
        'TextType','string');

    if ~isequal( ...
            masterTable.Properties.VariableNames, ...
            currentTable.Properties.VariableNames)

        error(['Existing master labelled dataset has different ' ...
            'columns. Rename or remove it before starting this ' ...
            'new labelling workflow.']);
    end

    keepRows = ...
        masterTable.SourceFile ~= sourceFile;

    masterTable = masterTable(keepRows,:);

    masterTable = [masterTable; currentTable];

else

    masterTable = currentTable;
end

writetable(masterTable, masterFile);

end
