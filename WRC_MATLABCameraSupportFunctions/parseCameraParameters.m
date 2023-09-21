function val = parseCameraParameters(camParams)
% PARSECAMERAPARAMETERS parses a set of camera parameters
%   val = parseCameraParameters(camParams)
%
%   Input(s)
%       camParams - camera parameters object
%
%   Output(s)
%       val - structured array containing parsed camera parameters
%           *.A_c2m      - 3x3 array defining intrinsic matrix
%           *.H_g2c      - n-element cell array containing rigid body
%                          transformations relating calibration 
%                          pattern/grid to the camera frame
%           *.Intrinscis - cameraIntrinsics object
%
%   M. Kutzer, 21Sep2023, USNA

%% Check input(s)
narginchk(1,1);
validateattributes(camParams,{'cameraParameters'},{'nonempty'});

% Required fields (2022b and earlier)
flds2022 = {...
    'ImageSize',... % ----------------------- 2022 & 2023
    'RadialDistortion',... % ---------------- 2022 & 2023
    'TangentialDistortion',... % ------------ 2022 & 2023
    'WorldPoints',... % --------------------- 2022 & 2023
    'WorldUnits',... % ---------------------- 2022 & 2023
    'EstimateSkew',... % -------------------- 2022 & 2023
    'NumRadialDistortionCoefficients',... % - 2022 & 2023
    'EstimateTangentialDistortion',... % ---- 2022 & 2023
    'TranslationVectors',... % <<<<<< Pattern Extrinsic Translation (transpose)
    'ReprojectionErrors',... % -------------- 2022 & 2023
    'DetectedKeypoints',... % --------------- 2022 & 2023
    'RotationVectors',... % ----------------- 2022 & 2023
    'NumPatterns',... % --------------------- 2022 & 2023
    'Intrinsics',... % ---------------------- 2022 & 2023
    'IntrinsicMatrix',... % <<<<<<<<< Intrinsic Matrix (transpose)
    'FocalLength',... % --------------------- 2022 & 2023
    'PrincipalPoint',... % ------------------ 2022 & 2023
    'Skew',... % ---------------------------- 2022 & 2023
    'MeanReprojectionError',... % ----------- 2022 & 2023
    'ReprojectedPoints',... % --------------- 2022 & 2023
    'RotationMatrices',... % <<<<<<<< Pattern Extrinsic Rotation (transpose)
    };

% Required fields (2023a and later)
flds2023 = {...
    'ImageSize',... % ----------------------- 2022 & 2023
    'RadialDistortion',... % ---------------- 2022 & 2023
    'TangentialDistortion',... % ------------ 2022 & 2023
    'WorldPoints',... % --------------------- 2022 & 2023
    'WorldUnits',... % ---------------------- 2022 & 2023
    'EstimateSkew',... % -------------------- 2022 & 2023
    'NumRadialDistortionCoefficients',... % - 2022 & 2023
    'EstimateTangentialDistortion',... % ---- 2022 & 2023
    'ReprojectionErrors',... % -------------- 2022 & 2023
    'DetectedKeypoints',... % --------------- 2022 & 2023
    'RotationVectors',... % ----------------- 2022 & 2023
    'K',... % <<<<<<<<<<<<<<<<<<<<<<<< New Intrinsic Matrix
    'NumPatterns',... % --------------------- 2022 & 2023
    'Intrinsics',... % ---------------------- 2022 & 2023
    'PatternExtrinsics',... % <<<<<<<< New Pattern Extrinsics
    'FocalLength',... % --------------------- 2022 & 2023
    'PrincipalPoint',... % ------------------ 2022 & 2023
    'Skew',... % ---------------------------- 2022 & 2023
    'MeanReprojectionError',... % ----------- 2022 & 2023
    'ReprojectedPoints',... % --------------- 2022 & 2023
    };

