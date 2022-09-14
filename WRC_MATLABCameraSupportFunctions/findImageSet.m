function [imageNames,corIndexes] = findImageSet(pName,bName,fExt)
% FINDIMAGESET finds all 
%
%   Input(s)
%       pName - [OPTIONAL] character array defining folder path containing 
%               m calibration images. Use pName = '' to prompt user to
%               select the folder path.
%       bName - [OPTIONAL] character array defining the base filename of 
%               each image. Use bName = '' to automatically detect the base
%               filename.
%       fExt  - [OPTIONAL] character array defining the file extension of
%               each image. Use fExt = '' to automatically detect image
%               file extension.
%
%   Output(s)
%       imageNames - m-element cell array containing image filenames
%                    including specified folder path 
%       corIndexes - m-element index array noting image index for 
%                    defining correspondence
%
%   NOTES: 
%   (1) If no base name (bName) and file extension (fExt) is specified, 
%       this function requires image names seperated using an underscore.
%           Example: 'checker_023.png'
%   (2) Base name (bName) and file extension (fExt) must exactly match
%       those used in image file naming
%           Example: 'testImage123.jpg'
%                     bName = 'testImage', 
%                     fExt ='.jpg'
%
%   M. Kutzer, 14Sep2022, USNA

%% Set default(s)
imageNames  = {};
corIndexes  = [];

%% Check input(s)
narginchk(0,3);

if nargin < 1
    pName = '';
end

if nargin < 2
    bName = '';
end

if nargin < 3
    fExt = '';
end

switch class(pName)
    case {'char','string'}
        pName = char(pName);
    otherwise
        error('Path must be specified as a character array.');
end

switch class(bName)
    case {'char','string'}
        bName = char(bName);
    otherwise
        error('Base filename must be specified as a character array.');
end

switch class(fExt)
    case {'char','string'}
        fExt = char(fExt);
    otherwise
        error('File extension must be specified as a character array.');
end

if numel(fExt) > 1
    if matches(fExt(1),'.')
        fExt(1) = [];
    end
end

%% Define path (if not specified)
if isempty(pName)
    pName = uigetdir;
end

if ~isfolder( char(pName) )
    error('Specified folder is not valid.');
end

%% Find file formats
if isempty(fExt)
    % Get supported image formats
    imExts = {};
    imExtStruct = imformats;
    for i = 1:numel(imExtStruct)
        imExt = imExtStruct(i).ext;
        for j = 1:numel(imExt)
            imExts{end+1} = imExt{j};
        end
    end
else
    % Use user specified format
    imExts{1} = fExt;
end

%% Get folder contents & identify images
D = dir(pName);
idx = find(~[D.isdir]);
tfImage = false(1,numel(idx));

names = cell(1,numel(idx));
exts  = cell(1,numel(idx));
for i = 1:numel(idx)
    % Isolate file parts
    [~,names{i},exts{i}] = fileparts( D( idx(i) ).name );
    % Identify files with image extensions
    tfImage(i) = nnz( matches(imExts,exts{i}(2:end)) ) > 0;
end

% Isolate remaining images
names = names(tfImage);
exts  =  exts(tfImage);

%% Exit if no images are found
if isempty(exts)
    warning('No valid image files found.');
    return
end

%% Isolate unique image formats found
u_exts = unique(exts);
for i = 1:numel(u_exts)
    n_exts(i) = nnz( matches(exts,u_exts{i}) );
    %fprintf('*%s - %d found.\n',u_exts{i},n_fExt(i));
end

%% Select single image format
% Identify most prevalent format
[~,idx] = max(n_exts);

% Prompt user if multiple formats were found
if numel(u_exts) > 1
    [ui_idx,tf] = listdlg('PromptString',{'Select file format.',''},...
        'SelectionMode','single','ListString',u_exts,'InitialValue',idx);
    
    % Use most prevalent format if acton is cancelled
    if tf
        idx = ui_idx;
    else
        warning('Action cancelled by user, using most prevalent format "%s".',u_exts{idx});
    end
