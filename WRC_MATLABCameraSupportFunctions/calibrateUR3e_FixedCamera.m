function cal = calibrateUR3e_FixedCamera(pname,bname_h,bname_f,fnameRobotInfo)
% CALIBRATEUR3E_FIXEDCAMERA calibrates a UR3e given a series of
% checkerboard images and associated end-effector poses of the robot.
%   cal = calibrateUR3e_FixedCamera(pname,bname_h,bname_f,fnameRobotInfo)
%
%   Legacy syntax:
%   cal = CALIBRATEUR3E_FIXEDCAMERA(pname,bname,fnameRobotInfo)
%
%   Input(s)
%                pname - character array containing the folder name (aka
%                        the path) containing the calibration images and 
%                        robot pose data file
%              bname_h - base filename for each handheld image
%              bname_f - base filename for each world fixed image
%       fnameRobotInfo - filename containing the robot pose data
%
%   Output(s)
%       cal - structured array containing robot/camera transformation
%             information
%           cal.cameraParams
%
%   M. Kutzer, 19Apr2021, USNA

% Updates
%   26Jan2022 - Allow user to manually find data set & dewarp image to
%               match error results with cameraCalibrator
%   31Mar2022 - Account for partial detections
%   13Apr2022 - Added handheld data sets and meanSE ZERO = 1e-8

% TODO - Allow users to select good images from entire calibration set! 
% TODO - Prompt users to close all figures

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
        cal = [];
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
        cal = [];
        return
    end
    % TODO - make this more robust!
    bname_h = bname(1:end-8);
end

if ~exist('bname_f','var')
    [bname,~] = uigetfile({'*.png'},'Select one end-effector fixed checkerboard calibration image',pname);
    if bname == 0
        warning('Action cancelled by user.');
        cal = [];
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
fprintf('Handheld checkerboard images found: %d\n',i);

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
fprintf('World fixed checkerboard images found: %d\n',j);
fprintf('Total checkerboard images found: %d\n',i);

% Rename variables for later use
nImagesTotal = i;
nImagesHandheld = j;
nImagesRobot = i-j;

% Define an array of all index values to use for image/pose correspondence
%   NOTE: Only images with the basename bname_f are associated with
%         image/pose correspondences
idx = 1:i;  % Indices of all images

%% Process images
% Detect checkerboards in images
%   -> This uses the same functions as "cameraCalibrator.m"
fprintf('Detecting checkerboards...')
try
    % NEWER VERSION OF MATLAB
    [P_m, boardSize, imagesUsed] = detectCheckerboardPoints(fnames,...
        'PartialDetections',false);
catch
    % OLDER VERSION OF MATLAB
    [P_m, boardSize, imagesUsed] = detectCheckerboardPoints(fnames);
end
fprintf('COMPLETE\n');

% Update list of images used
fnames = fnames(imagesUsed);
% Update list of indices used
idx = idx(imagesUsed);
% Images used
fprintf('Images with detected checkerboards: %d\n',numel(idx));

% Read the first image to obtain image size
originalImage = imread(fnames{1});
[mrows, ncols, ~] = size(originalImage);

% Prompt user for Square Size
squareSize = inputdlg({'Enter square size in millimeters'},'SquareSize',...
    [1,35],{'10.00'});
if numel(squareSize) == 0
    warning('Action cancelled by user.');
    cal = [];
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
    cal = [];
    return
end

% Calibrate the camera
switch list{listIdx}
    case 'Standard'
        % Standard camera calibration
        fprintf('Calibrating using standard camera model...')
        [cameraParams, imagesUsed, estimationErrors] = ...
            estimateCameraParameters(P_m, P_g, ...
            'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
            'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
            'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
            'ImageSize', [mrows, ncols]);
        fprintf('COMPLETE\n');
    case 'Fisheye'
        % Fisheye camera calibration
        fprintf('Calibrating using fisheye camera model...')
        [cameraParams, imagesUsed, estimationErrors] = ...
            estimateFisheyeParameters(P_m, P_g, ...
            [mrows, ncols], ...
            'EstimateAlignment', true, ...
            'WorldUnits', 'millimeters');
        fprintf('COMPLETE\n');
end
% Update list of images used
fnames = fnames(imagesUsed);
% Update list of indices used
idx = idx(imagesUsed);
% Images used
fprintf('Images used in calibration: %d\n',numel(idx));

% Update P_m
P_m = P_m(:,:,imagesUsed);

% View reprojection errors
reproj.Figure = figure('Name','Reprojection Errors'); 
showReprojectionErrors(cameraParams);
reproj.Axes   = findobj('Parent',reproj.Figure,'Type','Axes');
reproj.Legend = findobj('Parent',reproj.Figure,'Type','Legend');
reproj.Bar  = findobj('Parent',reproj.Axes,'Type','Bar','Tag','errorBars');
reproj.Line = findobj('Parent',reproj.Axes,'Type','Line');

