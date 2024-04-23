function varargout = adjustCamera(cam,varargin)
% ADJUSTCAMERA allows the user to adjust the settings of a video input
% object using a basic GUI.
%   adjustCamera(cam)
%   camSettings = adjustCamera(cam)
%   ___ = adjustCamera(cam,camSettings)
%   ___ = adjustCamera(cam,camSettings,skipGUI)
%
%   Input(s)
%               cam - video input object
%       camSettings - [OPTIONAL] structured array containing camera 
%                     settings. Note that field names must match the camera
%                     setting property name to be used. Incorrect settings
%                     are ignored.
%           skipGUI - [OPTIONAL] allows the user to adjust the camera using
%                     the camSettings structured array and automatically
%                     close the GUI. 
%
%   Output(s)
%       camSettings - [OPTIONAL] strutured array containing the last set of 
%                     camera settings implemented by the GUI. Note that
%                     specifying an output will block execution until the
%                     GUI is closed using the "Exit" button.
%
%
%   Example 1: Basic use
%       % Initialize camera
%       [init,cam] = initCamera;
%       % Adjust camera parameters
%       adjustCamera(cam);
%
%   Example 2: Saving and re-using parameters
%       % Initialize camera
%       [init,cam] = initCamera;
%       % Adjust camera parameters and get settings used
%       camSettings = adjustCamera(cam);
%       ...
%       % Apply camera settings to camera
%       adjustCamera(cam,camSettings,true);
%
%
%   Recommended steps for adjusting an Imaging Source DFK 21BU04 or 23U618 
%   cameras (or similar) with a mechanical aperture lens using the 
%   adjustCamera GUI:
%       (1) Change ExposureMode and GainMode to "Auto", click "Apply"
%       (2) Fully open the lens aperature (e.g. top ring on lens)
%       (3) Wait for the camera to auto adjust
%       (4) Change ExposureMode to manual and GainMode to manual, click 
%           "Apply"
%       (5) Close the aperature until the image in the preview is a good
%           constrast
%       (6) Adjust focus as necessary
%       (7) Click "Exit"
%
%   See also initCamera
%
%   M. Kutzer, 31Mar2022, USNA

% Updates
%   07Apr2022 - Updated to account for small monitors
%   22Apr2022 - Added example
%   30Nov2023 - Added structured array output for camera settings
%   30Nov2023 - Added user settings input option
%   30Nov2023 - Added bypass GUI option
%   23Apr2024 - Account for non-variable, bounded property value(s)

% TODO - avoid use of global variable for sharing camera settings
global adjustCamera_camSettings

debugON = false;

%% Check input(s)
narginchk(1,3);
switch lower(class(cam))
    case 'videoinput'
        % Input is a video input object
        if ~isvalid(cam)
            error('Video input object is not associated with any hardware, try reinitializing.');
        end
    otherwise
        error('Input must be a valid video input object.');
end

%% Initialize output(s)
camSettings = struct;

%% Show preview
prv = preview(cam);

%% Get device info
device = imaqhwinfo('winvideo',cam.DeviceID);

% List information
if debugON
    fprintf('   Default Format: %s\n',device.DefaultFormat);
    fprintf('      Device Name: %s\n',device.DeviceName);
    fprintf('Supported Formats:\n');
    fprintf('\t%s\n',device.SupportedFormats{:});
end

%% Get source info
src_obj = getselectedsource(cam);

%% List properties that can be set
if debugON
    fprintf('Available Properties:\n');
end

prop_struct = set(src_obj);
prop_names = fieldnames(prop_struct);

n = numel(prop_names);
for k = 1:n
    prop_info{k} = propinfo(src_obj,prop_names{k});
    if debugON
        fprintf('------------------------------------------------------\n');
        fprintf('(%02d of %02d) %s:\n',k,n,prop_names{k});
        disp(prop_info{k});
    end
end

%% Create GUI figure
hBTN = 40;      % Button height
wBTN = 100;     % Button width
w0 = 20;        % Width offset from LHS
dw = 300;       % Panel width
wf = 20;        % Width offset from RHS
h0 = 0;         % Height offset from top of figure
dh = 55;        % Panel height
hf = hBTN + 20; % Height offset from bottom of figure

% Define total figure dimensions
wALL = w0 + dw + wf;
hALL = h0 + n*dh + hf;

% Get available monitor dimension(s)
mPos = get(0,'MonitorPositions');
% Account for small monitor
%wMAX = min(mPos(:,3));
hMAX = min(mPos(:,4)) - 80;
if hALL > hMAX
    ratio = hMAX/hALL;
else
    ratio = 1;
end

fig = figure('Name',sprintf('%s Property Editor',device.DeviceName),...
    'MenuBar','none','NumberTitle','off',...
    'Units','Pixels','Position',[0,0,wALL,hALL]*ratio);
centerfig(fig);

