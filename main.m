clear, clc, close all
addpath Source\

% Настройки путей
configDir = "configs/";
configName = "test1"; 
configPath = configDir + configName + ".json";

if ~exist('results', 'dir'), mkdir('results'); end

scenarios = GenerateTests(configPath); 

conf = jsondecode(fileread(configPath));
patienceLimit = 3; % По умолчанию
if isfield(conf, 'StudyParams')
    if isfield(conf.StudyParams, 'Patience')
        patienceLimit = conf.StudyParams.Patience;
    else
        patienceLimit = 3;
    end
    if isfield(conf.StudyParams, 'MinBerThreshold')
        minBerThreshold = conf.StudyParams.MinBerThreshold;
    else
        minBerThreshold = 1e-6; 
    end
end
 
SimulationResults = struct();

for j_scenario = 1:length(scenarios)
    currScenario = scenarios(j_scenario);
    snrVec = currScenario.Value.SnrVec;
    numPackets = currScenario.Value.NumPackets;    
    patienceCounter = 0; 
    
    fprintf('\n=== Тест: %s ===\n', currScenario.Key);
    for tech = ["SE", "BF"]

        switch tech 
            case "SE"
                fieldName = "SpatialExpansion";
            case "BF"
                fieldName = "Beamformer";
        end

        fprintf("Технология: %s...\n", fieldName);

        for j_snr = 1:length(snrVec)
            [totalErrors.(tech), totalBits] = deal(0);
            currentSNR = snrVec(j_snr);
            
            for p = 1:numPackets
                params = currScenario.Value;
                params.CurrentSNR = currentSNR;
                
                Scenario = GenerateScenario(params);
                Res.(fieldName) = ScenarioRunner(Scenario, tech);
                
                totalErrors.(tech) = totalErrors.(tech) + Res.(fieldName).ErrCount;
                totalBits = totalBits + (Scenario.cfgVHT.PSDULength * 8);
            end

            ber.(tech)(j_snr) = totalErrors.(tech)/ totalBits;

            fprintf("SNR: %5 .2f | BER: %.5f\n", currentSNR, ber.(tech)(j_snr));

        end
    end
    % Сохранение
    SimulationResults(j_scenario).Key = currScenario.Key;
    SimulationResults(j_scenario).snrVec = snrVec;
    SimulationResults(j_scenario).berSE = berSE;
    SimulationResults(j_scenario).berBF = berBF;
    SimulationResults(j_scenario).params = currScenario.Value;
end

save("results/results_" + configName + ".mat", "SimulationResults");
fprintf('\nРезультаты сохранены в results/results_%s.mat\n', configName);