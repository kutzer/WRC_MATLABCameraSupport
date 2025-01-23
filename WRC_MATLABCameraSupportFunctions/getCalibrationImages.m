function varargout = getCalibrationImages(prv,varargin)
% GETCALIBRATIONIMAGES aquires a set number of images from one or more live
% camera preview(s) and saves them to a specific directory for use in 
% camera calibration.
%   getCalibrationImages(prv) acquires a set of 12 images with a base image
%   name of "im" in an image folder named 
%   "Calibration Data Set, [DATE], Experiment [TIME]" containing a date  
%   and a unique time stamp of creation.
%
%   NOTE: Multiple live camera previews can be specified within "prv" using
%   an array (e.g. prvs = [prv1, prv2, ...]). Doing so will update the 
%   image names to "cam1_im...", "cam2_im...", etc. Specifying a different 
%   image name value will change "im".
%
%   getCalibrationImages(prv,n) acquires a set of n images with the default
%   base image name and image folder specified above. 
%
%   getCalibrationImages(prv,imageName,imageFolder) acquires a set of 12
%   images with the base image name specified in "imageName" and an image 
%   folder name specified in "imageFolder".
%
%   getCalibrationImages(prv,imageName,imageFolder,n) acquires a set of n
%   images with the base image name specified in "imageName" and an image 
%   folder name specified in "imageFolder".
%
%   getCalibrationImages(prv,imageName,imageFolder,n,dt) allows the user to
%   specify an approximate fixed time interval (in seconds) between each 
%   calibration image allowing for hands-free operation.
%
%   imageFolder = getCalibrationImages(___) returns the full path to the
%   imageFolder.
%
%   [imageFolder,imageNames] = getCalibrationImages(___) returns the full 
%   path to the imageFolder and a cell array of the image names used.
%
%   Input(s)
%       prv         - array of camera preview image object(s). Multiple
%                     previews will alter the default image name. 
%       n           - [OPTIONAL] number of calibration images. The default
%                     number of images is 12. 
%       imageName   - [OPTIONAL] base name for images saved during 
%                     calibration. 
%       imageFolder - path used to save calibration images
%       dt          - [OPTIONAL] 
%
%   Output(s)
%       imageFolder - character arracy specifying image folder path
%       imageNames  - cell array defining image names
%
%   See also initCamera cameraCalibrator
%
%   M. Kutzer, 30Jan2016, USNA

% Updates
%   02Feb2016 - Added multiple camera option.
%   18Jan2017 - Updated to migrate from webcam to videoinput objects
%   07Jan2020 - Updated to replace camera object with live preview object. 
%               This makes the function compatible with webcam and
%               videoinput objects.
%   06Feb2020 - Added leading zeros to camera and image numbering in
%               filenames. 
%   06Feb2020 - Updated to also return image names.
%   08Mar2021 - Updated to include fixed time interval option.
%   15Nov2023 - Updated documentation
%   21Mar2024 - Updated documentation and fixed multi-preview support
%   23Jan2025 - Updated to add showCheckerboardOnPreview and clearPreview

%% Parse and check inputs
% Check number of inputs
narginchk(1,5);

% Set default values
imageName = [];
imageFolder = [];
n = [];
dt = [];
tfShowCheckerboard = true;

% Check videoinput object
goodPrv = true;
for i = 1:numel(prv)
    if ~ishandle(prv(i))
        goodPrv = false;
        break;
    end
    switch lower( get(prv(i),'Type') )
        case 'image'
            % Specified object is a valid preview
        otherwise
            goodPrv = false;
            break
    end
end

if ~goodPrv
    error('getCal:BadPrv',...
        ['Specified live preview must be a valid image graphics handle. Use:\n',...
        ' -> [~,prv] = initCamera; or \n',...
        ' -> [~,prv] = initWebcam;']);
else
    % Get preview axis
    for i = 1:numel(prv)
        prvFig = ancestor(prv(i),'Figure');
        set(prvFig,'Units','Normalized');
        pp = get(prvFig,'Position');
        ppNew = [0,1-pp(4)-0.025,pp(3),pp(4)];
        set(prvFig,'Position',ppNew);
    end
end

% Parse inputs
if nargin == 2
    n = varargin{1};
end
if nargin == 3
    imageName = varargin{1};
    imageFolder = varargin{2};
end
if nargin == 4
    imageName = varargin{1};
    imageFolder = varargin{2};
    n = varargin{3};
