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
        try
            isrunning(cam)
        catch
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

fig = figure('Name',sprintf('%s Editor',device.DeviceName),...
    'Units','Pixels','Position',[0,0,wALL,hALL]);
centerfig(fig);

prop_vals = {};
for k = 1:n
    % Set panel with property title
    uiP(k) = uipanel(fig,'Title',prop_names{k},...
        'Units','Pixels','Position',[w0,h0+(n-k)*dh+hf,dw,sum(dh)]);
    
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
                        'String',sprintf('%d',prop_vals{k}));
                case 'enum'
                    list = prop_info{k}.ConstraintValue;
                    val = find( contains(list,prop_vals{k}) );
                    uiC(k) =  uicontrol(uiP(k),'Style','popupmenu',...
                        'Units','Normalized','Position',[0.1,0.1,0.8,0.8],...
                        'String',list,'Tag',prop_names{k});
                otherwise
                    warning('"%s" is not recognized',prop_info{k}.Constraint);
                    
            end
        otherwise
            warning('"%s" is not recognized',prop_info{k}.Constraint);
    end
end

% Establish callback functions
fcnApply = @(hObject, eventdata)...
    applyCallback(hObject,eventdata,cam,src_obj,uiC,prop_info);
fcnDelete = @(hObject, eventdata)delete(fig);
% Define buttons
uiB(1) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0,10,wBTN,hBTN],...
    'Tag','Apply','String','Apply','Callback',fcnApply);
uiB(2) = uicontrol(fig,'Style','Pushbutton',...
    'Units','Pixels','Position',[w0+wBTN+10,10,wBTN,hBTN],...
    'Tag','Exit','String','Exit','Callback',fcnDelete);

end

%% Internal functions
function applyCallback(hObject,eventdata,cam,src_obj,uiC,prop_info)
fprintf('Applying settings...');
stop(cam);
for k = 1:numel(uiC)
    %uiC(k)
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
        case 'enum'
            list = get(uiC(k),'String');
            setVal = list{val};
        otherwise
            warning('uiC(%d) is unrecognized type "%s"',k,get(uiC(k),'Type'));
            continue
    end
    src_obj.(get(uiC(k),'Tag')) = setVal;
end
start(cam);
fprintf('[COMPLETE]\n');
end