function imageFolder = getCalibrationImages(cam,varargin)
% GETCALIBRATIONIMAGES aquires a set number of images from a designated
% videoinput object and saves them to a specific directory for use in camera
% calibration.
%   getCalibrationImages(cam) acquires a set of 12 images with the base
%   image name "im" in an image folder named 
%   "Calibration Data Set, ..., Experimental ..." containing a date stamp 
%   and a unique time of creation.
%
%   NOTE: Multiple camera objects can be specified within cam using a 
%   cell-array (e.g. cams = {cam1,cam2,...}). Doing so will update the 
%   image names to "cam1_im...", "cam2_im...", etc. Specifying a different 
%   image name will change "im".
%
%   getCalibrationImages(cam,n) acquires a set of n images with default
%   base image name and image folder specified above. 
%
%   getCalibrationImages(cam,imageName,imageFolder) acquires a set of 12
%   images with the base image name specified in "imageName" and an image 
%   folder name specified in "imageFolder".
%
%   getCalibrationImages(cam,imageName,imageFolder,n) acquires a set of n
%   images with the base image name specified in "imageName" and an image 
%   folder name specified in "imageFolder".
%
%   imageFolder = getCalibrationImages(___) returns the full path to the
%   imageFolder.
%
%   See also initCamera cameraCalibrator
%
%   M. Kutzer, 30Jan2016, USNA

% Updates
%   02Feb2016 - Added multiple camera option.
%   18Jan2017 - Updated to migrate from webcam to videoinput objects

%% Parse and check inputs
% Make single camera object into cell-array
if numel(cam) == 1 && ~iscell(cam)
    cam = {cam};
end
% Check number of inputs
narginchk(1,4);
% Set default values
imageName = [];
imageFolder = [];
n = [];
% Check videoinput object
for i = 1:numel(cam)
    switch lower( class(cam{i}) )
        case 'videoinput'
            % Specified camera object is a videoinput
        otherwise
            error('getCal:BadCam',...
                ['Specified camera object must be a "videoinput". Use:\n',...
                ' -> cam = initCamera; or \n',...
                ' -> cam = videoinput(___); %% e.g. videoinput(''winvideo'')']);
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
    imageFolder = sprintf('Calibration Data Set, %s, Experimental %d',...
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
if ~isdir(imageFolder)
    mkdir(imageFolder);
end

%% Get preview
for i = 1:numel(cam)
    prv(i) = preview(cam{i});
end

%% Get images
for i = 1:n
    % Status update
    fprintf('Getting calibration image %d of %d...',i,n);
    % Wait for user
    uiwait(...
        msgbox('Place checkerboard in camera FOV...[Enter to Continue]','Grab Image')...
        );
    % Grab image(s)
    drawnow
    for j = 1:numel(prv)
        im{j} = get(prv(j),'CData');
    end
    % Define image filename(s)
    if numel(im) == 1
        fname{1} = sprintf('%s%d.jpg',imageName,i);
    else
        for j = 1:numel(im)
            fname{j} = sprintf('cam%d_%s%d.jpg',j,imageName,i);
        end
    end
    % Save image(s)
    for j = 1:numel(im)
        imwrite(im{j},fullfile(imageFolder,fname{j}),'jpg');
    end
    % Status update
    fprintf('[Complete]\n');
end