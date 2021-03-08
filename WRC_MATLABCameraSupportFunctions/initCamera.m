function [cam,varargout] = initCamera
% INITCAMERA initializes a video input object and, if applicable, opens a
% preview.
%
%   [cam,prv] = INITCAMERA returns both the camera object and the preview
%   handle. Note that "prv" can be used to get images faster than
%   getsnapshot.m using:
%       -> im = get(prv,'CData');
%
%   [cam,prv,pHandles] = INITCAMERA returns the camera object, the preview
%   handle, and a structured array containing all handles contained in the
%   preview figure. The structured array pHandles contains the following:
%       pHandles.Figure - Figure handle that contains the preview
%       pHandles.Axes   - Axes handle that contains the preview
%       pHandles.Image  - Image handle that *is* the preview
%       pHandles.Text.*
%           .TriggerInfo     - Text handle that contains trigger info
%           .FramesPerSecond - Text handle that contains frames per second
%           .Resolution      - Text handle that contains resolution info
%           .Time            - Text handle that contains the time stamp
%
%   cam = INITCAMERA returns the camera object. This is required for using
%   getsnapshot.m:
%       -> im = getsnapshot(cam);
%
%   NOTE: This requires an installed version of the "Image Acquisition
%       Toolbox" and the "Image Acquisition Toolbox Support Package for OS
%       Generic Video Interface"
%       >> supportPackageInstaller
%           -> select "Install from Internet"
%           -> select “OS Generic Video Interface”
%           -> login to mathworks using email and password
%           -> Install
%
%   M. Kutzer, 02Mar2016, USNA

% Updates
%   18Jan2017 - Updated documentation
%   08Jan2019 - Updated documentation
%   02Apr2019 - Updated to assign frame rate
%   19Nov2019 - Updated to use imaqreset and check preview
%   28Jan2020 - Updated to check for a single output (MIDN C.J. Witte)
%   28Jan2020 - Updated documentation for handles output
%   28Jan2020 - Added callback function to preview
%   08Mar2021 - Turned warnings off/on around imaqhwinfo call

%% Declare persistent variable to declare new camera names
% TODO - remove persistent and replace with device selection
persistent callNum

if isempty(callNum)
    callNum = 1;
end

%% Check for installed adapters
goodAdaptor = false;
warning off
info = imaqhwinfo;
warning on
for i = 1:numel(info.InstalledAdaptors)
    switch lower(info.InstalledAdaptors{i})
        case 'winvideo'
            goodAdaptor = true;
            break
    end
end

if ~goodAdaptor
    error('initCam:BadAdaptor',...
        ['The "winvideo" adaptor is not detected.\n',...
        ' -> Run "supportPackageInstaller"\n',...
        ' -> Select and install "OS Generic Video Interface".\n',...
        '\n',...
        '    NOTE: This requires the Image Acquisition Toolbox\n'])
end

%% Check for cameras
devices = imaqhwinfo('winvideo');
if isempty(devices.DeviceIDs)
    fprintf(' -> Trying "imaqreset"\n');
    imaqreset;
    devices = imaqhwinfo('winvideo');
    if isempty(devices.DeviceIDs)
        error('initCam:NoCamera',...
            ['No connected camera found.\n',...
            ' -> Check to confirm that your camera is\n',...
            '    connected (e.g. use "Device Manager").\n']);
    end
end

n = numel(devices.DeviceIDs);
if n > 1
    for i = 1:n
        camList{i} = devices.DeviceInfo(i).DeviceName;
    end
    [camIdx,OK] = listdlg('PromptString','Select camera:',...
        'SelectionMode','single',...
        'ListString',camList);
    if ~OK
        error('No camera selected.');
    end
else
    camIdx = 1;
end

%% Check if the selected device is already initialized and in use
% NOTE: This recovers a previously initialized video input object with an
%       ID matching the ID selected by the user (or set as the default)
vids = imaqfind;
m = size(vids,2);
if m > 0
    for i = 1:m
        switch lower(vids(i).Type)
            case 'videoinput'
                if vids(i).DeviceID == camIdx
                    % Selected device already exists and is initialized
                    % -> Get existing object
                    cam = vids(i);
                    % -> Check if no preview is required
                    if nargout == 1
                        return
                    end
                    % -> Check to see if preview is working
                    vOut = packageVarOut(cam,3);
                    drawnow;
                    switch lower( get(vOut{2}.Text.Time,'String') )
                        case lower('Time Stamp')
                            fprintf(...
                                ['Preview is not working.\n',...
                                 '-> Trying "imaqreset"\n']);
                            imaqreset;
                            [cam,varargout] = initCamera;
                        otherwise
                            varargout = vOut(1:(nargout-1));
                    end
                    return
                end
        end
    end
