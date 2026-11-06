function plotPairedComparison( ...
    GTKData, MANData, pValue, ...
    GTKColor, MANColor, ...
    plotTitle, yLabel, yLimits, ...
    showLegend)

% Plots the two conditions of a paired comparison as bars, with the paired
% t-test result.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

% Create a reusable plotting function
% It does not perform any statistics (ttest, Spearman, etc.). 
% It simply plots whatever data you give it. 
% That means you'll be able to reuse it later for Spearman correlations without changing the function.


hold on

%% ---------------- Plot settings ----------------
% x = [1 2];

%% Plot appearance

xCenter        = 1;
barSpacing     = 0.45;   % Reduce to bring bars closer

barWidth       = 0.30;  % Reduce to make bars thinner

barEdgeWidth   = 4.5; %1.5

scatterSize    = 36;

pairLineWidth  = 0.8;

meanLineWidth  = 4.5; %1.5

errorWidth     = 5.0; %2.0

capSize        = 20; %15

x = [xCenter, xCenter + barSpacing];

%% ---------------- Remove invalid pairs ----------------
validIdx = isfinite(GTKData) & isfinite(MANData);

GTKData  = GTKData(validIdx);
MANData = MANData(validIdx);

%% ---------------- Mean and SE ----------------
m = [mean(GTKData), mean(MANData)];

se = [ ...
    std(GTKData)/sqrt(numel(GTKData)), ...
    std(MANData)/sqrt(numel(MANData))];

% yLimits = [] -> automatic
if isempty(yLimits)
    top = max(m + se);
    if ~isfinite(top) || top <= 0, top = 1; end
    yLimits = [0, 1.15*top];
end

%% ---------------- Bars ----------------
hold on
b1 = bar(x(1),m(1),barWidth);
b2 = bar(x(2),m(2),barWidth);

b1.FaceColor = GTKColor;
b2.FaceColor = MANColor;

b1.EdgeColor = 'k';
b2.EdgeColor = 'k';

b1.LineWidth = barEdgeWidth;
b2.LineWidth = barEdgeWidth;

%% ---------------- Error bars ----------------
errorbar(x,m,se,...
    'k',...
    'LineStyle','none',...
    'LineWidth',errorWidth,...
    'CapSize',capSize);

% % %% ---------------- Paired lines ----------------
% for k = 1:numel(GTKData)
% 
%     plot(x,...
%         [GTKData(k), MANData(k)],...
%         '-',...
%         'Color',[0.5 0.5 0.5],...
%         'LineWidth',pairLineWidth);
% 
% end
%% ---------------- Mean lines ---------------- 

plot([x(1)-0.15 x(1)+0.15],...
     [m(1) m(1)],...
     'r-',...
     'LineWidth',meanLineWidth);

plot([x(2)-0.15 x(2)+0.15],...
     [m(2) m(2)],...
     'r-',...
     'LineWidth',meanLineWidth);

% %% ---------------- Individual points ----------------
% 
% scatter(x(1)*ones(numel(GTKData),1),...
%         GTKData,...
%         scatterSize,...
%         'k',...
%         'filled');
% 
% scatter(x(2)*ones(numel(MANData),1),...
%         MANData,...
%         scatterSize,...
%         'k',...
%         'filled');

%% ---------------- Formatting ----------------
set(gca,'XTick',[])

ylabel(yLabel)

title(plotTitle)

ylim(yLimits)

box on
grid on

%% ---------------- Significance ----------------
% Called AFTER ylim: addPValueAnnotation raises the top of the axes to make room
% for the bracket, the stars and the "p = ..." text, and ylim(yLimits) called
% afterwards would put the old limit back, leaving that text clipped or sitting
% on the frame.
addPValueAnnotation(m,se,pValue,x,yLimits);

%% ---------------- Legend ----------------
% No legend inside the figure: the key to the two conditions is saved once, as
% its own figure, by plotLegendFigure. showLegend is still accepted as an input.

end