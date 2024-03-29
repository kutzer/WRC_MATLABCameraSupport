function varargout = aprilTagCorrespondence(camParams,tagFamily,tagID,tagSize,pName,varargin)
% APRILTAGCORRESPONDENCE runs MATLAB AprilTag tools returning information
% to establish a correspondence with other data set(s).
%   [H_a2c,corIndexes,info] = ...
%          APRILTAGCORRESPONDENCE(camParams,tagFamily,tagID,tagSize,pName)
%
%   [...] = APRILTAGCORRESPONDENCE(___,bName)
%
%   [...] = APRILTAGCORRESPONDENCE(___,fExt)
%
%   Input(s)
%       camParams - camera or fisheye parameters natively returned by 
%                   MATLAB camera calibration
%       tagFamily - character array specifying AprilTag family (see
%                   readAprilTag.m)
%       tagID     - scalar integer specifying AprilTag ID (see 
%                   readAprilTag.m)
%       tagSize   - scalar value specifying AprilTag size (see
%                   readAprilTag.m)
%       pName     - [OPTIONAL] character array defining folder path 
%                   containing m calibration images OR a cell array 
%                   defining calibration images
%       bName     - [OPTIONAL] character array defining the base filename  
%                   of each image
%       fExt      - [OPTIONAL] character array defining the file extension
%                   of each image. NOTE: fExt must include '.' as the
%                   first character (e.g. '.png')
%
%   Output(s)
%       H_f2c      - n-element cell array containing tag pose relative to
%                    the camera frame
%       corIndexes - m-element index array noting image index for 
%                    defining correspondence
%       info       - structured array containing additional information
%           info.imageNames   - cell array containing images used in
%                               calibration
%           info.tagLocations - cell array containing tag locations
%           info.tagFamily    - character array specifying AprilTag family
%           info.tagID        - scalar integer specifying AprilTag ID
%           info.tagSize      - scalar value specifying AprilTag size
%
%   M. Kutzer, 14Sep2022, USNA

%% Set default(s)
imageNames  = {};
corIndexes  = [];
bName       = '';
fExt        = '';

%% Set default output(s)
for i = 1:nargout
    varargout{i} = [];
end

%% Check input(s)
narginchk(4,7);

if nargin < 5
    pName = uigetdir;
end

switch lower( class(pName) )
    case {'string','char'}
        % User specified folder location of calibration images
    case 'cell'
        % User specified image names
        fprintf(['User specified image names, assuming correlation ',...
            'indexing is 1:%d.\n'],numel(pName));
        imageNames = pName;
        corIndexes = 1:numel(pName);
end

for i = 1:numel(varargin)
    switch class( varargin{i} )
        case {'char','string'}
            if numel(varargin{i}) > 1
                if matches(varargin{i}(1),'.')
                    fExt = varargin{i};
                else
                    bName = varargin{i};
                end
                continue
            end
    end

    warning('Ignoring input %d.',i+1);
end
        
%% Get image names
if isempty(imageNames)
    [imageNames,corIndexes] = findImageSet(pName,bName,fExt);
else
    % Check image names
    tfKeep = isfile(imageNames);
    imageNames = imageNames(tfKeep);
    corIndexes = corIndexes(tfKeep);

    % TODO - check image format
end

fprintf('%d candidate correspondence images.\n',numel(imageNames));

if numel(imageNames) < 1
    warning('No valid images found.');
    return
end

%% Process images
% Detect checkerboards in images
%   -> This uses the same functions as "cameraCalibrator.m"
H_a2c        = cell(1,numel(imageNames));
tagLocations = cell(1,numel(imageNames));
imagesUsed  = false(1,numel(imageNames));

fprintf('\nDetecting AprilTags...');
for i = 1:numel(imageNames)
    im = imread(imageNames{i});

    [H_a2c{i},tagLocations{i}] =...
        aprilTagPose(im,camParams,tagFamily,tagID,tagSize);

    if ~isempty(H_a2c{i})
        imagesUsed(i) = true;
    end
end
fprintf('COMPLETE\n');

H_a2c = H_a2c(imagesUsed);
tagLocations = tagLocations(imagesUsed);
imageNames = imageNames(imagesUsed);
corIndexes = corIndexes(imagesUsed);

%% Package outputs
info.imageNames = imageNames;
info.tagLocations = tagLocations;
info.tagFamily = tagFamily;
info.tagID = tagID;
info.tagSize = tagSize;

outTMP = {H_a2c,corIndexes,info};
for i = 1:nargout
    varargout{i} = outTMP{i};
end