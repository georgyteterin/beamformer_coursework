function Res = ScenarioRunner(Scenario)

    addpath ExampleSource\
    
    % Пересохранение в удобные переменные
    NumTxAnts = Scenario.NumTxAnts; 
    NumSTS = Scenario.NumSTS;
    NumRxAnts = Scenario.NumRxAnts;

    cfgVHT = Scenario.cfgVHT;

    tgacChannel = Scenario.tgacChannel;

    noisePower = Scenario.noisePower;

    awgnChannel = Scenario.awgnChannel;

    % Начало выполнения

    % Indices for extracting fields
    ind = wlanFieldIndices(cfgVHT);

    % Calculate the expected noise variance after OFDM demodulation
    noiseVar = vhtBeamformingNoiseVariance(noisePower,cfgVHT);

    % Number of spatial streams
    Nss = NumSTS/(cfgVHT.STBC+1);
    
    % Get the number of occupied subcarriers in VHT fields
    ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfgVHT);
    Nst = ofdmInfo.NumTones;
    
    % Generate a random PSDU which will be transmitted
    rng(0); % ИЗМЕНЯТЬ ЧИСЛО НА КАЖДОМ ПРОГОНЕ ?
    psdu = randi([0 1],cfgVHT.PSDULength*8,1);

    % 1. Spatial Expansion
    [symSE, chanEstSE] = runSpatialExpansion(cfgVHT, psdu, tgacChannel, awgnChannel, noiseVar);

    % 2. Beamforming (SVD)
    [symBF, chanEstBF] = runBeamforming(cfgVHT, psdu, tgacChannel, awgnChannel, noiseVar);
    
    % Визуализация и вывод
    refSym = wlanReferenceSymbols(cfgVHT);
    
    [Res.Beamformer.Sym, Res.Beamformer.Chest] = deal(symBF, chanEstBF);
    [Res.SpatialExpansion.Sym, Res.SpatialExpansion.Chest]  = deal(symSE, chanEstSE);
    Res.RefSym = refSym;

end

% Вспомогательные функции

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