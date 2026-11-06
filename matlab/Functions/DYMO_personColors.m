function C = DYMO_personColors()
%DYMO_PERSONCOLORS  The colours used for the two partners in every figure.
%
%   C = DYMO_personColors()
%
% C is a 4-by-3 matrix of RGB triplets, one row per series:
%   row 1  Person 1                  [0 0 1]        blue
%   row 2  Person 2                  [1 0 0]        red
%   row 3  a third series, if needed [0 0 0]        black
%   row 4  a fourth series, if needed[0 0.6 0.6]    teal
%
% The values are written as explicit RGB triplets, not the MATLAB shorthands
% ('b', 'r') and not the default axes colour order, so every figure in the
% project uses exactly the same blue and red, and the colours are stated in
% the code for anyone reading it.
%
% Use it as:
%   personColors = DYMO_personColors();
%   plot(t, y1, 'Color', personColors(1,:));   % Person 1, blue
%   plot(t, y2, 'Color', personColors(2,:));   % Person 2, red
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

C = [0    0    1        % Person 1: blue
     1    0    0        % Person 2: red
     0    0    0        % spare series: black
     0    0.6  0.6];    % spare series: teal
end
