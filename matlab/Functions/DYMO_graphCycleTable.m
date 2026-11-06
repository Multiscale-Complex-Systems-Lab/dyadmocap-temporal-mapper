function T = DYMO_graphCycleTable()
%DYMO_GRAPHCYCLETABLE  One table of the main graph and cycle metrics of every
%dyad and conversation. No statistics.
%
%   T = DYMO_graphCycleTable();
%
% Run stages 1-5 of DYMO_runAll first (DYMO_runAll(1, 5)): they build the TM
% graphs and find their cycles. This function only reads what they saved:
%   the TM graphs  (F.GTK_TM, F.MAN_TM)          from the TM stages
%   the cycles     (F.GTK_Cycles, F.MAN_Cycles)  from Cycles_WinShannon_03July
% and computes the metrics with DYMO_graphCycleMetrics. One row per dyad and
% conversation (Casual chat, Conflict), the same columns as the table of the
% Python notebooks.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

cfg = DYMO_config();
startFolder = pwd;
cd(cfg.resultsDir);                         % every saved path is relative to it
restoreFolder = onCleanup(@() cd(startFolder));

F = DYMO_files('TM_GTK');
need = {F.GTK_TM, F.MAN_TM, F.GTK_Cycles, F.MAN_Cycles};
for i = 1:numel(need)
    if ~isfile(need{i})
        error('DYMO_graphCycleTable:missing', ...
            'Not found: %s\nRun DYMO_runAll(1, 5) first (the TM graphs and the cycles).', need{i});
    end
end
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
load(F.MAN_Cycles, 'MANCycles', 'MANVis');

names = DYMO_dataIndex();                   % sorted, the order the TM stage uses
if numel(names) ~= numel(GTK_AllDyads_GraphData) || numel(names) ~= numel(MAN_AllDyads_GraphData)
    error('DYMO_graphCycleTable:count', ...
        '%d dyads in the index but %d / %d graphs saved: rerun DYMO_runAll(1, 5).', ...
        numel(names), numel(GTK_AllDyads_GraphData), numel(MAN_AllDyads_GraphData));
end

T = [DYMO_graphCycleMetrics(GTK_AllDyads_GraphData, GTKCycles, GTKVis, names, "Casual chat")
     DYMO_graphCycleMetrics(MAN_AllDyads_GraphData, MANCycles, MANVis, names, "Conflict")];
T = sortrows(T, {'Dyad', 'Conversation'});  % each dyad: Casual chat, then Conflict
end
