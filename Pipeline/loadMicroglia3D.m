function [imageStack, xVoxelSize, yVoxelSize, zVoxelSize] = ...
    loadMicroglia3D(filename)
% Load a 3D microscopy stack from TIFF or LSM.
%
% Inputs:
%   filename - path to a .tif, .tiff or .lsm file
%
% Outputs:
%   imageStack - 3D image volume
%   xVoxelSize - X voxel size in micrometres
%   yVoxelSize - Y voxel size in micrometres
%   zVoxelSize - Z spacing in micrometres


%% Check file

if ~isfile(filename)
    error('File not found: %s', filename);
end

[~, ~, extension] = fileparts(filename);

% Initialise calibration values as unknown
xVoxelSize = NaN;
yVoxelSize = NaN;
zVoxelSize = NaN;

%% Load TIFF

if strcmpi(extension, '.tif') || strcmpi(extension, '.tiff')

    info = imfinfo(filename);

    numberOfSlices = numel(info);
    imageHeight = info(1).Height;
    imageWidth = info(1).Width;

    imageStack = zeros( ...
        imageHeight, ...
        imageWidth, ...
        numberOfSlices, ...
        'single');

    for z = 1:numberOfSlices
        imageStack(:,:,z) = single( ...
            imread(filename, z, 'Info', info));
    end

    fprintf('Loaded TIFF: %d slices.\n', numberOfSlices);


    %% Read TIFF X and Y calibration

    if isfield(info(1), 'ResolutionUnit')

        resolutionUnit = info(1).ResolutionUnit;

        if isfield(info(1), 'XResolution')
            xResolution = info(1).XResolution;

            if xResolution > 0
                if strcmpi(resolutionUnit, 'Centimeter')
                    xVoxelSize = 10000 / xResolution;
                elseif strcmpi(resolutionUnit, 'Inch')
                    xVoxelSize = 25400 / xResolution;
                end
            end
        end

        if isfield(info(1), 'YResolution')
            yResolution = info(1).YResolution;

            if yResolution > 0
                if strcmpi(resolutionUnit, 'Centimeter')
                    yVoxelSize = 10000 / yResolution;
                elseif strcmpi(resolutionUnit, 'Inch')
                    yVoxelSize = 25400 / yResolution;
                end
            end
        end
    end

    %% Read ImageJ Z spacing

    if isfield(info(1), 'ImageDescription')

        description = info(1).ImageDescription;

        spacingText = regexp( ...
            description, ...
            'spacing=([0-9.]+)', ...
            'tokens', ...
            'once');

        if ~isempty(spacingText)
            zVoxelSize = str2double(spacingText{1});
        end
    end


%% Load LSM

elseif strcmpi(extension, '.lsm')

    if exist('bfGetReader', 'file') ~= 2
        error([ ...
            'Bio-Formats was not found. ' ...
            'Add the bfmatlab folder to the MATLAB path first.']);
    end

    reader = bfGetReader(filename);

    sizeX = reader.getSizeX();
    sizeY = reader.getSizeY();
    sizeZ = reader.getSizeZ();
    sizeC = reader.getSizeC();
    sizeT = reader.getSizeT();

    fprintf( ...
        'LSM dimensions: X=%d Y=%d Z=%d C=%d T=%d\n', ...
        sizeX, sizeY, sizeZ, sizeC, sizeT);

    % Use the first channel and first time point
    channel = 0;
    timePoint = 0;

    imageStack = zeros( ...
        sizeY, ...
        sizeX, ...
        sizeZ, ...
        'single');

    for z = 1:sizeZ

        planeIndex = reader.getIndex( ...
            z - 1, ...
            channel, ...
            timePoint) + 1;

        imageStack(:,:,z) = single( ...
            bfGetPlane(reader, planeIndex));
    end

    metadataStore = reader.getMetadataStore();

    pixelSizeX = metadataStore.getPixelsPhysicalSizeX(0);
    pixelSizeY = metadataStore.getPixelsPhysicalSizeY(0);
    pixelSizeZ = metadataStore.getPixelsPhysicalSizeZ(0);

    if ~isempty(pixelSizeX)
        xVoxelSize = pixelSizeX.value().doubleValue();
    end

    if ~isempty(pixelSizeY)
        yVoxelSize = pixelSizeY.value().doubleValue();
    end

    if ~isempty(pixelSizeZ)
        zVoxelSize = pixelSizeZ.value().doubleValue();
    end

    reader.close();

    fprintf('Loaded LSM: %d slices.\n', sizeZ);


%% Unsupported format

else

    error('Unsupported file format: %s', extension);

end

%% Display calibration

if isnan(xVoxelSize)
    fprintf('X voxel size was not found in metadata.\n');
else
    fprintf('X voxel size: %.4f um\n', xVoxelSize);
end

if isnan(yVoxelSize)
    fprintf('Y voxel size was not found in metadata.\n');
else
    fprintf('Y voxel size: %.4f um\n', yVoxelSize);
end

if isnan(zVoxelSize)
    fprintf('Z spacing was not found in metadata.\n');
else
    fprintf('Z spacing: %.4f um\n', zVoxelSize);
end

end
