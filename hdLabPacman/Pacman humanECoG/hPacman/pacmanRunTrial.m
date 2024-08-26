function pacmanRunTrial(pacmanOpts,visEnviro,pacmanTaskSpecs,eyeTrackerhHandle,ttlStruct)
%script runs trials of pacman task, based on pacman task's runTrial
%note task looks for keyboard input during all trial periods, but pausing
%only works during ITI period and recalibration only works during ITI and
%central cue period! Quitting happens during same periods so no actions are going on.
%
%written by Seth Konig 5/14/2020

%---Set Multi-trial (i.e.session) Variables---%
sessionVars = [];
sessionVars.trialNum = 0;%0; %trial number, always goes up
sessionVars.blockNum = 0; %pseudo block for TTL pulses
sessionVars.rewards = 0;
sessionVars.pauseFlag = false;
sessionVars.quitTask = false;
sessionVars.recalibrate = false;

%do string cat here so not time consuming later
pauseText = ['Paused \n \n Press "' char(pacmanOpts.KB.unpauseKey) '" to resume task!'];

%superstition but I think this helps, SDK
WaitSecs(0.5);
Screen(visEnviro.screen.window,'Flip');

while (sessionVars.trialNum < pacmanOpts.trialParams.ntrials) && ~sessionVars.quitTask 
    try
        %parameters for data index
        dataIndex = 1; %tracks index of gaze and mouse mosition because memory is pre-allocated
        
        %---Initiate Trial---%
        sessionVars.trialNum = sessionVars.trialNum + 1;% Increment trialnum
        sessionVars.blockNum = floor(sessionVars.trialNum/100)+1;%psuedo block for tracking with TTL pulses
        if pacmanOpts.debugMode
            disp(['Initiating Trial number: ' num2str(sessionVars.trialNum) ', in pseudo block ' num2str(sessionVars.blockNum)])
        end
        trialData = pacmanInitiateTrial(pacmanOpts,pacmanTaskSpecs,sessionVars,visEnviro);
        
        %send trial start TTL pulses, send after initiate cuz that opens/closes eye tracker fils
        trialData.trialStart = markEvent('trialStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        markEvent('trialNumber',sessionVars.trialNum,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        markEvent('blockNumber',sessionVars.blockNum,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        
        
        %parameters for tracking time in event periods, placed here for debugging since explicit call makes debugging easier
        itiEventTime = NaN; %for tracking duration in while loop in ITI period
        waitEventTime = NaN; %for tracking wait duration in while loop in wait period
        chaseEventTime = NaN; %for tracking time to choice selection in while loop in choice period
        choice2feedbackEventTime = NaN;%for tracking time in choice to feedback period
        feedbackEventTime = NaN; %for tracking feedback duration during feedback period (period following errors only)
        
        
        
        %---ITI Period----%
        if pacmanOpts.debugMode
            disp('ITI Period Start')
        end
        
        needToDrawPauseText = true;
        
        % GK CODE INSERTION - DRAW PHOTODIODE FOR THE ITI START
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                pacmanTaskSpecs.sizeOpts.boundaries');
        Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
        isPhotoDiodeDrawn = true;
        % Flip by mark-Event
        % GK CODE INSERTION END
        
        trialData.itiStart = markEvent('itiStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);
        itiEventTime = GetSecs() - trialData.itiStart;%explicit call makes debuging much easier
        while itiEventTime < trialData.iti
            % GK CODE INSERTION - STOP DRAWING THE PHOTODIODE FOR THE ITI START    
            if itiEventTime > pacmanTaskSpecs.phdOpts.flashTime && isPhotoDiodeDrawn
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen(visEnviro.screen.window,'Flip');
                isPhotoDiodeDrawn = false;
            end
            % GK CODE INSERTION END

            %get eye position
            if pacmanOpts.eyeParams.eyeTrackerConnected
                % Get eye position
                trialData.eyeSamples(:,dataIndex) = sampleEye(pacmanOpts.eyeParams.eyeTracked);
            end
            dataIndex = dataIndex + 1;
            
            %check for keyboard input
            [sessionVars.pauseFlag, sessionVars.quitTask, sessionVars.recalibrate, ~] = ...
                checkKeyBoardInput(pacmanOpts.KB,sessionVars.pauseFlag,sessionVars.quitTask,sessionVars.recalibrate);
            if sessionVars.pauseFlag && needToDrawPauseText
                Screen(visEnviro.screen.window,'FillRect',pacmanTaskSpecs.colorOpts.background); %clear screen
                
                % GK CODE INSERTION TASK PAUSE 1 PHOTODIODE
                DrawFormattedText(visEnviro.screen.window,pauseText,'center', 'center');

                % Draw photodiode
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
                isPhotoDiodeDrawn = true;
                % Flip by mark-Event

                trialData.paused = markEvent('taskPaused',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);

                % Wait for the photodiode time to end
                waitStart = GetSecs();
                while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end

                % Stop drawing the photodiode
                DrawFormattedText(visEnviro.screen.window,pauseText,'center', 'center');
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen(visEnviro.screen.window,'Flip');
                % GK CODE INSERTION END

                needToDrawPauseText = false;
            elseif ~sessionVars.pauseFlag && ~needToDrawPauseText

                % GK CODE ISERTION TASK RESUME 1 PHOTODIODE
                Screen(visEnviro.screen.window,'FillRect',pacmanTaskSpecs.colorOpts.background); %clear screen
                
                % Draw photodiode
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
                isPhotoDiodeDrawn = true;
                % Flip by mark-Event

                trialData.resume = markEvent('taskResume',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);

                % Wait for the photodiode time to end
                waitStart = GetSecs();
                while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end

                % Stop drawing the photodiode
                Screen(visEnviro.screen.window,'FillRect',pacmanTaskSpecs.colorOpts.background); %clear screen
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen(visEnviro.screen.window,'Flip');
                
                waitStart = GetSecs();
                while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end
                % GK CODE INSERTION END

                needToDrawPauseText = true;
            elseif sessionVars.recalibrate
                trialData.recalibrating = markEvent('recalibrateStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
                EyelinkDoTrackerSetup(eyeTrackerhHandle);
                trialData.doneCalibrating = markEvent('recalibrateEnd',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
                sessionVars.recalibrate = false;
            elseif sessionVars.quitTask
                error('KillTask')
            end
            
            WaitSecs(0.001);%so doesn't loop too fast
            
            if sessionVars.pauseFlag
                itiEventTime = 0; %while paused continually reset ITI time
            else
                itiEventTime = GetSecs() - trialData.itiStart; %update time since event start
            end
        end
                
        % GK CODE INSERTION - DRAW PHOTODIODE FOR THE ITI END
        % Draw the photodiode
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                pacmanTaskSpecs.sizeOpts.boundaries');
        Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
        Screen(visEnviro.screen.window,'Flip');

        trialData.itiEnd = markEvent('itiEnd',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);

        % Wait for the photodiode time to end
        waitStart = GetSecs();
        while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end
        
        % Stop drawing the photodiode
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                pacmanTaskSpecs.sizeOpts.boundaries');
        Screen(visEnviro.screen.window,'Flip');
        
        % Put some delay so the flash can properly register
        waitStart = GetSecs();
        while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end
        % GK CODE INSERTION END
        
        %---Wait Period---%
        %coded as central cue period
        if pacmanOpts.debugMode
            disp('Wait Period Start')
            disp(['ITI duration was ' num2str(itiEventTime)])
        end
        
        needToDrawPauseText = true;
        
        %draw objects on screen
        Screen(visEnviro.screen.window,'FillRect',pacmanTaskSpecs.colorOpts.background); %clear screen
        
        % GK CODE INSERTION - DRAW PHOTODIODE FOR WAIT START
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                pacmanTaskSpecs.sizeOpts.boundaries');
        Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
        % Flip by mark-Event function
        % GK CODE INSERTION END

        visualize_NPCs(visEnviro.screen.window, trialData.playerStartPosition, 0, trialData.playerColor, trialData.playerSize); %player
        for npc = 1:trialData.numNpcs
            if trialData.npcType(npc) == 1 %prey
                visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
            elseif trialData.npcType(npc) == -1 %predator
                visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
            end
        end
        WaitSecs(0.001);
        
        %draw starting positions
        if pacmanOpts.debugMode
            for pt = 1:size(pacmanTaskSpecs.taskData.startingPositions,2)
                zone = [pacmanTaskSpecs.taskData.startingPositions(1,pt)-2,pacmanTaskSpecs.taskData.startingPositions(2,pt)-2,...
                    pacmanTaskSpecs.taskData.startingPositions(1,pt)+2,pacmanTaskSpecs.taskData.startingPositions(2,pt)+2];
                Screen('FillOval', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.white, zone);
            end
            WaitSecs(0.001);
        end

        trialData.waitStart = markEvent('centralCueStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);
        
        % GK CODE INSERTION - RERENDER IMAGE WITHOUT THE PHOTODIODE
        waitStart = GetSecs();
        timeWaited = 0;
        while timeWaited < pacmanTaskSpecs.phdOpts.flashTime; timeWaited = GetSecs() - waitStart; end
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                pacmanTaskSpecs.sizeOpts.boundaries');
        
        visualize_NPCs(visEnviro.screen.window, trialData.playerStartPosition, 0, trialData.playerColor, trialData.playerSize); % player
        for npc = 1:trialData.numNpcs
            if trialData.npcType(npc) == 1 %prey
                visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
            elseif trialData.npcType(npc) == -1 %predator
                visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
            end
        end
        WaitSecs(0.001);
        
        %draw starting positions
        if pacmanOpts.debugMode
            for pt = 1:size(pacmanTaskSpecs.taskData.startingPositions,2)
                zone = [pacmanTaskSpecs.taskData.startingPositions(1,pt)-2,pacmanTaskSpecs.taskData.startingPositions(2,pt)-2,...
                    pacmanTaskSpecs.taskData.startingPositions(1,pt)+2,pacmanTaskSpecs.taskData.startingPositions(2,pt)+2];
                Screen('FillOval', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.white, zone);
            end
            WaitSecs(0.001);
        end
        Screen(visEnviro.screen.window,'Flip');
       
        waitEventTime = GetSecs() - trialData.waitStart - timeWaited; %explicit call makes debuging much easier
        % GK CODE INSERTION END

        while (waitEventTime < trialData.waitTime)
            
            %set joystick position to center of screen, where player is tho they can't move it
            trialData.joystickPosition(1,dataIndex) = trialData.playerStartPosition(1);
            trialData.joystickPosition(2,dataIndex) = trialData.playerStartPosition(2);
            trialData.joystickPosition(3,dataIndex) = GetSecs();
            
            %get eye position
            if pacmanOpts.eyeParams.eyeTrackerConnected
                trialData.eyeSamples(:,dataIndex) = sampleEye(pacmanOpts.eyeParams.eyeTracked);
            end
            
            %get npc position(s)
            for npc = 1:trialData.numNpcs
                trialData.npcPositionX(npc,dataIndex) = trialData.startingPositions{npc}(1);
                trialData.npcPositionY(npc,dataIndex) = trialData.startingPositions{npc}(2);
            end
            
            %check for keyboard input
            [sessionVars.pauseFlag, sessionVars.quitTask, sessionVars.recalibrate, ~] = ...
                checkKeyBoardInput(pacmanOpts.KB,sessionVars.pauseFlag,sessionVars.quitTask,sessionVars.recalibrate);
            if sessionVars.pauseFlag && needToDrawPauseText
                Screen(visEnviro.screen.window,'FillRect',pacmanTaskSpecs.colorOpts.background); %clear screen
                
                % GK CODE INSERTION TASK PAUSE 2 PHOTODIODE
                DrawFormattedText(visEnviro.screen.window,pauseText,'center', 'center');

                % Draw photodiode
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
                isPhotoDiodeDrawn = true;
                % Flip by mark-Event

                trialData.paused = markEvent('taskPaused',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);

                % Wait for the photodiode time to end
                waitStart = GetSecs();
                while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end

                % Stop drawing the photodiode
                DrawFormattedText(visEnviro.screen.window,pauseText,'center', 'center');
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen(visEnviro.screen.window,'Flip');
                % GK CODE INSERTION END

                needToDrawPauseText = false;
            elseif ~sessionVars.pauseFlag && ~needToDrawPauseText
                %draw objects on screen
                Screen(visEnviro.screen.window,'FillRect',pacmanTaskSpecs.colorOpts.background); %clear screen

                % GK CODE ISERTION TASK RESUME 2 PHOTODIODE
                visualize_NPCs(visEnviro.screen.window, trialData.playerStartPosition, 0, trialData.playerColor, trialData.playerSize); %player
                for npc = 1:trialData.numNpcs
                    if trialData.npcType(npc) == 1 %prey
                        visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                    elseif trialData.npcType(npc) == -1 %predator
                        visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                    end
                end
                
                % Draw photodiode
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
                isPhotoDiodeDrawn = true;
                % Flip by mark-Event

                WaitSecs(0.001);
                trialData.resume = markEvent('taskResume',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);

                % Wait for the photodiode time to end
                waitStart = GetSecs();
                while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end

                % Stop drawing the photodiode
                visualize_NPCs(visEnviro.screen.window, trialData.playerStartPosition, 0, trialData.playerColor, trialData.playerSize); %player
                for npc = 1:trialData.numNpcs
                    if trialData.npcType(npc) == 1 %prey
                        visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                    elseif trialData.npcType(npc) == -1 %predator
                        visualize_NPCs(visEnviro.screen.window, trialData.startingPositions{npc},pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                    end
                end
                Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                    pacmanTaskSpecs.sizeOpts.boundaries');
                Screen(visEnviro.screen.window,'Flip');
                waitStart = GetSecs();
                while GetSecs() - waitStart < pacmanTaskSpecs.phdOpts.flashTime; end
                % GK CODE INSERTION END

                needToDrawPauseText = true;
            elseif sessionVars.recalibrate
                trialData.recalibrating = taskData.remarkEvent('recalibrateStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
                EyelinkDoTrackerSetup(eyeTrackerhHandle);
                trialData.doneCalibrating = markEvent('recalibrateEnd',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
                sessionVars.recalibrate = false;
            elseif sessionVars.quitTask
                error('KillTask')
            end
            
            %update time and index
            WaitSecs(0.001);%so doesn't loop too fast
            dataIndex = dataIndex + 1;
            
            if sessionVars.pauseFlag
                waitEventTime = 0; %while paused continually reset event time
            else
                waitEventTime = GetSecs() - trialData.waitStart; %update time since event start
            end
        end
        
        
        
        %---Chase Period---%
        %coded as choice period
        if pacmanOpts.debugMode
            disp('Chase Period Start')
            disp(['Wait duration was ' num2str(feedbackEventTime)])
        end
        
        % Audio Trigger at Beginning of Chase Perioded
        PsychPortAudio('FillBuffer',visEnviro.soundParams.audioOutHandle,[visEnviro.soundParams.STSound; visEnviro.soundParams.STSound]);
        PsychPortAudio('Start', visEnviro.soundParams.audioOutHandle, 1, 0, 0);

        trialData.choiceStart = markEvent('choiceStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        choiceEventTime = GetSecs() - trialData.choiceStart;%explicit call makes debuging much easier
        while (choiceEventTime < pacmanOpts.timingParams.timeout) && isnan(trialData.choiceMade)
            
            %get joystick position
            if any(contains(pacmanOpts.cheaterMode.cheaterNames,pacmanOpts.fileParams.subjID))
                %check if subject is a cheater?, and if yes move input position to central cue location
                cheaterID = contains(pacmanOpts.cheaterMode.cheaterNames,pacmanOpts.fileParams.subjID);
                trialData.joystickPosition(:,dataIndex) = updatePacmanCheaterPosition(trialData.joystickPosition(1:2,dataIndex-1),...
                    trialData.npcPositionX(:,dataIndex-1),trialData.npcPositionY(:,dataIndex-1),...
                    pacmanOpts.joystickParams.sensitivity,trialData.npcValue,pacmanOpts.cheaterMode.cheaterNames{cheaterID});
            else
                trialData.joystickPosition(:,dataIndex) = updateJoystick(trialData.joystickPosition(1:2,dataIndex-1),...
                    pacmanOpts.joystickParams.sensitivity,pacmanTaskSpecs.sizeOpts.playerLimits,pacmanOpts.joystickParams.joystickThreshold,false);
            end
            
            %get eye position
            if pacmanOpts.eyeParams.eyeTrackerConnected
                trialData.eyeSamples(:,dataIndex) = sampleEye(pacmanOpts.eyeParams.eyeTracked);
            end
            
            %move npc(s)
            [trialData.npcPositionX(:,dataIndex),trialData.npcPositionY(:,dataIndex), trialData.choiceMade] = moveNPCs(...
                [trialData.npcPositionX(:,dataIndex-1),trialData.npcPositionY(:,dataIndex-1)],...
                trialData.npcPositionX(:,dataIndex-pacmanTaskSpecs.costOpts.momentumFrames:dataIndex-2),trialData.npcPositionY(:,dataIndex-pacmanTaskSpecs.costOpts.momentumFrames:dataIndex-2),...
                trialData.joystickPosition(:,dataIndex), trialData.npcVelocity, trialData.npcType,pacmanTaskSpecs);
            
            %draw objects on screen
            Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall, pacmanTaskSpecs.sizeOpts.boundaries');
            
            % GK CODE INSERTION DRAW PHOTODIODE
            if choiceEventTime < pacmanTaskSpecs.phdOpts.flashTime
                Screen( 'FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
            end
            % GK CODE INSERTION END


            visualize_NPCs(visEnviro.screen.window, trialData.joystickPosition(1:2,dataIndex-1), 0, trialData.playerColor, trialData.playerSize); %player
            for npc = 1:trialData.numNpcs
                if trialData.npcType(npc) == 1 %prey
                    visualize_NPCs(visEnviro.screen.window, [trialData.npcPositionX(npc,dataIndex-1),trialData.npcPositionY(npc,dataIndex-1)],1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                elseif trialData.npcType(npc) == -1 %predator
                    visualize_NPCs(visEnviro.screen.window, [trialData.npcPositionX(npc,dataIndex-1),trialData.npcPositionY(npc,dataIndex-1)],pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                end
            end
            
            %update visuals every frame &  update time and index
            WaitSecs(0.001);%so doesn't loop too fast
            Screen(visEnviro.screen.window,'Flip');
            choiceEventTime = GetSecs() - trialData.choiceStart; %update time since event start
            dataIndex = dataIndex + 1;
        end
        
        % GK CODE INSERTION DRAW PHOTODIODE FOR CHOICE2FEEDBACK START
        % Render Photodiode
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall, pacmanTaskSpecs.sizeOpts.boundaries');
        Screen( 'FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
        visualize_NPCs(visEnviro.screen.window, trialData.joystickPosition(1:2,dataIndex-1), 0, trialData.playerColor, trialData.playerSize); %player
        for npc = 1:trialData.numNpcs
            if trialData.npcType(npc) == 1 %prey
                visualize_NPCs(visEnviro.screen.window, [trialData.npcPositionX(npc,dataIndex-1),trialData.npcPositionY(npc,dataIndex-1)],1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
            elseif trialData.npcType(npc) == -1 %predator
                visualize_NPCs(visEnviro.screen.window, [trialData.npcPositionX(npc,dataIndex-1),trialData.npcPositionY(npc,dataIndex-1)],pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
            end
        end
        % Flip by mark-Event function
        % GK CODE INSERTION END
             
       
        %---Choice2Feedback Period---%
        if pacmanOpts.timingParams.choice2feedbackDuration > 0 %skip if this value is zero
            trialData.choice2feedbackStart = markEvent('choice2FeedbackStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
            
            %  GK CODE INSERTION START
            % Wait for Photodiode flash to end
            waitStart = GetSecs();
            timeWaited = 0;
            while timeWaited < pacmanTaskSpecs.phdOpts.flashTime; timeWaited = GetSecs() - waitStart; end

            % Stop rendering the photodiode
            Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall, pacmanTaskSpecs.sizeOpts.boundaries');
            visualize_NPCs(visEnviro.screen.window, trialData.joystickPosition(1:2,dataIndex-1), 0, trialData.playerColor, trialData.playerSize); %player
            for npc = 1:trialData.numNpcs
                if trialData.npcType(npc) == 1 %prey
                    visualize_NPCs(visEnviro.screen.window, [trialData.npcPositionX(npc,dataIndex-1),trialData.npcPositionY(npc,dataIndex-1)],1, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                elseif trialData.npcType(npc) == -1 %predator
                    visualize_NPCs(visEnviro.screen.window, [trialData.npcPositionX(npc,dataIndex-1),trialData.npcPositionY(npc,dataIndex-1)],pacmanTaskSpecs.gameOpts.predatorType, trialData.npcColors(npc,:), trialData.npcSize(npc,:));
                end
            end
            Screen(visEnviro.screen.window,'Flip');

            choice2feedbackEventTime = GetSecs() - trialData.choice2feedbackStart;%explicit call makes debuging much easier
            while choice2feedbackEventTime < pacmanOpts.timingParams.choice2feedbackDuration - timeWaited
            % GK CODE INSERTION END
                
                %get joystick position, this doesn't move the player, just
                %looking for post task movement of subject
                trialData.joystickPosition(:,dataIndex) = updateJoystick(trialData.joystickPosition(1:2,dataIndex-1),...
                    pacmanOpts.joystickParams.sensitivity,pacmanTaskSpecs.sizeOpts.playerLimits,pacmanOpts.joystickParams.joystickThreshold,false);
                
                %get eye position
                if pacmanOpts.eyeParams.eyeTrackerConnected
                    % Get eye position
                    trialData.eyeSamples(:,dataIndex) = sampleEye(pacmanOpts.eyeParams.eyeTracked);
                end
                dataIndex = dataIndex + 1;
                
                WaitSecs(0.001);%so doesn't loop too fast
                choice2feedbackEventTime = GetSecs() - trialData.choice2feedbackStart; %update time since event start
            end
        end
        
        
        
        %---Feedback Period---%
        if pacmanOpts.debugMode
            disp('Feedback Period Start')
            disp(['Chase duration was ' num2str(choiceEventTime)])
        end
        
        %setup reward text, value, and sound
        if isnan(trialData.choiceMade)
            trialData.rewardValue = pacmanTaskSpecs.gameOpts.timeOutCost;
        else
            trialData.rewardValue = trialData.npcValue(trialData.choiceMade);
        end
        if  trialData.rewardValue >= 1
            trialData.rewarded = 1;
            rewardText = strcat(['Win! \n \n + ' num2str(trialData.rewardValue) ' points \n \n' ]);
            
            %fill buffer and then play audio
            PsychPortAudio('FillBuffer',visEnviro.soundParams.audioOutHandle,[visEnviro.soundParams.rwdSound; visEnviro.soundParams.rwdSound]);
            PsychPortAudio('Start', visEnviro.soundParams.audioOutHandle, 1, 0, 0);
            markEvent('reward',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        elseif trialData.rewardValue < 0
            trialData.rewarded = -1;
            rewardText = strcat(['Loose! \n \n ' num2str(trialData.rewardValue) ' points \n \n' ]);
            
            %fill buffer and then play audio
            PsychPortAudio('FillBuffer',visEnviro.soundParams.audioOutHandle,[visEnviro.soundParams.norwdSound; visEnviro.soundParams.norwdSound]);
            PsychPortAudio('Start', visEnviro.soundParams.audioOutHandle, 1, 0, 0);
            markEvent('unrewarded',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        else
            trialData.rewarded = 0;
            if trialData.rewardValue == 0
                rewardText = strcat(['Trial timed out \n \n' ]);
            else
                rewardText = strcat(['Trial timed out. Loose! \n \n - ' num2str(trialData.rewardValue) ' points \n \n' ]);
            end
            
            %fill buffer and then play audio
            PsychPortAudio('FillBuffer',visEnviro.soundParams.audioOutHandle,[visEnviro.soundParams.norwdSound; visEnviro.soundParams.norwdSound]);
            PsychPortAudio('Start', visEnviro.soundParams.audioOutHandle, 1, 0, 0);
            markEvent('unrewarded',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        end
        
        sessionVars.rewards = sessionVars.rewards+trialData.rewardValue;
        
        %draw feedback
        rewardText2 = strcat(rewardText,'Total: ',num2str(sessionVars.rewards));
        DrawFormattedText(visEnviro.screen.window,rewardText2 ,'center', 'center',pacmanTaskSpecs.colorOpts.white);

        % GK CODE INSERTION - DRAW PHOTODIODE FOR THE FEEDBACK START
        % Draw the photodiode
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall,...
                pacmanTaskSpecs.sizeOpts.boundaries');
        Screen('FillRect', visEnviro.screen.window, 252:255, pacmanTaskSpecs.phdOpts.rect);
        % Flip by mark-Event function
        
        % Mark the event
        trialData.feedbackStart = markEvent('feedbackStart',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,1);

        % Wait for Photodiode flash to end
        waitStart = GetSecs();
        timeWaited = 0;
        while timeWaited < pacmanTaskSpecs.phdOpts.flashTime; timeWaited = GetSecs() - waitStart; end

        % Stop rendering the photodiode
        Screen( 'FillRect', visEnviro.screen.window, pacmanTaskSpecs.colorOpts.zoneWall, pacmanTaskSpecs.sizeOpts.boundaries');
        DrawFormattedText(visEnviro.screen.window,rewardText2 ,'center', 'center',pacmanTaskSpecs.colorOpts.white);
        Screen(visEnviro.screen.window,'Flip');
        % GK CODE INSERTION END

        %do feedback period loop
        feedbackEventTime = GetSecs() - trialData.feedbackStart; %explicit call makdes debugging easier
        while feedbackEventTime < pacmanOpts.timingParams.feedbackTextDuration
            
            %get joystick position, this doesn't move the player, just
            %looking for post task movement of subject
            trialData.joystickPosition(:,dataIndex) = updateJoystick(trialData.joystickPosition(1:2,dataIndex-1),...
                pacmanOpts.joystickParams.sensitivity,pacmanTaskSpecs.sizeOpts.playerLimits,pacmanOpts.joystickParams.joystickThreshold,false);
            
            %get eye position
            if pacmanOpts.eyeParams.eyeTrackerConnected
                trialData.eyeSamples(:,dataIndex) = sampleEye(pacmanOpts.eyeParams.eyeTracked);
            end
            dataIndex = dataIndex + 1;
            
            %check for keyboard input
            [sessionVars.pauseFlag, sessionVars.quitTask, sessionVars.recalibrate, ~] = ...
                checkKeyBoardInput(pacmanOpts.KB,sessionVars.pauseFlag,sessionVars.quitTask,sessionVars.recalibrate);
            
            WaitSecs(0.001);%so doesn't loop too fast
            feedbackEventTime = GetSecs() - trialData.feedbackStart;
        end

        
        %---Save and Close Trial---%
        if pacmanOpts.debugMode
            disp('Trial End')
            disp(['Feedback duration was ' num2str(feedbackEventTime)])
            disp(' ') %to create new line
        end
        
        %stop any audio device from playing
        PsychPortAudio('Stop', visEnviro.soundParams.audioOutHandle, 0, 0);
        
        %remvoe excess NaNs
        if dataIndex < size(trialData.eyeSamples,2)
            trialData.eyeSamples(:,dataIndex:end) = [];
            trialData.joystickPosition(:,dataIndex:end) = [];
        end
        
        trialData.trialStop =  markEvent('trialEnd',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
        pacmanTaskSpecs = hpacman_closetrial(pacmanOpts,visEnviro,trialData,sessionVars,pacmanTaskSpecs);
        
        
        
    catch ME
        disp(ME)
        disp('Unable to complete a trial!....trying to save existing data');
        
        try  %to save data else close task
            hpacman_closetrial(pacmanOpts,visEnviro,trialData,sessionVars,pacmanTaskSpecs);
            closeTask(ttlStruct,visEnviro);
        catch ME2
            closeTask(ttlStruct,visEnviro);
            rethrow(ME2)
        end
    end
    
end


%---Close Out task---%
%save last trial data
if sessionVars.quitTask %means quit task, try to save data else close task
    %     cbmex('comment',255,0,['MANUAL TASK END']); %% KK added
    trialData.quit = markEvent('taskQuit',NaN,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
    hpacman_closetrial(pacmanOpts,visEnviro,trialData,sessionVars,pacmanTaskSpecs);
    save([pacmanOpts.fileParams.dataDirectory pacmanOpts.fileParams.fileBaseName '_sessionVars.mat'],'sessionVars');
    error('KillTask')
elseif sessionVars.trialNum >= pacmanOpts.trialParams.ntrials
    markEvent('taskStop',0,ttlStruct,visEnviro.screen.window,pacmanOpts.eyeParams.eyeTrackerConnected,0);
    hpacman_closetrial(pacmanOpts,visEnviro,trialData,sessionVars,pacmanTaskSpecs);
    save([pacmanOpts.fileParams.dataDirectory pacmanOpts.fileParams.fileBaseName '_sessionVars.mat'],'sessionVars');
end

%save sessionVars just cuz it's nicer to

end

function [trialData] = pacmanInitiateTrial(pacmanOpts,pacmanTaskSpecs,sessionVars,visEnviro)
%does everything needed to initite each trial
%was hpacman_opentrial.m but turned into own subfunction by Seth Konig 2/17/2020

%---Initializes a new trial structure---%
trialData = [];

trialData.trialNum = sessionVars.trialNum;
trialData.blockNum = sessionVars.blockNum;
disp(['Trial number' num2str(trialData.trialNum)]);

% Significant Keyboard events
trialData.paused = NaN;
trialData.resume = NaN;
trialData.recalibrating = NaN;
trialData.doneCalibrating = NaN;
trialData.quit = NaN;

% Trial timing vars
trialData.trialStart = NaN;   % start of the trial
trialData.itiStart = NaN; % start of ITI
trialData.itiEnd = NaN;   % end of ITI
trialData.waitStart = NaN;    % fixation point appearance/i.e. central cue
trialData.choiceStart = NaN;  %chase start
trialData.choice2feedbackStart = NaN; %choice to feebback start
trialData.feedbackStart = NaN;%feedback period start

% Choice vars
trialData.choiceMade = NaN;   % prey/predator index, NaN if timedout
trialData.rewarded = NaN; %whether subject was rewarded or punished for trial, +/-1
trialData.rewardValue = NaN;%value of reward

% Selected Event Durations
trialData.iti = pacmanOpts.timingParams.drawTime(pacmanOpts.timingParams.iti);
trialData.waitTime = pacmanOpts.timingParams.drawTime(pacmanOpts.timingParams.waitTime);

% Create Sample Data arrays to speed up by pre-allocating space
trialData.joystickPosition = NaN(3,1500);%[X, Y, Time], time is last cuz works better with other code
trialData.npcPositionX = NaN(3,1500);%X position for up to 3 npc including prey/predator
trialData.npcPositionY = NaN(3,1500);%Y position for up to 3 npc including prey/predator

%player data
trialData.playerColor = pacmanTaskSpecs.colorOpts.player;
trialData.playerSize = [pacmanTaskSpecs.sizeOpts.playerWidth, pacmanTaskSpecs.sizeOpts.playerHeight];

%npc data
trialData.npcColors = NaN(3,3);
trialData.npcType = NaN(1,3);
trialData.npcSize = NaN(3,2);
trialData.npcValue = NaN(1,3);
trialData.npcVelocity = NaN(1,3);
trialData.numNpcs = pacmanTaskSpecs.taskData.numNPCs(sessionVars.trialNum);
trialData.npcIndex = pacmanTaskSpecs.taskData.npcIndex(:,sessionVars.trialNum);
for npc = 1:trialData.numNpcs
    if trialData.npcIndex(npc) > 0 %prey
        trialData.npcSize(npc,:) = [pacmanTaskSpecs.sizeOpts.preyWidth pacmanTaskSpecs.sizeOpts.preyHeight];
        trialData.npcColors(npc,:) = pacmanTaskSpecs.colorOpts.prey(trialData.npcIndex(npc),:);
        trialData.npcVelocity(npc) = pacmanTaskSpecs.gameOpts.preyVelocity(trialData.npcIndex(npc));
        trialData.npcValue(npc) = pacmanTaskSpecs.gameOpts.preyValue(trialData.npcIndex(npc));
        trialData.npcType(npc) = 1;
    else %predator
        trialData.npcSize(npc,:) = [pacmanTaskSpecs.sizeOpts.predatorWidth pacmanTaskSpecs.sizeOpts.predatorHeight];
        trialData.npcColors(npc,:) = pacmanTaskSpecs.colorOpts.predator(-trialData.npcIndex(npc),:);
        trialData.npcVelocity(npc) = pacmanTaskSpecs.gameOpts.predatorVelocity(-trialData.npcIndex(npc));
        trialData.npcValue(npc) = pacmanTaskSpecs.gameOpts.predatorValue(-trialData.npcIndex(npc));
        trialData.npcType(npc) = -1;
    end
end

%get initial starting positiosn and do correction for shape to center them
trialData.startingPositions = pacmanTaskSpecs.taskData.startingPosition(:,sessionVars.trialNum);
for npc = 1:trialData.numNpcs
    if trialData.npcType(npc) == 1 %prey
        trialData.startingPositions{npc} = trialData.startingPositions{npc}' +...
            correctPosition4Shape(trialData.npcType(npc),trialData.npcSize(npc,:));
    elseif trialData.npcType(npc) == -1 %predator
        trialData.startingPositions{npc} = trialData.startingPositions{npc}' +...
            correctPosition4Shape(pacmanTaskSpecs.gameOpts.predatorType,trialData.npcSize(npc,:));
    end
end
trialData.playerStartPosition = [visEnviro.screen.origin(1) visEnviro.screen.origin(2)] + ...
    correctPosition4Shape(0,trialData.playerSize);


%---Setup the Eye tracker for a new Trial---%
if pacmanOpts.eyeParams.eyeTrackerConnected
    trialData.eyeSamples = NaN(4,10000);%10 seconds of data, will clean up later
    
    closeLastTrialEyeTrackerFile(sessionVars.trialNum,pacmanOpts.fileParams);
    openNewTrialEyeTrackerFile(sessionVars.trialNum,pacmanOpts.fileParams.fileBaseName);
else
    trialData.eyeSamples = [];
end
end

function pacmanTaskSpecs = hpacman_closetrial(pacmanOpts,visEnviro,trialData,sessionVars,pacmanTaskSpecs)
%Seth Konig 2/18/2020 turned into own function
% Closes the trial and stores all the trial data
%simplified since pre-formatted data at opening of trial

if pacmanOpts.eyeParams.eyeTrackerConnected
    try
        r = Eyelink('RequestTime');
        if r == 0
            WaitSecs(0.1); %superstition
            beforeTime = GetSecs();
            trackerTime = Eyelink('ReadTime'); % in ms
            afterTime = GetSecs();

            pcTime = mean([beforeTime,afterTime]); % in s
            trialData.pcTime = pcTime;
            trialData.trackerTime = trackerTime;
            trialData.trackerOffset = pcTime - (trackerTime./1000);
            % would make legit time = (eyeTimestamp/1000)+offset
        end
    catch
        disp(['Unable to Request Eye Tracker Time on trial#' num2str(sessionVars.trialNum)])
    end

    %if last trial don't forget to move over file
    if sessionVars.trialNum == pacmanOpts.trialParams.ntrials || sessionVars.quitTask
        %must add 1 to trialNum since it's usually for the last trial
        closeLastTrialEyeTrackerFile(sessionVars.trialNum+1,pacmanOpts.fileParams);
    end
end

%save trial data
save([pacmanOpts.fileParams.dataDirectory pacmanOpts.fileParams.fileBaseName '_' num2str(sessionVars.trialNum) '.mat'],'trialData');

% Cleanup screen
Screen(visEnviro.screen.window,'FillRect', pacmanTaskSpecs.colorOpts.background);
Screen(visEnviro.screen.window,'Flip');
end