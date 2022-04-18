function out = processRobotCameraCalibration(pname,bname_h,bname_f,fnameRobotInfo)
% PROCESSROBOTCAMERACALIBRATION
%   out = processRobotCameraCalibration(pname,bname_h,bname_f,fnameRobotInfo)
%
%   Input(s)
%                pname - character array containing the folder name (aka
%                        the path) containing the calibration images and 
%                        robot pose data file
%              bname_h - base filename for each handheld image
%              bname_f - base filename for each robot/camera image
%       fnameRobotInfo - filename containing the robot pose data
%
%   Output(s)
%       out - structured array packaging all variables used (this is a
%             quick and lazy approach and should be updated)
%
%   See also calibrateUR3e_FixedCamera calibrateUR3e_EyeInHandCamera
%
%   M. Kutzer, 14Apr2022, USNA

% Updates
%               18
%% Check inputs
if nargin == 3
    % Legacy Compatibility
    fnameRobotInfo = bname_f;
    bname_f = bname_h;
    bname_h = [];
end

if nargin < 3
    [fnameRobotInfo,pname] = uigetfile({'*.mat'},'Select calibration data file (e.g. URInfo_*.mat)');
    if pname == 0
        warning('Action cancelled by user.');
        out = [];
        return
    end
end

%% Load saved robot data
% This file contains:
%   bname_h        - [POTENTIALLY REDUNDANT, DEFAULT - NOT LOADED]
%   bname_f        - [POTENTIALLY REDUNDANT, DEFAULT - NOT LOADED]
%   fnameRobotInfo - [REDUNDANT, NOT LOADED]
%   pname          - [REDUNTANT, NOT LOADED]
%   H_e2o          - N-element cell array containing end-effector pose
%                    information relative to the robot base frame for each
%                    of the N images used in calibration
%   q              - 6xN array containing robot joint configurations
%                    for each of the N images used in calibration

load( fullfile(pname,fnameRobotInfo),'H_e2o','q' );
if ~exist('bname_h','var')
    % Clear previous warnings
    lastwarn('', '');
    % Attempt to load file
    load( fullfile(pname,fnameRobotInfo),'bname_h' );
    % Check if warning was thrown
    str = lastwarn;
    if isempty(str)
        % Non-legacy file
    else
        % Legacy file
        bname_h = [];
        switch str
            case 'Variable ''bname_h'' not found.'
                % Expected warning
            otherwise
                % Unexpected warning
                fprintf('Unexpected Warning: "%s"\n',str);
        end
    end
end
if ~exist('bname_f','var')
    if ~isempty(bname_h)
        % Non-legacy file
        load( fullfile(pname,fnameRobotInfo),'bname_f' );
        fprintf('\n');
    else
        % Legacy file
        load( fullfile(pname,fnameRobotInfo),'bname' );
        bname_f = bname;
        clearvars bname
        fprintf('[Legacy data set, no handheld images available.]\n\n');
    end
end

%% Allow users to specify file(s) if no base filenames are available
if ~exist('bname_h','var')
    [bname,~] = uigetfile({'*.png'},'Select one handheld checkerboard calibration image',pname);
    if bname == 0
        warning('Action cancelled by user.');
        out = [];
        return
    end
    % TODO - make this more robust!
    bname_h = bname(1:end-8);
end

if ~exist('bname_f','var')
    [bname,~] = uigetfile({'*.png'},'Select one end-effector fixed checkerboard calibration image',pname);
    if bname == 0
        warning('Action cancelled by user.');
        out = [];
        return
    end
    % TODO - make this more robust!
    bname_f = bname(1:end-8);
end

%% Determine calibration image filenames
% (1) Check image names starting with 1, and stop after the filename is no
%     longer valid.
% (2) Combine all images into a single cell array named "fnames"

% Handheld images
i = 0;
while true
    % This assumes image numbering is sequential
    i = i+1;
    fname = fullfile(pname,sprintf('%s_%03d.png',bname_h,i));
    if exist(fname,'file') == 2
        fnames{i} = fname;
    else
        break
    end
end
i = i - 1;

