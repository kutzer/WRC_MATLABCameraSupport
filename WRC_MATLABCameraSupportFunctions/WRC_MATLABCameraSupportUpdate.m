function WRC_MATLABCameraSupportUpdate
% WRC_MATLABCAMERASUPPORTUPDATE download and update the WRC MATLAB Camera
% Support Package. 
%
%   M. Kutzer 27Feb2016, USNA

% Updates
%
%
% TODO - Find a location for Example SCRIPTS
% TODO - update function for general operation

% Update WRC MATLAB Camera Support
ToolboxUpdate('WRC_MATLABCameraSupport');

end

function ToolboxUpdate(toolboxName)

%% Setup functions
ToolboxVer = str2func( sprintf('%sVer',toolboxName) );
installToolbox = str2func( sprintf('install%s',toolboxName) );

%% Check current version
A = ToolboxVer;

%% Setup temporary file directory
fprintf('Downloading %s...',toolboxName);
tmpFolder = sprintf('%s',toolboxName);
pname = fullfile(tempdir,tmpFolder);

%% Download and unzip toolbox (GitHub)
url = sprintf('https://github.com/kutzer/%s/archive/master.zip',toolboxName);
try
    % Original download/unzip method using "unzip"
    fnames = unzip(url,pname);
    
    fprintf('SUCCESS\n');
    confirm = true;
catch
    try
        % Alternative download method using "urlwrite"
        % - This method is flagged as not recommended in the MATLAB
        % documentation.
        % TODO - Consider an alternative to urlwrite.
        tmpFname = sprintf('%s-master.zip',toolboxName);
        urlwrite(url,fullfile(pname,tmpFname));
        fnames = unzip(fullfile(pname,tmpFname),pname);
        delete(fullfile(pname,tmpFname));
        
        fprintf('SUCCESS\n');
        confirm = true;
    catch
        fprintf('FAILED\n');
        confirm = false;
    end
end

%% Check for successful download
alternativeInstallMsg = [...
    sprintf('Manually download the %s Toolbox using the following link:\n',toolboxName),...
    sprintf('\n'),...
    sprintf('%s\n',url),...
    sprintf('\n'),...
    sprintf('Once the file is downloaded:\n'),...
    sprintf('\t(1) Unzip your download of the "%s"\n',toolboxName),...
    sprintf('\t(2) Change your "working directory" to the location of "install%s.m"\n',toolboxName),...
    sprintf('\t(3) Enter "install%s" (without quotes) into the command window\n',toolboxName),...
    sprintf('\t(4) Press Enter.')];
        
if ~confirm
    warning('InstallToolbox:FailedDownload','Failed to download updated version of %s Toolbox.',toolboxName);
    fprintf(2,'\n%s\n',alternativeInstallMsg);
	
    msgbox(alternativeInstallMsg, sprintf('Failed to download %s Toolbox',toolboxName),'warn');
    return
end

%% Find base directory
install_pos = strfind(fnames, sprintf('install%s.m',toolboxName) );
sIdx = cell2mat( install_pos );
cIdx = ~cell2mat( cellfun(@isempty,install_pos,'UniformOutput',0) );

pname_star = fnames{cIdx}(1:sIdx-1);

%% Get current directory and temporarily change path
cpath = cd;
cd(pname_star);

%% Install Toolbox
installToolbox(true);

%% Move back to current directory and remove temp file
cd(cpath);
[ok,msg] = rmdir(pname,'s');
if ~ok
    warning('Unable to remove temporary download folder. %s',msg);
end

%% Complete installation
fprintf('Installation complete.\n');

end
