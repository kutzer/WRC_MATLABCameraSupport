function bw = segmentRedBall(im)

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