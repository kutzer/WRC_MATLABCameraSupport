function [tf,msg] = inFOV(p_m_tilde,camParams)
% INFOV checks if scaled pixel coordinates result in a point within the
% field of view of a camera.
%   [tf,msg] = inFOV(p_m_tilde,camParams)
%
%   Input(s)
%       p_m_tilde - 3xN array containing scaled pixel coordinates
%       camParams - cameraParameters
%
%   Output(s)
%       tf
%       msg
%
%   Civetta, Doherty, M. Kutzer, 12Sep2023, USNA

%% Check input(s)
% TODO - check inputs

%% Initialize message
msg = cell(1,size(p_m_tilde,2));

%% Check FOV
z_c = p_m_tilde(3,:);
behindCam = z_c <= 0;

tf = ~behindCam;

% Add descriptive message
str = 'Point lies at or behind focal point.';
msg(behindCam) = repmat({str},1,nnz(behindCam));

%% Check if pixel coordinates are in FOV

% Isolate points existing in front of camera
p_m_tilde_tf = p_m_tilde(:,tf);
% Define pixel coordinates
p_m_tf = p_m_tilde_tf./(p_m_tilde_tf(3,:));

% Identify image size
yxRes = camParams.ImageSize;

yLims = [0,yxRes(1)];
xLims = [0,yxRes(2)];

% Check for points in FOV
tf_x = p_m_tf(1,:) >= xLims(1) & p_m_tf(1,:) <= xLims(2);
tf_y = p_m_tf(2,:) >= yLims(1) & p_m_tf(2,:) <= yLims(2);

tf_xy = tf_x & tf_y;

%% Append logical values 
tf(tf) = tf_xy;

% Add message
outOfView = ~tf & ~behindCam;

str = 'Point lies outside FOV.';
msg(outOfView) = repmat({str},1,nnz(outOfView));