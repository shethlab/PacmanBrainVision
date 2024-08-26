function [newNPCPositionsX,newNPCPositionsY,detectedCollisions] = ...
    moveNPCs(npcPositions,prevNPCPositionXs,prevNPCPositionYs,playerPosition,npcVelocity,npcType,pacmanTaskSpecs)
%function moves all NPCs in parallel and is based on npc_move_ext but much simplified.
%function also determines if the player collides with any of the NPCs after they move.
%
%function written by Seth Koenig 5/16/20

%---Parameters---%
minCollisionRadius4Scrutiny = 1.1; %minimum radius scale factor to care about actual collisions not near collisions
nPointCircularEstimate = 16;%n-sided polygon to estimate circular shape

%---Pre-allocate space to outputs---%
detectedCollisions = NaN;
newNPCPositions = NaN(size(npcPositions));

%---Define Boundary Conditions---%
minX = pacmanTaskSpecs.sizeOpts.boundaries(1,4)-1;
maxX = pacmanTaskSpecs.sizeOpts.boundaries(3,1) - pacmanTaskSpecs.sizeOpts.preyWidth+1;
minY = pacmanTaskSpecs.sizeOpts.boundaries(4,3)-1;
maxY = pacmanTaskSpecs.sizeOpts.boundaries(2,2) - pacmanTaskSpecs.sizeOpts.preyHeight+1;


%---Get Vectors & Distances Between Player & NPCs---%
numNPCs = sum(~isnan(npcType));
playerNPCVector = NaN(numNPCs,2);
playerNPCDistance = NaN(1,numNPCs);
for npc = 1:numNPCs
    vector = [ playerPosition(1) - npcPositions(npc,1), playerPosition(2) - npcPositions(npc,2) ];	% Distance and direction of the vector
    playerNPCDistance(npc) = ceil(sqrt(sum(vector.^2)));
    playerNPCVector(npc,:) = vector./norm( vector );
end

npc2NPCVector = cell(numNPCs,numNPCs);
npc2NPCDistance = NaN(numNPCs,numNPCs);
if numNPCs > 1
    for npc = 1:numNPCs
        for npc2 = 1:numNPCs
            if npc2 ~= npc
                vector = [ npcPositions(npc2,1) - npcPositions(npc,1), npcPositions(npc2,2) - npcPositions(npc,2) ];	% Distance and direction of the vector
                npc2NPCDistance(npc,npc2) = ceil(sqrt(sum(vector.^2)));
                npc2NPCVector{npc,npc2} = vector./norm( vector );
            end
        end
    end
end


%---Calculate Move NPCs based on costs of position, distance to player, and distance to NPCs--%
for npc = 1:numNPCs
    npcX = ceil(npcPositions(npc,1));
    npcY = ceil(npcPositions(npc,2));
    
    switch npcType(npc)
        case 1 %prey, runs towards prey
            %movement for prey based on position
            positionVector = pacmanTaskSpecs.costOpts.positionCostGrid(npcY,npcX)*...
                [cos(pacmanTaskSpecs.costOpts.directionCostGridX(npcY,npcX)) -sin(pacmanTaskSpecs.costOpts.directionCostGridY(npcY,npcX))];
            
            %movement of prey based on wall
            positionVectorWall = pacmanTaskSpecs.costOpts.wallCostPosition(npcY,npcX)*...
                [cos(pacmanTaskSpecs.costOpts.wallCostdirectionX(npcY,npcX)) -sin(pacmanTaskSpecs.costOpts.wallCostdirectionY(npcY,npcX))];
            
            %movement for prey based on distance to player
            playerVector = -pacmanTaskSpecs.costOpts.player2NPCDistanceWeight(playerNPCDistance(npc)).*playerNPCVector(npc,:);
            
            %movement for prey based on distance to other npcs
            if numNPCs > 1
                npcVector = NaN(numNPCs,2);
                for npc2 = 1:numNPCs
                    if ~isnan(npc2NPCDistance(npc,npc2))
                        npcVector(npc2,:) = -pacmanTaskSpecs.costOpts.npc2NPCDistanceWeight(npc2NPCDistance(npc,npc2)).*npc2NPCVector{npc,npc2};
                    end
                end
                npcVector = nansum(npcVector,1);
                npcVector = npcVector/norm(npcVector);
            else
                npcVector = [0 0];
            end
            
            %get summed vector from all factors
            summedVector = positionVector + positionVectorWall + playerVector + npcVector;
            summedVectorNorm = norm(summedVector);
            
            %calculate movement based on momentum
            momentumVector = [mean(diff(prevNPCPositionXs(npc,:))) mean(diff(prevNPCPositionYs(npc,:)))];
            if summedVectorNorm > pacmanTaskSpecs.costOpts.momentumScaleValue(end)
                momentumScale = pacmanTaskSpecs.costOpts.momentumScaleFunction(end);
            else
                momentumScale = pacmanTaskSpecs.costOpts.momentumScaleFunction(...
                    summedVectorNorm > pacmanTaskSpecs.costOpts.momentumScaleValue(1:end-1) & ...
                    summedVectorNorm <= pacmanTaskSpecs.costOpts.momentumScaleValue(2:end));
            end
                
            %add movement effect to vector
            summedVector = summedVector + momentumScale.*momentumVector;
            summedVector = summedVector/norm(summedVector);
            
            %update npc position based on summed vector times max movovement velocity
            newNPCPositions(npc,:) = npcVelocity(npc).* summedVector + npcPositions(npc,:);
            
        case -1 %predator, runs towards player
            %movement for predator based on position
            positionVector = [0 0];%currently no position constriants
            positionVectorWall = [0 0]; %currently no position constriants
            
            %movement for predator based on distance to player, this is attraction!
            playerVector = pacmanTaskSpecs.costOpts.player2NPCDistanceWeight(playerNPCDistance(npc)).*playerNPCVector(npc,:);
            
            %movement for predator based on distance to other npcs
            if numNPCs > 1
                npcVector = NaN(numNPCs,2);
                for npc2 = 1:numNPCs
                    if ~isnan(npc2NPCDistance(npc,npc2))
                        npcVector(npc2,:) = -pacmanTaskSpecs.costOpts.npc2NPCDistanceWeight(npc2NPCDistance(npc,npc2)).*npc2NPCVector{npc,npc2};
                    end
                end
                npcVector = nansum(npcVector,1);
            else
                npcVector = [0 0];
            end
            
            %update new position
            summedVector = positionVector + positionVectorWall + playerVector + npcVector;
            summedVector = summedVector/norm(summedVector);
            newNPCPositions(npc,:) = npcVelocity(npc).* summedVector + npcPositions(npc,:);
            
        otherwise
            error('Unknown NPC type')
    end
    
    