end

%% Isolate specified image format
tfFormat = matches(exts,u_exts{idx});

names = names(tfFormat);
exts  =  exts(tfFormat);

% Keep the unique image format
fExt = exts{1};

%% Isolate images with common base filename
% Isolate base names from image numbers
n = numel(names);
baseName   =  cell(1,n);
imgNumStr  =  cell(1,n);
imgNum     = zeros(1,n);
nNumStr    = zeros(1,n);
tfNumbered = false(1,n);
if isempty(bName)
    for i = 1:n
        splitStr = regexp(names{i},'\_','split');
        switch numel(splitStr)
            case 2
                baseName{i}   = sprintf('%s_',splitStr{1});
                imgNumStr{i}  = splitStr{2};
                imgNum(i)     = str2double(imgNumStr{i});
                nNumStr(i)    = numel(imgNumStr{i});
                tfNumbered(i) = true;
            otherwise
                fprintf('Ignoring %s%s - Bad Format.\n',names{i},fExt);
        end
    end
else
    expression = sprintf('%s(\\d*)',bName);
    for i = 1:n
        token = regexp(names{i},expression,'tokens');
        if ~isempty(token)
            if ~isempty(token{1})
                baseName{i}   = bName;
                imgNumStr{i}  = token{1}{1};
                imgNum(i)     = str2double(imgNumStr{i});
                nNumStr(i)    = numel(imgNumStr{i});
                tfNumbered(i) = true;
                continue
            end
        end

        fprintf('Ignoring %s%s - Bad Format.\n',names{i},fExt);

    end
end

baseName  =  baseName(tfNumbered);
imgNumStr = imgNumStr(tfNumbered);
imgNum    =    imgNum(tfNumbered);

%% Exit if no images are found
if isempty(baseName)
    warning('No valid images found.');
    return
end

%% Isolate unique base filenames found
u_baseName = unique(baseName);
for i = 1:numel(u_baseName)
    n_baseName(i) = nnz( matches(baseName,u_baseName{i}) );
    %fprintf('%s_*%s - %d found.\n',u_baseName{i},fExt,n_baseName(i));
end

%% Select single base filename
% Identify most prevalent baseName
[~,idx] = max(n_baseName);

% Prompt user if multiple base filenames were found
if numel(u_exts) > 1
    [ui_idx,tf] = listdlg('PromptString',{'Select base file name.',''},...
        'SelectionMode','single','ListString',u_baseName,'InitialValue',idx);
    
    % Use most prevalent base filename if acton is cancelled
    if tf
        idx = ui_idx;
    else
        warning('Action cancelled by user, using most prevalent base file name "%s".',u_baseName{idx});
    end
end

%% Isolate files with base filename
tfbaseName = matches(baseName,u_baseName{idx});

baseName  =  baseName(tfbaseName);
imgNumStr = imgNumStr(tfbaseName);
imgNum    =    imgNum(tfbaseName);
nNumStr   =   nNumStr(tfbaseName);

% Keep the uniqe base name
bName = baseName{1};

%% Sort images
[~,idx] = sort(imgNum);

%baseName  =  baseName(idx);
imgNumStr = imgNumStr(idx);
imgNum    =    imgNum(idx);
nNumStr   =   nNumStr(idx);

% TODO - check nNumStr for consistency

%% Define image start and end index values
if imgNum(1) == 0
    i0 = 0;
else
    i0 = 1;
end
i1 = imgNum(end);

%% Define image names and correspondence indices
indexVals = i0:i1;
for i = 1:numel(indexVals)
    % Check if index is included
    tfImage = imgNum == indexVals(i);
    switch nnz(tfImage)
        case 1
            imageName = sprintf('%s%s%s',bName,imgNumStr{tfImage},fExt);
            imageNames{end+1} = fullfile(pName,imageName);
            corIndexes(end+1) = i;

            fprintf('\t%s - Correspondence Index %d\n',imageName,corIndexes(i));
        case 0
            % No image exists
        otherwise
            % Multiple images exist
    end
end