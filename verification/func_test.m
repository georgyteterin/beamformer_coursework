clear, clc, close all
addpath ExampleSource\

% Общие параметры
NumTxAnts = 4; NumSTS = 2; NumRxAnts = 2;
cfgVHT = wlanVHTConfig('ChannelBandwidth','CBW20','APEPLength',4000,...
    'NumTransmitAntennas',NumTxAnts,'NumSpaceTimeStreams',NumSTS,'MCS',4);


noisePower = -37;
noiseVar = vhtBeamformingNoiseVariance(noisePower,cfgVHT);

% Для канала
tgacChannel = wlanTGacChannel('DelayProfile','Model-B', ...
    'ChannelBandwidth',cfgVHT.ChannelBandwidth, ...
    'SampleRate',wlanSampleRate(cfgVHT), ...
    'NumReceiveAntennas',NumRxAnts, ...
    'NumTransmitAntennas',NumTxAnts, ...
    'TransmitReceiveDistance',100, ...
    'RandomStream','mt19937ar with seed', ...
    'Seed',70); % Убедитесь, что нет конфликта имен свойств

% Для шума
awgnChannel = comm.AWGNChannel('NoiseMethod','Variance', ...
    'Variance',10^(noisePower/10), ...
    'RandomStream','mt19937ar with seed', ...
    'Seed',5);

% Данные
rng(0);
psdu = randi([0 1],cfgVHT.PSDULength*8,1);

% 1. Spatial Expansion
[symSE, chanEstSE] = runSpatialExpansion(cfgVHT, psdu, tgacChannel, awgnChannel, noiseVar);

% 2. Beamforming (SVD)
[symBF, chanEstBF] = runBeamforming(cfgVHT, psdu, tgacChannel, awgnChannel, noiseVar);

% Визуализация и вывод
refSym = wlanReferenceSymbols(cfgVHT);
str = sprintf('%dx%d',NumTxAnts,NumRxAnts);
vhtBeamformingPlotConstellation([symSE(:) symBF(:)], refSym, ...
    'Comparison', {[str ' Spatial Expansion'], [str ' Transmit Beamforming']});

fprintf('Power SE: %.2f W, %.2f W\n', sum(mean(abs(chanEstSE).^2,1),3));
fprintf('Power BF: %.2f W, %.2f W\n', sum(mean(abs(chanEstBF).^2,1),3));

function [sym, chanEst] = runSpatialExpansion(cfg, psdu, channel, awgn, noiseVar)
    vhtSE = cfg;
    vhtSE.SpatialMapping = 'Custom';
    vhtSE.SpatialMappingMatrix = helperSpatialExpansionMatrix(vhtSE);
    
    tx = wlanWaveformGenerator(psdu, vhtSE);
    [sym, chanEst] = processReceiver(tx, vhtSE, channel, awgn, noiseVar);
end

function [sym, chanEst] = runBeamforming(cfg, psdu, channel, awgn, noiseVar)
    % Sounding (NDP) - пакет без данных для оценки канала
    vhtSound = cfg;
    vhtSound.APEPLength = 0; 
    vhtSound.NumSpaceTimeStreams = cfg.NumTransmitAntennas;
    vhtSound.SpatialMapping = 'Direct';
    
    txSound = wlanWaveformGenerator([], vhtSound);
    % Для NDP передаем 0 в noiseVar и сбрасываем канал
    reset(channel); reset(awgn);
    [~, chanEstSound] = processReceiver(txSound, vhtSound, channel, awgn, 0);
    
    % SVD Calculation
    chanEstSound = vhtBeamformingRemoveCSD(chanEstSound, cfg.ChannelBandwidth, vhtSound.NumSpaceTimeStreams);
    chanEstPerm = permute(chanEstSound, [3 2 1]); 
    [~, ~, V] = pagesvd(chanEstPerm, 'econ');
    steeringMatrix = permute(V(:, 1:cfg.NumSpaceTimeStreams, :), [3 2 1]);
    
    % Data Transmission - пакет с данными и steering matrix
    vhtBF = cfg;
    vhtBF.SpatialMapping = 'Custom';
    vhtBF.SpatialMappingMatrix = steeringMatrix;
    
    tx = wlanWaveformGenerator(psdu, vhtBF);
    reset(channel); reset(awgn); % Сброс для честного сравнения с SE
    [sym, chanEst] = processReceiver(tx, vhtBF, channel, awgn, noiseVar);
end

function [sym, chanEst] = processReceiver(tx, cfg, channel, awgn, noiseVar)
    % Добавляем нули для компенсации задержки фильтра
    rx = channel([tx; zeros(15, cfg.NumTransmitAntennas)]);
    rx = awgn(rx);
    
    ind = wlanFieldIndices(cfg);
    tOff = wlanSymbolTimingEstimate(rx(ind.LSTF(1):ind.LSIG(2),:), cfg.ChannelBandwidth);
    
    % LTF Channel Estimation
    vhtltf = rx(tOff+(ind.VHTLTF(1):ind.VHTLTF(2)),:);
    vhtltfDemod = wlanVHTLTFDemodulate(vhtltf, cfg);
    chanEst = wlanVHTLTFChannelEstimate(vhtltfDemod, cfg);
    
    % Безопасное извлечение данных (только если они есть в пакете)
    sym = [];
    if isfield(ind, 'VHTData') && ~isempty(ind.VHTData)
        vhtdata = rx(tOff+(ind.VHTData(1):ind.VHTData(2)),:);
        [~,~,sym] = wlanVHTDataRecover(vhtdata, chanEst, noiseVar, cfg, ...
            'PilotPhaseTracking', 'None');
    end
end
