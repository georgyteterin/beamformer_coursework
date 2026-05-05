clear, clc, close all
addpath Source\

configDir = "configs/";
configName = "test1"; 
configPath = configDir + configName + ".json";

scenarios = GenerateTests(configPath); 

% Инициализируем структуру для хранения результатов
SimulationResults = struct();

for j_scenario = 1:length(scenarios)
    currScenario = scenarios(j_scenario);
    snrVec = currScenario.Value.SnrVec;
    numPackets = currScenario.Value.NumPackets;
    
    berSE = zeros(size(snrVec));
    berBF = zeros(size(snrVec));
    
    fprintf('\n=== Исследование: %s ===\n', currScenario.Key);
    
    for j_snr = 1:length(snrVec)
        if j_snr > 1 && berSE(j_snr-1) == 0 && berBF(j_snr-1) == 0
            fprintf('Достигнут нулевой BER для обоих методов.\n');
            % Заполняем оставшиеся точки SNR нулями и выходим
            berSE(j_snr:end) = 0;
            berBF(j_snr:end) = 0;
            break;
        end

        totalErrorsSE = 0;
        totalErrorsBF = 0;
        totalBits = 0;
        
        for p = 1:numPackets
            params = currScenario.Value;
            params.CurrentSNR = snrVec(j_snr);
            
            Scenario = GenerateScenario(params);
            Res = ScenarioRunner(Scenario);
            
            % Накапливаем ошибки
            totalErrorsSE = totalErrorsSE + Res.SpatialExpansion.ErrCount;
            totalErrorsBF = totalErrorsBF + Res.Beamformer.ErrCount;
            
            % Считаем общее кол-во переданных бит
            totalBits = totalBits + (Scenario.cfgVHT.PSDULength * 8);
        end
        
        % Итоговый BER для данной точки SNR
        berSE(j_snr) = totalErrorsSE / totalBits;
        berBF(j_snr) = totalErrorsBF / totalBits;
        
        fprintf('SNR: %6.2f dB | BER BF: %.4e | BER SE: %.4e\n', ...
            snrVec(j_snr), berBF(j_snr), berSE(j_snr));
    end
    
    % Сохраняем данные сценария в структуру
    SimulationResults(j_scenario).Key = currScenario.Key;
    SimulationResults(j_scenario).snrVec = snrVec;
    SimulationResults(j_scenario).berSE = berSE;
    SimulationResults(j_scenario).berBF = berBF;
    SimulationResults(j_scenario).params = currScenario.Value;
end

% Сохранение результатов в файл
if ~exist('results', 'dir'), mkdir('results'); end
saveDir = "results\";
savePath = saveDir + "results_" + configName + ".mat";
save(savePath, "SimulationResults");

fprintf('\nРезультаты сохранены в файл: %s\n', savePath);
