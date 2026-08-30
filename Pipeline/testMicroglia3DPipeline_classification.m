%% Test microglia 3D pipeline

% Current development pipeline:
% load -> preprocess -> segment -> remove XY-border objects ->
% soma-assisted separation -> feature extraction -> classification

clear;
clc;
close all;

%% Select file
filename = '1_baseline_0min.lsm';

%% Default calibration
defaultXVoxelSize = 0.17;
defaultYVoxelSize = 0.17;
defaultZVoxelSize = 1.0;

%% Preprocessing settings
preprocessSettings.gaussianSigmaXY = 1.0;
preprocessSettings.gaussianSigmaZ = 0.7;
preprocessSettings.backgroundRadius = 18;

%% Segmentation settings
segmentSettings.lowThresholdMultiplier = 0.7;
segmentSettings.highThresholdMultiplier = 1.15;
segmentSettings.minimumObjectVolume_um3 = 200;

%% Soma settings
somaSettings.somaCoreRadius_um = 1.5;
somaSettings.minimumSomaVolume_um3 = 100;

%% Load image
[imageStack, xVoxelSize, yVoxelSize, zVoxelSize] = ...
    loadMicroglia3D(filename);

%% Apply default calibration if needed
if isnan(xVoxelSize)
    xVoxelSize = defaultXVoxelSize;
end
if isnan(yVoxelSize)
    yVoxelSize = defaultYVoxelSize;
end
if isnan(zVoxelSize)
    zVoxelSize = defaultZVoxelSize;
end

fprintf('\nFinal calibration:\n');
fprintf('X = %.4f um\n', xVoxelSize);
fprintf('Y = %.4f um\n', yVoxelSize);
fprintf('Z = %.4f um\n', zVoxelSize);

%% Preprocess image
[preprocessedStack, preprocessingInfo] = ...
    preprocessMicroglia3D(imageStack, preprocessSettings);

%% Add calibration to segmentation settings
segmentSettings.xVoxelSize = xVoxelSize;
segmentSettings.yVoxelSize = yVoxelSize;
segmentSettings.zVoxelSize = zVoxelSize;

%% Segment image
[labelVolume, binaryMask, thresholdInfo] = ...
    segmentMicroglia3D(preprocessedStack, segmentSettings);

%% Choose middle slice
numberOfSlices = size(imageStack, 3);
middleSlice = ceil(numberOfSlices / 2);


%% Display processing stages
figure('Name','Microglia3D Segmentation Check','NumberTitle','off');
tiledlayout(2,3);

nexttile;
imshow(mat2gray(imageStack(:,:,middleSlice)));
title(sprintf('Raw Slice %d / %d', middleSlice, numberOfSlices));

nexttile;
imshow(preprocessedStack(:,:,middleSlice));
title('Preprocessed Slice');

nexttile;
imshow(binaryMask(:,:,middleSlice));
title('Segmented Slice');

nexttile;
imshow(mat2gray(max(imageStack, [], 3)));
title('Raw MIP');

nexttile;
imshow(max(preprocessedStack, [], 3));
title('Preprocessed MIP');

nexttile;
imshow(max(binaryMask, [], 3));
title(sprintf('Segmented MIP - %d Objects', thresholdInfo.numberOfObjects));

%% Display labeled objects in different colours
labelProjection = max(labelVolume, [], 3);

figure('Name','Microglia3D Labelled Objects','NumberTitle','off');

imshow(label2rgb(labelProjection, 'hsv', 'k', 'shuffle'));

title(sprintf('Detected 3D Objects - %d Objects', ...
    thresholdInfo.numberOfObjects));

%% Display segmented cells in 3D
objectLabels = unique(labelVolume);
objectLabels(objectLabels == 0) = [];
numberOfObjects = numel(objectLabels);
objectColours = hsv(numberOfObjects);

figure3D = figure('Name','3D Segmented Microglia - Individual Cells', ...
    'NumberTitle','off','Color', 'w');
axes3D = axes('Parent', figure3D);
hold(axes3D,'on');

for objectIndex = 1:numberOfObjects
    currentLabel = objectLabels(objectIndex);
    objectMask = labelVolume == currentLabel;
    surfaceData = isosurface(objectMask,0.5);
    if isempty(surfaceData.vertices)
        continue;
    end
    vertices = surfaceData.vertices;
    vertices(:,1) = vertices(:,1) * xVoxelSize;
    vertices(:,2) = vertices(:,2) * yVoxelSize;
    vertices(:,3) = vertices(:,3) * zVoxelSize;
    patch(axes3D,'Faces', surfaceData.faces,'Vertices', vertices,'FaceColor', ...
        objectColours(objectIndex,:),'EdgeColor','none','FaceAlpha', 0.8);
end

xlabel(axes3D, 'X (\mum)');
ylabel(axes3D, 'Y (\mum)');
zlabel(axes3D, 'Z (\mum)');
title(axes3D,sprintf('3D Segmentation - %d Individual Cells',numberOfObjects));
axis(axes3D, 'equal');
axis(axes3D, 'tight');
grid(axes3D, 'on');
view(axes3D, 3);
rotate3d(figure3D, 'on');
camlight(axes3D, 'headlight');
lighting(axes3D, 'gouraud');
hold(axes3D, 'off');



