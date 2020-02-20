function testLiveFeed(prv,fcn)
% prv - preview handle
% fcn - @functionName

im = prv.CData;
fig = figure('Name','Test Live Feed');
img = imshow(im);
axs = get(img,'Parent');
set(axs,'Parent',fig);
hold(axs,'on');

plt = plot(axs,0,0,'.m');
while true
    im = prv.CData;
    set(img,'CData',im);
    
    bin = fcn(im);
    [y,x] = find(bin);
    
    set(plt,'XData',x,'YData',y);
    drawnow
    
    if ~ishandle(fig)
        break
    end
end
    