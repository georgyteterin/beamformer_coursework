clear, clc, close all
addpath Source\

rng('shuffle');

configName = "test1";
configPath = "configs/"+configName+".json";
if ~exist('results', 'dir'), mkdir('results'); end

scenarios = GenerateTests(configPath); 
conf = jsondecode(fileread(configPath));

currPool = gcp('nocreate');
if isempty(currPool)
    parpool('Processes', conf.StudyParams.NumWorkers);
elseif currPool.NumWorkers ~= conf.StudyParams.NumWorkers
    delete(currPool);
    parpool('Processes', conf.StudyParams.NumWorkers);
end

perDiffThreshold = 0.25;

SimulationResults = struct();

for j_scenario = 1:length(scenarios)
    curr = scenarios(j_scenario);
    fprintf('=== Сценарий: %s ===\n', curr.Key);
    params = curr.Value;
    for tech = string(conf.StudyParams.tech).'
        switch tech 
            case "SE"
                fieldName = "SpatialExpansion";
            case "BF"
                fieldName = "Beamformer";
        end

    fprintf("Технология: %s...\n", fieldName);
    
    % Начальная сетка
    coarseSnr = linspace(min(params.SnrVec), max(params.SnrVec), 5); % 5 опорных точек для начала
    per.(fieldName) = zeros(size(coarseSnr));

    runPoint = @(snr, tech) calculatePer(snr, tech, params);

    % считаем начальные точки
    for j_snr = 1:length(coarseSnr)
        per.(fieldName)(j_snr) = runPoint(coarseSnr(j_snr), tech);
        fprintf('SNR: %5.2f | per: %.5f\n', coarseSnr(j_snr), per.(fieldName)(j_snr));
        if per.(fieldName)(j_snr) <= conf.StudyParams.MinPerThreshold
            coarseSnr(j_snr + 1: end) = [];
            break;
        end
    end

    refinementDone = true;
    level = 0;
    while refinementDone && level < conf.StudyParams.maxRefinements
        refinementDone = false;
        newper = [];
        newSnr = [];
        
        for j_snr = 1:length(coarseSnr)-1
            snr_left = coarseSnr(j_snr); snr_right = coarseSnr(j_snr+1);
            per_left = per.(fieldName)(j_snr);   per_right = per.(fieldName)(j_snr+1);
            
            isRefinementNeeded = ...
                (abs(per_left - per_right) > perDiffThreshold);
            isDiffHighEnough = ...
                (per_left > conf.StudyParams.MinPerThreshold);
            isStepHighEnough = ...
                (snr_right - snr_left > conf.StudyParams.minSnrStep);
            
            if isRefinementNeeded && isDiffHighEnough && isStepHighEnough
                midSNR = (snr_left + snr_right) / 2;
                midper = runPoint(midSNR, tech);
                
                fprintf('[Уточнение] Добавляем точку SNR: %5.2f\n', midSNR);
                
                newSnr = [newSnr, snr_left, midSNR]; %#ok<AGROW>
                newper  = [newper,  per_left, midper]; %#ok<AGROW>
                refinementDone = true;
            else
                newSnr = [newSnr, snr_left]; %#ok<AGROW>
                newper  = [newper,  per_left]; %#ok<AGROW>
            end
        end 
        coarseSnr = [newSnr, coarseSnr(end)];
        per.(fieldName) = [newper, per.(fieldName)(end)];
        level = level + 1;
    end 
    
    % Сортируем (на всякий случай)
    [coarseSnr, idx] = sort(coarseSnr);
    per.(fieldName) = per.(fieldName)(idx);

    % Сохранение
    SimulationResults(j_scenario).Key = curr.Key;
    SimulationResults(j_scenario).snr.(fieldName) = coarseSnr;
    SimulationResults(j_scenario).per.(fieldName) = per.(fieldName);
    SimulationResults(j_scenario).config = conf;
    end
end

save("results/results_"+configName+".mat", "SimulationResults");


function per = calculatePer(currentSNR, tech, params)
    
    numPackets = params.NumPackets;

    pointScenario.Config = params.Config;
    pointScenario.targetSNR = currentSNR;
    
    tempS = GenerateScenario(params); 
    pointScenario.tgacChannel = tempS.tgacChannel;
    pointScenario.awgnChannel = tempS.awgnChannel;

    errorFlags = zeros(1, numPackets);
    
    parfor i = 1:numPackets
        res = ScenarioRunner(pointScenario, tech); 
        if res.ErrCount > 0
            errorFlags(i) = 1;
        end
    end
    
    per = sum(errorFlags) / numPackets;

    if per == 0
        per = 1 / numPackets; 
    end
    
end