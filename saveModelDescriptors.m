%% quick script to calculate and svae a certain sets of descriptors for the
% model, using the speedyDescriptors Implementation

% shuffle seed for random locations
rng('shuffle');

% read model pointcluod
path = 'Data/PointClouds/';
pcModel = pcread(strcat(path, 'Render.pcd'));

% sample options
sampleOptM.d = 0.3;
sampleOptM.margin = 3.5; % should equal R

% descriptor options
descOptM.ALIGN_POINTS = true;
descOptM.min_pts = 500;
descOptM.max_pts = 6000;
descOptM.R = 3.5; % should equal margin
descOptM.thVar = [3, 1.5]; 
descOptM.k = 0.85;
descOptM.VERBOSE = 1;
descOptM.max_region_size = 15;


[featModel, descModel] = ...
        speedyDescriptors(pcModel.Location, sampleOptM, descOptM);   

% save the features and descriptors to workspace
save('Data/Descriptors/featModel0.3_render.mat', 'featModel');
save('Data/Descriptors/descModel0.3_render.mat', 'descModel');