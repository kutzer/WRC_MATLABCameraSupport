function pname = combineRobotCameraCalibration(pname01,pname02)
% COMBINEROBOTCAMERACALIBRATION combines the calibration images and saved 
% variables from two directories.
%   combineRobotCameraCalibration(pname01,pname02)
%
%   Input(s)
%       pname01 - character array specifying the path name for folder 1
%       pname02 - character array specifying the path name for folder 2
%
%   Output(s)
%       pname - character array specifying path of combine data
%
%   See also calibrateRobotCameraFromFolder
%
%   M. Kutzer, 02Dec2025, USNA

%% Check input(s)
narginchk(2,2);

if ~isfolder(pname01)
    error('The folder path specified for the first folder is invalid.');
end

if ~isfolder(pname02)
    error('The folder path specified for the second folder is invalid.');
end

%% Define image base name, folder name, and number of images
imBaseNameOut = 'coCal';
calFolderNameOut = sprintf('CombineRobCamCal_%s',char(datetime,'yyyyMMdd_hhmmss'));
fnameRobotInfoOut = 'URcoCalInfo.mat';

if ~isfolder(calFolderNameOut)
    mkdir(calFolderNameOut);
end

%% Combine inputs
pnames = {pname01,pname02};

%% Load and combine images
iter = 0;
for i = 1:numel(pnames)
    % Find images
    c = dir( fullfile(pnames{i},'*.png') );

    % Load data
    try
        S = load( fullfile(pnames{i},fnameRobotInfoOut) );
    catch
        error('%s does not exist in %s.',pnames{i},fnameRobotInfoOut);
    end

    % Define variables
    flds = fields(S);
    for j = 1:numel(flds)
        if exist(flds{j},'var')
            msg = sprintf('%s = [%s, S.%s]',flds{j},flds{j},flds{j});
        else
            msg = sprintf('%s = S.%s;',flds{j},flds{j});
        end
        fprintf('%d - %s\n',exist(flds{j},'var'),msg);
        try
            eval( msg );
        catch ME
            ME.message
        end
    end

    % Move images
    for j = 1:numel(c)
        iter = iter+1;
        source = fullfile(pnames{i},c(j).name);
        fname = sprintf('%s%03d.png',imBaseNameOut,iter);
        destination = fullfile(calFolderNameOut,fname);

        copyfile(source,destination);
    end
end
nImages = iter;

save(fullfile(calFolderNameOut,fnameRobotInfoOut),...
    'q','H_e2o','calFolderNameOut','imBaseNameOut','squareSize','cameraParams','fnameRobotInfoOut','nImages');

%% Package output(s)
pname = calFolderNameOut;