prop_vals = {};
for k = 1:n
    % Set panel with property title
    uiP(k) = uipanel(fig,'Title',prop_names{k},...
        'Units','Pixels','Position',[w0,h0+(n-k)*dh+hf,dw,sum(dh)]*ratio);
    
    % Set default tag
    switch lower(prop_names{k})
        case 'tag'
            if isempty( src_obj.(prop_names{k}) )
                src_obj.(prop_names{k}) = device.DeviceName;
            end
    end
    
    % Get current property value
    prop_vals{k} = src_obj.(prop_names{k});
    switch lower( prop_info{k}.Type )
        case 'integer'
            switch lower( prop_info{k}.Constraint )
                case 'bounded'
                    % Account for non-variable, bounded property value
                    if double(diff(prop_info{k}.ConstraintValue)) ~= 0
                        val = ...
                            double(prop_vals{k} - prop_info{k}.ConstraintValue(1))./...
                            double(diff(prop_info{k}.ConstraintValue));
                    else
                        val = mean(prop_vals{k});
                    end
                    uiC(k) =  uicontrol(uiP(k),'Style','Slider',...
                        'Units','Normalized','Position',[0.1,0.15,0.8,0.7],...
                        'Tag',prop_names{k},'Value',val);
                otherwise
                    uiC(k) =  uicontrol(uiP(k),'Style','Edit',...
                        'Units','Normalized','Position',[0.1,0.15,0.8,0.7],...
                        'Tag',prop_names{k},...
                        'String',sprintf('%d',prop_vals{k}));
            end
        case 'string'
            switch lower( prop_info{k}.Constraint )
                case 'none'
                    uiC(k) =  uicontrol(uiP(k),'Style','Edit',...
                        'Units','Normalized','Position',[0.1,0.15,0.8,0.7],...
                        'Tag',prop_names{k},...
                        'String',sprintf('%s',prop_vals{k}));
                case 'enum'
                    list = prop_info{k}.ConstraintValue;
                    val = find( matches(list,prop_vals{k}) );
                    uiC(k) =  uicontrol(uiP(k),'Style','popupmenu',...
                        'Units','Normalized','Position',[0.1,0.1,0.8,0.8],...
                        'String',list,'Value',val,'Tag',prop_names{k});
                otherwise
                    warning('"%s" is not recognized',prop_info{k}.Constraint);
                    
            end
        otherwise
            warning('"%s" is not recognized',prop_info{k}.Type);
    end
end

%% Establish buttons & callback functions
fcnApply = @(hObject, eventdata)...
    applyCallback(hObject,eventdata,cam,src_obj,uiC,prop_info);
fcnDefault = @(hObject, eventdata)...
    applyDefault(hObject,eventdata,cam,src_obj,uiC,prop_info,prop_vals);
fcnDelete = @(hObject, eventdata)delete(fig);

% Define buttons
uiB(1) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0,10,wBTN,hBTN]*ratio,...
    'Tag','Apply','String','Apply','Callback',fcnApply);
uiB(2) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0+wBTN+5,10,wBTN,hBTN]*ratio,...
    'Tag','Default','String','Default','Callback',fcnDefault);
uiB(3) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0+2*(wBTN+5),10,wBTN,hBTN]*ratio,...
    'Tag','Exit','String','Exit','Callback',fcnDelete);

%% Adjust defaults if camSettings is provided
if nargin > 1
    camSettings = varargin{1};
    
    % Check input
    if ~isstruct(camSettings)
        error('Camera settings must be specified as a structured array');
    end
    
    % Get provided property names
    set_names = fields(camSettings);
    
    % Initialize comparison arrays
    tfSet = false(numel(set_names),1);
    tfProp = false(1,numel(prop_names));
    
    % Compare field names
    for k = 1:numel(prop_names)
        tfFind = matches(set_names,prop_names{k});
        tfSet = tfSet | tfFind;
        if any(tfFind)
            tfProp(k) = true;
            % Update default property value
            prop_vals{k} = camSettings.(set_names{tfFind});
        end
    end
    
    % Display comparison results to user
    if ~all(tfProp)
        fprintf('\nThe following camera settings were not included in the user-provided camera settings:\n');
        for k = reshape(find(~tfProp),1,[])
            fprintf('%20s - ',prop_names{k});
            
            if ischar(prop_vals{k})
                fprintf('[DEFAULT] "%s"\n',prop_vals{k});
            else
                fprintf('[DEFAULT] %d\n',prop_vals{k});
            end
        end
    end
    
    if ~all(tfSet)
        fprintf('\nThe following user-provided camera settings are not valid settings for this camera:\n');
        for k = reshape(find(~tfSet),1,[])
            fprintf('%20s - ',set_names{k});
            
            if ischar(camSettings.(set_names{k}))
                fprintf('[IGNORED] "%s"\n',camSettings.(set_names{k}));
            else
                fprintf('[IGNORED] %d\n',camSettings.(set_names{k}));
            end
        end
    end
    
    % Update defaults
    fprintf('\n>>>>>> Applying user-provided camera settings >>>>>>\n');
    kids = get(fig,'Children');
    applyDefault(kids(1),[],cam,src_obj,uiC,prop_info,prop_vals);
    fprintf('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n\n');
end

