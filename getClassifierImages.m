function classifierDataFolder = getClassifierImages(cam,W,idx,n)

%% Get camera preview
prv = preview(cam);

%% Get classifier data
% Define folder name
classifierDataFolder = sprintf('Classifier Data, %s',W{idx});
% Create directory if it doesn't exist
if ~isdir(classifierDataFolder)
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
        sprintf(['Place the “%s” in the camera FOV...',...
        '[Enter to Continue]'],W{idx}),'Grab Image'));
    % Allow MATLAB to update
    drawnow
    % Get image
    im = get(prv,'CData');
    % Save image to classifier data folder
    imwrite(im,fullfile(classifierDataFolder,fname),'png');
end