% Fixed images
j = 0;
ij = [];    % Index correspondence
while true
    % This assumes image numbering is sequential
    i = i+1;
    j = j+1;
    ij(end+1,:) = [i,j];
    fname = fullfile(pname,sprintf('%s_%03d.png',bname_f,j));
    if exist(fname,'file') == 2
        fnames{i} = fname;
    else
        break
    end
end
i = i - 1;
j = j - 1;
ij(end,:) = [];

% Rename variables for later use
nImagesTotal    = i;
nImagesRobot    = j;
nImagesHandheld = i-j;
fprintf('%40s: %4d\n','Handheld checkerboard images found',nImagesHandheld);
fprintf('%40s: %4d\n','Robot/Camera checkerboard images found',nImagesRobot);
fprintf('%40s: %4d\n','Total checkerboard images found',nImagesTotal);

% Define an array of all index values to use for image/pose correspondence
%   NOTE: Only images with the basename bname_f are associated with
%         image/pose correspondences
imageIdx = 1:i;  % Indices of all images

%% Process images
% Detect checkerboards in images
%   -> This uses the same functions as "cameraCalibrator.m"
fprintf('\nDetecting checkerboards...');
try
    % NEWER VERSION OF MATLAB
    [P_m, boardSize, imagesUsed] = detectCheckerboardPoints(fnames,...
        'PartialDetections',false);
catch
    % OLDER VERSION OF MATLAB
    [P_m, boardSize, imagesUsed] = detectCheckerboardPoints(fnames);
end
fprintf('COMPLETE\n\n');

% Update list of images used
fnames = fnames(imagesUsed);
% Update list of indices used
imageIdx = imageIdx(imagesUsed);
% Images used
fprintf('%40s: %4d\n','Images with detected checkerboards',numel(imageIdx));

% Read the first image to obtain image size
originalImage = imread(fnames{1});
[mrows, ncols, ~] = size(originalImage);

% Prompt user for Square Size
squareSize = inputdlg({'Enter square size in millimeters'},'SquareSize',...
    [1,35],{'10.00'});
if numel(squareSize) == 0
    warning('Action cancelled by user.');
    out = [];
    return
end
squareSize = str2double( squareSize{1} );

% Generate coordinates of the corners of the squares
%   relative to the "grid frame"
P_g = generateCheckerboardPoints(boardSize, squareSize);

% Prompt user for Camera Model
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

% Calibrate the camera
switch list{listIdx}
    case 'Standard'
        % Standard camera calibration
        fprintf('\nCalibrating using standard camera model...');
        [cameraParams, imagesUsed, estimationErrors] = ...
            estimateCameraParameters(P_m, P_g, ...
            'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
            'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
            'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
            'ImageSize', [mrows, ncols]);
        fprintf('COMPLETE\n\n');
    case 'Fisheye'
        % Fisheye camera calibration
        fprintf('\nCalibrating using fisheye camera model...');
        [cameraParams, imagesUsed, estimationErrors] = ...
            estimateFisheyeParameters(P_m, P_g, ...
            [mrows, ncols], ...
            'EstimateAlignment', true, ...
            'WorldUnits', 'millimeters');
        fprintf('COMPLETE\n\n');
end
% Update list of images used
fnames = fnames(imagesUsed);
% Update list of indices used
imageIdx = imageIdx(imagesUsed);
% Images used
fprintf('%40s: %4d\n','Images used in calibration',numel(imageIdx));

% Update P_m
P_m = P_m(:,:,imagesUsed);

% View reprojection errors
reproj.Figure = figure('Name','Reprojection Errors','NumberTitle','off'); 
showReprojectionErrors(cameraParams);
reproj.Axes   = findobj('Parent',reproj.Figure,'Type','Axes');
reproj.Legend = findobj('Parent',reproj.Figure,'Type','Legend');
reproj.Bar  = findobj('Parent',reproj.Axes,'Type','Bar','Tag','errorBars');
reproj.Line = findobj('Parent',reproj.Axes,'Type','Line');

% Visualize pattern locations
extrin.Figure = figure('Name','Camera Extrinsics','NumberTitle','off'); 
showExtrinsics(cameraParams,'CameraCentric');

% Display parameter estimation errors
%displayErrors(estimationErrors, cameraParams);

% For example, you can use the calibration data to remove effects of lens distortion.
%undistortedImage = undistortImage(originalImage, cameraParams);

