function fig = plotDeltaRho(R, metricLabel)
%PLOTDELTARHO  rho(Symmetric) vs rho(Asymmetric) with delta and its bootstrap
%CI (figure used by the SpearCorr scripts). The CI is the inference.
%   fig = plotDeltaRho(R, metricLabel)   R: fields rhoG1, rhoG2, delta, CI
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
fig = figure('Position',[100 100 600 500]);
hold on
plot([1 2], [R.rhoG1 R.rhoG2], 'k-', 'LineWidth',2);
scatter(1, R.rhoG1, 150, 'filled', 'MarkerFaceColor',[0 0.4470 0.7410]);
scatter(2, R.rhoG2, 150, 'filled', 'MarkerFaceColor',[0.8500 0.3250 0.0980]);
text(1, R.rhoG1, DYMO_numText(R.rhoG1), 'HorizontalAlignment','center', ...
     'VerticalAlignment','bottom', 'FontWeight','bold');
text(2, R.rhoG2, DYMO_numText(R.rhoG2), 'HorizontalAlignment','center', ...
     'VerticalAlignment','bottom', 'FontWeight','bold');
statsText = sprintf('\\Delta\\rho = %s\n95%% CI = [%s, %s]', ...
    DYMO_numText(R.delta), DYMO_numText(R.CI(1)), DYMO_numText(R.CI(2)));   % the CI is the inference
% Coloured by the CI, which is the inference here: grey when it contains zero
text(0.03, 0.97, statsText, 'Units','normalized', 'VerticalAlignment','top', ...
     'FontSize',30, 'FontWeight','bold', 'Color',DYMO_sigColor(R.CI));
set(gca, 'XTick',[1 2], 'XTickLabel',{'Symmetric Interaction','Asymmetric Interaction'}, ...
    'FontSize',12, 'LineWidth',1.5);
ylabel('Spearman \rho')
ylim([-1 1])
xlim([0.5 2.5])
title(metricLabel, 'FontWeight','bold', 'Interpreter','none')
grid on
box on
end
