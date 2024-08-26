function hPacman(rewardStructType, subjId, nTrials, showInstructions)
% hPacman.m
% The human version of the pacaman task.
% Updated and streamlined by Seth Konig 6/17/2020
%
% Input:
%   1) rewardStructType: reward structure type: originalRandom & newBalanced (250 trials)
%   2) nTrials: number of trials, should be a multiple of 100
%   3) showInstructions: true/false flag to show instructions

%add all folders and subfolders to path
mainFolderName = 'hdLabPacman';
thisFunctionPath = mfilename('fullpath');
mainFolderStart = strfind(thisFunctionPath,mainFolderName);
mainFolderPath = thisFunctionPath(1:mainFolderStart+length(mainFolderName));
addpath(genpath(mainFolderPath));

%parse inputs
if nargin < 4
    showInstructions = true;
end
if nargin < 3
    nTrials = 100;
end
if nargin < 2
    subjId = 'TEST';
end
if nargin < 1
    rewardStructType = 'noPredatorRandom'; %AssiaC 09/25/2023
end


%% ---Do Task Setup and Initiate All Variables/Parameters--- %%
try %for task setup
    
    ListenChar(2);
    
    try 
        [emuNum,subjID] = getNextLogEntry(); 
        % emuNum = 0;
        % subjID = 'TEST';
        computerMaxVolume()
    catch
        emuNum = 0;
        subjID = subjId;
    end
    
    %Setup Task
    pacmanOpts = hPacman_params(subjID,rewardStructType, nTrials, emuNum);    % Load & store the task parameters
    [eyeTrackerhHandle,visEnviro,pacmanOpts,ttlStruct] = pacmanOpenTask(pacmanOpts); % general rig stuff, seperate function in case need task specific
    [pacmanTaskSpecs, pacmanOpts] = pacmanSetupStimuli(pacmanOpts,visEnviro);  % specific task function for reward and Stimuli
    
    %hide mouse since this is a joystick task
    HideCursor();
    
catch ME
    disp('Unable to start task!');
    sca
    rethrow(ME)
    if exist('ttlStruct','var') == 1
        closeTask(ttlStruct,visEnviro);
    else
        closeTask();
    end
    rethrow(ME)
end

%% ---Run task--- %%

% start neural recordings with BRK
% % EB inverted the order of start recording and instructions to give enough
% % time to the NSPs to synchronize:
if visEnviro.rig.neuralRecording
    try 
        onlineNSP = TaskComment('start',pacmanOpts.fileParams.neuralRecFilename);
    catch;end
    %writeNextLogEntry();
    visEnviro.rig.neuralRecording=true;
    ttlStruct.neuralRecording = visEnviro.rig.neuralRecording;
end

pause(1)

%Show Instructions to remove learning component and any confusion
try
    if showInstructions
        pacmanInstructions(visEnviro,pacmanOpts,pacmanTaskSpecs);
    end
    
    %then run task
    pacmanRunTrial(pacmanOpts,visEnviro,pacmanTaskSpecs,eyeTrackerhHandle,ttlStruct);
    
    %---End Task & Clean Up---%
    %try
    thankYouText = 'Thank you!';
    DrawFormattedText(visEnviro.screen.window,thankYouText,'center', 'center');
    markEvent('taskStop',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);
    WaitSecs(2);
    closeTask(ttlStruct,visEnviro);
%     if isfield(visEnviro,'soundParams')
%         if isfield(visEnviro.soundParams,'audioOutHandle')
%             PsychPortAudio('Close',visEnviro.soundParams.audioOutHandle);
%         end
%     end
    if visEnviro.rig.neuralRecording
        %StopBlackrockAquisition(pacmanOpts.fileParams.neuralRecFilename,onlineNSP); % For stopping Neural Recording in Baylor EMU
        try TaskComment('stop',pacmanOpts.fileParams.neuralRecFilename); catch; end
        %writeSuccessLogEntry(1)
    end
catch ME
    if contains(ME.message,'KillTask')
        try TaskComment('kill',pacmanOpts.fileParams.neuralRecFilename); catch; end
        %writeSuccessLogEntry(0)
        disp('Escape key pressed!');
    else
        try TaskComment('error',pacmanOpts.fileParams.neuralRecFilename); catch; end
        %writeSuccessLogEntry(0)
        disp('Unable to end task properly!');
    end
    
    if exist('ttlStruct','var') == 1
        closeTask(ttlStruct,visEnviro);
    else
        closeTask();
    end
end
rmpath(genpath(mainFolderPath));

end