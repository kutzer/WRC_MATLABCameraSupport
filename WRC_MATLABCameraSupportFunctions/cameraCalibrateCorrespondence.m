function varargout = cameraCalibrateCorrespondence(pName,varargin)
% CAMERACALIBRATECORRESPONDENCE runs MATLAB camera calibration tools
% returning information to establish a correspondence with other data
% set(s).
%   [A_c2m,H_f2c,corIndexes,camParams,info] =...
%                                     CAMERACALIBRATECORRESPONDENCE(pName)
%
%   [...] = cameraCalibrateCorrespondence(___,squareSize)
%
%   [...] = cameraCalibrateCorrespondence(___,lensType)
%
%   [...] = cameraCalibrateCorrespondence(___,bName)
%
%   [...] = cameraCalibrateCorrespondence(___,fExt)
%
%   Input(s)
%       pName      - [OPTIONAL] character array defining folder path 
%                    containing m calibration images OR a cell array 
%                    defining calibration images
%       squareSize - [OPTIONAL] positive scalar value defining square size 
%                    in millimeters
%       lensType   - [OPTIONAL] string argument defining lens type
%                    {'standard','fisheye'}
%       bName      - [OPTIONAL] character array defining the base filename  
%                    of each image
%       fExt       - [OPTIONAL] character array defining the file extension
%                    of each image. NOTE: fExt must include '.' as the
%                    first character (e.g. '.png')
%
%   Output(s)
%       A_c2m      - 3x3 array defining camera intrinsics
%       H_f2c      - n-element cell array containing extrinsics
%       corIndexes - m-element index array noting image index for 
%                    defining correspondence
%       camParams  - camera parameters natively returned by MATLAB
%       info       - structured array containing additional information
%           info.imageNames - cell array containing images used in
%                             calibration
%           info.squareSize - calibration checkerboard square size
%           info.boardSize  - calibration checkerboard size
%
%   NOTE: This function requires image names seperated using an underscore.
%         Example: checker_023.png
%
%   M. Kutzer, 12Sep2022, USNA

%% Set default(s)
squareSize  = [];
lensType    = [];
imageNames  = {};
corIndexes  = [];
bName       = '';
fExt        = '';

%% Set default output(s)
for i = 1:nargout
    varargout{i} = [];
end

%% Check input(s)
narginchk(0,5);

if nargin < 1
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
    % Square size
    if isnumeric( varargin{i} )
        if numel(varargin{i}) == 1 && nnz(varargin{i} > 0) == 1
            squareSize = varargin{i};
        end
        continue
    end
    
    switch lower( varargin{i} )
        case {'standard','fisheye'}
            lensType = lower( char( varargin{i} ) );
            continue
    end
    
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
fprintf('\nDetecting checkerboards...');
try
    % NEWER VERSION OF MATLAB
    [P_m, boardSize, imagesUsed] = detectCheckerboardPoints(imageNames,...
        'PartialDetections',false);
catch
    % OLDER VERSION OF MATLAB
    [P_m, boardSize, imagesUsed] = detectCheckerboardPoints(imageNames);
end
fprintf('COMPLETE\n\n');

% Update list of images used
imageNames = imageNames(imagesUsed);
% Update list of indices used
corIndexes = corIndexes(imagesUsed);
% Images used
fprintf('%40s: %4d\n','Images with detected checkerboards',numel(corIndexes));

% Read the first image to obtain image size
originalImage = imread(imageNames{1});
[mrows, ncols, ~] = size(originalImage);

% Prompt user for Square Size
if isempty(squareSize)
    squareSize = inputdlg({'Enter square size in millimeters'},'SquareSize',...
        [1,35],{'10.00'});
    if numel(squareSize) == 0
        warning('Action cancelled by user.');
        out = [];
        return
    end
    squareSize = str2double( squareSize{1} );
end

