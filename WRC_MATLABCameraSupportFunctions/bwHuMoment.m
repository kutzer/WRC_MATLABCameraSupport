function Hi = bwHuMoment(imBin,i)
% BWHUMOMENT Calculate a Hu's Moment Invariant for a binary image.
%   Hi = BWHUMOMENT(imBin,i) calculate the ith Hu's Moment Invariant 
%   associated binary image.
%
%   References:
%   	[1] Ming-Kuei Hu, "Visual pattern recognition by moment 
%           invariants," in IRE Transactions on Information Theory, 
%           vol. 8, no. 2, pp. 179-187, February 1962.
%
%   M. Kutzer, 14Nov2017, USNA

%% Check inputs
% Check for two inputs
narginchk(2,2);
% Check for valid binary image
if ~isBinaryImage(imBin)
    error('Specificed input must be an MxN binary image');
end

%% Calculate Hu's moment invariant
switch i
    case 1
        V20 = bwNormalizedCentralMoment(imBin,2,0);
        V02 = bwNormalizedCentralMoment(imBin,0,2);
        M00 = bwGeneralMoment(imBin,0,0);
        % -> Definition from [1]
        %Hi = V20 + V02
        % -> Definition from ES450 Course
        Hi = V20 + V02 + 1/(6*M00);
    case 2
        V20 = bwNormalizedCentralMoment(imBin,2,0);
        V02 = bwNormalizedCentralMoment(imBin,0,2);
        V11 = bwNormalizedCentralMoment(imBin,1,1);
        Hi = (V20 - V02)^2 + 4*V11^2;
    case 3
        V30 = bwNormalizedCentralMoment(imBin,3,0);
        V12 = bwNormalizedCentralMoment(imBin,1,2);
        V21 = bwNormalizedCentralMoment(imBin,2,1);
        V03 = bwNormalizedCentralMoment(imBin,0,3);
        Hi = (V30 - 3*V12)^2 + (3*V21 - V03)^2;
    case 4
        V30 = bwNormalizedCentralMoment(imBin,3,0);
        V12 = bwNormalizedCentralMoment(imBin,1,2);
        V21 = bwNormalizedCentralMoment(imBin,2,1);
        V03 = bwNormalizedCentralMoment(imBin,0,3);
        Hi = (V30 + V12)^2 + (V21 + V03)^2;
    case 5
        V30 = bwNormalizedCentralMoment(imBin,3,0);
        V12 = bwNormalizedCentralMoment(imBin,1,2);
        V21 = bwNormalizedCentralMoment(imBin,2,1);
        V03 = bwNormalizedCentralMoment(imBin,0,3);
        Hi = (V30 - 3*V12)*(V30 + V12)*( (V30 + V12)^2 - 3*(V21 + V03)^2 ) + (3*V21 - V03)*(V21 + V03)*( 3*(V30 + V12)^2 - (V21 + V03)^2 );
    case 6
        V20 = bwNormalizedCentralMoment(imBin,2,0);
        V02 = bwNormalizedCentralMoment(imBin,0,2);
        V30 = bwNormalizedCentralMoment(imBin,3,0);
        V12 = bwNormalizedCentralMoment(imBin,1,2);
        V21 = bwNormalizedCentralMoment(imBin,2,1);
        V11 = bwNormalizedCentralMoment(imBin,1,1);
        V03 = bwNormalizedCentralMoment(imBin,0,3);
        Hi = (V20 - V02)*( (V30 + V12)^2 - (V21 + V03)^2 ) + 4*V11*(V30 + V12)*(V21 + V03);
    case 7
        V21 = bwNormalizedCentralMoment(imBin,2,1);
        V03 = bwNormalizedCentralMoment(imBin,0,3);
        V30 = bwNormalizedCentralMoment(imBin,3,0);
        V12 = bwNormalizedCentralMoment(imBin,1,2);
        Hi = (3*V21 - V03)*(V30 + V12)*( (V30 + V12)^2 - 3*(V21 + V03)^2 ) - (V30 - 3*V12)*(V21 + V03)*( 3*(V30 + V12)^2 - (V21 + V03)^2 );
    otherwise
        error('This function is only defined for Hu''s six absolute orthogonal invariants and one skew orthogonal invariant (i.e. H1 - H7).');
end