% Visualize pattern locations
extrin.Figure = figure('Name','Camera Extrinsics'); 
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
        fprintf('Fisheye does not provide an intrinsic matrix!\n')
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
        %delete([reproj.Figure,extrin.Figure]);

        % Prompt user to add more handheld images
        rsp = questdlg('Would you like to try to add more handheld images?',...
            'Add Images','Yes','No','Yes');
        switch rsp
            case 'Yes'
                % Add calibration images
                addHandheldImages(pname,bname_h,nImagesHandheld+1);
                % Recursive function call
                cal = calibrateUR3e_FixedCamera(pname,bname_h,bname_f,fnameRobotInfo);
                return
            otherwise
                cal = [];
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
fprintf('\nDefining AX = XB correspondence...\n');
fprintf('\tIgnoring handheld images:\n');
for i = 1:numel(idx)
    % Find image index in i/j index correspondence
    bin = ij(:,1) == idx(i);
    if nnz(bin) ~= 1
        [~,fileName,ext] = fileparts(fnames{i});
        fprintf('\t\tImage filename "%s%s"\n',fileName,ext);
        continue
    end

    % Increase calibration index
    calIdx = calIdx + 1;
    % Define fixed checkerboard image index
    j = ij(bin,2);

    % Calibration image name
    calFnames{calIdx} = fnames{i};
    % Calibration image index
    cal_i(calIdx) = i;
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

