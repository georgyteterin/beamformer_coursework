function Res = ScenarioRunner(Scenario)
    % Подключаем папки с хелперами
    addpath ExampleSource\
    
    cfgVHT = Scenario.cfgVHT;
    tgacChannel = Scenario.tgacChannel;
    awgnChannel = Scenario.awgnChannel;
    targetSNR = Scenario.targetSNR;

    % Генерируем данные (одинаковые для обоих методов в рамках одного прогона)
    rng(0); 
    psdu = randi([0 1], cfgVHT.PSDULength*8, 1);

    % --- ШАГ 1: ФИКСИРУЕМ МОЩНОСТЬ ШУМА (Эфирный фон) ---
    % Мы измеряем мощность на обычном Spatial Expansion. 
    % Это будет наш "эталон" для расчета NoiseVar.
    vhtSample = cfgVHT;
    vhtSample.SpatialMapping = 'Custom';
    vhtSample.SpatialMappingMatrix = helperSpatialExpansionMatrix(vhtSample);
    txSample = wlanWaveformGenerator(psdu, vhtSample);
    
    reset(tgacChannel);
    rxSample = tgacChannel([txSample; zeros(100, size(txSample,2))]);
    basePower = mean(abs(rxSample(:)).^2); 
    % ---------------------------------------------------

    % 1. Запуск Spatial Expansion
    [symSE, ~, bitsSE] = runSpatialExpansion(cfgVHT, psdu, tgacChannel, awgnChannel, targetSNR, basePower);

    % 2. Запуск Beamforming (SVD)
    [symBF, ~, bitsBF] = runBeamforming(cfgVHT, psdu, tgacChannel, awgnChannel, targetSNR, basePower);

    % Считаем количество битовых ошибок для main.m
    Res.SpatialExpansion.ErrCount = biterr(psdu, bitsSE);
    Res.Beamformer.ErrCount = biterr(psdu, bitsBF);

    % Сохраняем результаты для графиков и созвездий
    refSym = wlanReferenceSymbols(cfgVHT);
    Res.Beamformer.Sym = symBF;
    Res.Beamformer.BER = Res.Beamformer.ErrCount / length(psdu);
    
    Res.SpatialExpansion.Sym = symSE;
    Res.SpatialExpansion.BER = Res.SpatialExpansion.ErrCount / length(psdu);
    
    Res.RefSym = refSym;
end

% --- ФУНКЦИИ МЕТОДОВ ПЕРЕДАЧИ ---

function [sym, chanEst, bits] = runSpatialExpansion(cfg, psdu, channel, awgn, targetSNR, basePower)
    vhtSE = cfg;
    vhtSE.SpatialMapping = 'Custom';
    % Используем матрицу со сдвигами CSD (как в примере MathWorks)
    vhtSE.SpatialMappingMatrix = helperSpatialExpansionMatrix(vhtSE);

    tx = wlanWaveformGenerator(psdu, vhtSE);
    reset(channel); reset(awgn);
    [sym, chanEst, bits] = processReceiver(tx, vhtSE, channel, awgn, targetSNR, basePower);
end

function [sym, chanEst, bits] = runBeamforming(cfg, psdu, channel, awgn, targetSNR, basePower)
    % 1. Sounding (NDP пакет для оценки канала)
    vhtSound = cfg;
    vhtSound.APEPLength = 0; 
    vhtSound.NumSpaceTimeStreams = cfg.NumTransmitAntennas;
    vhtSound.SpatialMapping = 'Direct';

    txSound = wlanWaveformGenerator([], vhtSound);
    reset(channel); reset(awgn);
    % Оцениваем канал при SNR 40 дБ (чистая оценка для идеального SVD)
    [~, chanEstSound] = processReceiver(txSound, vhtSound, channel, awgn, 40, []);

    % 2. Расчет Steering Matrix (SVD)
    chanEstSound = vhtBeamformingRemoveCSD(chanEstSound, cfg.ChannelBandwidth, vhtSound.NumSpaceTimeStreams);
    chanEstPerm = permute(chanEstSound, [3 2 1]); 
    [~, ~, V] = pagesvd(chanEstPerm, 'econ');
    
    % Выбираем векторы для наших потоков
    nSTS = min(cfg.NumSpaceTimeStreams, size(V,2));
    steeringMatrix = permute(V(:, 1:nSTS, :), [3 2 1]);

    % 3. Передача данных с Beamforming
    vhtBF = cfg;
    vhtBF.NumSpaceTimeStreams = nSTS;
    vhtBF.SpatialMapping = 'Custom';
    vhtBF.SpatialMappingMatrix = steeringMatrix;

    tx = wlanWaveformGenerator(psdu, vhtBF);
    reset(channel); reset(awgn);
    % Используем базовую мощность шума, чтобы увидеть выигрыш в SNR
    [sym, chanEst, bits] = processReceiver(tx, vhtBF, channel, awgn, targetSNR, basePower);
end

% --- УНИВЕРСАЛЬНЫЙ ПРИЕМНИК ---

function [sym, chanEst, bits] = processReceiver(tx, cfg, channel, awgn, targetSNR, basePower)
    % Пропускаем через канал с запасом на затухание
    rxSignalNoNoise = channel([tx; zeros(150, size(tx,2))]);
    
    % Если basePower не задана (для NDP), считаем по факту, иначе берем эталонную
    if isempty(basePower)
        refP = mean(abs(rxSignalNoNoise(:)).^2);
    else
        refP = basePower;
    end
    
    % Вычисляем дисперсию шума
    actualNoiseVar = refP / (10^(targetSNR/10));
    awgn.Variance = actualNoiseVar;
    rx = awgn(rxSignalNoNoise);

    ind = wlanFieldIndices(cfg);
    
    % Синхронизация (защищенная)
    tOff = wlanSymbolTimingEstimate(rx, cfg.ChannelBandwidth);
    if isempty(tOff) || tOff < 0 || tOff > 100, tOff = 0; end

    % Компенсация частотного сдвига (улучшает BER в Model-B)
    lstf = rx(tOff+(ind.LSTF(1):ind.LSTF(2)),:);
    fOffset = wlanCoarseCFOEstimate(lstf, cfg.ChannelBandwidth);
    fs = wlanSampleRate(cfg);
    t = (0:length(rx)-1)'/fs;
    rx = rx .* exp(-1i*2*pi*fOffset*t);

    % Оценка канала по VHT-LTF
    vhtltf = rx(tOff+(ind.VHTLTF(1):ind.VHTLTF(2)),:);
    vhtltfDemod = wlanVHTLTFDemodulate(vhtltf, cfg);
    chanEst = wlanVHTLTFChannelEstimate(vhtltfDemod, cfg);

    % Извлечение данных
    bits = []; sym = [];
    isDataPresent = isfield(ind, 'VHTData') && ~isempty(ind.VHTData);
    
    if isDataPresent
        dataIdx = tOff + (ind.VHTData(1):ind.VHTData(2));
        if dataIdx(end) <= size(rx,1)
            % Эквалайзер MMSE и Pilot Tracking PreEQ для стабильности
            [bits, ~, sym] = wlanVHTDataRecover(rx(dataIdx,:), chanEst, actualNoiseVar, cfg, ...
                'EqualizationMethod', 'MMSE', ...
                'PilotPhaseTracking', 'PreEQ');
        else
            % Если пакет обрезан, возвращаем нули для biterr
            bits = zeros(cfg.PSDULength*8, 1);
        end
    end
end