% Generate coordinates of the corners of the squares
%   relative to the "grid frame"
P_g = generateCheckerboardPoints(boardSize, squareSize);

% Prompt user for Camera Model
if isempty(lensType)
    list = {'Standard','Fisheye'};
    [listIdx,tf] = listdlg('PromptString',...
        {'Select Camera Model',...
        'Only one model can be selected at a time',''},...
        'SelectionMode','single','ListString',list);
    if ~tf
        warning('Action cancelled by user.');
        out = [];
        return
    end
    lensType = lower(list{listIdx});
end

% Calibrate the camera
try
    switch lensType
        case 'standard'
            % Standard camera calibration
            fprintf('\nCalibrating using standard camera model...');
            [camParams, imagesUsed, estimationErrors] = ...
                estimateCameraParameters(P_m, P_g, ...
                'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
                'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
                'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
                'ImageSize', [mrows, ncols]);
            fprintf('COMPLETE\n\n');
        case 'fisheye'
            % Fisheye camera calibration
            fprintf('\nCalibrating using fisheye camera model...');
            [camParams, imagesUsed, estimationErrors] = ...
                estimateFisheyeParameters(P_m, P_g, ...
                [mrows, ncols], ...
                'EstimateAlignment', true, ...
                'WorldUnits', 'millimeters');
            fprintf('COMPLETE\n\n');
    end
catch
    fprintf('ERROR\n\n');
    warning('Unable to estimate camera parameters.');
    return
end

% Update list of images used
imageNames = imageNames(imagesUsed);
% Update list of indices used
corIndexes = corIndexes(imagesUsed);
% Images used
fprintf('%40s: %4d\n','Images used in calibration',numel(corIndexes));

% Update P_m
P_m = P_m(:,:,imagesUsed);

% View reprojection errors
reproj.Figure = figure('Name','Reprojection Errors','NumberTitle','off');
showReprojectionErrors(camParams);
reproj.Axes   = findobj('Parent',reproj.Figure,'Type','Axes');
reproj.Legend = findobj('Parent',reproj.Figure,'Type','Legend');
reproj.Bar  = findobj('Parent',reproj.Axes,'Type','Bar','Tag','errorBars');
reproj.Line = findobj('Parent',reproj.Axes,'Type','Line');

% Visualize pattern locations
extrin.Figure = figure('Name','Camera Extrinsics','NumberTitle','off');
showExtrinsics(camParams,'CameraCentric'); 

% Display parameter estimation errors
%displayErrors(estimationErrors, camParams);

% For example, you can use the calibration data to remove effects of lens distortion.
%undistortedImage = undistortImage(originalImage, camParams);

% See additional examples of how to use the calibration data.  At the prompt type:
% showdemo('MeasuringPlanarObjectsExample')
% showdemo('StructureFromMotionExample')

%% Package camera parameters and intrinsics into output struct
% Package intrinsics
switch lensType
    case 'standard'
        A_c2m = camParams.IntrinsicMatrix.';
    case 'fisheye'
        fprintf('\n!!! Fisheye Model Selected !!!\n\n')
        fprintf('Fisheye camera model does not provide an intrinsic matrix!\n')
        fprintf('\tTo project points onto the image, use:\n');
        fprintf('\t\timagePoints = worldToImage(camParams.Intrinsics,H_o2c(1:3,1:3).'',H_o2c(1:3,4).'',P_o(1:3,:).'')\n')
        A_c2m = [];
end

%% Parse transformations
for i = 1:numel(corIndexes)
    H_f2c{i} = [...
        camParams.RotationMatrices(:,:,i).', ...
        camParams.TranslationVectors(i,:).';...
        0,0,0,1];
end

%% Package outputs
info.imageNames = imageNames;
info.squareSize = squareSize;
info.boardSize  = boardSize;

outTMP = {A_c2m,H_f2c,corIndexes,camParams,info};
for i = 1:nargout
    varargout{i} = outTMP{i};
end