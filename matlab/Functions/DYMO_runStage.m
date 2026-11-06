function DYMO_runStage(scriptName)
%DYMO_RUNSTAGE  Run one pipeline script in its own, private workspace.
%
%   DYMO_runStage('GTK_TM_26June26');
%
% WHY A FUNCTION AND NOT JUST run()
% Each stage of this pipeline is a script, and a script shares the workspace of
% whatever called it. Running several stages one after another in the Command
% Window therefore leaves each stage's variables behind for the next one, and a
% stage that tests `if ~exist('X','var')` before loading X from disk will happily
% reuse a stale X from the previous stage. Running the script inside THIS function
% gives it a private workspace that is discarded when the function returns, so
% every stage starts from the same clean state as if it had been run on its own.
%
% The stage still writes to disk exactly as it normally does and still prints to
% the Command Window, so nothing about its behaviour changes.
%
% WHY THIS FUNCTION MEASURES NOTHING AND RETURNS NOTHING
% Some stage scripts begin with a bare `clear`, which clears the workspace of
% whatever is running them - here, this function's own workspace. So nothing may
% be stored before the script runs and read afterwards: any such variable can be
% gone by then. The stage is therefore timed by the CALLER (DYMO_runAll), whose
% workspace the script cannot reach, and this function does nothing after `run`.
%
% INPUT
%   scriptName : the script's name, with or without .m. It must be on the MATLAB
%                path, which DYMO_setup arranges.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

scriptPath = which(scriptName);
if isempty(scriptPath)
    error('DYMO_runStage:notFound', ...
        ['Script ''%s'' is not on the MATLAB path. Run DYMO_setup.m, and check ' ...
         'the name is spelled as the file is.'], scriptName);
end

% The script is called by its NAME, not with run(scriptPath): with a full path,
% run() makes the script's folder the current folder while the script runs, so
% every relative output path (all of them, see DYMO_files) would be written
% inside the code folder, and a later stage could not find an earlier stage's
% files. Called by its name, the script runs in this workspace from the current
% (results) folder.
[~, scriptName] = fileparts(scriptPath);
eval(scriptName);

% Deliberately nothing after this line: a script that called `clear` has emptied
% this workspace, so scriptPath may no longer exist.
end
