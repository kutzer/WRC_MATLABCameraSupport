%% SCRIPT_CalibrateUR3e_EyeInHandCamera
% This script initializes a camera and the UR3e robot, then prompts the
% user to take a series of images of a checkerboard under two conditions:
%   (1) Freely moved by the user for typical camera calibration
%   (2) Placed in a fixed location relative to the UR3e base frame
%
%   M. Kutzer, 24Mar2022, USNA

% Updates

%clear all
close all
clc

%% Define the folder name for calibration data
% This will store the images and variables saved from calibration
pname = 'EyeInHandCameraImages';

%% Initialize camera
while true
    rsp = questdlg('Is your eye-in-hand camera currently initialized?','Existing Camera','Yes','No','No');

    switch rsp
        case 'Yes'
            % Get current list of variables in workspace
            list = who;
            % Ask user to specify their camera object
            [idx,tf] = listdlg('ListString',list,'SelectionMode','single',...
                'PromptString',{'Select your existing','"camera" object handle',...
                '(typically "cam" is used as','the variable name)'});

            if tf
                cam = eval(sprintf('%s'),list{idx});
                prv = preview(cam);
                handles = recoverPreviewHandles(prv);
                break
            end

        case 'No'
            % Initialize camera
            [cam,prv,handles] = initCamera;
            break
        otherwise
            warning('Please select a valid response.');
    end
end

%% Initialize robot
while true
    rsp = questdlg('Is your URQt object initialized?','Existing URQt','Yes','No','No');

    switch rsp
        case 'Yes'
            % Get current list of variables in workspace
            list = who;
            % Ask user to specify their URQt object
            [idx,tf] = listdlg('ListString',list,'SelectionMode','single',...
                'PromptString',{'Select your existing','"URQt" object handle',...
                '(typically "ur" is used as','the variable name)'});
            if tf
                ur = eval(sprintf('%s'),list{idx});
                break
            end
        case 'No'
            f = msgbox('Power on UR3e and press OK when complete.','Power on robot');
            uiwait(f);
            ur = URQt('UR3e');
            ur.Initialize;
            break
        otherwise
            warning('Please select a valid response.');
    end

end

%% Initialize simulation
ur.FlushBuffer;

sim = URsim;
sim.Initialize('UR3');
hFrames = {...
    'hFrame0','hFrame1','hFrame2','hFrame3',...
    'hFrame4','hFrame5','hFrame6','hFrameE','hFrameT'};
for i = 1:numel(hFrames)
    hideTriad(sim.(hFrames{i}));
end
view(sim.Axes,[85,50]);
set(sim.Axes,'Visible','off');
set(sim.Figure,'Color',[1 1 1]);
sim.Joints = ur.Joints;

%% Setup calibration data folder & image information
% Create the calibration folder
if ~isfolder(pname)
    mkdir(pname);
end

% Define the "base" image names (these use the date/time to make sure we
% differentiate between calibration sessions)
%   Example Image Name: 'Im_20210419_092301_001.png'
%       -> The "base" image name is 'Im_20210419_092301'
dstr = datestr(now,'yyyymmdd_HHMMSS');
bname_h = sprintf('Im_h_%s',dstr);  % Images of handheld checkerboard
bname_f = sprintf('Im_f_%s',dstr);  % Images of fixed checkerboard

% Define the image format (fmt) and total number of calibration images
fmt = 'png';

%% Take handheld calibration images
% Prompt user for number of calibration images
nImages = inputdlg({'Enter number of standard calibration images'},...
    'Standard Calibration Images',[1,35],{'20'});
if numel(nImages) == 0
    warning('Action cancelled by user.');
    cal = [];
    return
end
n = ceil( str2double( nImages{1} ) );

% Get standard calibration images
for i = 1:n
    % Define filename of image
    fname = sprintf('%s_%03d.%s',bname_h,i,fmt);
    % Bring preview to foreground
    figure(handles.Figure);
    % Prompt user to move arm
    msg = sprintf(['Move the checkerboard to a new pose that is ',...
        'fully in the camera FOV avoiding poses with glare.',...
        'Taking Image %d of %d.'],i,n);
    f = msgbox(msg,'Get Handheld Image');
    uiwait(f);
   
    % Get the image from the preview
    im = get(prv,'CData');
    % Save the image
    imwrite(im,fullfile(pname,fname),fmt);
end

%% Take fixed checkerboard calibration images
% Place robot in local control and take images
f = msgbox('Set robot to local control.','Local Control');
uiwait(f);

% Prompt user to place the checkerboard in a fixed location
% -> Fixed *relative* to the UR base frame
msg = sprintf([...
    'Place the checkerboard in a fixed location relative to the robot',...
    'base frame.\n\n',...
    'Your placement must satisfy the following:\n',...
    '  (1) The checkerboard will not move during data acquisition\n',...
    '  (2) The checkerboard should be entirely visible in the camera FOV\n',...
    '    (a) from multiple, unique poses of the UR\n',...
    '    (b) with minimal glare.']);
f = msgbox(msg,'Place Checkerboard');
uiwait(f);

% Prompt user for number of calibration images
nImages = inputdlg({'Enter number of fixed calibration images'},...
    'Fixed Calibration Images',[1,35],{'10'});
if numel(nImages) == 0
    warning('Action cancelled by user.');
    cal = [];
    return
end
n = ceil( str2double( nImages{1} ) );

% Initialize joint positions
q = [];     % <--- We are not actually using this for calibration
H_e2o = {}; % <--- We are using this for calibration
for i = 1:n
    % Define filename of image
    fname = sprintf('%s_%03d.%s',bname_f,i,fmt);
    % Bring preview to foreground
    figure(handles.Figure);
    % Prompt user to move arm
    msg = sprintf(['Use the "Teach" button to move the arm to a new ',...
        'pose with the checkerboard fully in the camera FOV. ',...
        'Taking Image %d of %d.'],i,n);
    f = msgbox(msg,'Position for Image');
    uiwait(f);

    % Get the image from the preview
    im = get(prv,'CData');
    % Get the joint configuration from the robot
    q(:,end+1) = ur.Joints;
    % Update simulation
    sim.Joints = q(:,end);
    % Get the end-effector pose from the robot
    H_e2o{end+1} = ur.Pose;
    % Save the image
    imwrite(im,fullfile(pname,fname),fmt);
end

%% Save calibration dataset
% Define the filename for the robot data
fnameRobotInfo = sprintf('URInfo_%s.mat',dstr);
save(fullfile(pname,fnameRobotInfo),...
    'q','H_e2o','pname','bname_h','bname_f','fnameRobotInfo');

%% Calibrate camera position
cal = calibrateUR3e_EyeInHandCamera(pname,bname_h,bname_f,fnameRobotInfo);

%% Visualize camera
H_e2o = sim.Pose;
H_o2a = sim.Frame0;
H_c2e = cal.H_c2e;
H_c2a = H_o2a*H_e2o*H_c2e;
sc = 50;
cam3D = plotCamera('Parent',sim.Axes,'Location',H_c2a(1:3,4).',...
    'Orientation',H_c2a(1:3,1:3).','Size',sc/2,'Color',[0,0,1]);
h_c2a = triad('Parent',sim.hFrameE,'Matrix',H_c2e,'Scale',sc,...
    'AxisLabels',{'x_c','y_c','z_c'},'LineWidth',2);
set(sim.Axes,'Visible','on');
axis(sim.Axes,'tight');

%% Save calibration
fname = sprintf('UR3eEyeInHandCamera_%s.mat',dstr);
save(fname,'cal');