%% Documentation for hideGame
%This program as it is written takes in a live webcam video and
%analyzes each frame to find the centroid of the mouse's area. It also
%generates a target that the mouse must navigate to in order to escape the
%bright background light. Once the mouse stands over the target, the target
%moves to a new location. 

%Last update: 9-18-17 by Kostya. kib6@duke.edu

%% set up
clear cam ardi
% ardi = arduino('Com5','Uno');
cam = webcam('Logitech HD Webcam C615');
a = strfind(cam.Resolution,'x');
imWidth = str2double(cam.Resolution(1:a-1))-45;
imHeight = str2double(cam.Resolution(a+1:end))-90;

sigmoidSweepRate = 0.05;
t = [(-1-sigmoidSweepRate) -1:sigmoidSweepRate:1 (1+sigmoidSweepRate)];
changeFunc = mySigmoidFunction(t,7,0);

figure(2);
clf
x = imWidth-40; y = imHeight/2;
while (y < 236 && y > 60) && (x < 520 && x > 60)
            x = randi(imWidth,1);
            y = randi(imHeight,1);
end
priorX = x; priorY = y;

markerColor = 'k';
walls = [0 imWidth 0 imHeight];
axis(walls)
set(gcf,'color','w','Position',[2060 62 1314 896])

% mouseCentroid = plot(0,0,'.g','MarkerSize',20);

figure(1)
clf
colormap(gray)
recPos = [25 50 imWidth imHeight];
webCamSamples = 100000;
for frameInd = 1:webCamSamples
    
    videoFrame = rgb2gray(snapshot(cam));
            
    figure(1)
    subplot(2,2,[1 3])
    imagesc(videoFrame)
    rectangle('Position',recPos)
end

%% play the game
figure(2)
clf
walls = [0 imWidth 0 imHeight];
axis(walls)
set(gca,'XDir','normal','XColor','k','YColor','k','color','k'); set(gcf,'color','k')

figure(1)
clf
colormap(gray)

hitRadius = 40;
touchCount = 15;
stopMove = 0;
trialSuccess = 1;
targetStandCount = 0;
lowContrLevel = 0.1;
highContrLevel = 0.25;

durs = zeros(1,webCamSamples);
breakStatus = zeros(1,webCamSamples);
targetPositions = zeros(2,webCamSamples);
mouseCentroidPositions = zeros(2,webCamSamples);
tic
for frameInd = 1:webCamSamples
    
    videoFrame = snapshot(cam);
    videoFrame = imcrop(videoFrame,recPos);
    
    figure(1)
    subplot(2,2,[1 3])
    imagesc(videoFrame)
    
     % get x&y coordinates for mouse-related pixels 
    [centroid,roiArea] = getCentroids(flipud(videoFrame),lowContrLevel,highContrLevel);
    if isempty(centroid)
        continue
    end
    
    mouseCentroidPositions(:,frameInd) = centroid;
    
    %if trial success, move target to a new location using a new relocation function. 
    %otherwise, keep plotting it in the same location
    
    if trialSuccess == 1 && stopMove == 0   % calculate a new move function
        posChangeInd = 1;
        
        while (x < 50 || x > imWidth-50) || (y < 40 || y > imHeight-40) || (abs(x-priorX)< 150) && (abs(y-priorY)<150)  
            x = randi(imWidth,1);
            y = randi(imHeight,1);
        end
        
        xChange = [priorX ((x-priorX).*changeFunc)+priorX x];  %make the move-trajectory
        yChange = [priorY ((y-priorY).*changeFunc)+priorY y];
        
        trialSuccess = 0;
        breakCount = 0;
        arenaColor = 'w';
        markerColor = 'k';
        
        lowContrLevel = 0.1;
        highContrLevel = 0.25;
        
    elseif trialSuccess == 1 && stopMove == 1
        posChangeInd = 1;

        arenaColor = 'k';
        markerColor = 'k';
        breakCount = breakCount + 1;
        
        if breakCount == 30
            
%             writeDigitalPin(ardi,'D13',1)
%             pause(0.05)
%             writeDigitalPin(ardi,'D13',0)
        end
            
        breakStatus(frameInd) = 1;
        
    elseif trialSuccess == 0 && stopMove == 1   % or keep the target in the same location
%         disp('Maintain target position')
        xChange = x;
        yChange = y;
        posChangeInd = 1;
    end
  
    subplot(2,2,2)
    hold off
%     plot(roiArea(:,2),roiArea(:,1),'.r','MarkerSize',10)
    plot(xChange(posChangeInd),yChange(posChangeInd),'.','MarkerEdgeColor',markerColor,'MarkerSize',20);
    hold on
    plot(centroid(2),centroid(1),'.g','MarkerSize',20)
    set(gca,'YDir','normal')
    axis(walls)
    title(['Frame no. ' num2str(frameInd) ', StandCount = ' num2str(targetStandCount)])

    figure(2)
    plot(xChange(posChangeInd),yChange(posChangeInd),'.','MarkerEdgeColor',markerColor,'MarkerSize',700);
    set(gca,'XDir','normal','XColor',arenaColor,'YColor',arenaColor,'color',arenaColor); set(gcf,'color',arenaColor)
    axis(walls)
    
    if xChange(posChangeInd) == x
        stopMove = 1;
    end
    
    if breakCount >= 300
        stopMove = 0;
    end
    
    posChangeInd = posChangeInd + 1;

    % if the distance between target and mouse is small enough, send
    % instructions to move the target again
    distanceX = abs(centroid(2)- x); distanceY = abs(centroid(1)- y); 
    targetPositions(:,frameInd) = [x;y];
    if distanceX <= hitRadius && distanceY <= hitRadius && targetStandCount < touchCount && breakCount == 0
        targetStandCount = targetStandCount + 1;
    elseif distanceX <= hitRadius && distanceY <= hitRadius && targetStandCount >= touchCount
        trialSuccess = 1;
        targetStandCount = 0;
        
        lowContrLevel = 0;
        highContrLevel = 0.04;
        
        priorX = x;
        priorY = y;
 
        disp('Move target')
    elseif distanceX >= hitRadius && distanceY >= hitRadius && targetStandCount <= touchCount
        targetStandCount = 0;
    end
    
    figure(1)
    subplot(2,2,4)
    plot(repmat((1:frameInd)',1,2),targetPositions(:,1:frameInd)')
    line([0;frameInd],[hitRadius;hitRadius],'LineStyle','--','Color','k')
    ylabel('Distance from Target')
    xlabel('Frame Grab')
    
    drawnow

%     while toc - durs(frameInd-1) < 1/50
%         pause(0.001)
%     end
    durs(frameInd+1) = toc;
    
end

%% Plot sampling rate over time
figure(3)
subplot(2,1,1)
plot(1:frameInd-2,1./diff(durs(1:frameInd-1)))
xlabel('Frame number')
ylabel('Sampling Rate')

subplot(2,1,2)
histogram(1./diff(durs(1:frameInd-1)))

%% Put data in TimeTable format and save

dataMat = [durs(1:frameInd)' targetPositions(:,1:frameInd)' mouseCentroidPositions(:,1:frameInd)' breakStatus(:,1:frameInd)'];

save('C:\Kostya Data\WT-03 dom\Sept 25 2017 moving data.mat','dataMat')