%% Display calibration results
% Define grid-referenced points
X_g = P_g.';
X_g(3,:) = 0;
X_g(4,:) = 1;
for i = 1:numel(cal.H_g2c)
    % Create figure and axes
    fig(i) = figure('Name',sprintf('Image %02d',i),'Tag',sprintf('%d',cal_i(i)));
    axs(i) = axes('Parent',fig(i));
    % Load image
    im = imread(calFnames{i});
    % Undistort image
    uIm = undistortImage(im, cameraParams);
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
            X_m_cam = worldToImage(cal.cameraParams.Intrinsics,...
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
        delete(fig(i));
    end
    drawnow
end

%% Prompt user to close "bad" images
f = msgbox('Close all bad calibration images.','Refine calibration');
while ishandle(f)
    drawnow
end

%% Define indices to remove
bin = false(1,size(fig,2));
for i = 1:numel(fig)
    if ~ishandle(fig(i))
        bin(1,i) = true;
        fprintf('Removing Image %d\n',i);
    end
end
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
for i = 1:numel(fig)
    figName = get(fig(i),'Name');
    [~,fileName,ext] = fileparts(fnames{i});
    fprintf('\t\tImage filename "%s%s" (Figure "%s")\n',fileName,ext,figName);
end

%% Define relative camera and end-effector pairs
% This defines all combinations of relative grid poses and relative
% end-effector poses, and compile "A" and "B" terms to solve the "AX = XB"
% calibration problem.

% Define total number of extrinsic and forward kinematic pairs
n = numel(cal.H_g2c);
% Initialize parameters
iter = 0;
A = {};
B = {};
for i = 1:n
    for j = 1:n
        % Define:
        %   pose of grid in image i *relative to*
        %   pose of grid in image j
        cal.H_gi2gj{i,j} = invSE( cal.H_g2c{j} )*cal.H_g2c{i};
        % Define:
        %   end-effector pose for image i *relative to*
        %   end-effector pose for image j
        cal.H_ei2ej{i,j} = invSE( cal.H_e2o{j} )*cal.H_e2o{i};
        
        if i ~= j && i < j
            % Define transformation pairs to solve for H_e2g given:
            %   H_gi2gj * H_ei2gi = H_ej2gj * H_ei2ej
            %       where H_ej2gj = H_ei2gi = H_e2g
            %
            % We can rewrite this as
            %   A * X = X * B, solve for X
            iter = iter+1;
            A{iter} = cal.H_gi2gj{i,j};
            B{iter} = cal.H_ei2ej{i,j};
        end
    end
end
fprintf('Number of A/B pairs: %d\n',numel(A));

%% Solve A * X = X * B
X = solveAXeqXBinSE(A,B);
cal.H_e2g = X;

% Check H_e2g
[tf,msg] = isSE(cal.H_e2g);
if ~tf
    warning(msg);
    %fprintf('\tApplying cal.H_e2g = cal.H_e2g*Sz(-1)\n');
    %cal.H_e2g = cal.H_e2g*Sz(-1);
end

%% Make sure rotation is valid
axang = rotm2axang(cal.H_e2g(1:3,1:3));
R_e2g = axang2rotm(axang);
cal.H_e2g(1:3,1:3) = R_e2g;

%% Populate remaining useful tramsformations
cal.H_g2e = invSE( cal.H_e2g );
for i = 1:n
    H_c2o{i} = cal.H_e2o{i}*cal.H_g2e*invSE( cal.H_g2c{i} );
end
% TODO - investigate decoupled meanSE and/or use AX = XB
cal.H_c2o = meanSE(H_c2o,1,1e-8);
cal.H_o2c = invSE( cal.H_c2o );

%% Visualize base frame estimates and mean
fig3D = figure('Name','Base Frame Estimate');
axs3D = axes('Parent',fig3D);
hold(axs3D,'on');
daspect(axs3D,[1 1 1]);
view(axs3D,3);

H_c2a = cal.H_c2o;
sc = max( abs(H_c2a(1:3,4)) )/10;
cam3D = plotCamera('Parent',axs3D,'Location',H_c2a(1:3,4).',...
    'Orientation',H_c2a(1:3,1:3).','Size',sc/2,'Color',[0,0,1]);
h_c2a = triad('Parent',axs3D,'Matrix',H_c2a,'Scale',sc,...
    'AxisLabels',{'x_c','y_c','z_c'});

for i = 1:numel(cal.H_e2o)
    H_o2c = cal.H_g2c{i}*cal.H_e2g*invSE( cal.H_e2o{i} );
    xyz = 'xyz';
    for j = 1:3
        lbls{j} = sprintf('%s_{o_%d}',xyz(j),i);
    end
    h_o2c(i) = triad('Parent',h_c2a,'Matrix',H_o2c,'Scale',sc);%,...
    %'AxisLabels',{lbls{1},lbls{2},lbls{3}});
end

h_o2c_mu = triad('Parent',h_c2a,'Matrix',cal.H_o2c,'Scale',sc*3,...
    'AxisLabels',{'x_o','y_o','z_o'},'LineWidth',2);

%% Calculate reprojection errors using calculated extrinsics
for i = 1:n
    % Define segmented image points
    X_m = P_m(:,:,i).';
    X_m(3,:) = 1;
    % Define reproject image points (using camera extrinsics)
    X_m_cam = P_m_cam(:,:,i).';
    X_m_cam(3,:) = 1;
    % Define calibrated robot extrinsics
    H_g2c_ext = cal.H_o2c*cal.H_e2o{i}*cal.H_g2e;
    
    % Project points
    switch list{listIdx}
        case 'Standard'
            % Define projection
            P_g2m_ext = cal.A_c2m * H_g2c_ext(1:3,:);
            % Project grid-referenced points
            sX_m_ext = P_g2m_ext * X_g;
            X_m_ext = sX_m_ext./sX_m_ext(3,:);
        case 'Fisheye'
            % Project points
            X_m_ext = worldToImage(cal.cameraParams.Intrinsics,...
                H_g2c_ext(1:3,1:3).',H_g2c_ext(1:3,4).',X_g(1:3,:).').';
            X_m_ext(3,:) = 1;
    end
    
    % Calculate RMS error
    err = X_m_cam(1:2,:) - X_m_ext(1:2,:);
    err = sum( sqrt(sum(err.^2,1)),2 )/size(err,2);
    delete(ttl(i));
    ttl(i) = title(axs(i),...
        sprintf('Reprojection RMS Error: %.2f pixels',err));
    
    % Plot reprojected points
    plt_m_ext(i) = plot(axs(i),X_m_ext(1,2:end),X_m_ext(2,2:end),...
        'xc','MarkerSize',8,'LineWidth',1.5);
    plt_m0_ext(i) = plot(axs(i),X_m_ext(1,1),X_m_ext(2,1),...
        '+c','MarkerSize',10,'LineWidth',2.0);
    % Plot connections
    con_m_ext(i) = plot(axs(i),...
        reshape([X_m_cam(1,2:end); X_m_ext(1,2:end); nan(1,size(X_m_cam,2)-1)],1,[]),...
        reshape([X_m_cam(2,2:end); X_m_ext(2,2:end); nan(1,size(X_m_cam,2)-1)],1,[]),...
        'c');
    con_m0_ext(i) = plot(axs(i),...
        [X_m_cam(1,1),X_m_ext(1,1)],...
        [X_m_cam(2,1),X_m_ext(2,1)],'c');
    
    % Create legend
    delete(lgnd(i))
    lgnd(i) = legend(...
        [plt_m(i),plt_m0(i),plt_m_cam(i),plt_m0_cam(i),...
        plt_m_ext(i),plt_m0_ext(i)],...
        'Detected points',...
        'Checkerboard origin',...
        'Reprojected points (Cam. Ext.)',...
        'Reprojected origin (Cam. Ext.)',...
        'Reprojected points (Rob. Ext.)',...
        'Reprojected origin (Rob. Ext.)');
    
    % Adjust axes limits
    xx = [...
        max([min( [X_m(1,:),X_m_cam(1,:),X_m_ext(1,:)] ),0.5]),...
        min([max( [X_m(1,:),X_m_cam(1,:),X_m_ext(1,:)] ),size(im,2)+0.5])...
        ] + [-50,50];
    yy = [...
        max([min( [X_m(2,:),X_m_cam(2,:),X_m_ext(2,:)] ),0.5]),...
        min([max( [X_m(2,:),X_m_cam(2,:),X_m_ext(2,:)] ),size(im,1)+0.5])...
        ] + [-50,50];
    xx = [max([xx(1),0.5]),min([xx(2),size(im,2)+0.5])];
    yy = [max([yy(1),0.5]),min([yy(2),size(im,1)+0.5])];
    xlim(axs(i),xx);
    ylim(axs(i),yy);
    
    figure(fig(i));
    centerfig(fig(i));
    drawnow
end