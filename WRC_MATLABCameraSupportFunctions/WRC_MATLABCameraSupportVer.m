function varargout = WRC_MATLABCameraSupportVer
% WRC_MATLABCAMERASUPPORTVER displays the Plotting Toolbox information.
%   WRC_MATLABCAMERASUPPORTVER displays the information to the command
%   prompt.
%
%   A = WRC_MATLABCAMERASUPPORTVER returns in A the sorted struct array of  
%   version information for the Plotting Toolbox.
%     The definition of struct A is:
%             A.Name      : toolbox name
%             A.Version   : toolbox version number
%             A.Release   : toolbox release string
%             A.Date      : toolbox release date
%
%   M. Kutzer 03Nov2020, USNA

% Updates
%   08Jan2021 - Updated ToolboxUpdate
%   09Mar2022 - Added functions to drawOnTarget, added USNA and WRC stock
%               images
%   10Mar2022 - Added UR3e fixed camera calibration
%   10Mar2022 - Added recoverPreview* functions
%   24Mar2022 - Added UR3e Eye-in-Hand camera calibration
%   31Mar2022 - Remove partial detections from calibrateUR3e* functions
%   31Mar2022 - Included red ball segment/props functions
%   31Mar2022 - Removed initCamera warnings, added adjustCamera GUI
%   13Apr2022 - Added handheld images to fixedCamera calibration
%   14Apr2022 - Created common function for use in fixed and eye-in-hand
%               calibration
%   18Apr2022 - Bug fixes in calibrate* functions
%   21Nov2023 - Added refineCameraIntrinsics
%   30Nov2023 - Updated adjustCamera to enable output and input of camera
%               settings.
%   17Apr2024 - Updated to account for no visible checkerboard in 
%               showCheckerboardOnPreview
%   23Apr2024 - Updated adjustCamera to account for non-variable, bounded 
%               property values
%   23Apr2024 - Updated to enable inputs for initCamera
%   23Jan2025 - Updated getCalibrationImages to add 
%               showCheckerboardOnPreview and clearPreview
%   17Mar2025 - Added isBinaryImage to support legacy functions
%   27Mar2025 - Updated documentation
%   14Apr2025 - Added TicTacToeSim and UR3eTicTacToeSim classes
%   17Apr2025 - Updated to include adjustCameraForAprilTags
%   21Apr2025 - Updated to fix TicTacToeSim H_ao2c error
%   22May2025 - Updated to enable local install

A.Name = 'WRC MATLAB Camera Support';
A.Version = '1.3.0';
A.Release = '(R2019b)';
A.Date = '23-May-2025';
A.URLVer = 1;

msg{1} = sprintf('MATLAB %s Version: %s %s',A.Name, A.Version, A.Release);
msg{2} = sprintf('Release Date: %s',A.Date);

n = 0;
for i = 1:numel(msg)
    n = max( [n,numel(msg{i})] );
end

fprintf('%s\n',repmat('-',1,n));
for i = 1:numel(msg)
    fprintf('%s\n',msg{i});
end
fprintf('%s\n',repmat('-',1,n));

if nargout == 1
    varargout{1} = A;
end