end

%% Check for available formats
formatIDX = 1; % Use default format if good one is unavailable
m = numel(devices.DeviceInfo(camIdx).SupportedFormats);
for i = 1:m
    switch devices.DeviceInfo(camIdx).SupportedFormats{i}
        case 'YUY2_640x480'
            formatIDX = i;
            break
    end
end

%% Create video input object
cam = videoinput('winvideo',camIdx,...
    devices.DeviceInfo(camIdx).SupportedFormats{formatIDX});

%% Setup camera parameters
set(cam,'ReturnedColorSpace','rgb');
set(cam,'Name',sprintf('camera%d',callNum));
callNum = callNum + 1;

%% Update camera properties
src_obj = getselectedsource(cam);
try
    set(src_obj, 'ExposureMode', 'manual');
    set(src_obj, 'Exposure', -4);
    set(src_obj, 'FrameRate', '15.0000');
catch
    warning('Unable to set "ExposureMode" to manual.');
end

%% Start camera and create preview
triggerconfig(cam,'manual');
start(cam);
varargout = packageVarOut(cam,nargout);
end

%% Embedded function(s)

% Package varargout
function vOut = packageVarOut(cam,nOut)
vOut = {};
if nOut == 0
    return;
end

if nOut > 1
    % Initialize preview
    prv = preview(cam);
    vOut{1} = prv;
    
    % Parse preview handles 
    % Image object
    img = prv;
    % Axes object
    axs = get(img,'Parent');
    % Scroll panel object
    scrlPanel = get(axs,'Parent');
    % Panel object (containing preview image)
    imagPanel = get(scrlPanel,'Parent');
    % Figure object
    fig = get(imagPanel,'Parent');
    
    % Set useful properties of axes object
    set(axs,'Visible','on');
    hold(axs,'on');
    xlabel(axs,'x (pixels)');
    ylabel(axs,'y (pixels)');
    
    % Update tags
    set(fig,'Tag','Camera Preview: Figure Object');
    set(axs,'Tag','Camera Preview: Axes Object');
    set(prv,'Tag','Camera Preview: Image Object');
    
    % Update figure name and close request function
    name = get(fig,'Name');
    name = sprintf('USNA WRC %s',name);
    set(fig,'Name',name,'CloseRequestFcn',{@previewCloseCallback,cam,prv,axs});
end

if nOut > 2
    % Get children of the preview object
    kids = get(fig,'Children');
    % Panel object (containing preview info)
    infoPanel = kids(2);
    kids = get(infoPanel,'Children');
    % Preview info text objects
    txtTrg = get(kids(1),'Children');
    txtFPS = get(kids(2),'Children');
    txtRes = get(kids(3),'Children');
    txtTime = get(kids(4),'Children');
    
    % Package output
    out.Figure = fig;
    out.Axes   = axs;
    out.Image  = img;
    out.Text.TriggerInfo = txtTrg;
    out.Text.FramesPerSecond = txtFPS;
    out.Text.Resolution = txtRes;
    out.Text.Time = txtTime;
    
    vOut{2} = out;
end

end

% Close preview callback
function previewCloseCallback(src,event,cam,prv,axs)

out = questdlg(...
    'Are you sure you want to close this preview? Closing will delete the preview object.',...
    'Close Preview',...
    'Yes','No','Recover Handles','No');

switch out
    case 'Yes'
        closepreview(cam);
    case 'No'
        % Bring preview figure to front
        figure(src);
    case 'Recover Handles'
        % Bring preview figure to front
        figure(src);
        
        % Get any/all objects added to the axes
        kids = get(axs,'Children');
        bin = false(size(kids));
        for i = 1:numel(kids)
            switch get(kids(i),'Tag')
                case 'Camera Preview: Image Object'
                    % Preview object
                    bin(i) = true;
                otherwise
                    % Miscellaneous "added" object
            end
        end
        % Remove preview object
        kids(bin) = [];
        
        % Assign values to the base workspace
        assignin('base','cam',cam);
        assignin('base','prv',prv);
        assignin('base','misc',kids);
        % Notify the user
        fprintf(...
            ['The following variables have been added/updated in your base workspace:\n',...
            '\t "cam" - webcam object handle,\n',...
            '\t "prv" - preview image object handle, and\n',...
            '\t"misc" - any objects that have been added as children of the preview axes handle.\n']);
    otherwise
        fprintf(2,'Action cancelled.\n');
        % Bring preview figure to front
        figure(src);
end

end