end

%set for output
newNPCPositionsX = newNPCPositions(:,1);
newNPCPositionsY = newNPCPositions(:,2);


%---Check For Boundary Conditions---%
%maybe more complicated than necessary but keeps velocity so makes it a little harder :)
borderIssues = find(newNPCPositionsX < minX | newNPCPositionsX > maxX | newNPCPositionsY < minY | newNPCPositionsY > maxY);
if ~isempty(borderIssues)
    for npc = 1:length(borderIssues) %usually only one but sometimes multiple
        thisNPC = borderIssues(npc);
        if (newNPCPositionsX(thisNPC) < minX || newNPCPositionsX(thisNPC) > maxX) && ...
                (newNPCPositionsY(thisNPC) < minY || newNPCPositionsY(thisNPC) > maxY) %corner issue, doesn't happen often
            %fix y position
            if newNPCPositionsY(thisNPC) < minY
                newNPCPositionsY(thisNPC) = minY;
            else
                newNPCPositionsY(thisNPC) = maxY;
            end
            
            %fix X position
            if newNPCPositionsX(thisNPC) < minX
                newNPCPositionsX(thisNPC) = minX;
            else
                newNPCPositionsX(thisNPC) = maxX;
            end
                        
        elseif newNPCPositionsX(thisNPC) < minX || newNPCPositionsX(thisNPC) > maxX % x limit issue
            %fix X position
            if newNPCPositionsX(thisNPC) < minX
                newNPCPositionsX(thisNPC) = minX;
            else
                newNPCPositionsX(thisNPC) = maxX;
            end
            
            %estimate how much more you need to move to keep velocity
            totalMovementX = newNPCPositionsX(thisNPC)-npcPositions(thisNPC,1);
            totalMovementY = newNPCPositionsY(thisNPC)-npcPositions(thisNPC,2);
            totalMovement = sqrt(totalMovementX.^2 + totalMovementY.^2);
            extraMovementNeeded = npcVelocity(thisNPC)-totalMovement;

            %updated Y position
            if totalMovementY > 0
                newNPCPositionsY(thisNPC) =  newNPCPositionsY(thisNPC) + extraMovementNeeded;
            else
                newNPCPositionsY(thisNPC) =  newNPCPositionsY(thisNPC) - extraMovementNeeded;
            end
            
        else %newNPCPositionsY(thisNPC) < minY || newNPCPositionsY(thisNPC) > maxY %ylimit issue
            %fix y position
            if newNPCPositionsY(thisNPC) < minY
                newNPCPositionsY(thisNPC) = minY;
            else
                newNPCPositionsY(thisNPC) = maxY;
            end
            
            %estimate how much more you need to move to keep velocity
            totalMovementX = newNPCPositionsX(thisNPC)-npcPositions(thisNPC,1);
            totalMovementY = newNPCPositionsY(thisNPC)-npcPositions(thisNPC,2);
            totalMovement = sqrt(totalMovementX.^2 + totalMovementY.^2);
            extraMovementNeeded = npcVelocity(thisNPC)-totalMovement;            
            
            %updated X position
            if totalMovementX > 0
                newNPCPositionsX(thisNPC) =  newNPCPositionsX(thisNPC) + extraMovementNeeded;
            else
                newNPCPositionsX(thisNPC) =  newNPCPositionsX(thisNPC) - extraMovementNeeded;
            end
        end
    end
