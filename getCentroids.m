function [centroid,roiArea] = getCentroids(videoFrame,lowContrLevel,highContrLevel)

frI = rgb2gray(videoFrame);

frIU = im2uint8(frI+1,'indexed');
frIUc = imadjust(frIU,[lowContrLevel;highContrLevel],[0;1]);  %%contrast adjustment

frIUc = imbinarize(frIUc);               %% turn image into 0's and 1's
frIUc = imcomplement(frIUc);             %% inverse image

% figure(3)
% imagesc(frIUc)

cc = bwconncomp(frIUc, 4);               %% find connected pixles

[AreaSizes,areaInds] = sort(cellfun('length',cc.PixelIdxList),'descend');   %extract the largest connected pixel area

grabROIs = find(AreaSizes > 2000);

if length(grabROIs) > 1
    [bigAreaY,bigAreaX] = ind2sub(cc.ImageSize,cc.PixelIdxList{areaInds(2)});
elseif length(grabROIs) == 1
    [bigAreaY,bigAreaX] = ind2sub(cc.ImageSize,cc.PixelIdxList{areaInds(1)});
else
    roiArea = [];
    centroid = [];
    return
end
 
roiArea = [bigAreaY bigAreaX];
centroid = [median(bigAreaY) median(bigAreaX)];
end