function [pts_aligned, coeff_unambig, c] = AlignPoints_KNN(pts, varargin)
%% AlignPoints_KNN.m
% PCA for alignment on the k (in %) nearest neighbors of the centroid
% returns the pca-aligned points (pts_aligned),
% the rotation matrix that was used (coeff_unambig)
% and the centroid 

    if length(varargin) == 2
        C1 = varargin{1};
        C2 = varargin{2};
    else
        C1 = false;
        C2 = false;
    end

    % --- 1) find median (L1) / mean (L2)
    c = mean(pts, 1);
    
    % --- 2) get the k nearest neighbors from the centroid
    k = 0.85; % fraction of points considered. (rest assumed outlier)
    K = round(size(pts,1) * k);
    pts_rel = pts - c;
    dists = vecnorm(pts_rel, 2, 2);
    [~, I] = sort(dists);
    pts_sorted = pts_rel(I, :);
    pts_k = pts_sorted(1:K, :);
    
    
    % --- 3) use those points for alignment (get transform)
    if C1 % C1 = true: Not with respecft to centroid!
        [coeff, pts_lrf, ~] = pca(pts_k, 'Algorithm', 'eig', 'Centered', 'off'); 
    else
        [coeff, pts_lrf, ~] = pca(pts_k, 'Algorithm', 'eig'); 
    end

    % ---- use sign disambiguition method for aligned points
    k = size(pts, 1);
    
    if C2 % C2 = true: not with respect to centroid
        pts_lrf = pts*coeff;
    end

    % count number of points with positive sign and see if they
    % dominate 
    x_sign = sum(sign(pts_lrf(:, 1)) == 1) >= k/2;
    z_sign = sum(sign(pts_lrf(:, 3)) == 1) >= k/2;

    % map from {0, 1} to {-1, 1}
    x_sign = x_sign*2-1;
    z_sign = z_sign*2-1;

    %  get y sign so that rotation is proper
    y_sign = det(coeff .* [x_sign, 1, z_sign]);

    % apply signs to transform matrix (pca coefficients)
    coeff_unambig = coeff .* [x_sign, y_sign, z_sign];

    % --- 4) transform all points into the new coordinate system
    pts_aligned = pts*coeff_unambig;
end