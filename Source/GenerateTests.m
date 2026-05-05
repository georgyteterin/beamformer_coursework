function scenarios = GenerateTests(jsonFileName)
    if nargin < 1, jsonFileName = 'config.json'; end
    
    if ~exist(jsonFileName, 'file')
        error('Файл конфигурации %s не найден!', jsonFileName);
    end
    
    % Читаем JSON
    conf = jsondecode(fileread(jsonFileName));
    sys = conf.SystemParams;
    snrVec = conf.StudyParams.SnrRange;
    

    if isfield(conf.StudyParams, 'NumPackets')
        numPackets = conf.StudyParams.NumPackets;
    else
        numPackets = 1;
    end
    
    scenarios = [];
    
    % Формируем список конфигураций
    for numTx = sys.TxVals'
        % Кол-во потоков ограничено и передатчиком, и приемников
        
        for cur_numSTS = sys.numSTS.'
            for mcs = sys.McsVals'
                for bwCell = sys.BwVals'
                    bw = bwCell{1};
                    
                    cfgVHT = wlanVHTConfig;
                    cfgVHT.ChannelBandwidth = bw;
                    cfgVHT.NumTransmitAntennas = numTx;
                    cfgVHT.NumSpaceTimeStreams = cur_numSTS;
                    cfgVHT.MCS = mcs;
                    cfgVHT.APEPLength = sys.APEPLength;

                    % Создаем структуру для одной конфигурации
                    S.Key = sprintf('Tx%d_STS%d_MCS%d_%s', numTx, cur_numSTS, mcs, sys.DelayProfile);
                    
                    S.Value.Config = cfgVHT;
                    S.Value.SnrVec = snrVec(:)'; 
                    S.Value.NumRxAnts = sys.NumRxAnts;
                    S.Value.NumPackets = numPackets; 
                    
                    % ПАРАМЕТРЫ ФИЗИКИ
                    S.Value.DelayProfile = sys.DelayProfile;
                    S.Value.Distance = sys.Distance;
                    
                    scenarios = [scenarios; S]; 
                end
            end
        end
    end
    fprintf('Сгенерировано %d конфигураций из %s (Пакетов на точку: %d)\n', ...
        length(scenarios), jsonFileName, numPackets);
end