% See additional examples of how to use the calibration data.  At the prompt type:
% showdemo('MeasuringPlanarObjectsExample')
% showdemo('StructureFromMotionExample')

%% Package camera parameters and intrinsics into output struct
% Package camera parameters
cal.cameraParams = cameraParams;
% Package intrinsics
switch list{listIdx}
    case 'Standard'
        cal.A_c2m = cameraParams.IntrinsicMatrix.';
    case 'Fisheye'
        fprintf('\n!!! Fisheye Model Selected !!!\n\n')
        fprintf('Fisheye camera model does not provide an intrinsic matrix!\n')
        fprintf('\tUse imagePoints = worldToImage(cal.cameraParams.Intrinsics,H_o2c(1:3,1:3).'',H_o2c(1:3,4).'',P_o(1:3,:).'')\n')
        cal.A_c2m = [];
end

%% Check for negative principal point
if ~isempty(cal.A_c2m)
    principalPoint = cal.A_c2m(1:2,3);
    bin = principalPoint < 0;
    if nnz(bin) > 0
        %   12345678901234567890123456789012345678901234567890123456789012345678901234567890
        str = sprintf(['\n'...
            'Camera calibration for this data set has produced a negative principal point.\n'...
            'The following intrinsics cannot be used:\n\n']);
        val = max(abs(round( reshape(cal.A_c2m,1,[]) )));
        ndig = numel( int2str(val) );
        ndig = ndig+1+3;
        fstr = ['%',sprintf('%d',ndig),'.2f'];
        str = sprintf(['%s',...
            '\tA_c2m = ['],str);

        for i = 1:size(cal.A_c2m,1)
            for j = 1:size(cal.A_c2m,2)
                vstr = sprintf(fstr,cal.A_c2m(i,j));
                if j == 1
                    str = sprintf('%s%s',str,vstr);
                elseif j > 1 && j < size(cal.A_c2m,2)
                    str = sprintf('%s, %s',str,vstr);
                elseif i < size(cal.A_c2m,1)
                    str = sprintf('%s%s]\n\t        [',str,vstr);
                else
                    str = sprintf('%s%s]\n',str,vstr);
                end
            end
        end
        str = sprintf(['%s\n'...
            'Try adding handheld images with larger checkerboard pose variations.\n\n'],str);
        fprintf(2,str);
        
        % Close old figures
        delete([reproj.Figure,extrin.Figure]);

        % Prompt user to add more handheld images
        rsp = questdlg('Would you like to try to add more handheld images?',...
            'Add Images','Yes','No','Yes');
        switch rsp
            case 'Yes'
                % Create handheld file base name if it does not exist
                if isempty(bname_h)
                    bname_h = [bname_f(1:3),'h_',bname_f(4:end)];
                    updateFnameRobotInfo = true;
                else
                    updateFnameRobotInfo = false;
                end
                
                % Add calibration images
                addHandheldImages(pname,bname_h,nImagesHandheld+1);
                
                % Add handheld file base name to calibration file
                if updateFnameRobotInfo
                    save(fullfile(pname,fnameRobotInfo),'bname_h','-append');
                    save(fullfile(pname,fnameRobotInfo),'bname_f','-append');
                end

                % Recursive function call
                out = processRobotCameraCalibration(pname,bname_h,bname_f,fnameRobotInfo);
                return
            otherwise
                out = [];
                fprintf([...
                    'Action cancelled by user\n\n',...
                    'No valid calibration found.\n']);
                return
        end

    end
end

