function [weights,params] = lstm_train(xData_t,yData_t,netMexName,params,weights_hotstart)
%% Parameters
lstm_parameters;

%% Convert data
xData_t = cast(xData_t,typename);
yData_t = cast(yData_t,typename);

%% Induced parameters
batchSizeThread = batchSize / NumThreads;
% Sequence data, take out the amount of periods
lengthData = size(xData_t,2) - periods+1;

%% Initiate networks
MEX_TASK = MEX_NNET_INFO;
eval(netMexName);
% sizeWeights will be returned by MEX
% Init weights
rng(0729);
weights = (-1 + 2*rand(sizeWeights,1,typename))*initWeightsScale;
dweights_thread = zeros([size(weights) NumThreads],typename);
RmsProp_r = ones(size(weights),typename);

% Overwrite
if (nargin>=5)
    if numel(weights_hotstart) == numel(weights)
        weights = weights_hotstart;
    else
        error('weights_hotstart size not correct');
    end
end

%% Pre treatment
MEX_TASK = MEX_INIT;
eval(netMexName);
MEX_TASK = MEX_PRE_TREAT;
eval(netMexName);

%% Prepare space for thread data
% Split training data based on batchSize
lengthDataBatch = floor(lengthData/batchSize);
batchDataStride = 1:lengthDataBatch:lengthDataBatch*batchSize;
% 0 based
batchDataStride = batchDataStride - 1;
% Space for loss
loss_thread = zeros(periods,batchSizeThread,NumThreads,typename);

%% Train
MEX_TASK = MEX_TRAIN;
saveCount = 0;
timeCount = tic;
last_loss_training = inf;
for currentBatch=1:lengthDataBatch
    eval(netMexName);
    
    % Collapse thread dweights
    dweights = reshape(dweights_thread,[],NumThreads);
    % Sum over training set
    dweights = sum(dweights(:,1:end-1),2);
    dweights = reshape(dweights,size(weights));
    
    % Adjust learning rate
    RmsProp_r = (1-RmsPropDecay)*dweights.^2 + RmsPropDecay*RmsProp_r;
    RmsProp_v = learningRate ./ (RmsProp_r.^0.5);
    % RmsProp_v = min(RmsProp_v,learningRate*10);
    % RmsProp_v = max(RmsProp_v,learningRate/10);
    RmsProp_v = RmsProp_v.* dweights;
    
    %  Learn
    weights = weights - RmsProp_v;
    
    % Output
    saveCount = saveCount + 1;
    if mod(saveCount,saveFreq)==0
        output_func;
    end
    
    batchDataStride = batchDataStride + 1;
end
end
