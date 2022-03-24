function cal = calibrateUR3e_FixedCamera(pname,bname,fnameRobotInfo)
% CALIBRATEUR3E_FIXEDCAMERA calibrates a UR3e given a series of
% checkerboard images and associated end-effector poses of the robot.
%   cal = CALIBRATEUR3E_FIXEDCAMERA(pname,bname,fnameRobotInfo)
%
%   Input(s)
%                pname - character array containing the folder name (aka
%                        the path) containing the calibration images and robot pose data file
%                bname - base filename for each image
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

%% Check inputs
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
%   pname          - [REDUNTANT, NOT LOADED]
%   bname          - [REDUNDANT, NOT LOADED]
%   fnameRobotInfo - [REDUNDANT, NOT LOADED]
%   H_e2o          - N-element cell array containing end-effector pose
%                    information relative to the robot base frame for each
%                    of the N images used in calibration
%   q              - 6xN array containing robot joint configurations
%                    for each of the N images used in calibration

load( fullfile(pname,fnameRobotInfo),'H_e2o','q' );
if ~exist('bname','var')
    load( fullfile(pname,fnameRobotInfo),'bname' );
end

if ~exist('bname','var')
    [bname,~] = uigetfile({'*.png'},'Select one calibration image',pname);
    if pname == 0
        warning('Action cancelled by user.');
        cal = [];
        return
    end
    % TODO - make this more robust!
    bname = bname(1:end-8);
end

%% Determine calibration image filenames
% (1) Check image names starting with 1, and stop after the filename is no
%     longer valid.
% (2) Combine all images into a single cell array named "fnames"
i = 0;
while true
    % This assumes image numbering is sequential
    i = i+1;
    fname = fullfile(pname,sprintf('%s_%03d.png',bname,i));
    if exist(fname,'file') == 2
        fnames{i} = fname;
    else
        break
    end
end
i = i - 1;
fprintf('Images found: %d\n',i);

% Define an array of all index values to use for image/pose correspondence
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
    [1,35],{'12.70'});
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
h1 = figure('Name','Reprojection Errors'); showReprojectionErrors(cameraParams);

% Visualize pattern locations
h2 = figure('Name','Camera Extrinsics'); showExtrinsics(cameraParams, 'CameraCentric');

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

%% Define extrinsic and forward kinematic correspondences
% This uses the index values of images accepted in calibration to define
% pairs between extrinsics and forward kinematics (and joint
% configurations)
for i = 1:numel(idx)
    % Camera extrinsics ("grid" frame relative to camera frame)
    cal.H_g2c{i} = [...
        cameraParams.RotationMatrices(:,:,i).', ...
        cameraParams.TranslationVectors(i,:).';...
        0,0,0,1];
    % Forward kinematics (end-effector frame relative to base frame)
    cal.H_e2o{i} = H_e2o{idx(i)};
    % Joint configuration
    %   -> We aren't actually using this
    cal.q(:,i) = q(:,idx(i));
end

%% Display calibration results
% Define grid-referenced points
X_g = P_g.';
X_g(3,:) = 0;
X_g(4,:) = 1;
for i = 1:numel(cal.H_g2c)
    % Create figure and axes
    fig(i) = figure('Name',sprintf('Image %02d',i),'Tag',sprintf('%d',i));
    axs(i) = axes('Parent',fig(i));
    % Load image
    im = imread(fnames{i});
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

fprintf('Remaining Images:\n');
for i = 1:numel(fig)
    figName = get(fig(i),'Name');
    [~,fileName,ext] = fileparts(fnames{i});
    fprintf('\tFigure "%s", Image filename "%s%s"\n',figName,fileName,ext);
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
cal.H_c2o = meanSE(H_c2o,1);
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