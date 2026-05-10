clear, clc, close all

testname = "test1";
resultsFile = "..\results\results_" + testname + ".mat"; 

if ~exist(resultsFile, 'file')
    error('Файл с результатами не найден!');
end

load(resultsFile); 

for j_res = 1:length(SimulationResults)

    res = SimulationResults(j_res);
    tech = fieldnames(res.snr);
    numTech = length(tech);
    
    figure('Name', res.Key);
    markerList = {'o', 's', '^', 'd', 'v', 'p', 'h'};
    colorList = lines(numTech);

    for j_tech = 1 : numTech

        currentColor = colorList(j_tech, :);
    
        semilogy(res.snr.(tech{j_tech}), res.per.(tech{j_tech}), ...
            'LineStyle', '-', ...
            'Color', currentColor, ...
            'Marker', markerList{1}, ...
            'LineWidth', 2, ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', currentColor, ...
            'DisplayName', tech{j_tech});
        hold on;

    end

    hold off;
    
    grid on; grid minor;
    ax = gca;
    ax.YScale = 'log';
    ax.FontSize = 11;
    
    maxPer = 1;
    c_per = struct2cell(res.per); 
    all_per = [c_per{:}];
    minPer = min(all_per);
    if minPer == 1
        minPer = 0.5;
        maxPer = 1.2;
    end
    ylim([minPer maxPer]);

    c_snr = struct2cell(res.snr);
    validSnrs = [];
    
    for i = 1:length(c_per)
        perVec = c_per{i};
        snrVec = c_snr{i};
        validSnrs = [validSnrs, snrVec(perVec < 0.99)]; %#ok<AGROW>
    end 
    
    if ~isempty(validSnrs)
        xStart = min(validSnrs) - 2; % Отступаем 2 дБ влево для красоты
        all_snr = [c_snr{:}];
        xEnd = max(all_snr);
        xlim([xStart, xEnd]);
    end
    
    xlabel('Отношение сигнал/шум SNR (дБ)', 'FontSize', 12);
    ylabel('Вероятность пакетной ошибки (PER)', 'FontSize', 12);
    
    cleanTitle = strrep(res.Key, '_', ' ');
    title(['Сравнение эффективности: ' cleanTitle], 'FontSize', 14);
    
    legend('Location', 'southwest', 'FontSize', 10);

    y_thresold = 0.1;

    hl = yline(y_thresold, '--', 'LineWidth', 2.5);
    hl.Color = [0.8 0.2 0.2]; 
    hl.Label = 'Wi-Fi Working Point (PER=0.1)';
    hl.Interpreter = 'latex'; 
    hl.FontWeight = 'bold';
    hl.FontSize = 10;

    if ~exist('plots/' + testname, 'dir'), mkdir('plots/' + testname); end
    saveas(gcf, fullfile('plots', testname + "/per_vs_snr_" + res.Key + ".png"));
end

fprintf('Все графики построены и сохранены в папку plots/%s\n', testname);
