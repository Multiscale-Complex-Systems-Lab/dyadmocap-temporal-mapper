function C = DYMO_conditionColorsPurple()
%DYMO_CONDITIONCOLORSPURPLE  The two condition colours for figures that are
%NOT split by behavioural state (whole graph, node-size bands, node distances).
%
%   C = DYMO_conditionColorsPurple();
%   C(1,:) = Casual Chat (GTK), solid purple
%   C(2,:) = Conflict (MAN),    light purple
%
% The rule across the figures is "Casual Chat solid, Conflict light". Figures
% split by state follow it with the state colour (plotCategoryPairedBars);
% figures without states use purple, which is not one of the four state colours
% (black, green, blue, red), so it cannot be read as a state.
% DYMO_conditionColors (teal / salmon) holds the colours of the earlier figures.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

C = [0.49, 0.18, 0.56;    % Casual Chat - solid purple
     0.82, 0.71, 0.85];   % Conflict    - light purple
end