end

%make sure none were moved outside by extra movement, slightly redundant
newNPCPositionsX(newNPCPositionsX < minX) = minX; %too far left
newNPCPositionsX(newNPCPositionsX > maxX) = maxX; %too far right
newNPCPositionsY(newNPCPositionsY < minY) = minY; %too far bottom
newNPCPositionsY(newNPCPositionsY > maxY) = maxY; %too far top

%last double check to make sure movement wasn't too large
if any(abs(newNPCPositionsX-npcPositions(:,1)) > 1.1*max(npcVelocity)) ...
        || any(abs(newNPCPositionsY-npcPositions(:,2)) > 1.1*max(npcVelocity))
    error('movement is too large!')
end


%---Check for Player-NPC Collisions---%
%get npc centers and npc2player distances
newPlayerNPCDistance = NaN(1,numNPCs);
playerCenter = playerPosition(1:2)' - correctPosition4Shape(0,[pacmanTaskSpecs.sizeOpts.playerWidth, pacmanTaskSpecs.sizeOpts.playerHeight]);
for npc = 1:numNPCs
    if npcType(npc) == 1 %prey
        npcCenter = newNPCPositions(npc,:) - correctPosition4Shape(npcType(npc) ,[pacmanTaskSpecs.sizeOpts.preyWidth, pacmanTaskSpecs.sizeOpts.preyHeight]);
    else %predator
        npcCenter = newNPCPositions(npc,:) - correctPosition4Shape(pacmanTaskSpecs.gameOpts.predatorType ,[pacmanTaskSpecs.sizeOpts.predatorWidth, pacmanTaskSpecs.sizeOpts.predatorHeight]);
    end
    vector = playerCenter - npcCenter;	% Distance and direction of the vector
    newPlayerNPCDistance(npc) = ceil(sqrt(sum(vector.^2)));
end

%detect collisions
collisions = find(newPlayerNPCDistance < pacmanTaskSpecs.sizeOpts.collisionRadius);
if ~isempty(collisions)
    if length(collisions) > 1
        error('How is this possible?')
    else
        if pacmanTaskSpecs.sizeOpts.collission.collisionRadiusFactor <= minCollisionRadius4Scrutiny
            % actually care about overlap since player & NPC are close enough
            % further scrutinize and this is computational more intensive than
            % estimating circular collisions, could take up to ~10 ms, likley 2-5 ms tho
            
            %make player polygon using n-point estimate of a circle
            effectivePlayerRadius = pacmanTaskSpecs.sizeOpts.playerWidth/2*pacmanTaskSpecs.sizeOpts.collission.collisionRadiusFactor;
            th = 0:2*pi/nPointCircularEstimate:2*pi;
            xunit = effectivePlayerRadius * cos(th) + playerCenter(1);
            yunit = effectivePlayerRadius * sin(th) + playerCenter(2);
            playerPoly = polyshape(xunit(1:end-1),yunit(1:end-1));
            
            %make npc polygon
            xPosNPC = newNPCPositions(collisions,1);
            yPosNPC = newNPCPositions(collisions,2);
            if npcType(collisions) == 1 %square prey
                npcPoly = polyshape([xPosNPC, xPosNPC + pacmanTaskSpecs.sizeOpts.preyWidth, xPosNPC + pacmanTaskSpecs.sizeOpts.preyWidth, xPosNPC],...
                    [yPosNPC, yPosNPC, yPosNPC + pacmanTaskSpecs.sizeOpts.preyHeight, yPosNPC + pacmanTaskSpecs.sizeOpts.preyHeight]);
            elseif npcType(collisions) == -1
                if pacmanTaskSpecs.gameOpts.predatorType == -1 %triangular predator
                    npcPoly = polyshape([xPosNPC, xPosNPC + pacmanTaskSpecs.sizeOpts.preyWidth, xPosNPC + pacmanTaskSpecs.sizeOpts.preyWidth/2],...
                        [yPosNPC, yPosNPC, yPosNPC-pacmanTaskSpecs.sizeOpts.preyHeight]);
                elseif pacmanTaskSpecs.gameOpts.predatorType == -2 %hexaongal predator
                    th = 0:2*pi/8:2*pi;
                    xunit = pacmanTaskSpecs.sizeOpts.preyWidth * cos(th) + xPosNPC;
                    yunit = pacmanTaskSpecs.sizeOpts.preyWidth * sin(th) + yPosNPC;
                    npcPoly = polyshape(xunit(1:end-1),yunit(1:end-1));
                else
                    error('predator type not recognized')
                end
            else
                error('npc type not recognized')
            end
            
            %calculate intersection collision
            polyIntersect = intersect(playerPoly,npcPoly);
            if ~isempty(polyIntersect.Vertices) %then actual collision
                detectedCollisions = collisions;
            end
            
        else
            %made task easier so they don't actually have to collide
            %directly just get close
            detectedCollisions = collisions;
        end
    end
end

end