function adjustCamera(cam)
% ADJUSTCAMERA allows the user to adjust the settings of a video input
% object using a basic GUI.
%
%   Input(s)
%       cam - video input object
%
%   See also initCamera
%
%   M. Kutzer, 31Mar2022, USNA

debugON = false;

%% Check input(s)
narginchk(1,1);
switch lower(class(cam))
    case 'videoinput'
        % Input is a video input object
        if ~isvalid(cam)
            error('Video input object is not associated with any hardware, try reinitializing.');
        end
    otherwise
        error('Input must be a valid video input object.');
end

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
hBTN = 40;
wBTN = 100;
w0 = 20;
dw = 300;
wf = 20;
h0 = 0;
dh = 55;
hf = hBTN + 20;
wALL = w0 + dw + wf;
hALL = h0 + n*dh + hf;

fig = figure('Name',sprintf('%s Property Editor',device.DeviceName),...
    'MenuBar','none','NumberTitle','off',...
    'Units','Pixels','Position',[0,0,wALL,hALL]);
centerfig(fig);

prop_vals = {};
for k = 1:n
    % Set panel with property title
    uiP(k) = uipanel(fig,'Title',prop_names{k},...
        'Units','Pixels','Position',[w0,h0+(n-k)*dh+hf,dw,sum(dh)]);
    
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
                    val = ...
                        (prop_vals{k} - prop_info{k}.ConstraintValue(1))./...
                        diff(prop_info{k}.ConstraintValue);
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
                    val = find( contains(list,prop_vals{k}) );
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
    'Units','Pixels','Position',[w0,10,wBTN,hBTN],...
    'Tag','Apply','String','Apply','Callback',fcnApply);
uiB(2) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0+wBTN+5,10,wBTN,hBTN],...
    'Tag','Default','String','Default','Callback',fcnDefault);
uiB(3) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0+2*(wBTN+5),10,wBTN,hBTN],...
    'Tag','Exit','String','Exit','Callback',fcnDelete);

end

%% Internal functions
function applyCallback(hObject,eventdata,cam,src_obj,uiC,prop_info)
hObject
eventdata

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
for k = 1:numel(uiC)
    %uiC(k)
    camProp = get(uiC(k),'Tag');
    fprintf('%20s to ',camProp);
    
    val = get(uiC(k),'Value');
    switch lower( get(uiC(k),'Style') )
        case 'slider'
            setVal = val*diff(prop_info{k}.ConstraintValue) +...
                prop_info{k}.ConstraintValue(1);
        case 'edit'
            switch lower( prop_info{k}.Type )
                case 'integer'
                    setVal = round( str2double(val) );
                    set(uiC(k),'Value',sprintf('%d',setVal));
                case 'string'
                    setVal = val;
            end
        case 'popupmenu'
            list = get(uiC(k),'String');
            setVal = list{val};
        otherwise
            warning('uiC(%d) "%s" is unrecognized type "%s"',k,get(uiC(k),'Type'));
            assignin('base','uiC',uiC);
            assignin('base','src_obj',src_obj);
            continue
    end
    src_obj.(camProp) = setVal;
    
    if ischar(setVal)
        fprintf('"%s"\n',setVal);
    else
        fprintf('%d\n',setVal);
    end
end
fprintf('Starting Camera...');
start(cam);
fprintf('[COMPLETE]\n');
end

function applyDefault(hObject,eventdata,cam,src_obj,uiC,prop_info,prop_vals)
hObject
eventdata

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
            val = (setVal - prop_info{k}.ConstraintValue(1))/diff(prop_info{k}.ConstraintValue);
            set(uiC(k),'Value',val);
            src_obj.(camProp) = setVal;
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
            val = find( contains(list,setVal) );
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
end
fprintf('Starting Camera...');
start(cam);
fprintf('[COMPLETE]\n');
end