%% Bypass GUI if user specifies
if nargin > 2
    skipGUI = varargin{2};
    if numel(skipGUI) ~= 1 || ~islogical(skipGUI)
        warning('The "skip GUI" option must be specified as a scalar logical array (i.e. true or false)');
    else
        if skipGUI
            delete(fig);
        end
    end
end

%% Provide output if required
if nargout > 0
    % Wait for execution to finish
    uiwait(fig);
    
    % Recover settings from GUI
    varargout{1} = adjustCamera_camSettings;
end

end

%% Internal functions
function applyCallback(hObject,eventdata,cam,src_obj,uiC,prop_info)
% hObject
% eventdata

% TODO - avoid use of global variable for sharing camera settings
global adjustCamera_camSettings

if ~isvalid(cam)
    warning('Video input object is not associated with any hardware, try reinitializing.');
    fig = get(hObject,'Parent');
    delete(fig);
    return
end

fprintf('------ Applying Settings ------\n');
fprintf('Stopping Camera...');
stop(cam);
fprintf('[COMPLETE]\n');
fprintf('\tSetting:\n');

% Debug code
%assignin('base','uiC',uiC);

for k = 1:numel(uiC)
    % Debug code
    %uiC(k)
    
    camProp = get(uiC(k),'Tag');
    fprintf('%20s to ',camProp);
    
    switch lower( get(uiC(k),'Style') )
        case 'slider'
            val = get(uiC(k),'Value');
            setVal = val*double(diff(prop_info{k}.ConstraintValue)) +...
                double(prop_info{k}.ConstraintValue(1));
            setVal = round(setVal);
        case 'edit'
            val = get(uiC(k),'String');
            switch lower( prop_info{k}.Type )
                case 'integer'
                    setVal = round( str2double(val) );
                    set(uiC(k),'Value',sprintf('%d',setVal));
                case 'string'
                    setVal = val;
            end
        case 'popupmenu'
            val = get(uiC(k),'Value');
            list = get(uiC(k),'String');
            setVal = list{val};
        otherwise
            warning('uiC(%d) "%s" is unrecognized type "%s"',k,get(uiC(k),'Type'));
            assignin('base','uiC',uiC);
            assignin('base','src_obj',src_obj);
            continue
    end
    
    % Try setting property
    % TODO - Address issue with DFx 21BU04
    try
        src_obj.(camProp) = setVal;
        
        if ischar(setVal)
            fprintf('"%s"\n',setVal);
        else
            fprintf('%d\n',setVal);
        end
    catch
            fprintf('UNABLE TO SET, SEE TODO\n');
    end
    
    % Update camera settings variable
    adjustCamera_camSettings.(camProp) = setVal;
end
fprintf('Starting Camera...');
start(cam);
fprintf('[COMPLETE]\n');
end

function applyDefault(hObject,eventdata,cam,src_obj,uiC,prop_info,prop_vals)
% hObject
% eventdata

% TODO - avoid use of global variable for sharing camera settings
global adjustCamera_camSettings

if ~isvalid(cam)
    warning('Video input object is not associated with any hardware, try reinitializing.');
    fig = get(hObject,'Parent');
    delete(fig);
    return
end

fprintf('------ Applying Defaults ------\n');
fprintf('Stopping Camera...');
stop(cam);
fprintf('[COMPLETE]\n');
fprintf('\tSetting:\n');
for k = 1:numel(uiC)
    %uiC(k)
    camProp = get(uiC(k),'Tag');
    fprintf('%20s to ',camProp);
    
    setVal = prop_vals{k};
    switch lower( get(uiC(k),'Style') )
        case 'slider'
            val = double(setVal - prop_info{k}.ConstraintValue(1))/...
                double(diff(prop_info{k}.ConstraintValue));
            set(uiC(k),'Value',val);
            try
                src_obj.(camProp) = setVal;
            catch ME
                % Debug
                fprintf('[Error in src_obj.%s = setVal]\n',camProp);
                assignin('base','fcnDebug.src_obj',src_obj);
                assignin('base','fcnDebug.setVal',setVal);
            end
        case 'edit'
            switch lower( prop_info{k}.Type )
                case 'integer'
                    val = sprintf('%d',setVal);
                case 'string'
                    val = setVal;
            end
            
            set(uiC(k),'String',val);
            src_obj.(camProp) = setVal;
        case 'popupmenu'
            list = get(uiC(k),'String');
            val = find( matches(list,setVal) );
            set(uiC(k),'Value',val);
            src_obj.(camProp) = setVal;
        otherwise
            warning('uiC(%d) "%s" is unrecognized type "%s"',k,get(uiC(k),'Type'));
            assignin('base','uiC',uiC);
            assignin('base','src_obj',src_obj);
            continue
    end
    
    if ischar(setVal)
        fprintf('"%s"\n',setVal);
    else
        fprintf('%d\n',setVal);
    end
    
    % Update camera settings variable
    adjustCamera_camSettings.(camProp) = setVal;
end
fprintf('Starting Camera...');
start(cam);
fprintf('[COMPLETE]\n');
end