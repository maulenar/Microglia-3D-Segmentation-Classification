function [preprocessedStack, preprocessingInfo] = ...
    preprocessMicroglia3D(imageStack, settings)
% Preprocess a 3D microglia image stack
%
% Inputs:
% imageStack - raw 3D image volume
% settings - structure containing preprocessing settings
%
% Outputs:
% preprocessedStack - normalised and background-corrected 3D image
% preprocessingInfo - values useful for checking and reporting preprocessing
%
% Required settings:
% settings.gaussianSigmaXY
% settings.gaussianSigmaZ
% settings.backgroundRadius


%% Read settings

gaussianSigmaXY = settings.gaussianSigmaXY;
gaussianSigmaZ = settings.gaussianSigmaZ;
backgroundRadius = settings.backgroundRadius;


%% Check image

if isempty(imageStack)
    error('The image stack is empty.');
end

if ndims(imageStack) ~= 3
    error('The input must be a 3D image stack.');
end

numberOfSlices = size(imageStack, 3);


%% Convert to single precision

imageStack = single(imageStack);

%% Normalise intensity

% Use the 0.1th and 99.9th percentiles so that a small number of
% extremely dark or bright voxels do not control the full intensity range

lowValue = prctile(imageStack(:), 0.1);
highValue = prctile(imageStack(:), 99.9);

if highValue <= lowValue
    error('Image intensity range is too small.');
end

normalisedStack = ...
    (imageStack - lowValue) / ...
    (highValue - lowValue);

normalisedStack = min( ...
    max(normalisedStack, 0), 1);


%% Apply 3D Gaussian smoothing

smoothedStack = imgaussfilt3( ...
    normalisedStack, ...
    [gaussianSigmaXY ...
     gaussianSigmaXY ...
     gaussianSigmaZ]);

%% Estimate background

% Background is estimated slice by slice using morphological opening

backgroundStack = zeros( ...
    size(smoothedStack), ...
    'like', smoothedStack);

backgroundKernel = strel( ...
    'disk', backgroundRadius, 0);

for z = 1:numberOfSlices

    backgroundStack(:,:,z) = imopen( ...
        smoothedStack(:,:,z), ...
        backgroundKernel);

end

%% Subtract background

correctedStack = ...
    smoothedStack - backgroundStack;

correctedStack(correctedStack < 0) = 0;

preprocessedStack = rescale(correctedStack);


%% Save preprocessing information

preprocessingInfo.lowPercentileValue = lowValue;
preprocessingInfo.highPercentileValue = highValue;
preprocessingInfo.gaussianSigmaXY = gaussianSigmaXY;
preprocessingInfo.gaussianSigmaZ = gaussianSigmaZ;
preprocessingInfo.backgroundRadius = backgroundRadius;

positivePixels = ...
    preprocessedStack(preprocessedStack > 0);

preprocessingInfo.positivePixels = positivePixels;

%% Display summary

fprintf('\nPreprocessing complete.\n');
fprintf('Normalisation percentile range: %.4f to %.4f\n', ...
    lowValue, highValue);
fprintf('Gaussian sigma XY: %.2f\n', gaussianSigmaXY);
fprintf('Gaussian sigma Z: %.2f\n', gaussianSigmaZ);
fprintf('Background radius: %.2f pixels\n', backgroundRadius);

end