%% Xy-border object removal
[labelVolumeXYClean, borderTable] = ...
    removeXYBorderObjects3D(labelVolume);

%% Use the cleaned label volume from this point on
labelVolume = labelVolumeXYClean;

%% Display xy-border cleaned labelled MIP
xyCleanProjection = max( labelVolume, [], 3);
remainingLabels = unique(labelVolume);
remainingLabels(remainingLabels == 0) = [];

figure('Name','After XY-Border Object Removal','NumberTitle','off');
imshow(label2rgb(xyCleanProjection,'hsv','k','shuffle'));
title(sprintf( ...
    'After XY-Border Removal - %d Objects', ...
    numel(remainingLabels)));

%% Detect soma candidates
[somaMask, somaTable] = ...
    detectMicrogliaSomas3D(labelVolume, xVoxelSize, yVoxelSize, ...
    zVoxelSize, somaSettings);

%% Display soma candidates
segmentedProjection = max(labelVolume > 0, [], 3);
somaProjection = max(somaMask, [], 3);
somaOverlay = imoverlay( segmentedProjection, somaProjection, [1 0 0]);

figure('Name','Microglia3D Soma Detection','NumberTitle','off');
imshow(somaOverlay);
title('Detected Soma Candidates - Red');

%% Separate possible merged cells
[separatedLabelVolume, separationTable] = ...
    separateMicroglia3D( labelVolume, somaMask);

%% Display labeled objects after separation
separatedLabelProjection = max( separatedLabelVolume, [], 3);
finalLabels = unique(separatedLabelVolume);
finalLabels(finalLabels == 0) = [];
numberOfSeparatedObjects = numel(finalLabels);

figure('Name','Microglia3D Objects After Separation', ...
'NumberTitle','off');
imshow( ...
    label2rgb( separatedLabelProjection,'hsv', ...
    'k','shuffle'));
title(sprintf( ...
    'After Soma-Guided Separation - %d Objects', ...
    numberOfSeparatedObjects));


%% Display separated cells in 3D
separatedColours = hsv(numberOfSeparatedObjects);

figureSeparated3D = figure( ...
    'Name','3D Microglia After Soma-Guided Separation', ...
    'NumberTitle','off','Color','w');

axesSeparated3D = axes('Parent', figureSeparated3D);
hold(axesSeparated3D, 'on');

for objectIndex = 1:numberOfSeparatedObjects
    currentLabel = finalLabels(objectIndex);
    objectMask = ...
        separatedLabelVolume == currentLabel;
    surfaceData = isosurface(objectMask, 0.5);
    if isempty(surfaceData.vertices)
        continue;
    end

    vertices = surfaceData.vertices;
    vertices(:,1) = vertices(:,1) * xVoxelSize;
    vertices(:,2) = vertices(:,2) * yVoxelSize;
    vertices(:,3) = vertices(:,3) * zVoxelSize;

    patch( ...
        axesSeparated3D, ...
        'Faces', surfaceData.faces, ...
        'Vertices', vertices, ...
        'FaceColor', separatedColours(objectIndex,:), ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.8);
end

xlabel(axesSeparated3D, 'X (\mum)');
ylabel(axesSeparated3D, 'Y (\mum)');
zlabel(axesSeparated3D, 'Z (\mum)');

title( ...
    axesSeparated3D, ...
    sprintf( ...
    '3D After Separation - %d Cells', ...
    numberOfSeparatedObjects));

axis(axesSeparated3D, 'equal');
axis(axesSeparated3D, 'tight');
grid(axesSeparated3D, 'on');
view(axesSeparated3D, 3);

rotate3d(figureSeparated3D, 'on');
camlight(axesSeparated3D, 'headlight');
lighting(axesSeparated3D, 'gouraud');
hold(axesSeparated3D, 'off');


%% Feature extraction
% Use whichever label volume you want to analyse

% If separation is being used:
 analysisLabelVolume = separatedLabelVolume;

% If separation is NOT being used:
% analysisLabelVolume = labelVolume

featureTable = ...
    extractMicrogliaFeatures3D( ...
    analysisLabelVolume, ...
    somaMask, ...
    xVoxelSize, ...
    yVoxelSize, ...
    zVoxelSize);

%% Save features to CSV
outputFilename = 'Microglia_3D_Features.csv';
writetable(featureTable, outputFilename);
fprintf('\nFeature table saved as: %s\n', outputFilename);


%% Check possible merged objects
mergedObjects = ...
    featureTable(featureTable.PossibleMerged, :);

if isempty(mergedObjects)
    fprintf('\nNo possible merged objects were detected.\n');
else
    fprintf('\nPossible merged objects:\n');
    disp(mergedObjects);
end

%% Display simple feature summary
fprintf('\nFeature ranges:\n');
fprintf( ...
    'Volume: %.2f to %.2f um^3\n', ...
    min(featureTable.Volume_um3), ...
    max(featureTable.Volume_um3));
