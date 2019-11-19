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
plt = plot(axs,0,0,'.g');
while true
    im = get(img,'CData');
    [BW,maskedRGBImage] = createMaskExample(im);
    BW = bwareaopen(BW,5000);
    BW = imfill(BW,'holes');
    
    [y,x] = find(~BW);
    set(plt,'XData',x,'YData',y);
    drawnow;
end