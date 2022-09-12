function varargout = cameraCalibrateCorrespondence(pName,varargin)
% CAMERACALIBRATECORRESPONDENCE runs MATLAB camera calibration tools
% returning information to establish a correspondence with other data
% set(s).
%   [A_c2m,H_f2c,corIndexes,camParams,info] =...
%                                     cameraCalibrateCorrespondence(pName)
%
%   [...] = cameraCalibrateCorrespondence(___,squareSize)
%
%   [...] = cameraCalibrateCorrespondence(___,lensType)
%
%   Input(s)
%       fname      - [OPTIONAL] string defining folder path containing m
%                    calibration images
%       squareSize - [OPTIONAL] positive scalar value defining square size 
%                    in millimeters
%       lensType   - [OPTIONAL] string argument defining lens type
%                    {'standard','fisheye'}
%
%   Output(s)
%       A_c2m      - 3x3 array defining camera intrinsics
%       H_f2c      - n-element cell array containing extrinsics
%       corIndexes - m-element index array noting image index for 
%                      defining correspondence
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
squareSize = [];
lensType   = [];

%% Check input(s)
narginchk(0,3);

if nargin < 1
    pName = uigetdir;
end

for i = 1:numel(varargin)
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

    warning('Ignoring input %d.',i+1);
end

%% Get supported image formats
imExts = {};
imExtStruct = imformats;
for i = 1:numel(imExtStruct)
    imExt = imExtStruct(i).ext;
    for j = 1:numel(imExt)
        imExts{end+1} = imExt{j};
    end
end

%% Get folder contents & identify images
D = dir(pName);
idx = find(~[D.isdir]);
tfImage = false(1,numel(idx));
for i = 1:numel(idx)
    [~,bName{i},fExt{i}] = fileparts( D( idx(i) ).name );
    tfImage(i) = nnz( matches(imExts,fExt{i}(2:end)) ) > 0;
end

%% Isolate images
bName = bName(tfImage);
fExt = fExt(tfImage);

% Display available image formats
u_fExt = unique(fExt);
for i = 1:numel(u_fExt)
    n_fExt(i) = nnz( matches(fExt,u_fExt{i}) );
    fprintf('*%s - %d found.\n',u_fExt{i},n_fExt(i));
end

% Select most prevalent format
% TODO - prompt user?
[~,idx] = max(n_fExt);
tfFormat = matches(fExt,u_fExt{idx});

bName = bName(tfFormat);
fExt  =  fExt(tfFormat);

% Keep the unique image format
fExt = fExt{1};

%% Isolate base names from image numbers
n = numel(bName);
baseName   =  cell(1,n);
imgNumStr  =  cell(1,n);
imgNum     = zeros(1,n);
nNumStr    = zeros(1,n);
tfNumbered = false(1,n);
for i = 1:n
    splitStr = regexp(bName{i},'\_','split');
    switch numel(splitStr)
        case 2
            baseName{i}   = splitStr{1};
            imgNumStr{i}  = splitStr{2};
            imgNum(i)     = str2double(imgNumStr{i});
            nNumStr(i)    = numel(imgNumStr{i});
            tfNumbered(i) = true;
        otherwise
            fprintf('Ignoring %s%s - Bad Format.\n',bName{i},fExt);
    end
end

baseName  =  baseName(tfNumbered);
imgNumStr = imgNumStr(tfNumbered);
imgNum    =    imgNum(tfNumbered);

% Find unique base names
u_baseName = unique(baseName);
for i = 1:numel(u_baseName)
    n_baseName(i) = nnz( matches(baseName,u_baseName{i}) );
    fprintf('%s_*%s - %d found.\n',u_baseName{i},fExt,n_baseName(i));
end

% Select most prevalent baseName
% TODO - prompt user?
[~,idx] = max(n_baseName);
tfbaseName = matches(baseName,u_baseName{idx});

baseName  =  baseName(tfbaseName);
imgNumStr = imgNumStr(tfbaseName);
imgNum    =    imgNum(tfbaseName);
nNumStr   =   nNumStr(tfbaseName);

% Keep the uniqe base name
baseName = baseName{1};

% TODO - check nNumStr for consistency

% Sort images
[~,idx] = sort(imgNum);

%baseName  =  baseName(idx);
imgNumStr = imgNumStr(idx);
imgNum    =    imgNum(idx);
nNumStr   =   nNumStr(idx);

%% Define image names
if imgNum(1) == 0
    i0 = 0;
else
    i0 = 1;
end
i1 = imgNum(end);

imageNames  = {};
corIndexes  = [];
indexVals = i0:i1;
for i = 1:numel(indexVals)
    % Check if index is included
    tfImage = imgNum == indexVals(i);
    switch nnz(tfImage)
        case 1
            %fmtStr = sprintf('0%d',nNumStr(tfImage));
            imageName = sprintf('%s_%s%s',baseName,imgNumStr{tfImage},fExt);
            imageNames{end+1} = fullfile(pName,imageName);
            corIndexes(end+1) = i;

            fprintf('\t%s - Correspondence Index %d\n',imageName,corIndexes(i));
        case 0
            % No image exists
        otherwise
            % Multiple images exist
    end
end

fprintf('%d candidate correspondence images.\n',numel(imageNames));

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
        fprintf('\tUse imagePoints = worldToImage(cal.camParams.Intrinsics,H_o2c(1:3,1:3).'',H_o2c(1:3,4).'',P_o(1:3,:).'')\n')
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