fprintf( ...
    'Sphericity: %.3f to %.3f\n', ...
    min(featureTable.Sphericity,[],'omitnan'), ...
    max(featureTable.Sphericity,[],'omitnan'));
fprintf( ...
    'Elongation: %.3f to %.3f\n', ...
    min(featureTable.Elongation,[],'omitnan'), ...
    max(featureTable.Elongation,[],'omitnan'));

%% Classify microglia morphology
% Apply the previously trained Bagged Trees classifier
% This does NOT retrain the model

classifiedTable = ...
    classifyMicroglia3D(featureTable);

%% Save classification results

classificationOutputFilename = ...
    'Microglia_3D_Classified.csv';

writetable( ...
    classifiedTable, ...
    classificationOutputFilename);

fprintf( ...
    '\nClassification table saved as: %s\n', ...
    classificationOutputFilename);

%% Display classified cells on 2d MIP
% Class colours:
%   Amoeboid  = red
%   Activated = yellow
%   Ramified  = green

originalProjection = ...
    mat2gray(max(imageStack, [], 3));

classifiedImage = ...
    repmat(im2uint8(originalProjection), [1 1 3]);

numberOfClassifiedObjects = ...
    height(classifiedTable);

for objectIndex = 1:numberOfClassifiedObjects

    currentLabel = ...
        classifiedTable.ObjectID(objectIndex);

    objectMask = ...
        analysisLabelVolume == currentLabel;

    objectProjection = ...
        max(objectMask, [], 3);

    boundary = ...
        bwperim(objectProjection);

    predictedClass = ...
        classifiedTable.PredictedMorphology(objectIndex);

    if predictedClass == "Amoeboid"

        currentColour = [1 0 0];

    elseif predictedClass == "Activated"

        currentColour = [1 1 0];

    elseif predictedClass == "Ramified"

        currentColour = [0 1 0];

    else

        currentColour = [1 1 1];

    end

    classifiedImage = ...
        imoverlay( ...
        classifiedImage, ...
        boundary, ...
        currentColour);

end

figure( ...
    'Name', ...
    'Microglia3D Morphology Classification', ...
    'NumberTitle', ...
    'off');

imshow(classifiedImage);

title( ...
    sprintf( ...
    '3D Microglia Classification - %d Cells', ...
    numberOfClassifiedObjects));

xlabel( ...
    'Red = Amoeboid   |   Yellow = Activated   |   Green = Ramified');


%% Display classified cells in 3D

figureClassified3D = figure( ...
    'Name', ...
    '3D Microglia Morphology Classification', ...
    'NumberTitle', ...
    'off', ...
    'Color', ...
    'w');

axesClassified3D = ...
    axes('Parent', figureClassified3D);

hold(axesClassified3D, 'on');

for objectIndex = 1:numberOfClassifiedObjects

    currentLabel = ...
        classifiedTable.ObjectID(objectIndex);

    objectMask = ...
        analysisLabelVolume == currentLabel;

    surfaceData = ...
        isosurface(objectMask, 0.5);

    if isempty(surfaceData.vertices)
        continue;
    end

    predictedClass = ...
        classifiedTable.PredictedMorphology(objectIndex);

    if predictedClass == "Amoeboid"

        currentColour = [1 0 0];

    elseif predictedClass == "Activated"

        currentColour = [1 1 0];

    elseif predictedClass == "Ramified"

        currentColour = [0 1 0];

    else

        currentColour = [1 1 1];

    end

    vertices = ...
        surfaceData.vertices;

    vertices(:,1) = ...
        vertices(:,1) * xVoxelSize;

    vertices(:,2) = ...
        vertices(:,2) * yVoxelSize;

    vertices(:,3) = ...
        vertices(:,3) * zVoxelSize;

    patch( ...
        axesClassified3D, ...
        'Faces', surfaceData.faces, ...
        'Vertices', vertices, ...
        'FaceColor', currentColour, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.8);

end

xlabel(axesClassified3D, 'X (\mum)');
ylabel(axesClassified3D, 'Y (\mum)');
zlabel(axesClassified3D, 'Z (\mum)');

title( ...
    axesClassified3D, ...
    sprintf( ...
    '3D Classified Microglia - %d Cells', ...
    numberOfClassifiedObjects));

axis(axesClassified3D, 'equal');
axis(axesClassified3D, 'tight');
grid(axesClassified3D, 'on');
view(axesClassified3D, 3);

rotate3d(figureClassified3D, 'on');
camlight(axesClassified3D, 'headlight');
lighting(axesClassified3D, 'gouraud');

hold(axesClassified3D, 'off');

%% Final classification summary

fprintf('\n--- FINAL STACK CLASSIFICATION ---\n');

fprintf( ...
    'Amoeboid:  %d\n', ...
    sum(classifiedTable.PredictedMorphology == "Amoeboid"));

fprintf( ...
    'Activated: %d\n', ...
    sum(classifiedTable.PredictedMorphology == "Activated"));

fprintf( ...
    'Ramified:  %d\n', ...
    sum(classifiedTable.PredictedMorphology == "Ramified"));

fprintf( ...
    'Total:     %d\n', ...
    height(classifiedTable));

fprintf('\n3D microglia pipeline complete.\n');
