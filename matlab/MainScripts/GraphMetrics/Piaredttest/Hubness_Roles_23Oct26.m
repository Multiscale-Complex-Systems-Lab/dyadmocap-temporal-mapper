%% ============ IS THE BOSS MORE CENTRAL THAN THE EMPLOYEE? ============
% The closeness analysis for the two persons. Same measure
% (nodeClosenessByCategory), same machinery (pairedDiffStats: paired t-test +
% BCa bootstrap over 10,000 dyad resamples), one comparison: Person 1 Active
% against Person 2 Active, within dyad, run separately in each conversation.
%
% WHY THIS IS A STRONG TEST AND NOT AN EXTRA ONE
% In casual chat, Person 1 and Person 2 are arbitrary labels - nothing
% distinguishes them. In conflict they are the boss and the employee. So the
% two conditions are a control and a test of the same comparison:
%
%   Casual chat -> expect NO difference. If one appears, the labels are
%                  carrying something they should not, and the per-person
%                  states cannot be read as role-free anywhere.
%   Conflict    -> a difference here is a ROLE effect, measured structurally
%                  rather than annotated by hand.
%
% This is the claim the method is meant to support: that the network recovers
% behavioural structure, and distinguishes the two conversations.
%
% Expected: in casual chat the CI contains zero. In conflict, a role effect
% would show as Person 1 (boss) nearer the core, so meanDiff (P1 - P2)
% negative; if the CI contains zero, there is no role effect.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('nodeClosenessByCategory','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');

first               = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
BehaviouralCategory = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
numCategories       = numel(BehaviouralCategory);

Close.GTK = nodeClosenessByCategory(GTK_AllDyads_GraphData, numCategories);
Close.MAN = nodeClosenessByCategory(MAN_AllDyads_GraphData, numCategories);

iP1 = find(strcmpi(BehaviouralCategory, 'Person 1 Active'), 1);
iP2 = find(strcmpi(BehaviouralCategory, 'Person 2 Active'), 1);
if isempty(iP1) || isempty(iP2)
    error('Could not find the Person 1 / Person 2 categories in: %s', ...
          strjoin(BehaviouralCategory, ', '));
end

conditions = {'Casual Chat (labels arbitrary - control)', 'GTK'; ...
              'Conflict (Person 1 = boss, Person 2 = employee)', 'MAN'};
nC = size(conditions,1);

Condition = strings(nC,1);  N        = nan(nC,1);
MeanP1    = nan(nC,1);      MeanP2   = nan(nC,1);
MeanDiff  = nan(nC,1);      CI_Lower = nan(nC,1);
CI_Upper  = nan(nC,1);      tStat    = nan(nC,1);
dfOut     = nan(nC,1);      pValue   = nan(nC,1);
dz        = nan(nC,1);      Verdict  = strings(nC,1);

for k = 1:nC
    S = pairedDiffStats(Close.(conditions{k,2})(:,iP1), ...
                        Close.(conditions{k,2})(:,iP2));

    Condition(k) = string(conditions{k,1});
    N(k)         = S.N;      MeanP1(k)   = S.meanA;
    MeanP2(k)    = S.meanB;  MeanDiff(k) = S.meanDiff;
    CI_Lower(k)  = S.ciBoot(1);  CI_Upper(k) = S.ciBoot(2);
    tStat(k)     = S.t;      dfOut(k)    = S.df;
    pValue(k)    = S.p;      dz(k)       = S.dz;

    % distance, so a NEGATIVE difference means Person 1 is nearer the core
    Verdict(k) = DYMO_ciVerdict(S.ciBoot, ...
        'Person 2 nearer the network core', ...
        'Person 1 nearer the network core');

    fprintf('\n%s (N = %d)\n', conditions{k,1}, S.N);
    fprintf('  Person 1 Active %.4g   Person 2 Active %.4g\n', S.meanA, S.meanB);
    fprintf('  difference (P1 - P2) = %.4g, 95%% CI [%.4g, %.4g]\n', ...
        S.meanDiff, S.ciBoot(1), S.ciBoot(2));
    fprintf('  %s\n', Verdict(k));
end

Roles = table(Condition, N, MeanP1, MeanP2, MeanDiff, CI_Lower, CI_Upper, ...
    tStat, dfOut, pValue, dz, Verdict, ...
    'VariableNames', {'Condition','N','Closeness_Person1','Closeness_Person2', ...
                      'MeanDiff_P1minusP2','CI_Lower','CI_Upper','t','df','p', ...
                      'dz','Verdict'});

Roles = DYMO_roundTable(Roles);
DYMO_writeTable(Roles, 'Hubness_Roles.csv');
DYMO_writeTable(Roles, 'Hubness_Roles.xlsx');
disp(Roles)

%% ============ IS THE ROLE GAP BIGGER IN CONFLICT? (THE INTERACTION) ============
%
% WHY THIS BLOCK EXISTS
% A significant result in one condition and a null in the other is NOT a
% difference between conditions - the classic trap. Claiming the role gap is
% specific to conflict requires testing the gap against the gap, which is what
% this does: each dyad's (Person 1 - Person 2) difference in conflict minus the
% same dyad's difference in casual chat, paired across dyads.
%

dGTK = Close.GTK(:,iP1) - Close.GTK(:,iP2);   % role gap, casual chat
dMAN = Close.MAN(:,iP1) - Close.MAN(:,iP2);   % role gap, conflict

Sint = pairedDiffStats(dMAN, dGTK);           % conflict gap minus casual gap

fprintf('\nInteraction: gap(conflict) - gap(casual) = %.4g, 95%% CI [%.4g, %.4g], p = %.4g\n', ...
    Sint.meanDiff, Sint.ciBoot(1), Sint.ciBoot(2), Sint.p);

RoleGap = table("Role gap: conflict minus casual chat", Sint.N, ...
    mean(dGTK(isfinite(dGTK))), mean(dMAN(isfinite(dMAN))), ...
    Sint.meanDiff, Sint.ciBoot(1), Sint.ciBoot(2), Sint.t, Sint.df, Sint.p, Sint.dz, ...
    DYMO_ciVerdict(Sint.ciBoot, ...
        'Role gap larger in casual chat', ...
        'Role gap larger in conflict'), ...
    'VariableNames', {'Contrast','N','Gap_CasualChat','Gap_Conflict', ...
                      'MeanDiff','CI_Lower','CI_Upper','t','df','p','dz','Verdict'});

RoleGap = DYMO_roundTable(RoleGap);
DYMO_writeTable(RoleGap, 'Hubness_RoleGap.csv');
DYMO_writeTable(RoleGap, 'Hubness_RoleGap.xlsx');
disp(RoleGap)

fprintf(['\nNote: this interval was marginal when first run (-0.747, 95%% CI\n' ...
         '[-1.464, -0.058], p = .0500). It excludes zero, but barely. Report it\n' ...
         'with its interval; it should not carry a claim on its own.\n\n']);
