function classifierDataFolder = getClassifierImages(prv,W,idx,n,fnameBase)
% GETCLASSIFIERIMAGES takes a series of images for object classification.
%   classifierDataFolder = GETCLASSIFIERIMAGES(prv,W,idx,n)
%
%   classifierDataFolder = GETCLASSIFIERIMAGES(prv,W,idx,n,fnameBase)
%
%   M. Kutzer, 27Feb2017, USNA

% Updates
%   16Mar2020 - Updated to use preview object instead of camera object.
%   16Mar2020 - Updated to add line feed & image number in pop-up.
%   16Mar2020 - Updated to allow data folder name changes.

%% Set defaults
% Define folder name
if nargin < 5
    classifierDataFolder = sprintf('Classifier Data, %s',W{idx});
else
    classifierDataFolder = sprintf('%s, %s',fnameBase,W{idx});
end

%% Get classifier data

% Create directory if it doesn't exist
if ~isfolder(classifierDataFolder)
    mkdir(classifierDataFolder);
end

% Get classifier images
for i = 1:n
    % Status update
    fprintf('Getting classifier image %d of %d...',i,n);
    % Create filename
    fname = sprintf('classifierImage%d.png',i);
    % Prompt user to put object in FOV
    uiwait(...
        msgbox(...
        sprintf(['Place the “%s” in the camera FOV (%d of %d)...',...
        '[Enter to Continue]'],W{idx},i,n),'Grab Image'));
    % Allow MATLAB to update
    drawnow
    % Get image
    im = get(prv,'CData');
    % Save image to classifier data folder
    imwrite(im,fullfile(classifierDataFolder,fname),'png');
    fprintf('\n');
end
