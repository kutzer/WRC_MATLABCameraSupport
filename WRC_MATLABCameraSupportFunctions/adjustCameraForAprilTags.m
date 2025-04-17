function varargout = adjustCameraForAprilTags(cam,tagFamily)
% ADJUSTCAMERAFORAPRILTAGS allows a user to use an
%   [camSettings,DeviceName,DeviceFormat] = adjustCameraForAprilTags(cam,tagFamily)
%
%   Input(s)
%       cam - video input object
%
%   Output(s)
%       camSettings - strutured array containing the last set of
%                     camera settings implemented by the GUI. Note that
%                     specifying an output will block execution until the
%                     GUI is closed using the "Exit" button.
%        DeviceName - character array specifying specific
%                     camera device.
%      DeviceFormat - character array specifying camera format
%
%   See also initCamera adjustCamera
%
%   M. Kutzer, 17Apr2025, USNA

%% Check input(s)
narginchk(2,2);

%% Close any existing adjustCamera GUIs
figADJ = findobj('Type','Figure','Tag','adjustCamera');
delete(figADJ);

%% Adjust
adjustCamera(cam);
figADJ = findobj('Type','Figure','Tag','adjustCamera');

prv = preview(cam);

fig = figure('Name','adjustCameraForAprilTags');
axs = axes('Parent',fig,'NextPlot','add');
axis(axs,'tight');
img = [];
tag = [];

while true
    try
        im = get(prv,'CData');
        if isempty(img)
            img = imshow(im,'Parent',axs);
        else
            set(img,'CData',im);
        end

        [id,loc] = readAprilTag(im,tagFamily);
        
        %tag(1).ptc
        %numel(tag)
        if ~isempty(tag)
            set([tag.ptc],'Visible','off');
            set([tag.txt],'Visible','off');
        end

        for i = 1:numel(id)
            % Define AprilTag label
            str = sprintf('%03d',id(i));
            ang = rad2deg( atan2(...
                loc(2,1,i) - loc(1,1,i),...
                loc(2,2,i) - loc(1,2,i)) - pi/2 );

            if numel(tag) < i
                % Highlight AprilTag(s) matching tagID in blue
                tag(i).ptc = patch(axs,'Vertices',loc(:,:,i),'Faces',1:4,...
                    'EdgeColor','b','FaceColor','b','FaceAlpha',0.9);

                % Label AprilTag
                tag(i).txt = text(axs,mean(loc(:,1,i)),mean(loc(:,2,i)),str,...
                    'HorizontalAlignment','center','VerticalAlignment','bottom',...
                    'Rotation',ang,'FontWeight','Bold','FontSize',10,'Color','w');

            else
                set(tag(i).ptc,'Vertices',loc(:,:,i),'Visible','on');
                set(tag(i).txt,'String',str,'Position',mean(loc(:,:,i)),...
                    'Rotation',ang,'Visible','on');
            end

        end

        set(fig,'WindowState','maximized');
        figure(figADJ);
        drawnow
    catch
        break
    end

    % Check adjust camera GUI
    if ~ishandle(figADJ)
        break
    end
end
delete(fig);
delete(figADJ);

if nargout > 0
    [camSettings,DeviceName,DeviceFormat] = getCameraSettings(cam);

    if nargout > 0
        varargout{1} = camSettings;
    end
    if nargout > 1
        varargout{2} = DeviceName;
    end
    if nargout > 2
        varargout{3} = DeviceFormat;
    end
end
