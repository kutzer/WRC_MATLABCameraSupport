function paramsOut = updateCameraParamsImagesUsed(params,imagesUsed)
% UPDATECAMERAPARAMSIMAGESUSED removed extrinic and keypoint information
% based on an images used binary array.
%   paramsOut = updateCameraParamsImagesUsed(params,imagesUsed)
%
%   Input(s)
%           params - camera parameters 
%       imagesUsed - binary array of images used
%
%   Output(s)
%       paramsOut - camera parameters with extrinsic and keypoint
%                   information adjusted based on binary array
%
%   See also refineCameraIntrinsics
%
%   M. Kutzer, 02Dec2023, USNA

%% Check input(s)
narginchk(2,2)
% TODO - check inputs

%% Package camera parameters
paramsStruct = toStruct(params);

if isfield(paramsStruct,'IntrinsicMatrix')
    % MATLAB 2022b and older
    paramsStruct.RotationMatrices = paramsStruct.RotationMatrices(:,:,imagesUsed);
    paramsStruct.TranslationVectors = paramsStruct.TranslationVectors(imagesUsed,:);
    paramsStruct.ReprojectionErrors = paramsStruct.ReprojectionErrors(:,:,imagesUsed);
    paramsStruct.DetectedKeypoints  = paramsStruct.DetectedKeypoints(:,imagesUsed);
elseif isfield(paramsStruct,'K')
    % MATLAB 2023a and newer
    paramsStruct.RotationVectors    = paramsStruct.RotationVectors(imagesUsed,:);
    paramsStruct.TranslationVectors = paramsStruct.TranslationVectors(imagesUsed,:);
    paramsStruct.ReprojectionErrors = paramsStruct.ReprojectionErrors(:,:,imagesUsed);
    paramsStruct.DetectedKeypoints  = paramsStruct.DetectedKeypoints(:,imagesUsed);
end
paramsOut = cameraParameters(paramsStruct);