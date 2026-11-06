function projRoot = DYMO_setup()
%DYMO_SETUP  Put the DYMO functions and Temporal Mapper (tmapper2) on the
%MATLAB path. Run this ONCE per MATLAB session before running any script.
%
%   >> cd <repository>/matlab
%   >> DYMO_setup
%
% What it adds:
%   Functions/ and MainScripts/ (with every subfolder), relative to this file;
%   Temporal Mapper's tmapper_tools folder.
%
% TEMPORAL MAPPER is an external dependency and is NOT part of this
% repository. Get it once:
%   git clone https://github.com/Multiscale-Complex-Systems-Lab/tmapper2.git
%   cd tmapper2 && git checkout v2.2
% (the analysis used commit 58ee193, which differs from v2.2 only in its tests),
% then either put tmapper2/tmapper_tools on the MATLAB path yourself, or write
% the tmapper2 folder in dymo_config.ini (tmapper2_dir = ...).
%
% It also REMOVES any other copy of Temporal Mapper on the path, so MATLAB
% cannot silently use an outdated tknndigraph/filtergraph, and checks that the
% copy in use has the 'lowMemory' option (tmapper2 v2.1 or later).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

projRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projRoot, 'Functions')));
addpath(genpath(fullfile(projRoot, 'MainScripts')));

% -- where Temporal Mapper is
cfg = DYMO_config();
tmTools = '';
if ~isempty(cfg.tmapperDir)
    tmTools = cfg.tmapperDir;
    if isfolder(fullfile(tmTools, 'tmapper_tools'))
        tmTools = fullfile(tmTools, 'tmapper_tools');
    end
    if ~isfile(fullfile(tmTools, 'tknndigraph.m'))
        error('DYMO_setup:noTmapper', ['tmapper2_dir in dymo_config.ini is %s, but no ' ...
              'tknndigraph.m is there.'], cfg.tmapperDir);
    end
elseif ~isempty(which('tknndigraph'))
    tmTools = fileparts(which('tknndigraph'));
else
    error('DYMO_setup:noTmapper', ['Temporal Mapper (tmapper2) is not on the path. Get it with\n' ...
          '  git clone https://github.com/Multiscale-Complex-Systems-Lab/tmapper2.git\n' ...
          '  (then git checkout v2.2)\nand set tmapper2_dir in dymo_config.ini, or addpath its ' ...
          'tmapper_tools folder.']);
end

% -- remove other temporal mapper copies that would shadow this one
p = strsplit(path, pathsep);
for i = 1:numel(p)
    if ~strcmpi(p{i}, tmTools) && isfile(fullfile(p{i}, 'tknndigraph.m'))
        rmpath(p{i});
        fprintf('DYMO_setup: removed other temporal mapper copy from path: %s\n', p{i});
    end
end
addpath(tmTools);

% -- sanity check: the lowMemory option exists (tmapper2 >= v2.1)
w = which('tknndigraph');
if ~contains(fileread(w), 'lowMemory')
    error('DYMO_setup:oldToolbox', ['The tknndigraph on the path (%s) is too old: it has ' ...
          'no ''lowMemory'' option. Use tmapper2 v2.2.'], w);
end
fprintf('DYMO_setup: code         = %s\n', projRoot);
fprintf('DYMO_setup: tknndigraph  = %s\n', w);
fprintf('DYMO_setup: data index   = %s\n', cfg.dataIndex);
fprintf('DYMO_setup: results      = %s\n', cfg.resultsDir);
end
