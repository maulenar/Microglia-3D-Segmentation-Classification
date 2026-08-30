%% Assign microglia dataset splits
% Assign each labeled cell to Training, Validation or Test
% according to its source image

clear;
clc;

%% Load labeled dataset

filename = fullfile( ...
    'Results_3D_Microglia', ...
    'Microglia_Labelled_Dataset.csv');

data = readtable( ...
    filename, ...
    'TextType','string');


%% Define test files

testFiles = [ ...
    "1_baseline_0min.lsm"
    "5.tif"
    "25.tif"
    ];

%% Define validation files

validationFiles = [ ...
    "3.tif"
    "6.tif"
    "10.tif"
    "11.tif"
    "16.tif"
    ];


%% Assign all other files to training

data.DatasetSplit(:) = "Training";

%% Assign validation data

isValidation = ismember( ...
    data.SourceFile, ...
    validationFiles);

data.DatasetSplit(isValidation) = ...
    "Validation";

%% Assign test data

isTest = ismember( ...
    data.SourceFile, ...
    testFiles);

data.DatasetSplit(isTest) = ...
    "Test";

%% Save updated dataset

writetable(data, filename);

fprintf('\nDataset splits assigned and saved.\n');

%% Display split counts

fprintf('\nTraining objects: %d\n', ...
    sum(data.DatasetSplit == "Training"));

fprintf('Validation objects: %d\n', ...
    sum(data.DatasetSplit == "Validation"));

fprintf('Test objects: %d\n', ...
    sum(data.DatasetSplit == "Test"));

%% Display file assignments

fprintf('\nFiles and assigned splits:\n');

splitSummary = unique( ...
    data(:, {'SourceFile','DatasetSplit'}));

disp(splitSummary);
