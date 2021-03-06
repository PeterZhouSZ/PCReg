%% function to calculate a descriptor for each point
function [feat, desc, ang] = getMomentDescriptors(pts, sample_pts, options)
    % pts: points in pointcloud
    % sample_pts: points to calculate descriptors at
    % options.min_pts: minimum number of points in sphere
    % options.R: Radius of sphere
    % options.thVar: two element vector that contains the two thresholds for the
        % eigenvalues of the covariance matrix (sphere-reject)
    % options.ALIGN_POINTS: use local reference frame?
    % options.CENTER: center to centroid before calculating descriptor?
    % options.k: k nearest neighbors used for alignment
    
    % returns:
        % - feat: feature locations
        % - desc: feature descriptors
        
    % unpack options
    min_pts = options.min_pts;
    max_pts = options.max_pts;
    R = options.R;
    thVar = options.thVar;
    K = options.k;
    ALIGN_POINTS = options.ALIGN_POINTS;
    CENTER = options.CENTER;
    
       
    % preallocate space for features and descriptors, even though we don't
    % know their length
    desc = nan(size(sample_pts, 1), 31);
    feat = nan(size(sample_pts, 1), 3);
    ang = nan(size(sample_pts, 1), 3);
    tic
    parfor i = 1:size(sample_pts, 1) % PARFOR
        c = sample_pts(i, :);
        
        % return local points
        [pts_local, dists] = getLocalPoints(pts, R, c, min_pts, max_pts);

        if ~ isempty(pts_local) 
            num_points = size(pts_local, 1);
            
            % ---- rejection based on PCA variances (== eigenvalues of
            % covariance matrix!!) of k nearest neighbors  
            if strcmp(K, 'all')
                k = num_points;
            else
                k = K;
                % sort points by distance to center for KNN
                [~, I] = sort(dists);
                pts_local = pts_local(I, :);
            end
            pts_k = pts_local(1:k, :);
            if ~(sum(thVar == 1) == 2) || ALIGN_POINTS
                [coeff, pts_lrf, variances] = pca(pts_k, 'Algorithm', 'eig'); 
                % continue if constraints are not met
                if (variances(1) / variances(2) < thVar(1)) || ...
                        (variances(2) / variances(3) < thVar(2))
                    continue
                end
            end

            % ---- use sign disambiguition method for aligned points
            
            % count number of points with positive sign and see if they
            % dominate ( k nearest neighbors)
            if ALIGN_POINTS
                x_sign = sum(sign(pts_lrf(:, 1)) == 1) >= k/2;
                z_sign = sum(sign(pts_lrf(:, 3)) == 1) >= k/2;

                % map from {0, 1} to {-1, 1}
                x_sign = x_sign*2-1;
                z_sign = z_sign*2-1;

                %  get y sign so that rotation is proper
                y_sign = det(coeff .* [x_sign, 1, z_sign]);
                
                % apply signs to transform matrix (pca coefficients)
                coeff_unambig = coeff .* [x_sign, y_sign, z_sign];
                
                % transform all points into the new coordinate system
                pts_local = pts_local*coeff_unambig;
                %r = rand(1, 3)*2*pi;
                %pts_local = pts_local * eul2rotm(r);
                %pts_local = pts_local*coeff;
            end
            
            % ---- calculate the descriptor
            % get first order moments [X, Y Z]
            M1_L2 = mean(pts_local, 1);
            M1_L1 = median(pts_local, 1);
            
            % center to median point coordinates
            if CENTER
                pts_local = pts_local - M1_L1;
                c = c - M1_L1;
            end

            % get second order moments [XX, YY, ZZ, XY, XZ, YZ];
            M2 = (pts_local' * pts_local) / num_points;
            M2_L2 = [M2(1,1), M2(2,2), M2(3,3), M2(1,2), M2(1,3), M2(2, 3)];
            
            % get third order moments
            pts2 = pts_local.^2;
            % [XXX, YYY, ZZZ, XXY, XXZ, YYX, YYZ, ZZX, ZZY] (order differs)
            M3 = (pts2' * pts_local) / num_points;
            % [XYZ]
            mom3XYZ = mean(pts_local(:,1).*pts_local(:,2).*pts_local(:,3), 1);
            M3_L2 = [reshape(M3, 1, []), mom3XYZ];
            
            % get pure and semi-pure fourth order moments
            M4 = (pts2'*pts2) / num_points;
            % [XXXX, YYYY, ZZZZ, XXYY, XXZZ, YYXX, YYZZ, ZZXX, ZZYY] (order
            % differs)
            M4_L2 = reshape(M4, 1, []);

            % descriptor structure is 
            % [X, Y, Z, X, Y, Z, XX, YY, ZZ, XY, XZ, YZ, XXX, YYY, ZZZ, XXY,
            % XXZ, YYX, YYZ, ZZX, ZZY, XYZ], 
            % where the first X, Y, Z are in L2 norm and the second X, Y, Z are
            % in L1 norm
            new_entry = [M1_L2, ...
                         M1_L1, ...
                         M2_L2, ...
                         M3_L2, ...
                         M4_L2];
                     

            desc(i, :) = new_entry;
            feat(i, :) = c;
            %% DEBUG
            ang(i, :) = coeff_unambig(:, 1); % DEBUG
            %desc = [desc; new_entry];
            %feat = [feat; c];
        end
    end
    
    % remove nan rows from desc and feat and return
    mask = find(~isnan(desc(:, 1))); % row indices of filled rows
    desc = desc(mask, :);
    feat = feat(mask, :);
    
    % apply weight by moment to descriptor
    weights.M1 = 0.2; % 0.2
    weights.M2 = 0.75; % 0.75
    weights.M3 = 0.38; % 0.38
    weights.M4 = 0.54; % 0.54

    desc = applyMomentWeight(desc, weights);
    
    toc
end

%% helper function that applies weight to descriptor
function descW = applyMomentWeight(desc, weights)
    descW = desc;
    descW(:, 1:6) = desc(:, 1:6)*weights.M1;
    descW(:, 7:12) = desc(:, 7:12)*weights.M2;
    descW(:, 13:22) = desc(:, 13:22)*weights.M3;
    descW(:, 23:31) = desc(:, 23:31)*weights.M4;
end