%% Define extrinsic and forward kinematic correspondences
% This uses the index values of images accepted in calibration to define
% pairs between extrinsics and forward kinematics (and joint
% configurations)
calIdx = 0;
robotIdx = [];
handheldIdx = [];
fprintf('\nDefining AX = XB correspondence...\n');
fprintf('\tIgnoring handheld images:\n');
for i = 1:numel(imageIdx)
    % Find image index in i/j index correspondence
    bin = ij(:,1) == imageIdx(i);
    if nnz(bin) ~= 1
        [~,fileName,ext] = fileparts(fnames{i});
        fprintf('\t\tImage filename "%s%s"\n',fileName,ext);
        % Append handheld image index
        handheldIdx(end+1) = i;
        continue
    end

    % Increase calibration index
    calIdx = calIdx + 1;
    % Define fixed checkerboard image index
    j = ij(bin,2);
    
    % Append handheld image index
    robotIdx(calIdx) = i;
    % Calibration image name
    calFnames{calIdx} = fnames{i};
    % Camera extrinsics ("grid" frame relative to camera frame)
    cal.H_g2c{calIdx} = [...
        cameraParams.RotationMatrices(:,:,i).', ...
        cameraParams.TranslationVectors(i,:).';...
        0,0,0,1];
    % Forward kinematics (end-effector frame relative to base frame)
    cal.H_e2o{calIdx} = H_e2o{j};
    % Joint configuration
    %   -> We aren't actually using this
    cal.q(:,calIdx) = q(:,j);
end

% Display "no handheld" 
if isempty(handheldIdx)
    fprintf('\t\tNo handheld images used in calibration\n\n');
else
    fprintf('\n');
end

