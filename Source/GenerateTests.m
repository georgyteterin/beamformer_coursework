function scenarios = GenerateTests(jsonFileName)
    
    if nargin < 1, jsonFileName = 'config.json'; end
    
    if ~exist(jsonFileName, 'file')
        error('Файл конфигурации %s не найден!', jsonFileName);
    end
    
    % Читаем JSON
    conf = jsondecode(fileread(jsonFileName));
    sys = conf.SystemParams;
    rawSnr = conf.StudyParams.SnrRange;
    
    % Поддерживает SNR в форматах: [1, 2, 3] или [[start, step, end], [start, step, end]]
    snrVec = [];
    if iscell(rawSnr)
        % Если SNR задан как список диапазонов в формате { [start, step, end], [...] }
        for j_snr = 1:length(rawSnr)
            r = rawSnr{j_snr};
            if length(r) == 3
                snrVec = [snrVec, r(1):r(2):r(3)];
            else
                snrVec = [snrVec, r(:)']; % на случай, если внутри просто список
            end
        end
    elseif ismatrix(rawSnr) && size(rawSnr, 2) == 3 && size(rawSnr, 1) > 1
        % Если SNR задан как матрица N x 3
        for j_snr = 1:size(rawSnr, 1)
            snrVec = [snrVec, rawSnr(j_snr,1):rawSnr(j_snr,2):rawSnr(j_snr,3)];
        end
    else
        % Если SNR задан обычным плоским вектором [5, 10, 15]
        snrVec = rawSnr;
    end
    snrVec = unique(snrVec); % Сортировка и удаление дубликатов на стыках диапазонов
    % ----------------------------------

    if isfield(conf.StudyParams, 'NumPackets')
        numPackets = conf.StudyParams.NumPackets;
    else
        numPackets = 1;
    end
    
    scenarios = [];
    
    % Итерируемся по всем параметрам из SystemParams для создания сетки тестов
    for numTx = sys.TxVals'
        for cur_numSTS = sys.numSTS'
            for mcs = sys.McsVals'
                for bwCell = sys.BwVals'
                    bw = bwCell{1};
                    
                    cfgVHT = wlanVHTConfig;
                    cfgVHT.ChannelBandwidth = bw;
                    cfgVHT.NumTransmitAntennas = numTx;
                    cfgVHT.NumSpaceTimeStreams = cur_numSTS;
                    cfgVHT.MCS = mcs;
                    cfgVHT.APEPLength = sys.APEPLength;

                    % Формируем уникальный ключ для идентификации теста
                    S.Key = sprintf('Tx%d_STS%d_MCS%d_%s', numTx, cur_numSTS, mcs, sys.DelayProfile);
                    
                    S.Value.Config = cfgVHT;
                    S.Value.SnrVec = snrVec(:)'; 
                    S.Value.NumRxAnts = sys.NumRxAnts;
                    S.Value.NumPackets = numPackets; 
                    
                    % Параметры окружения
                    S.Value.DelayProfile = sys.DelayProfile;
                    S.Value.Distance = sys.Distance;
                    
                    scenarios = [scenarios; S]; %#ok<AGROW>
                end
            end
        end
    end
end
