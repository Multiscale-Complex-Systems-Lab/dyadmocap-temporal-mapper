function v = DYMO_ciVerdict(ci, aboveText, belowText, nsText)
%DYMO_CIVERDICT  Turn a bootstrap CI into the sentence it means.
%
%   v = DYMO_ciVerdict(ci, aboveText, belowText)
%   v = DYMO_ciVerdict(ci, aboveText, belowText, nsText)
%
% The CI is the inference everywhere in this pipeline, so the reading rule is
% always the same and is written out here once:
%
%   CI entirely above 0 -> aboveText
%   CI entirely below 0 -> belowText
%   CI contains 0       -> nsText   (default "No significant difference")
%   CI not computable   -> "Not testable"
%
% WHY A COLUMN AND NOT A NOTE
% The verdict was being read off the two CI columns by eye, every time, by
% whoever opened the table. Writing it down removes that step and makes two
% tables comparable at a glance. It adds no new inference: it states the rule
% already agreed, applied to the interval already computed.
%
% Returns a string, so DYMO_roundTable passes it through untouched.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 4 || isempty(nsText)
    nsText = "No significant difference";
end

if numel(ci) ~= 2 || any(~isfinite(ci))
    v = "Not testable";
elseif min(ci) > 0
    v = string(aboveText);
elseif max(ci) < 0
    v = string(belowText);
else
    v = string(nsText);
end
end
