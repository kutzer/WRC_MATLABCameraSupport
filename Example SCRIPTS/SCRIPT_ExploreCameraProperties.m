%% SCRIPT_ExploreCameraProperties
% This script explores the available camera properties and settings.
%
%   M. Kutzer, 24Mar2022, USNA

%% Create/initialize camera object and preview
[cam,prv] = initCamera;

%% Get device info
device = imaqhwinfo('winvideo',cam.DeviceID);

% List information
fprintf('   Default Format: %s\n',device.DefaultFormat);
fprintf('      Device Name: %s\n',device.DeviceName);
fprintf('Supported Formats:\n');
fprintf('\t%s\n',device.SupportedFormats{:});

%% Get source info
src_obj = getselectedsource(cam);

%% List properties that can be set
prop_struct = set(src_obj);
prop_names = fieldnames(prop_struct);
fprintf('Available Properties:\n');
n = numel(prop_names);
for i = 1:n
    fprintf('------------------------------------------------------\n');
    fprintf('(%02d of %02d) %s:\n',i,n,prop_names{i});
    prop_info{i} = propinfo(src_obj,prop_names{i});
    disp(prop_info{i});
end

%% Create GUI figure
fig = figure('Name',sprintf('%s Editor',device.DeviceName));
%c = uicontrol(Name,Value) 