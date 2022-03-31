function bw = segmentRedBall(im)
% SEGMENTREDBALL thresholds an RGB image and filters the returned binary
% image.
%   bw = SEGMENTREDBALL(im)
%
%   Input(s)
%       im - MxNx3 uint8 array representing an RGB color image
%
%   Output(s)
%       bw - MxN binary array with "true" values corresponding to the
%            segmented pixels of the red ball
%
%   M. Kutzer, 28Feb2022, USNA

% Create binary image using color-thresholding
bw = createRedMask(im);

% Remove clusters of pixels with less than or equal to 100 total pixels
bw = bwareaopen(bw,100);

% Remove remaining objects (this appears unnecessary)
bw = bwareafilt(bw,1);

% Fill holes
bw = imfill(bw,'holes');

% Remove non-circular objects (a perfect circle has an eccentricity of 0)
bw = bwpropfilt(bw,'Eccentricity',[0.0, 0.6]);