function s = DYMO_pText(p)
%DYMO_PTEXT  A p-value as APA text, for a figure annotation.
%
%   DYMO_pText(0.0025)   -> 'p = .003'
%   DYMO_pText(4.7e-16)  -> 'p < .001'
%   DYMO_pText(0.3646)   -> 'p = .365'
%
% APA (7th ed.) reports p to two or three decimals and writes p < .001 below
% that, with no leading zero because p cannot exceed 1.
%
% WHY THIS EXISTS
% The figures used five different formats for p: '%.3g' in six places and
% '%.4f' in two. '%.4f' on a p of 4.7e-16 printed "p = 0.0000" onto the figure,
% which says the test returned zero and it did not. '%.3g' printed "4.7e-16",
% which is accurate but not reportable. One helper, used everywhere, so the
% figures and the tables say the same thing.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~isfinite(p)
    s = 'p = n/a';
elseif p < 0.001
    s = 'p < .001';
else
    s = ['p = ' stripLeadingZero(sprintf('%.3f', p))];
end
end

function t = stripLeadingZero(t)
t = regexprep(t, '^0\.', '.');
t = regexprep(t, '^-0\.', '-.');
end
