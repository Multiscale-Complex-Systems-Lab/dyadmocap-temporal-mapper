function T = DYMO_roundTable(T, nSig)
%DYMO_ROUNDTABLE  Round a results table for reporting: 3 significant figures,
%p-values to 3 decimals with a .001 floor. APA-compatible.
%
%   T = DYMO_roundTable(T)        % 3 significant figures
%   T = DYMO_roundTable(T, 2)
%
% WHY NOT A FIXED NUMBER OF DECIMAL PLACES
% APA (7th ed., 6.36) is written in decimal places - two for most statistics,
% two or three for p. That works for a correlation and fails for two columns
% here: edge density runs about 0.0005 to 0.0018, so two decimals writes every
% value as 0.00. Significant figures keep 0.00123 as 0.00123 and 0.826 as
% 0.826, which is what both columns need.
%
% WHY SIGNIFICANT FIGURES ARE FLOORED AT WHOLE NUMBERS
% Three significant figures would turn a mean node count of 2966 into 2970.
% So the rounding never goes coarser than 0 decimal places: counts stay exact,
% and anything below 1 gets its three figures.
%
%   0.825777679  -> 0.826        (3 significant figures)
%   0.09529167   -> 0.0953
%  -0.0621765    -> -0.0622
%   0.00123456   -> 0.00123
%   2966.43      -> 2966         (floored at whole numbers, not 2970)
%
% P-VALUE COLUMNS
% A column named 'p' or 'PValue', or ending in '_p', is rounded to 3 decimals
% and floored at 0.001: anything smaller is written as 0.001, to be reported in
% prose as "p < .001". This is APA's convention, and it also means a very small
% p-value is never written into the table as exactly 0.
%
% NOT DONE HERE: APA also drops the leading zero on values that cannot exceed 1
% (.826 rather than 0.826, p = .003 rather than 0.003). That is a formatting
% step for the manuscript, not for the CSV, because it would turn numbers into
% text and stop them being usable downstream.
%
% Text columns, NaN and Inf pass through untouched.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(nSig)
    nSig = 3;
end

pDecimals = 3;
pFloor    = 10^(-pDecimals);
names     = T.Properties.VariableNames;

for k = 1:numel(names)

    v = T.(names{k});
    if ~isnumeric(v)
        continue
    end

    % The pipeline's tables spell the p column six different ways:
    % p, PValue, P_Value, p_value, Symmetric_p, Asymmetric_p. All are caught
    % here, so a new table spelling it a seventh way is the only thing that
    % would slip through - worth a glance at any new table's header.
    nm     = lower(names{k});
    isPcol = ismember(nm, {'p', 'pvalue', 'p_value'}) || ...
             endsWith(nm, '_p') || endsWith(nm, '_pvalue') || endsWith(nm, '_p_value');

    if isPcol
        small    = isfinite(v) & (v >= 0) & (v < pFloor);
        v(small) = pFloor;                       % floor BEFORE rounding
        T.(names{k}) = round(v, pDecimals);
        continue
    end

    % 3 significant figures, but never coarser than whole numbers
    out = v;
    ok  = isfinite(v) & (v ~= 0);
    if any(ok)
        d        = nSig - 1 - floor(log10(abs(v(ok))));   % decimals for nSig figures
        d        = max(d, 0);                             % the whole-number floor
        vals     = v(ok);
        for j = 1:numel(vals)
            vals(j) = round(vals(j), d(j));
        end
        out(ok) = vals;
    end
    T.(names{k}) = out;
end
end