end
if nargin == 5
    imageName = varargin{1};
    imageFolder = varargin{2};
    n = varargin{3};
    dt = varargin{4};
end

% Set defaults
if isempty(n)
    n = 12;
end
if isempty(imageName)
    imageName = 'im';
end
if isempty(imageFolder)
    d = datetime('today');
    dateStr = sprintf('%04d%02d%02d',d.Year,d.Month,d.Day);
    imageFolder = sprintf('Calibration Data Set, %s, Experiment %d',...
        dateStr,round((now-floor(now))*1e6));
    fprintf('Using default Image Folder: \n -> "%s"\n',imageFolder);
end

% Check inputs
if ~isnumeric(n) || numel(n) ~= 1
    error('The number of images must be specified as a single numeric value.');
end
if ~ischar(imageName)
    error('The base image name must be specified as a string.');
end
if ~ischar(imageFolder)
    error('The image folder name must be specified as a string.');
end
%TODO - check for valid file/folder names

%% Create image folder if it does not already exist
if ~isfolder(imageFolder)
    mkdir(imageFolder);
end

%% Initialize timed image capture
if ~isempty(dt)
    fig = figure('Name','Grab Image','MenuBar','none','NumberTitle','off',...
        'Resize','off','Scrollable','off','ToolBar','none',...
        'CloseRequestFcn',[],'Units','Points','Position',[0,0,600,120]);
    centerfig(fig);
    axs = axes('Parent',fig,'Units','Normalized','Visible','off',...
        'Position',[0,0,1,1],'XLim',[-1,1],'YLim',[-1,1]);
    
    msg{1} = sprintf('Place checkerboard in camera FOV (%2d of %2d);',0,n);
    msg{2} = sprintf('Taking snapshot in %2d',ceil(dt));
    txt = text(0,0,msg,'Parent',axs,'HorizontalAlignment','Center',...
        'VerticalAlignment','Middle','FontSize',26);
end

%% Get images
fmt = 'png';
for i = 1:n
    % Status update
    fprintf('Getting calibration image %d of %d...',i,n);
    
    % Bring preview to the front
    figure(prvFig);

    % Prompt user
    if isempty(dt)
        % -> Manual image capture
        if n > 1
            msg = sprintf('Place checkerboard in camera FOV (%d of %d)...[Enter to Continue]',i,n);
            % Wait for user
            uiwait(...
                msgbox(msg,'Grab Image')...
                );
        else
            fprintf('<SINGLE IMAGE, UIWAIT>...');
        end
    else
        % -> Timed image capture
        t = 0;
        t0 = tic;
        while t < dt
            figure(fig);
            t = toc(t0);
            msg{1} = sprintf('Place checkerboard in camera FOV (%2d of %2d);',i,n);
            msg{2} = sprintf('Taking snapshot in %2d...',round(dt - t));
            set(txt,'String',msg);
            drawnow;
        end
        msg{2} = sprintf('HOLD STILL, Taking snapshot!!!',0);
        set(txt,'String',msg);
        drawnow
    end
    
    % Grab image(s)
    drawnow
    for j = 1:numel(prv)
        im{j} = get(prv(j),'CData');
    end

    % Show checkerboard on preview(s)
    if tfShowCheckerboard
        for j = 1:numel(im)
            showCheckerboardOnPreview(prv(j),im{j});
        end
    end
    drawnow

    % Update timed user prompt
    if ~isempty(dt)
        msg{1} = sprintf('Image(s) Captured!');
        msg{2} = sprintf('Saving Image(s)...');
        set(txt,'String',msg);
        drawnow
    end

    % Define image filename(s)
    if numel(im) == 1
        fname{1} = sprintf('%s%03d.%s',imageName,i,fmt);
    else
        for j = 1:numel(im)
            fname{j} = sprintf('cam%02d_%s%03d.%s',j,imageName,i,fmt);
        end
    end

    % Save image(s)
    for j = 1:numel(im)
        imwrite(im{j},fullfile(imageFolder,fname{j}),fmt);
        imageNames{i,j} = fname{j};
    end
    % Status update
    fprintf('[Complete]\n');
end

%% Delete status figure
if ~isempty(dt)
    delete(fig);
end

%% Clear preview
if tfShowCheckerboard
    for j = 1:numel(prv)
        clearPreview(prv(j));
    end
end

%% Package output(s)
if nargout > 0
    varargout{1} = imageFolder;
end

if nargout > 1
    varargout{2} = imageNames;
end