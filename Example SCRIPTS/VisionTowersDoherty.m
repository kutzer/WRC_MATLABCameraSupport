%bin = RedBlock(imag);
%bin = BlueBlock(imag);
%bin = WhiteBlock(imag);
bin = Base(imag);
figure;
imshow(bin);
title('Red Block Binary');

%%
binFill = imfill(bin,'holes');
figure;
imshow(binFill);
title('Filled Holes Binary');

%% Get area of all connected components
stats = regionprops(binFill,'Area');
areas = [stats.Area];

figure;
plot(areas)
%%
MinAreaRed = 2000;
MaxAreaRed = inf;
MinAreaBlue = 1000;
MaxAreaBlue = 2250;
MinAreaWhite = 2000;
MaxAreaWhite = 4000;
MinAreaBase = 15000;
MaxAreaBase = inf;

%[binArea,binMinArea,binMaxArea] = bwminmaxarea(binFill,MinAreaRed,MaxAreaRed);
%[binArea,binMinArea,binMaxArea] = bwminmaxarea(binFill,MinAreaBlue,MaxAreaBlue);
%[binArea,binMinArea,binMaxArea] = bwminmaxarea(binFill,MinAreaWhite,MaxAreaWhite);
[binArea,binMinArea,binMaxArea] = bwminmaxarea(binFill,MinAreaBase,MaxAreaBase);
figure;
imshow(binArea);

%%
im = get(prv,'CData');
fig = figure;
img = imshow(im);
axs = get(img,'Parent');
set(axs,'Visible','On','NextPlot','add');

pltR = plot(axs,0,0,'.r');
pltB = plot(axs,0,0,'.b');
pltW = plot(axs,0,0,'.g');
pltP = plot(axs,0,0,'.w');

cntR = plot(axs,0,0,'+g','MarkerSize',10,'LineWidth',2);
cntB = plot(axs,0,0,'+g','MarkerSize',10,'LineWidth',2);
cntW = plot(axs,0,0,'+g','MarkerSize',10,'LineWidth',2);
cntP = plot(axs,0,0,'+g','MarkerSize',10,'LineWidth',2);

while true
    % Get image
    im = get(prv,'CData');
    % Update image in figure
    set(img,'CData',im);
    
    % Process image
    % -> Create binary
    binR = RedBlock(im);
    binB = BlueBlock(im);
    binW = WhiteBlock(im);
    binP = Base(im);

    % -> Remove objects below MinArea
    binR = bwisolate(binR,MinAreaRed,MaxAreaRed);
    binB = bwisolate(binB,MinAreaBlue,MaxAreaBlue);
    binW = bwisolate(binW,MinAreaWhite,MaxAreaWhite);
    binP = bwisolate(binP,MinAreaBase,MaxAreaBase);
    
    % Calculate centroids
    s = regionprops(binR,'centroid');
    centroids = cat(1,s.Centroid);
    set(cntR,'XData',centroids(:,1),'YData',centroids(:,2));
    
    s = regionprops(binB,'centroid');
    centroids = cat(1,s.Centroid);
    set(cntB,'XData',centroids(:,1),'YData',centroids(:,2));
    
    s = regionprops(binW,'centroid');
    centroids = cat(1,s.Centroid);
    set(cntW,'XData',centroids(:,1),'YData',centroids(:,2));
    
    s = regionprops(binP,'centroid');
    centroids = cat(1,s.Centroid);
    set(cntP,'XData',centroids(:,1),'YData',centroids(:,2));
    
    % Find all pixels associated with binFill
    [y,x] = find(binR);
    % Highlight all pixels associated with binFill
    set(pltR,'XData',x,'YData',y);
    
    % Find all pixels associated with binFill
    [y,x] = find(binB);
    % Highlight all pixels associated with binFill
    set(pltB,'XData',x,'YData',y);
    
    % Find all pixels associated with binFill
    [y,x] = find(binW);
    % Highlight all pixels associated with binFill
    set(pltW,'XData',x,'YData',y);
    
    % Find all pixels associated with binFill
    [y,x] = find(binP);
    % Highlight all pixels associated with binFill
    set(pltP,'XData',x,'YData',y);
    % Let MATLAB update the plot before doing anything else
    drawnow
end