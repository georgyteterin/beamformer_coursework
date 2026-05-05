clear, clc, close all

testname = "test1";
resultsFile = "..\results\results_" + testname + ".mat"; 

if ~exist(resultsFile, 'file')
    error('Файл с результатами не найден!');
end

load(resultsFile); 

for j_res = 1:length(SimulationResults)
    res = SimulationResults(j_res);
    
    figure('Color', 'w', 'Name', res.Key);
    
    semilogy(res.snrVec, res.berSE, '-ro', 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Spatial Expansion');
    hold on;
    semilogy(res.snrVec, res.berBF, '-bs', 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'Transmit Beamforming');
    
    grid on; grid minor;
    ax = gca;
    ax.YScale = 'log';
    ax.FontSize = 11;
    
    minBer = 1e-5; 
    ylim([minBer 1]);
    
    xlabel('Отношение сигнал/шум SNR (дБ)', 'FontSize', 12);
    ylabel('Вероятность ошибки на бит (BER)', 'FontSize', 12);
    
    cleanTitle = strrep(res.Key, '_', ' ');
    title(['Сравнение эффективности: ' cleanTitle], 'FontSize', 14);
    
    legend('Location', 'southwest', 'FontSize', 10);

    if ~exist('plots', 'dir'), mkdir('plots'); end
    saveas(gcf, fullfile('plots', "ber_vs_snr_" + res.Key + ".png"));
end

fprintf('Все графики построены и сохранены в папку plots\n');
