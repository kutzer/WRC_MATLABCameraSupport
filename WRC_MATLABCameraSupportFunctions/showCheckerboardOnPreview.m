function [objs,im] = showCheckerboardOnPreview(prv,im,varargin)
% SHOWCHECKERBOARDINPREVIEW overlays a patch object on a preview showing
% where a checkerboard has been detected within an image.
%   [objs,im] = showCheckerboardInPreview(prv,im)
%   ___ = showCheckerboardInPreview(prv)
%   ___ = showCheckerboardInPreview(___,Name,Value)
%
%   Input(s)
%       prv - preview image object (see initCamera.m)
%       im  - image taken from preview (or associated camera object)
%       
%       Name-Value Arguments (see detectCheckerboardPoints.m)
%             MinCornerMetric - 0.15 | 0.12 | nonnegative scalar
%              HighDistortion - false (default) | true
%           PartialDetections - false (default) | true
%
%   Output(s)
%       objs - patch object used that is overlaid on preview
%
%   See also clearPreview initCamera
%
%   M. Kutzer, 15Nov2023, USNA

%% Check input(s)
% TODO - check inputs
if nargin < 2
    im = get(prv,'CData');
end

if nargin > 2
    % Check if second input is an image
    if ischar(im) || isstring(im)
        varargin = {im, varargin{:}};
        im = get(prv,'CData');
    end
end

%% Recover preview handles
hndls = recoverPreviewHandles(prv);
figure(hndls.Figure);

%% Detect checkerboard in image
warning('off','vision:calibrate:boardShouldBeAsymmetric');
if numel(varargin) == 0
    [imagePoints,~] = detectCheckerboardPoints(im,'PartialDetections',false);
else
    tfChar = cellfun(@ischar,varargin) | cellfun(@isstring,varargin);
    tf = contains(lower(varargin(tfChar)),'partialdetections');
    if ~any(tf)
        varargin{end+1} = 'PartialDetections';
        varargin{end+1} = false;
        [imagePoints,~] = detectCheckerboardPoints(im,varargin{:});
    else
        [imagePoints,~] = detectCheckerboardPoints(im,...
            'PartialDetections',false,varargin{:});
    end
end
warning('on','vision:calibrate:boardShouldBeAsymmetric');

% Remove nan values from image points
tf = isnan(imagePoints);
tf = tf(:,1) | tf(:,2);
imagePoints(tf,:) = [];

%% Check for no image points
if isempty(imagePoints)
    ptc = patch('Parent',hndls.Axes,'Tag','Checkerboard Overlay');
    objs = ptc;
    return
end

%% Create patch object
% Define outer bounds of image points
idx = convhull(imagePoints(:,1),imagePoints(:,2));
idx(end) = [];

% Define artificial z to keep patch object in foreground
z_m = 0.5;

% Patch vertices
verts = imagePoints(idx,:);
verts(:,3) = z_m;

% Patch faces
faces = 1:numel(idx);

% Create patch object
color = rand(1,3)*0.5 + 0.5;
ptc = patch('Parent',hndls.Axes,'Vertices',verts,'Faces',faces,...
    'FaceAlpha',0.3,'FaceColor',color,'EdgeColor','m','Tag',...
    'Checkerboard Overlay');

% Plot checkerboard origin
plt(1) = plot(hndls.Axes,imagePoints(1,1),imagePoints(1,2),'dr',...
    'MarkerSize',10,'LineWidth',1.5,'MarkerFaceColor','r');
plt(2) = plot(hndls.Axes,imagePoints(end,1),imagePoints(end,2),'og',...
    'MarkerSize',10,'LineWidth',1.5,'MarkerFaceColor','g');
plt(3) = plot(hndls.Axes,...
    [imagePoints(1,1),imagePoints(end,1)],...
    [imagePoints(1,2),imagePoints(end,2)],'-m','LineWidth',1.0);
%% Package output(s)
objs = [ptc,plt];