%% Display calibration results
% Define grid-referenced points
X_g = P_g.';
X_g(3,:) = 0;
X_g(4,:) = 1;
tf_noCheckerboard = false(1,numel(cal.H_g2c));
for i = 1:numel(cal.H_g2c)
    % Create figure and axes
    fig(i) = figure('Name',sprintf('Image %02d',robotIdx(i)),...
        'Tag',sprintf('%d',robotIdx(i)),'NumberTitle','off');
    axs(i) = axes('Parent',fig(i));
    % Load image
    im = imread(calFnames{i});
    % Undistort image
    switch list{listIdx}
        case 'Standard'
            uIm = undistortImage(im, cameraParams);
        case 'Fisheye'
            % Debug code
            assignin('base','cameraParams',cameraParams);
            assignin('base','im',im);
            % Undistort fisheye image & recover virtual pinhole intrinsics
            [uIm,vPinholeIntrinsics] = ...
                undistortFisheyeImage(im, cameraParams.Intrinsics);
    end
    % Display undistorted image
    img(i) = imshow(uIm,'Parent',axs(i));
    axis(axs(i),'tight');
    set(axs(i),'Visible','on');
    hold(axs(i),'on');
    xlabel(axs(i),'x (pixels)');
    ylabel(axs(i),'y (pixels)');
    
    % Define segmented image points
    % - We need to detect board points in the *undistorted* image to match
    %   the error results from cameraCalibrator
    X_m = detectCheckerboardPoints(uIm);
    % - Check & account for partial detections
    badFig = false;
    if nnz(size(P_m(:,:,1)) == size(X_m)) ~= 2
        % Bad data set!
        X_m = nan(size(P_m(:,:,1)));
        badFig = true;
    end
    % - Update P_m for undistorted points
    P_m(:,:,i) = X_m;
    % - Format X_m into a homogeneous pixel coordinate
    X_m = X_m.';
    X_m(3,:) = 1;
    
    % Define extrinsics
    H_g2c_cam = cal.H_g2c{i};
    % Project points
    switch list{listIdx}
        case 'Standard'
            % Define projection
            P_g2m_cam = cal.A_c2m * H_g2c_cam(1:3,:);
            % Project grid-referenced points
            sX_m_cam = P_g2m_cam * X_g;
            X_m_cam = sX_m_cam./sX_m_cam(3,:);
        case 'Fisheye'
            % Project points
            X_m_cam = worldToImage(vPinholeIntrinsics,...
                H_g2c_cam(1:3,1:3).',H_g2c_cam(1:3,4).',X_g(1:3,:).').';
            X_m_cam(3,:) = 1;
    end
    % Compile P_m_cam
    P_m_cam(:,:,i) = X_m_cam(1:2,:).';
    
    % Calculate RMS error
    err = X_m(1:2,:) - X_m_cam(1:2,:);
    err = sum( sqrt(sum(err.^2,1)),2 )/size(err,2);
    ttl(i) = title(axs(i),...
        sprintf('Reprojection RMS Error: %.2f pixels',err));

    % Plot segmented point
    plt_m(i) = plot(axs(i),X_m(1,2:end),X_m(2,2:end),...
        'og','MarkerSize',8,'LineWidth',1.5);
    plt_m0(i) = plot(axs(i),X_m(1,1),X_m(2,1),...
        'sy','MarkerSize',10,'LineWidth',2.0);
    % Plot reprojected points
    plt_m_cam(i) = plot(axs(i),X_m_cam(1,2:end),X_m_cam(2,2:end),...
        '+r','MarkerSize',8,'LineWidth',1.5);
    plt_m0_cam(i) = plot(axs(i),X_m_cam(1,1),X_m_cam(2,1),...
        'xr','MarkerSize',10,'LineWidth',2.0);
    % Plot connections
    con_m_cam(i) = plot(axs(i),...
        reshape([X_m(1,2:end); X_m_cam(1,2:end); nan(1,size(X_m,2)-1)],1,[]),...
        reshape([X_m(2,2:end); X_m_cam(2,2:end); nan(1,size(X_m,2)-1)],1,[]),...
        'r');
    con_m0_cam(i) = plot(axs(i),...
        [X_m(1,1),X_m_cam(1,1)],...
        [X_m(2,1),X_m_cam(2,1)],'r');
    
    % Create legend
    lgnd(i) = legend([plt_m(i),plt_m0(i),plt_m_cam(i),plt_m0_cam(i)],...
        'Detected points',...
        'Checkerboard origin',...
        'Reprojected points (Cam. Ext.)',...
        'Reprojected origin (Cam. Ext.)');
    
    % Adjust axes limits
    xx = [...
        min( [X_m(1,:),X_m_cam(1,:)] ),...
        max( [X_m(1,:),X_m_cam(1,:)] )...
        ] + [-50,50];
    yy = [...
        min( [X_m(2,:),X_m_cam(2,:)] ),...
        max( [X_m(2,:),X_m_cam(2,:)] )...
        ] + [-50,50];
    xx = [max([xx(1),0.5]),min([xx(2),size(im,2)+0.5])];
    yy = [max([yy(1),0.5]),min([yy(2),size(im,1)+0.5])];
    xlim(axs(i),xx);
    ylim(axs(i),yy);
    
    % Automatically remove partial detections
    if badFig
        tf_noCheckerboard(i) = true;
        delete(fig(i));
    else
        centerfig(fig(i));
    end
    drawnow
end

%% Prompt user to close "bad" images
if nnz(tf_noCheckerboard) < numel(tf_noCheckerboard)
    % If images remain, prompt user
    f = msgbox('Close all bad calibration images.','Refine calibration');
    while ishandle(f)
        drawnow
    end
end

%% Define indices to remove
bin = false(1,size(fig,2));
for i = 1:numel(fig)
    if ~ishandle(fig(i))
        bin(1,i) = true;
        if tf_noCheckerboard
            fprintf('Removing Image %3d [Removed automatically: no/partial checkerboard detected in dewarped image]\n',i);
        else
            fprintf('Removing Image %3d [Removed by user]\n',i);
        end
    end
end
fprintf('\n');

% Remove array elements
robotIdx(bin) = [];
P_m(:,:,bin) = [];
P_m_cam(:,:,bin) = [];
cal.H_g2c(:,bin) = [];
cal.H_e2o(:,bin) = [];
cal.q(:,bin) = [];
fnames(:,bin) = [];
fig(:,bin) = [];
axs(:,bin) = [];
img(:,bin) = [];
ttl(:,bin) = [];
plt_m(:,bin) = [];
plt_m0(:,bin) = [];
plt_m_cam(:,bin) = [];
plt_m0_cam(:,bin) = [];
con_m_cam(:,bin) = [];
con_m0_cam(:,bin) = [];
lgnd(:,bin) = [];

fprintf('\tRemaining Images:\n');
if nnz(bin) == numel(bin)
    fprintf('\t\tNo images available for calibration\n');
else
    for i = 1:numel(fig)
        figName = get(fig(i),'Name');
        [~,fileName,ext] = fileparts(fnames{i});
        fprintf('\t\tImage filename "%s%s" (Figure "%s")\n',fileName,ext,figName);
    end
end
fprintf('\n');

%% Package output
% Package all variables in the workspace into one structured array
% TODO - package only the variables needed by the calling function(s)
varInfo = whos;
for i = 1:numel(varInfo)
    out.(varInfo(i).name) = eval( sprintf('%s;',varInfo(i).name) );
end