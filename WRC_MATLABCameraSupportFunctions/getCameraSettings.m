function [camSettings,DeviceName,DeviceFormat] = getCameraSettings(cam)
% GETCAMERASETTINGS gets the camera settings and device information from a
% MATLAB video input object.
%   [camSettings,DeviceName,DeviceFormat] = getCameraSettings(cam)
%
%   Input(s)
%       cam - video input object
%
%   Output(s)
%       camSettings - strutured array containing the last set of
%                     camera settings implemented by the GUI. Note that
%                     specifying an output will block execution until the
%                     GUI is closed using the "Exit" button.
%        DeviceName - character array specifying specific
%                     camera device.
%      DeviceFormat - character array specifying camera format
%
%   See also initCamera adjustCamera
%
%   M. Kutzer, 17Apr2025, USNA

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

%% Get device information
DeviceInfo = imaqhwinfo(cam);
DeviceName = DeviceInfo.DeviceName;
DeviceFormat = cam.VideoFormat;

%% Get source info
src_obj = getselectedsource(cam);


%% Get camera settings
prop_struct = set(src_obj);
prop_names = fieldnames(prop_struct);

n = numel(prop_names);
for k = 1:n
    camSettings.(prop_names{k}) = src_obj.(prop_names{k});
end

