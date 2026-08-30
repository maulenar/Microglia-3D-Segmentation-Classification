%% Train the Bagged Trees classifier

clear;
clc;
close all;

% Fix the random seed so the result can be reproduced
rng(1);

%% Prepare machine learning data

prepareMicrogliaMLDataset;

%% Fixed classifier settings

minimumLeafSize = 1;
numberOfTrees = 100;

% Keep the class order consistent in all results
classNames = ["Amoeboid"; "Activated"; "Ramified"];

fprintf('\n--- TRAIN MICROGLIA CLASSIFIER ---\n');

fprintf('Training cells:   %d\n', size(XTrain,1));
fprintf('Validation cells: %d\n', size(XValidation,1));
fprintf('Test cells:       %d  (NOT USED)\n', size(XTest,1));

fprintf('\nClassifier settings:\n');
fprintf('  Model: Bagged Trees\n');
fprintf('  MinLeafSize: %d\n', minimumLeafSize);
fprintf('  Number of trees: %d\n', numberOfTrees);
fprintf('  Number of predictors: %d\n', length(featureNames));



%% Train classifier

treeTemplate = templateTree( ...
    'MinLeafSize', minimumLeafSize);

microgliaClassifier = fitcensemble( ...
    XTrain, ...
    YTrain, ...
    'Method', 'Bag', ...
    'NumLearningCycles', numberOfTrees, ...
    'Learners', treeTemplate);

fprintf('\nClassifier training complete.\n');

%% Validate classifier

validationPrediction = predict( ...
    microgliaClassifier, ...
    XValidation);

[validationMetrics, validationConfusionMatrix] = ...
    calculateClassificationMetrics( ...
        YValidation, ...
        validationPrediction, ...
        classNames);

%% Print validation results

fprintf('\n--- VALIDATION RESULTS ---\n');

fprintf('Overall accuracy:  %.4f  (%.1f%%)\n', ...
    validationMetrics.OverallAccuracy, ...
    100 * validationMetrics.OverallAccuracy);

fprintf('Balanced accuracy: %.4f  (%.1f%%)\n', ...
    validationMetrics.BalancedAccuracy, ...
    100 * validationMetrics.BalancedAccuracy);

fprintf('Macro F1:          %.4f\n', ...
    validationMetrics.MacroF1);

numberCorrect = sum(validationPrediction == YValidation);
numberIncorrect = numel(YValidation) - numberCorrect;

fprintf('\nCorrect classifications:   %d / %d\n', ...
    numberCorrect, numel(YValidation));

fprintf('Incorrect classifications: %d / %d\n', ...
    numberIncorrect, numel(YValidation));


%% Per-class validation results

validationClassMetrics = table( ...
    string(classNames), ...
    validationMetrics.Precision, ...
    validationMetrics.Recall, ...
    validationMetrics.F1, ...
    'VariableNames', { ...
        'Class', ...
        'Precision', ...
        'Recall', ...
        'F1'});

fprintf('\n--- PER-CLASS VALIDATION METRICS ---\n');
disp(validationClassMetrics);

%% Display confusion matrix

figure(1);

trueLabelsForPlot = reordercats( ...
    YValidation, ...
    classNames);

predictedLabelsForPlot = reordercats( ...
    validationPrediction, ...
    classNames);

chartHandle = confusionchart( ...
    trueLabelsForPlot, ...
    predictedLabelsForPlot);

chartHandle.Title = ...
    'Bagged Trees Classifier - Validation Set';


%% Save trained classifier

resultsFolder = 'Results_3D_Microglia';

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

modelFile = fullfile( ...
    resultsFolder, ...
    'Microglia_Classifier.mat');

save( ...
    modelFile, ...
    'microgliaClassifier', ...
    'featureNames', ...
    'minimumLeafSize', ...
    'numberOfTrees', ...
    'classNames');

fprintf('\nTrained classifier saved to:\n%s\n', modelFile);


%% Final message

fprintf('\nTRAINING COMPLETE.\n');
fprintf('The Test set has not been used.\n');

%% Local function

function [metrics, confusionMatrix] = ...
    calculateClassificationMetrics( ...
        trueLabels, predictedLabels, classNames)

confusionMatrix = confusionmat( ...
    trueLabels, ...
    predictedLabels, ...
    'Order', categorical(classNames, classNames));

numberOfClasses = numel(classNames);

precision = zeros(numberOfClasses,1);
recall = zeros(numberOfClasses,1);
f1 = zeros(numberOfClasses,1);

for classIndex = 1:numberOfClasses

    truePositive = ...
        confusionMatrix(classIndex,classIndex);

    falsePositive = ...
        sum(confusionMatrix(:,classIndex)) - truePositive;

    falseNegative = ...
        sum(confusionMatrix(classIndex,:)) - truePositive;

    if truePositive + falsePositive > 0
        precision(classIndex) = ...
            truePositive / ...
            (truePositive + falsePositive);
    else
        precision(classIndex) = 0;
    end

    if truePositive + falseNegative > 0
        recall(classIndex) = ...
            truePositive / ...
            (truePositive + falseNegative);
    else
        recall(classIndex) = 0;
    end

    if precision(classIndex) + recall(classIndex) > 0
        f1(classIndex) = ...
            2 * precision(classIndex) * recall(classIndex) / ...
            (precision(classIndex) + recall(classIndex));
    else
        f1(classIndex) = 0;
    end

end

overallAccuracy = ...
    sum(diag(confusionMatrix)) / ...
    sum(confusionMatrix,'all');

balancedAccuracy = mean(recall);
macroF1 = mean(f1);

metrics.OverallAccuracy = overallAccuracy;
metrics.BalancedAccuracy = balancedAccuracy;
metrics.MacroF1 = macroF1;

metrics.Precision = precision;
metrics.Recall = recall;
metrics.F1 = f1;

end
