function Q = helperSpatialExpansionMatrix(varargin)
% helperSpatialExpansionMatrix Return a spatial expansion matrix
%
%   Q = helperSpatialExpansionMatrix(CFGFORMAT) returns a spatial expansion
%   matrix for the specified format configuration object, CFGFORMAT.
%
%   Q is a complex matrix sized Nst-by-Nsts-by-Nt. Nst is the number of
%   occupied subcarriers, Nsts is the number of space-time streams, and Nt
%   is the number of transmit antennas.
%
%   CFGFORMAT is the format configuration object of type <a
%   href="matlab:help('wlanHESUConfig')">wlanHESUConfig</a>, 
%   <a href="matlab:help('wlanVHTConfig')">wlanVHTConfig</a>, or <a
%   href="matlab:help('wlanHTConfig')">wlanHTConfig</a>, which specifies the parameters for the 
%   HE-SU, VHT or HT-Mixed formats respectively.
%
%   Example: Spatial expansion for a VHT format configuration. 
%
%   cfgVHT = wlanVHTConfig;
%   cfgVHT.SpatialMapping = 'Custom';
%   Q = helperSpatialExpansionMatrix(cfgVHT);
%   cfgVHT.SpatialMappingMatrix = Q;
%
%   See also wlanHESUConfig, wlanVHTConfig, wlanHTConfig.

%   Copyright 2015-2019 The MathWorks, Inc.

%#codegen

if nargin==1
    cfg = varargin{1};

    validateattributes(cfg,{'wlanVHTConfig','wlanHTConfig','wlanHESUConfig'}, ...
        {'scalar'},mfilename,'format configuration object');

    numSTS = sum(cfg.NumSpaceTimeStreams);
    NumTx = cfg.NumTransmitAntennas;
    csd = wlan.internal.getCyclicShiftVal('VHT',NumTx,wlan.internal.cbwStr2Num(cfg.ChannelBandwidth));
    if isa(cfg,'wlanHESUConfig')
        ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg);
    else
        ofdmInfo = wlan.internal.vhtOFDMInfo('VHT-Data',cfg.ChannelBandwidth,'Long');
    end
    
    n = ofdmInfo.ActiveFrequencyIndices;
    Nfft = ofdmInfo.FFTLength;
    numTones = ofdmInfo.NumTones;
else
    Nfft = varargin{1};
    numSTS = varargin{2};
    n = varargin{3};
end

% Calculate MCSD matrix (Std 802.11-2012 Section 20.3.11.11.2)
phaseShift = exp(-1i*2*pi*csd*n'/Nfft).';
Mcsd = permute(phaseShift,[1 3 2]);

% Calculate D matrix (Std 802.11-2012 Section 20.3.11.11.2)
base = eye(numSTS);
D = zeros(NumTx,numSTS);
for d=1:NumTx
   D(d,:) = base(mod(d-1,numSTS)+1,:); 
end
D = sqrt(numSTS/NumTx)*D;

% Calculate spatial expansion matrix for occupied subcarriers
Q = repmat(Mcsd,1,numSTS,1).*repmat(permute(D,[3 2 1]),numTones,1,1);
end