function Scenario = GenerateScenario(config)
    NumTxAnts = 4;  % Number of transmit antennas
    NumSTS = 2;     % Number of space-time streams
    NumRxAnts = 2;  % Number of receive antennas
    
    cfgVHT = wlanVHTConfig;
    if nargin < 1
        cfgVHT.ChannelBandwidth = 'CBW20';
        cfgVHT.APEPLength = 4000;
        cfgVHT.NumTransmitAntennas = NumTxAnts;
        cfgVHT.NumSpaceTimeStreams = NumSTS;
        cfgVHT.MCS = 4; % 16-QAM, rate 3/4
    else
        cfgVHT = config.Config;
    end

    
    
    tgacChannel = wlanTGacChannel;
    tgacChannel.DelayProfile = 'Model-B';
    tgacChannel.ChannelBandwidth = cfgVHT.ChannelBandwidth;
    tgacChannel.SampleRate = wlanSampleRate(cfgVHT);
    tgacChannel.NumReceiveAntennas = NumRxAnts;
    tgacChannel.NumTransmitAntennas = NumTxAnts;
    tgacChannel.TransmitReceiveDistance = 100; % Meters
    tgacChannel.RandomStream = 'mt19937ar with seed';
    tgacChannel.Seed = 70; % Seed to allow repeatability
    
    noisePower = -37; % dBW
    
    awgnChannel = comm.AWGNChannel;
    awgnChannel.RandomStream = 'mt19937ar with seed';
    awgnChannel.Seed = 5;
    awgnChannel.NoiseMethod = 'Variance';
    awgnChannel.Variance = 10^(noisePower/10);
    
    Scenario.NumTxAnts = NumTxAnts; 
    Scenario.NumSTS = NumSTS;
    Scenario.NumRxAnts = NumRxAnts;
    Scenario.cfgVHT = cfgVHT;
    Scenario.tgacChannel = tgacChannel;
    Scenario.noisePower = noisePower;
    Scenario.awgnChannel = awgnChannel;
end