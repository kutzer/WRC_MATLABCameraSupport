%% SCRIPT_CalibrateUR3e_FixedCamera
% This script initializes a camera and the UR3e robot, then prompts the
% user to take a series of images of a checkerboard held tightly in the
% gripper of the robot.
%
%   M. Kutzer, 19Apr2021, USNA

% Updates
%   10Mar2022 - Allow user to specify robot connection
%   13Apr2022 - Added user cancel options
%   13Apr2022 - Allow user to collect hand-held fiducial images and 
%               end-effector fixed fiducial images

%clear all
close all
clc

%% Define the folder name for calibration data
% This will store the images and variables saved from calibration
pname = 'FixedCameraImages';

%% Initialize camera
while true
    rsp = questdlg('Is your fixed camera currently initialized?',...
        'Existing Camera','Yes','No','Cancel','No');

    switch rsp
        case 'Yes'
            % Get current list of variables in workspace
            list = who;

            % Find existing camera object with typical variable name
            bin = matches(list,'cam','IgnoreCase',false);
            if nnz(bin) == 0
                bin = matches(list,'cam','IgnoreCase',true);
            end
            if nnz(bin) ~= 0
                idx = find(bin,1,'first');
            else
                idx = 1;
            end

            % Ask user to specify their camera object
            [idx,tf] = listdlg('ListString',list,'SelectionMode','single',...
                'InitialValue',idx,'PromptString',...
                {'Select your existing','"camera" object handle',...
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

        case 'Cancel'
            % Action cancelled by user
            fprintf('Action cancelled by user\n');
            return

        otherwise
            warning('Please select a valid response.');
    end
end

%% Initialize robot
while true
    rsp = questdlg('Is your URQt object initialized?',...
        'Existing URQt','Yes','No','Cancel','No');

    switch rsp
        case 'Yes'
            % Get current list of variables in workspace
            list = who;

            % Find existing URQt object with typical variable name
            bin = matches(list,'ur','IgnoreCase',false);
            if nnz(bin) == 0
                bin = matches(list,'ur','IgnoreCase',true);
            end
            if nnz(bin) ~= 0
                idx = find(bin,1,'first');
            else
                idx = 1;
            end

            % Ask user to specify their URQt object
            [idx,tf] = listdlg('ListString',list,'SelectionMode','single',...
                'InitialValue',idx,'PromptString',...
                {'Select your existing','"URQt" object handle',...
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

        case 'Cancel'
            % Action cancelled by user
            fprintf('Action cancelled by user\n');
            return

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
if ~isfolder(pname)
    mkdir(pname);
end

% Define the "base" image name (these use the date/time to make sure we
% differentiate between calibration sessions.
%   Example Image Name: 'Im_20210419_092301_001.png'
%       -> The "base" image name is 'Im_20210419_092301'
dstr = datestr(now,'yyyymmdd_HHMMSS');
bname_h = sprintf('Im_h_%s',dstr);  % Images of handheld checkerboard
bname_f = sprintf('Im_f_%s',dstr);  % Images of fixed checkerboard

% Define the image format (fmt) and total number of calibration images
fmt = 'png';

%% Take handheld calibration images
% Prompt user for number of calibration images
nImages = inputdlg({'Enter number of handheld calibration images'},...
    'Handheld Calibration Images',[1,35],{'20'});
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

%% Take end-effector fixed checkerboard calibration images

%% Put checkerboard in gripper
ur.GripSpeed = 255;
ur.GripForce = 255;
ur.GripPosition = 18;
f = msgbox('Hold checkerboard in gripper.','Grip Checkerboard');
uiwait(f);
ur.GripPosition = 52;

%% Place robot in local control and take images
f = msgbox('Set robot to local control.','Local Control');
uiwait(f);

% Prompt user for number of calibration images
nImages = inputdlg({'Enter number of end-effector fixed calibration images'},...
    'Robot/Camera Calibration Images',[1,35],{'15'});
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
        'position with the checkerboard fully in the camera FOV. ',...
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
    'q','H_e2o','pname','bname_h','bname_f','fnameRobotInfo','pname');

%% Calibrate camera position
cal = calibrateUR3e_FixedCamera(pname,bname_h,bname_f,fnameRobotInfo);

%% Visualize camera
H_o2a = sim.Frame0;
H_c2a = H_o2a*cal.H_c2o;
sc = 50;
cam3D = plotCamera('Parent',sim.Axes,'Location',H_c2a(1:3,4).',...
    'Orientation',H_c2a(1:3,1:3).','Size',sc/2,'Color',[0,0,1]);
h_c2a = triad('Parent',sim.Axes,'Matrix',H_c2a,'Scale',sc,...
    'AxisLabels',{'x_c','y_c','z_c'},'LineWidth',2);
set(sim.Axes,'Visible','on');
axis(sim.Axes,'tight');

%% Save calibration
fname = sprintf('UR3eFixedCamera_%s.mat',dstr);
save(fname,'cal');