function [cam,prv] = initWebcam
% INITWEBCAM initializes a webcam object and, if applicable, opens a 
% preview.
%
%   cam = INITWEBCAM returns the webcam object. This is required for using
%   snapshot.m:
%       -> im = snapshot(cam);
%
%   [cam,prv] = INITWEBCAM returns both the webcam object and the preview
%   handle. Note that "prv" can be used to get images faster than 
%   snapshot.m using:
%       -> im = get(prv,'CData');
%
%   NOTE: This requires an installed version of the "MATLAB Support 
%       Package for USB Webcams" 
%       >> supportPackageInstaller
%           -> select "Install from Internet"
%           -> select “USB Webcams”
%           -> login to mathworks using email and password
%           -> Install
%
%   M. Kutzer, 19Jul2019, USNA

%% List existing webcams
try
    camList = webcamlist;
catch
    error('initWebcam:NoWebcamList',...
        ['The "webcamlist" function is not detected.\n',...
        ' -> Run "supportPackageInstaller"\n',...
        ' -> Select and install "USB Webcams".\n']);
end

%% Select webcam
if numel(camList) == 0
    error('No connected camera found');
end

if numel(camList) == 1
    camIdx = 1;
else
    [camIdx,OK] = listdlg('PromptString','Select camera:',...
        'SelectionMode','single',...
        'ListString',camList);
    if ~OK
        error('No camera selected.');
    end
end

cam = webcam(camIdx);
if nargout > 1
    prv = preview(cam);
end