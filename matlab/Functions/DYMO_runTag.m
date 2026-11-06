function tag = DYMO_runTag()
%DYMO_RUNTAG  Which analysis run the file names and folders belong to.
%
%   tag = DYMO_runTag();
%
% Every file and folder name in the pipeline ends in this tag (see
% DYMO_files.m), so changing the line below moves the WHOLE pipeline - the
% temporal mapper, the subgraphs, the cycles, the graph metrics and the node
% distances - to a separate set of results folders. Nothing is overwritten and
% nothing is mixed. DYMO_checkSettings stops a TM script whose settings do not
% match the tag.
%
% The analysis: the behavioural categories from the median-normalised angular
% speed, the temporal mapper from the z-scored signed angular velocity, 180 s
% per recording. The tag is the same as the Python version's (PY_TAG in
% dymo_settings.py), so the two sets of tables have the same names and can be
% compared with tools/compare_matlab_python.py.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

tag = 'mednorm_180s';
end
