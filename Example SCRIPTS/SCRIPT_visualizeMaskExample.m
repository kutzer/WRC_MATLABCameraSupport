clear all
close all
clc

imaqreset;
[cam,img] = initCamera;

%% Get parent axes
axs = get(img,'Parent');
hold(axs,'on');

%% Grab a picture for processing
im = get(img,'CData');

%% Threshold image
%colorThresholder(im);

%% visualize
minArea = 5000;
maxArea = 10000;
plt = plot(axs,0,0,'.g');
while true
    im = get(img,'CData');
    BW = createMaskExample(im);
    BW = bwminmaxarea(BW,minArea,maxArea,8);
    BW = imfill(BW,'holes');
    
    [y,x] = find(BW);
    set(plt,'XData',x,'YData',y);
    drawnow;
end