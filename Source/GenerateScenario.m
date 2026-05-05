function Scenario = GenerateScenario(config)
    cfgVHT = config.Config; 
    
    % Количество антенн теперь берется динамически
    NumTxAnts = cfgVHT.NumTransmitAntennas; 
    NumSTS = cfgVHT.NumSpaceTimeStreams;
    NumRxAnts = config.NumRxAnts; 
    
    % 2. Настройка модели канала TGac
    tgacChannel = wlanTGacChannel;
    tgacChannel.DelayProfile = config.DelayProfile;         % Модель (A, B, C, D)
    tgacChannel.TransmitReceiveDistance = config.Distance;  % Дистанция (м)
    tgacChannel.ChannelBandwidth = cfgVHT.ChannelBandwidth;
    tgacChannel.SampleRate = wlanSampleRate(cfgVHT);
    
    % Устанавливаем соответствие антенн (критично для устранения твоей ошибки)
    tgacChannel.NumReceiveAntennas = NumRxAnts;
    tgacChannel.NumTransmitAntennas = NumTxAnts;
    
    % Параметры дистанции и повторяемости
    tgacChannel.TransmitReceiveDistance = 10; % Метры (можно вынести в JSON)
    tgacChannel.RandomStream = 'mt19937ar with seed';
    tgacChannel.Seed = 70; 


    awgnChannel = comm.AWGNChannel;
    awgnChannel.RandomStream = 'mt19937ar with seed';
    awgnChannel.Seed = 5;
    awgnChannel.NoiseMethod = 'Variance';

    Scenario.NumTxAnts = NumTxAnts; 
    Scenario.NumSTS = NumSTS;
    Scenario.NumRxAnts = NumRxAnts;
    Scenario.cfgVHT = cfgVHT;
    Scenario.tgacChannel = tgacChannel;
    Scenario.awgnChannel = awgnChannel;
    

    if isfield(config, 'CurrentSNR')
        Scenario.targetSNR = config.CurrentSNR;
    else
        Scenario.targetSNR = 20;
    end
end
