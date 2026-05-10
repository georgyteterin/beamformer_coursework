clear, clc, close all
addpath Source\

% 1. Настройки путей
configName = "test1";
configPath = "configs/"+configName+".json";
if ~exist('results', 'dir'), mkdir('results'); end

scenarios = GenerateTests(configPath); 
conf = jsondecode(fileread(configPath));

berDiffThreshold = 0.25;   % Порог изменения log10(BER) для добавления точки

SimulationResults = struct();

for j_scenario = 1:length(scenarios)
    curr = scenarios(j_scenario);
    fprintf('=== Сценарий: %s ===\n', curr.Key);
    params = curr.Value;
    for tech = ["SE", "BF"]
        switch tech 
            case "SE"
                fieldName = "SpatialExpansion";
            case "BF"
                fieldName = "Beamformer";
        end

    fprintf("Технология: %s...\n", fieldName);
    
    % Начальная сетка
    coarseSnr = linspace(min(params.SnrVec), max(params.SnrVec), 5); % 5 опорных точек для начала
    ber.(fieldName) = zeros(size(coarseSnr));

    runPoint = @(snr, tech) calculateBER(snr, tech, params);

    % считаем начальные точки
    for j_snr = 1:length(coarseSnr)
        ber.(fieldName)(j_snr) = runPoint(coarseSnr(j_snr), tech);
        fprintf('SNR: %5.2f | BER: %.5f\n', coarseSnr(j_snr), ber.(fieldName)(j_snr));
        if ber.(fieldName)(j_snr) <= conf.StudyParams.MinBerThreshold
            coarseSnr(j_snr + 1: end) = [];
            break;
        end
    end

    refinementDone = true;
    level = 0;
    while refinementDone && level < conf.StudyParams.maxRefinements
        refinementDone = false;
        newBer = [];
        newSnr = [];
        
        for j_snr = 1:length(coarseSnr)-1
            snr_left = coarseSnr(j_snr); snr_right = coarseSnr(j_snr+1);
            ber_left = ber.(fieldName)(j_snr);   ber_right = ber.(fieldName)(j_snr+1);
            
            diff = abs(log10(ber_left+1e-9) - log10(ber_right+1e-9));
            
            if (diff > conf.StudyParams.berDiffThreshold) && (snr_right - snr_left > conf.StudyParams.minSnrStep)
                midSNR = (snr_left + snr_right) / 2;
                midBer = runPoint(midSNR, tech);
                
                fprintf('[Уточнение] Добавляем точку SNR: %5.2f\n', midSNR);
                
                newSnr = [newSnr, snr_left, midSNR]; %#ok<AGROW>
                newBer  = [newBer,  ber_left, midBer]; %#ok<AGROW>
                refinementDone = true;
            else
                newSnr = [newSnr, snr_left]; %#ok<AGROW>
                newBer  = [newBer,  ber_left]; %#ok<AGROW>
            end
        end 
        coarseSnr = [newSnr, coarseSnr(end)];
        ber.(fieldName) = [newBer, ber.(fieldName)(end)];
        level = level + 1;
    end 
    
    % Сортируем (на всякий случай)
    [coarseSnr, idx] = sort(coarseSnr);
    ber.(fieldName) = ber.(fieldName)(idx);

    % Сохранение
    SimulationResults(j_scenario).Key = curr.Key;
    SimulationResults(j_scenario).snr.(fieldName) = coarseSnr;
    SimulationResults(j_scenario).ber.(fieldName) = ber.(fieldName);
    end
end

save("results/results_"+configName+".mat", "SimulationResults");

% --- Вспомогательная функция (добавьте её в конец файла main.m) ---
function ber = calculateBER(currentSNR, tech, params)
    totalErrors = 0;
    totalBits = 0;
    
    % Вшиваем логику пакетов прямо сюда
    for p = 1:params.NumPackets
        p_in = params;
        p_in.CurrentSNR = currentSNR;
        
        % Используем ваши оригинальные функции
        Scenario = GenerateScenario(p_in);
        Res = ScenarioRunner(Scenario, tech);
        
        totalErrors = totalErrors + Res.ErrCount;
        totalBits = totalBits + (Scenario.cfgVHT.PSDULength * 8);
    end
    ber = totalErrors / totalBits;
end