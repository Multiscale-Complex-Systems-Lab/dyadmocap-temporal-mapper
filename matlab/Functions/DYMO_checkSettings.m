function DYMO_checkSettings(uniformWindowSec, categoryNormalization, graphNormalization)
%DYMO_CHECKSETTINGS  Stop a run whose settings do not match its run tag.
%
%   DYMO_checkSettings(uniformWindowSec, categoryNormalization)
%   DYMO_checkSettings(uniformWindowSec, categoryNormalization, graphNormalization)
%
% graphNormalization is optional and defaults to 'zscore', the setting of the
% reported analysis, so a script that omits it is still checked correctly.
%
% WHY THIS EXISTS
% An analysis is defined by TWO things that have to agree: the run tag in
% DYMO_runTag.m, which decides where the results go, and the settings at the top
% of the TM scripts, which decide what is computed. Changing one and forgetting
% the other writes one analysis into another analysis's folder, and the mistake
% is invisible until someone reads a table months later and the numbers do not
% match its name.
%
% This function is called once by each TM script, straight after its settings. It
% compares them with the registry below and stops the run if they disagree,
% BEFORE any hour of computation is spent.
%
% ADDING AN ANALYSIS
% Add a row here and a tag in DYMO_runTag.m. A tag that is not listed gets a
% warning rather than an error, so a new analysis is never blocked - but it is
% worth adding, because then the guard protects it too.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3 || isempty(graphNormalization)
    graphNormalization = 'zscore';
end

tag = DYMO_runTag();

% tag | analysed window (s) | CATEGORY normalisation | GRAPH normalisation
registry = { ...
    'mednorm_180s',               180, 'median', 'zscore'   % *_TM_26June26.m: the reported analysis
    };

row = find(strcmp(registry(:,1), tag), 1);

if isempty(row)
    warning('DYMO_checkSettings:unknownTag', ...
        ['Run tag ''%s'' is not in the registry in DYMO_checkSettings.m, so the ' ...
         'settings cannot be checked. Window %g s, categories ''%s'', graph ''%s''. ' ...
         'Add a row for this analysis if it is meant to be a lasting one.'], ...
         tag, uniformWindowSec, categoryNormalization, graphNormalization);
    return
end

wantWindow    = registry{row, 2};
wantNorm      = registry{row, 3};
wantGraphNorm = registry{row, 4};

problems = {};
if uniformWindowSec ~= wantWindow
    problems{end+1} = sprintf('uniformWindowSec is %g but tag ''%s'' expects %g', ...
        uniformWindowSec, tag, wantWindow);
end
if ~strcmpi(categoryNormalization, wantNorm)
    problems{end+1} = sprintf('categoryNormalization is ''%s'' but tag ''%s'' expects ''%s''', ...
        categoryNormalization, tag, wantNorm);
end
if ~strcmpi(graphNormalization, wantGraphNorm)
    problems{end+1} = sprintf('graphNormalization is ''%s'' but tag ''%s'' expects ''%s''', ...
        graphNormalization, tag, wantGraphNorm);
end

if ~isempty(problems)
    error('DYMO_checkSettings:mismatch', ...
        ['The settings do not match the run tag, so this run would write one ' ...
         'analysis into another one''s results folder.\n\n  %s\n\n' ...
         'Fix either the tag in DYMO_runTag.m or the settings at the top of this ' ...
         'script, so that they agree. Nothing has been computed or written.'], ...
         strjoin(problems, sprintf('\n  ')));
end

fprintf(['Settings match run tag %s: window %g s, categories from ''%s'', ' ...
         'graph from ''%s''.\n'], ...
    tag, uniformWindowSec, categoryNormalization, graphNormalization);
end
