function GenerateTests(filename)
    if nargin < 1
        filename = 'TestScenarios.mat';
    end

    TxVals = [2, 4, 8];
    McsVals = [0, 4];
    BwVals = {'CBW20', 'CBW40'};
    MappingTypesVals = {'SpatialExpansion', 'Beamforming'};

    scenarioCount = 0;
    scenarios = [];   % Дикшенари Key, Value

    for idx_Tx = 1 : length(TxVals)
        NumTx = TxVals(idx_Tx);
        StsVals = 1 : min(4, NumTx);

        for idx_STS = 1 : length(StsVals)
            NumSTS = StsVals(idx_STS);

            for idx_MCS = 1 : length(McsVals)
                MCS = McsVals(idx_MCS);

                for idx_BW = 1:length(BwVals)
                    BW = BwVals{idx_BW};

                    for i_MT = 1:length(MappingTypesVals)
                        spatialType = MappingTypesVals{i_MT};

                        if strcmp(spatialType, 'SpatialExpansion')
                            dft = dftmtx(NumTx);
                            Q = (dft(:, 1 : NumSTS) / sqrt(NumTx)).';
                        else
                            Q = ones(NumSTS, NumTx) / sqrt(NumTx);
                        end

                        cfgVHT = wlanVHTConfig;
                        cfgVHT.ChannelBandwidth = BW;
                        cfgVHT.NumTransmitAntennas = NumTx;
                        cfgVHT.NumSpaceTimeStreams = NumSTS;
                        cfgVHT.MCS = MCS;
                        cfgVHT.APEPLength = 4000;
                        cfgVHT.SpatialMapping = 'Custom';
                        cfgVHT.SpatialMappingMatrix = Q;

                        Key = sprintf('%s_Tx%d_STS%d_MCS%d_%s', spatialType, NumTx, NumSTS, MCS, BW);

                        KeyValuePair.Key = Key;
                        KeyValuePair.Value.SpatialType = spatialType;
                        KeyValuePair.Value.Config = cfgVHT;

                        if isempty(scenarios)
                            scenarios = KeyValuePair;
                        else
                            scenarios(end + 1) = KeyValuePair;
                        end

                        scenarioCount = scenarioCount + 1;
                        fprintf('Generated scenario %d: %s\n', scenarioCount, Key);
                    end
                end
            end
        end
    end

    save(filename, 'scenarios');
    fprintf('\nTotal of %d scenarios saved in %s\n', length(scenarios), filename);
end