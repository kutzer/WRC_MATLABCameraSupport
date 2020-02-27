function L = calculateLossMatrix(P_wCondx)
% CALCULATELOSSMATRIX
%
% P_wCondx - m-element cell array with each cell containing an m x n array
%   m - total number of objects being classified
%   n - total number of classification samples

% Define total number of objects
m = numel(P_wCondx);
m_star = size(P_wCondx{1},1);
if m ~= m_star 
    error('Total number of cells must match the total number of rows per cell.');
end
% Define total number of samples
n = size(P_wCondx{1},2);

% Combine cells of P_wCondx to make P and define R
% NOTE: This assumes we area defining a risk of 10 for our ground truth and
% a risk of 1000 for everything else. This is somewhat arbitrary.
P = [];
R = [];
r_low = 10;    % Low risk value 
r_high = 1000;  % High risk value 
for i = 1:m
    % Combine P
    P = [P,P_wCondx{i}];
    % Combine R
    R_tmp = r_high * ones(size(P_wCondx{i}));
    R_tmp(i,:) = r_low;
    R = [R,R_tmp];
end

% Calculate columns of L ( rows of transpose(L) )
for i = 1:m
    % Account for zero along diagonal
    P_tmp = P;
    P_tmp(i,:) = [];
    % Calculate row of transpose( L )
    L_tmp = R(i,:) * pinv( P_tmp );
    % Populate column of L
    LL_tmp = zeros(m,1);
    if i == 1
        LL_tmp(2:m) = L_tmp;
    end
    if i > 1 && i < m
        LL_tmp(1:(i-1)) = L_tmp(1:(i-1));
        LL_tmp((i+1):m) = L_tmp(i:end);
    end
    if i == m
        LL_tmp(1:(m-1)) = L_tmp;
    end
    L(:,i) = transpose( LL_tmp );
end

%% Impose only positive loss
L = L - min(min(L)) + 10;
% Impose constraint of zeros along diagonal
L = L - diag( diag(L) );