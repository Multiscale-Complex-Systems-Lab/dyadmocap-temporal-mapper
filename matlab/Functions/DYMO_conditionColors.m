function C = DYMO_conditionColors()
%DYMO_CONDITIONCOLORS  The two condition colours, in one place.
%
%   C = DYMO_conditionColors();
%   C(1,:) = Casual Chat (GTK),  C(2,:) = Conflict (MAN)
%
% These are the condition colours of the earlier bar figures. They live here so
% that the figures and the standalone legend figure cannot drift apart: both
% read them from this function.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

C = [0.24, 0.70, 0.76;    % Casual Chat
     0.95, 0.47, 0.42];   % Conflict
end
