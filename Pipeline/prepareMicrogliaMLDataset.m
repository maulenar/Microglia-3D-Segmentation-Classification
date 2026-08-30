%% Prepare microglia machine learning dataset

% Reads the newly labeled dataset and prepares the fixed
% Training, Validation and Test sets for classifier development
%
% Test set is not be used

clear;
clc;

%% File

datasetFile = 'Microglia_Labelled_Dataset.csv';

if ~isfile(datasetFile)
    error('Dataset file was not found: %s', datasetFile);
end

data = readtable(datasetFile, 'TextType', 'string');

%% Remove excluded objects

validLabels = ["Amoeboid", "Activated", "Ramified"];

keepRows = ismember(data.MorphologyLabel, validLabels);
data = data(keepRows, :);

fprintf('Usable labelled cells: %d\n', height(data));


%% Select morphology features

featureNames = { ...
    'Volume_um3', ...
    'SurfaceArea_um2', ...
    'EquivalentDiameter_um', ...
    'Sphericity', ...
    'MajorAxisLength_um', ...
    'IntermediateAxisLength_um', ...
    'MinorAxisLength_um', ...
    'Elongation', ...
    'Flatness'};

% Check that all required features exist
missingFeatures = setdiff(featureNames, data.Properties.VariableNames);

if ~isempty(missingFeatures)
    error('Missing feature(s): %s', strjoin(missingFeatures, ', '));
end

%% Check dataset split

requiredSplits = ["Training", "Validation", "Test"];

if ~ismember('DatasetSplit', data.Properties.VariableNames)
    error('DatasetSplit column is missing.');
end

if any(~ismember(data.DatasetSplit, requiredSplits))
    error('DatasetSplit contains missing or unexpected values.');
end

%% Check that each source file has only one split

sourceFiles = unique(data.SourceFile);

for fileIndex = 1:length(sourceFiles)

    currentFile = sourceFiles(fileIndex);

    currentSplits = unique( ...
        data.DatasetSplit(data.SourceFile == currentFile));

    if length(currentSplits) ~= 1
        error( ...
            'Source file %s appears in more than one dataset split.', ...
            currentFile);
    end
end

%% Create training, validation and test sets

trainingRows   = data.DatasetSplit == "Training";
validationRows = data.DatasetSplit == "Validation";
testRows       = data.DatasetSplit == "Test";

XTrain = data{trainingRows, featureNames};
YTrain = categorical(data.MorphologyLabel(trainingRows));

XValidation = data{validationRows, featureNames};
YValidation = categorical(data.MorphologyLabel(validationRows));

XTest = data{testRows, featureNames};
YTest = categorical(data.MorphologyLabel(testRows));



%% Check for invalid feature values

if any(~isfinite(XTrain), 'all')
    error('Training features contain NaN or Inf values.');
end

if any(~isfinite(XValidation), 'all')
    error('Validation features contain NaN or Inf values.');
end

if any(~isfinite(XTest), 'all')
    error('Test features contain NaN or Inf values.');
end

%% Print dataset summary

fprintf('\n--- MACHINE LEARNING DATASET ---\n');

fprintf('\nTraining: %d cells\n', size(XTrain, 1));
printClassCounts(YTrain);

fprintf('\nValidation: %d cells\n', size(XValidation, 1));
printClassCounts(YValidation);

fprintf('\nTest: %d cells\n', size(XTest, 1));
printClassCounts(YTest);

fprintf('\nNumber of predictor features: %d\n', length(featureNames));

fprintf('\nPredictors:\n');

for featureIndex = 1:length(featureNames)
    fprintf('  %s\n', featureNames{featureIndex});
end

fprintf('\nDataset preparation complete.\n');
fprintf('Do not use XTest or YTest during model selection.\n');


%% Local function

function printClassCounts(labels)

classNames = ["Amoeboid", "Activated", "Ramified"];

for classIndex = 1:length(classNames)

    currentClass = classNames(classIndex);

    numberOfCells = sum(string(labels) == currentClass);

    fprintf('  %-10s : %d\n', currentClass, numberOfCells);
end

end
