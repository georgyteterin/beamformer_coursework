clear, clc, close all
addpath Source\

if(~exist("TestScenarios.mat", "file"))
    GenerateTests();
end

load("TestScenarios.mat", "scenarios")

for loadedScenario = scenarios
    Scenario = GenerateScenario(loadedScenario.Value);
    Res = ScenarioRunner(Scenario);
    
    symSE = Res.SpatialExpansion.Sym;
    symBF = Res.Beamformer.Sym;
    refSym = Res.RefSym;
    chanEstSE = Res.SpatialExpansion.Chest;
    chanEstBF = Res.Beamformer.Chest;
    
    str = sprintf('%dx%d',Scenario.NumTxAnts,Scenario.NumRxAnts);
    vhtBeamformingPlotConstellation([symSE(:) symBF(:)], refSym, ...
        'Comparison', {[str ' Spatial Expansion'], [str ' Transmit Beamforming']});
    
    fprintf('Power SE: %.2f W, %.2f W\n', sum(mean(abs(chanEstSE).^2,1),3));
    fprintf('Power BF: %.2f W, %.2f W\n', sum(mean(abs(chanEstBF).^2,1),3));
end


