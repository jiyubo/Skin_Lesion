clear all
close all

% %segtMethod = input('segmentation method (otsu or srm): ','s');
computeOtsu = strcmp(segtMethod,'otsu');
computeSrm = strcmp(segtMethod,'srm');

%% DISPLAY OPTIONS %%
melaVsNev=true; % To separate the results between melanoma and nevus
datasetResult=true; % To display the results on the entire dataset

%% PRE AND POSTPROCESSING OPTIONS
channel = 'b'; % color channel ('r', 'g' ,'b', 'X', 'v', or 'meanRGB')
hair_removal = true; % remove hair
compute_blackframe = true; % avoid segmenting the black frame around the image
compute_filling = true; % remove holes in the region
compute_CCA = true; % connected component analysis (removes small islands)
% clear_border = false; % deprecated, do not use

% inputs 
% melanoma and nevus are separated to facilitate analysis of the results
path = '../data/norestriction/'; % either norestriction/ or easysample/ (sample with easy images)
nevusList = dir([path 'training/nevus/*.jpg']); % file list (nevus)
idNevus = cell(1,numel(nevusList));
for i=1:numel(nevusList)
    idNevus{i}=nevusList(i).name(end-6:end-4); % to get the 3 last digits without extension.jpg
end
melaList = dir([path 'training/melanoma/*.jpg']); % file list (melanoma)
idMelanoma = cell(1,numel(melaList));
for i=1:numel(melaList)
    idMelanoma{i}=melaList(i).name(end-6:end-4); % to get the 3 last digits without extension.jpg
end

idList = [idNevus idMelanoma];

% init outputs
segtList=[];
diceList=zeros(numel(idList),1);
jaccardList=zeros(numel(idList),1);
etaList=zeros(numel(idList),1);
                
for i=1:numel(idList)
    
    if i>numel(idNevus)
        Melanoma = true;
        type = 'melanoma';
    else
        Melanoma = false;
        type = 'nevus';
    end
    fprintf('processing image number %d, id = %s, type = %s\n',i, idList{i},type)
    
    %% read image and ground truth
    % read image, normalize values between 0 and 1, resize (for dullRazor)
    
    [I, T] = getData(path, idList{i},type);
    I = imresize(I,[538 720], 'bilinear');
    T = imresize(T,[538 720], 'nearest');
    
    %%%%%%%% PREPROCESSING STAGE %%%%%%%%%%
    [IpreProc, blackM, Ishaved]=preProc(I,channel, hair_removal, compute_blackframe);

    %%%%%%%% SEGMENTATION %%%%%%%%%%
    % OTSU    
    if computeOtsu
        %% otsu
        % Threshold the image using Otsu's paper : 'threshold' is the optimal threshold.
        % eta is Otsu's separability measure at the optimal threshold. 
        % it can be used to evaluate the quality of the thresholding. 
        [threshold, eta,~] = otsu(IpreProc((IpreProc-2*blackM>0)));
        I_seuil = double(IpreProc < threshold)-blackM;
        etaList(i)=eta;
    end
    % SRM
    if computeSrm 
        %% Segmentation parameter Q; Q small gives few segments, Q gives large many segments
        Qlevel=250;

        %% Performing SRM
        Isrm=srm(IpreProc*255,Qlevel);
        Isrm=Isrm/255;

        %% post proc : selectionner les bonnes regions
        figure(3);
        imshow(I,[])
        input=round(ginput(2));  % selectionner patch de peau
        skinpatch=IpreProc(input(1,2):input(2,2),input(1,1):input(2,1));
        skinvalue=mean(skinpatch(:));
        skinmatrix=ones(size(IpreProc))*skinvalue;
        ISrm=double(abs(skinmatrix-Isrm)>60/255);

        if compute_blackframe
            ISrm=double((ISrm - blackM)>0);
        end
        I_seuil=ISrm;
       
    end
    
    %% Post processing
    Isegt=postProc(I_seuil,compute_filling, compute_CCA, clear_border);
    
    %% evaluation
    % compute dice and jaccard index 
    diceList(i) = dice(Isegt, T);
    jaccardList(i) =  jaccard(Isegt,T);
    
    segtList=cat(3,segtList,Isegt);
end
fprintf('Global :\n Mean dice = %.2f, mean jaccard = %.2f \n',mean(diceList),mean(jaccardList));
diceNevus=diceList(1:numel(idNevus));
jaccardNevus=jaccardList(1:numel(idNevus));
etaNevus=etaList(1:numel(idNevus));

diceMela=diceList(numel(idNevus)+1:end);
jaccardMela=jaccardList(numel(idNevus)+1:end);
etaMela=etaList(numel(idNevus)+1:end);
fprintf('Nevus :\n Mean dice = %.2f, mean jaccard = %.2f \n',mean(diceNevus),mean(jaccardNevus));
fprintf('Melanoma :\n Mean dice = %.2f, mean jaccard = %.2f \n',mean(diceMela),mean(jaccardMela));

% %% save
% save(['dice' channel], 'diceList')
% save(['jaccard' channel], 'jaccardList')

%% display
% plot the dice and jaccard indices for all images
if melaVsNev
    F=figure;
    subplot(1,2,1)
    plot(diceNevus,'-s','Color','red')
    hold on
    plot(get(gca,'xlim'), [mean(diceNevus) mean(diceNevus)],'red'); 
    plot(jaccardNevus,'-d','Color', 'blue')
    plot(get(gca,'xlim'), [mean(jaccardNevus) mean(jaccardNevus)],'blue'); 
%     plot(etaNevus,'-o','Color', 'green')
    hold off
    axis([0 numel(diceNevus)+1 0 1])
    title('Dice and jaccard indices : nevus')
    legend('dice','average dice','jaccard','average jaccard','Location','SouthWest')

    subplot(1,2,2)
    plot(diceMela,'-s','Color','red')
    hold on
    plot(get(gca,'xlim'), [mean(diceMela) mean(diceMela)],'red'); 
    plot(jaccardMela,'-d','Color', 'blue')
    plot(get(gca,'xlim'), [mean(jaccardMela) mean(jaccardMela)],'blue'); 
%     plot(etaMela,'-o','Color', 'green')

    hold off
    axis([0 numel(diceMela)+1 0 1])
    title('Dice and jaccard indices : melanoma')
    legend('dice','average dice','jaccard','average jaccard','Location','SouthWest')

    set(0, 'units', 'points')
    p=get(0,'screensize');
    set(F,'Position',[0.25*p(3) 0.25*p(4) 1.3*p(3) p(4)])
end

if  datasetResult
    F2=figure; 
    plot(diceList,'-s','Color','red')
    hold on
    plot(get(gca,'xlim'), [mean(diceList) mean(diceList)],'red'); 
    plot(jaccardList,'-d','Color', 'blue')
    plot(get(gca,'xlim'), [mean(jaccardList) mean(jaccardList)],'blue');  
%     plot(etaList,'-o','Color', 'green')
%     plot(get(gca,'xlim'), [0.8 0.8],'black'); 
    hold off
    axis([0 numel(diceList)+1 0 1])
    title(sprintf('Channel %s - Dice and jaccard indices : d = %g, j = %g',channel,mean(diceList),mean(jaccardList)))
    legend('dice','mean','jaccard', 'mean','Location','SouthWest')
end

