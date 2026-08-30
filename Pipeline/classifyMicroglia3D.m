function classifiedFeatures = classifyMicroglia3D(featureTable)
% Classify segmented microglia as:
%   Amoeboid
%   Activated
%   Ramified
%
% Input:
%   featureTable - table produced by extractMicrogliaFeatures3D.m
%
% Output:
%   classifiedFeatures - feature table with Predicted morphology added


%% Find trained classifier

% In the app, classifyMicroglia3D.m and Microglia_Classifier.mat should
% both be inside the Microglia_3D folder
functionFolder = fileparts(mfilename('fullpath'));

modelFile = fullfile( ...
    functionFolder, ...
    'Microglia_Classifier.mat');

% Keep the old development location as a fallback
if ~isfile(modelFile)

    oldModelFile = fullfile( ...
        'Results_3D_Microglia', ...
        'Microglia_Classifier.mat');

    if isfile(oldModelFile)
        modelFile = oldModelFile;
    else
        error( ...
            ['Microglia_Classifier.mat was not found. ' ...
             'Place it in the same Microglia_3D folder as classifyMicroglia3D.m.']);
    end
end

%% Load trained classifier

loadedModel = load(modelFile);

if isfield(loadedModel, 'microgliaClassifier')
    microgliaClassifier = ...
        loadedModel.microgliaClassifier;

elseif isfield(loadedModel, 'classifier')
    % Compatibility with an older saved variable name
    microgliaClassifier = ...
        loadedModel.classifier;

else
    error( ...
        'The classifier MAT file does not contain a trained classifier.');
end

if ~isfield(loadedModel, 'featureNames')
    error( ...
        'The classifier MAT file does not contain featureNames.');
end

featureNames = loadedModel.featureNames;


%% Check required features

missingFeatures = setdiff( ...
    featureNames, ...
    featureTable.Properties.VariableNames);

if ~isempty(missingFeatures)
    error( ...
        'Missing classifier feature(s): %s', ...
        strjoin(missingFeatures, ', '));
end

%% Create classifier input

X = featureTable{:, featureNames};

if any(~isfinite(X), 'all')
    error( ...
        'Feature table contains NaN or Inf values.');
end

%% Classify microglia

predictedLabels = predict( ...
    microgliaClassifier, ...
    X);

%% Add predictions to feature table

classifiedFeatures = featureTable;

classifiedFeatures.PredictedMorphology = ...
    string(predictedLabels);

%% Display classification summary

fprintf('\n--- MICROGLIA CLASSIFICATION ---\n');
fprintf('Total classified cells: %d\n', ...
    height(classifiedFeatures));

classNames = ["Amoeboid", "Activated", "Ramified"];

for classIndex = 1:length(classNames)

    currentClass = classNames(classIndex);

    numberOfCells = sum( ...
        classifiedFeatures.PredictedMorphology == currentClass);

    fprintf('  %-10s : %d\n', ...
        currentClass, ...
        numberOfCells);
end

fprintf('Classification complete.\n');

end
