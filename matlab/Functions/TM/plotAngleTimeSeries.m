function plotAngleTimeSeries(personAngles, personTime, titlePrefix, outputFolder, filePrefix, personNames, makeOverview)
%PLOTANGLETIMESERIES  Plot every calculated joint angle over time for one
%dyad (both people in the same axes): one figure per angle, plus an
%optional overview figure with all 11 angles. Figures are saved with
%AutoSavePublishableFigure and closed.
%
%   plotAngleTimeSeries(personAngles, personTime, titlePrefix, outputFolder, filePrefix)
%   plotAngleTimeSeries(..., personNames, makeOverview)
%
% Inputs
%   personAngles : 1-by-P cell of angle structs from computeJointAngles,
%                  e.g. GTKallAngles(d,:)   (empty cells are skipped)
%   personTime   : 1-by-P cell of time vectors (s), e.g. column 1 of
%                  GTKallDataFiles{d,s}
%   titlePrefix  : e.g. 'GTK Dyad 3'
%   outputFolder : parent folder; each angle is saved in its own subfolder
%                  (outputFolder/Left_Shoulder, ..., outputFolder/All_Angles_Overview)
%   filePrefix   : e.g. 'GTK_Dyad_3'  -> 'GTK_Dyad_3_Left_Shoulder_Angle'
%   personNames  : (optional) legend entries, default {'Person 1','Person 2'}
%   makeOverview : (optional) also save one 11-panel figure, default true
%
% The angle list, labels and joint names come from one table below (and the
% angle order from skeletonAngleGeometry), so nothing can be mislabelled.
% Every figure has the same legend (Person 1 / Person 2). The y-axis is fixed
% to [0 180] only for the elbows; all other angles use automatic limits.
% Figures are saved and closed. The plotted angles are exactly the ones used
% for the velocities.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 6 || isempty(personNames),  personNames  = {'Person 1','Person 2'}; end
if nargin < 7 || isempty(makeOverview), makeOverview = true; end
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

% Person 1 blue, Person 2 red, as explicit RGB triplets (see DYMO_personColors)
colors = DYMO_personColors();

% field name, label, motion description, fixed y-limits ([] = automatic)
info = { ...
    'shoulder_left',  'Left Shoulder',  'Abduction/Adduction',        []; ...
    'shoulder_right', 'Right Shoulder', 'Abduction/Adduction',        []; ...
    'wrist_left',     'Left Wrist',     'Flexion/Extension',          []; ...
    'wrist_right',    'Right Wrist',    'Flexion/Extension',          []; ...
    'elbow_left',     'Left Elbow',     'Flexion/Extension',          [0 180]; ...
    'elbow_right',    'Right Elbow',    'Flexion/Extension',          [0 180]; ...
    'knee_left',      'Left Knee',      'Flexion/Extension',          []; ...
    'knee_right',     'Right Knee',     'Flexion/Extension',          []; ...
    'ankle_left',     'Left Ankle',     'Dorsiflexion/Plantarflexion', []; ...
    'ankle_right',    'Right Ankle',    'Dorsiflexion/Plantarflexion', []; ...
    'head_general',   'Head',           'Tilt from vertical',         []};

present = find(~cellfun(@isempty, personAngles));
if isempty(present)
    return
end

% ---------- one figure per angle ----------
for k = 1:size(info,1)
    [field, label, motion, yl] = info{k,:};

    fig = figure('Visible','off', 'Color','w');
    ax  = axes(fig);
    hold(ax, 'on');
    drawPersons(ax, personAngles, personTime, present, field, colors, personNames);

    xlabel(ax, 'Time (s)');
    ylabel(ax, [label ' Angle (Degrees)']);
    title(ax, sprintf('%s: %s Angle Over Time (%s)', titlePrefix, label, motion));
    if ~isempty(yl), ylim(ax, yl); end
    legend(ax, 'Location', 'best');
    grid(ax, 'on');
    hold(ax, 'off');

    % one subfolder per angle, so each folder holds one kind of figure
    angleFolder = fullfile(outputFolder, strrep(label,' ','_'));
    AutoSavePublishableFigure(sprintf('%s_%s_Angle', filePrefix, strrep(label,' ','_')), fig, angleFolder);
    close(fig);
end

% ---------- overview: all angles in one figure ----------
if makeOverview
    fig = figure('Visible','off', 'Color','w');
    tl  = tiledlayout(fig, 4, 3, 'TileSpacing','compact', 'Padding','compact');
    for k = 1:size(info,1)
        [field, label, ~, yl] = info{k,:};
        ax = nexttile(tl);
        hold(ax, 'on');
        drawPersons(ax, personAngles, personTime, present, field, colors, personNames);
        title(ax, label);
        if ~isempty(yl), ylim(ax, yl); end
        grid(ax, 'on');
        if k == 1
            legend(ax, 'Location', 'best');
        end
    end
    xlabel(tl, 'Time (s)');
    ylabel(tl, 'Angle (Degrees)');
    title(tl, [titlePrefix ': All Joint Angles Over Time']);

    AutoSavePublishableFigure(sprintf('%s_All_Angles_Overview', filePrefix), fig, fullfile(outputFolder, 'All_Angles_Overview'));
    close(fig);
end
end

function drawPersons(ax, personAngles, personTime, present, field, colors, personNames)
for s = present
    y = personAngles{s}.(field);
    t = personTime{s};
    n = min(numel(t), numel(y));
    col = colors(mod(s-1, size(colors,1)) + 1, :);      % row 1 = Person 1, row 2 = Person 2
    plot(ax, t(1:n), y(1:n), 'Color', col, 'LineWidth', 2, ...
         'DisplayName', personNames{min(s, numel(personNames))});
end
end
