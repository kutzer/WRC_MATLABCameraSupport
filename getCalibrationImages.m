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
%   imageFolder = getCalibrationImages(___) returns the full path to the
%   imageFolder.
%
%   [imageFolder,imageNames] = getCalibrationImages(___) returns the full 
%   path to the imageFolder and a cell array of the image names used.
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
%

%% Parse and check inputs
% Check number of inputs
narginchk(1,4);
% Set default values
imageName = [];
imageFolder = [];
n = [];
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

%% Get images
fmt = 'png';
for i = 1:n
    % Status update
    fprintf('Getting calibration image %d of %d...',i,n);
    
    if n > 1
        msg = sprintf('Place checkerboard in camera FOV (%d of %d)...[Enter to Continue]',i,n);
        % Wait for user
        uiwait(...
            msgbox(msg,'Grab Image')...
            );
    else
        fprintf('<SINGLE IMAGE, UIWAIT>...');
    end
    
    % Grab image(s)
    drawnow
    for j = 1:numel(prv)
        im{j} = get(prv(j),'CData');
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

%% Package output(s)
if nargout > 0
    varargout{1} = imageFolder;
end

if nargout > 1
    varargout{2} = imageNames;
end