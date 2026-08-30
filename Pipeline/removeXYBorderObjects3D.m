function [cleanLabelVolume, borderTable] = ...
    removeXYBorderObjects3D(labelVolume)
% Remove 3D objects touching X/Y image borders
%
% Objects touching the first or last Z slice are NOT removed
%
% Input:
% labelVolume - labeled 3D segmentation volume
%
% Outputs:
% cleanLabelVolume - relabeled volume after XY-border removal
% borderTable - summary showing which original objects were removed


%% Check input

if isempty(labelVolume)
    error('The label volume is empty.');
end

%% Image size

imageHeight = size(labelVolume,1);
imageWidth = size(labelVolume,2);

%% Find object labels

objectLabels = unique(labelVolume);
objectLabels(objectLabels == 0) = [];

numberOfObjects = numel(objectLabels);


%% Prepare output mask

cleanBinaryMask = labelVolume > 0;

%% Prepare summary table

objectID = zeros(numberOfObjects,1);
touchesXYBorder = false(numberOfObjects,1);
removed = false(numberOfObjects,1);

%% Check each object

for objectIndex = 1:numberOfObjects

    currentLabel = objectLabels(objectIndex);

    currentObjectMask = ...
        labelVolume == currentLabel;

    currentIndices = find(currentObjectMask);

    [rows, columns, ~] = ind2sub( ...
        size(labelVolume), ...
        currentIndices);

    %% Check X/Y borders

    currentTouchesXYBorder = ...
        any(rows == 1) || ...
        any(rows == imageHeight) || ...
        any(columns == 1) || ...
        any(columns == imageWidth);

    %% Remove objects touching X/Y borders

    if currentTouchesXYBorder

        cleanBinaryMask(currentObjectMask) = false;

    end

    %% Save object result

    objectID(objectIndex) = currentLabel;
    touchesXYBorder(objectIndex) = currentTouchesXYBorder;
    removed(objectIndex) = currentTouchesXYBorder;

end


%% Relabel remaining objects

remainingComponents = bwconncomp( ...
    cleanBinaryMask, ...
    26);

cleanLabelVolume = labelmatrix( ...
    remainingComponents);

cleanLabelVolume = uint32( ...
    cleanLabelVolume);

%% Create summary table

borderTable = table( ...
    objectID, ...
    touchesXYBorder, ...
    removed);


%% Display summary

numberRemoved = nnz(removed);
numberRemaining = remainingComponents.NumObjects;

fprintf('\nXY-border removal results:\n');
fprintf('Original object count: %d\n', numberOfObjects);
fprintf('Removed XY-border objects: %d\n', numberRemoved);
fprintf('Remaining objects: %d\n', numberRemaining);
fprintf('Z-border objects were retained.\n');

end
