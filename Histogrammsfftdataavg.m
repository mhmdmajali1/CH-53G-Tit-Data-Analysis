%% ========================================================================
%  histogramRelations.m
%  ------------------------------------------------------------------------
%  Histogram report of every relation that can be derived from the
%  FFT-vs-compliance analysis in fftdataavg.m.
%
%  Per test it collects
%     - the mean FFT amplitude (target harmonic / condition) per channel
%     - its % deviation from the fleet-wide baseline
%     - the compliance outcome of the test's last flight, number of violations
%     - number of flights, aircraft, end date
%
%  Figures
%     1. FFT amplitude per test, per channel
%     2. FFT deviation from the fleet baseline (%), per channel
%     3. Raw FFT amplitude per flight entry (the data behind the baseline)
%     4. Compliance outcome of the tests (status, violations, flights per
%        test, before/after the limit change, per-aircraft rate, FFT sample count)
%     5. FFT amplitude of compliant vs. non-compliant tests, per channel
%     6. FFT deviation category (LOWER / close / HIGHER) vs. compliance outcome
%  ========================================================================

clear; clc; close all;

%% ------------------------------------------------------------------------
%  0. Settings
%  ------------------------------------------------------------------------
jsonFile        = 'CH-53G Tit_data.json';   % or 'CH-53G_Tit-data_CLEANED.json'
targetCondition = '130 Knoten';
targetHarmonic  = 1;                         % 1 = 1/rev fundamental
channels        = {'Lateral', 'Vertikal', 'Radial', 'Axial'};
axisLimitDate   = iso2serial('2023-07-20T00:00:00');
nBins           = 20;                        % bins for continuous histograms
pctThreshold    = 10;                        % same +/-10 % band as fftdataavg.m

set(0, 'defaultaxesfontsize', 9);
set(0, 'defaulttextfontsize', 9);

addFigTitle = @(s) annotation('textbox', [0 0.95 1 0.05], 'String', s, ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 12, 'FontWeight', 'bold');

%% ------------------------------------------------------------------------
%  1. Load the JSON file
%  ------------------------------------------------------------------------
fid = fopen(jsonFile, 'r');
if fid == -1
    error('Could not open %s', jsonFile);
end
raw = fread(fid, inf, 'uint8=>char')';
fclose(fid);
data = jsondecode(raw);
fprintf('Loaded %d aircraft from %s\n', numel(data.Aircraft), jsonFile);

ampUnit = getFieldOrEmpty(data, 'AmplitudeUnits');
if isempty(ampUnit)
    ampUnit = 'amplitude units';
end

%% ------------------------------------------------------------------------
%  2. Fleet-wide baseline (every flight in the dataset)
%  ------------------------------------------------------------------------
allFlights = {};
for i = 1:numel(data.Aircraft)
    testItems = toItems(getFieldOrEmpty(data.Aircraft(i), 'Tests'));
    for j = 1:numel(testItems)
        flightItems = toItems(normalizeFlights(getFieldOrEmpty(testItems{j}, 'Flights')));
        allFlights = [allFlights(:); flightItems(:)];
    end
end

globalVals = collectHarmonicAmplitudes(allFlights, targetCondition, targetHarmonic);

globalMean = struct();
for c = 1:numel(channels)
    ch = channels{c};
    if isempty(globalVals.(ch))
        globalMean.(ch) = NaN;
    else
        globalMean.(ch) = mean(globalVals.(ch));
    end
end

fprintf('\n=== GLOBAL average (harmonic %g, condition "%s") ===\n', targetHarmonic, targetCondition);
for c = 1:numel(channels)
    ch = channels{c};
    fprintf('%-10s: mean=%.4f %s (n=%d)\n', ch, globalMean.(ch), ampUnit, numel(globalVals.(ch)));
end

%% ------------------------------------------------------------------------
%  3. Collect one record per test (all vectors stay aligned, one entry / test)
%  ------------------------------------------------------------------------
testMean = struct();   % mean FFT amplitude of the test, per channel (NaN = no data)
testN    = struct();   % number of FFT entries behind that mean
testPct  = struct();   % % deviation from the global baseline
for c = 1:numel(channels)
    ch = channels{c};
    testMean.(ch) = [];
    testN.(ch)    = [];
    testPct.(ch)  = [];
end

testStatus     = [];   %  1 = closed compliant | 0 = closed non-compliant | -1 = no compliance data
testNumViol    = [];   % violated readings on the last flight
testNumFlights = [];
testAircraft   = [];
testEnd        = [];   % serial date of the last flight's end (NaN if unknown)

for i = 1:numel(data.Aircraft)
    testItems = toItems(getFieldOrEmpty(data.Aircraft(i), 'Tests'));

    for j = 1:numel(testItems)
        flightItems = toItems(normalizeFlights(getFieldOrEmpty(testItems{j}, 'Flights')));
        if isempty(flightItems)
            continue
        end

        % ---- FFT values of this test ----
        testVals = collectHarmonicAmplitudes(flightItems, targetCondition, targetHarmonic);
        hasAnyFftData = false;
        for c = 1:numel(channels)
            if ~isempty(testVals.(channels{c}))
                hasAnyFftData = true;
            end
        end

        % ---- Compliance of the actual last flight ----
        [~, lastFlight] = getLastFlight(flightItems);
        [compliant, hasComplianceData, violations] = checkFlightCompliance(lastFlight, axisLimitDate);

        if ~hasAnyFftData && ~hasComplianceData
            continue      % same rule as fftdataavg.m: nothing relevant -> skip
        end

        for c = 1:numel(channels)
            ch = channels{c};
            vals = testVals.(ch);
            if isempty(vals)
                testMean.(ch)(end+1) = NaN;
                testN.(ch)(end+1)    = 0;
                testPct.(ch)(end+1)  = NaN;
            else
                m = mean(vals);
                testMean.(ch)(end+1) = m;
                testN.(ch)(end+1)    = numel(vals);
                gMean = globalMean.(ch);
                if isnan(gMean) || gMean == 0
                    testPct.(ch)(end+1) = NaN;
                else
                    testPct.(ch)(end+1) = 100 * (m - gMean) / gMean;
                end
            end
        end

        if hasComplianceData
            if compliant
                testStatus(end+1)  = 1;
                testNumViol(end+1) = 0;
            else
                testStatus(end+1)  = 0;
                testNumViol(end+1) = numel(violations);
            end
        else
            testStatus(end+1)  = -1;
            testNumViol(end+1) = 0;
        end

        testNumFlights(end+1) = numel(flightItems);
        testAircraft(end+1)   = i;

        eStr = getFieldOrEmpty(lastFlight, 'Ended');
        if isempty(eStr)
            testEnd(end+1) = NaN;
        else
            testEnd(end+1) = iso2serial(eStr);
        end
    end
end

nComp = sum(testStatus ==  1);
nNon  = sum(testStatus ==  0);
nNo   = sum(testStatus == -1);

if isempty(testStatus)
    error('No test with FFT or compliance data was found - nothing to plot.');
end

%% ------------------------------------------------------------------------
%  4. Console summary
%  ------------------------------------------------------------------------
fprintf('\n=== Tests analysed: %d  (closed compliant %d | closed non-compliant %d | no compliance data %d) ===\n', ...
    numel(testStatus), nComp, nNon, nNo);
if (nComp + nNon) > 0
    fprintf('Non-compliant share among tests with compliance data: %.1f %%\n', ...
        100 * nNon / (nComp + nNon));
end

fprintf('\nMean FFT amplitude per test [%s], split by compliance outcome:\n', ampUnit);
for c = 1:numel(channels)
    ch = channels{c};
    v  = testMean.(ch);
    a  = v(testStatus == 1 & ~isnan(v));
    b  = v(testStatus == 0 & ~isnan(v));
    mA = NaN;  if ~isempty(a), mA = mean(a); end
    mB = NaN;  if ~isempty(b), mB = mean(b); end
    fprintf('  %-9s compliant: %.4f (n=%d) | non-compliant: %.4f (n=%d)\n', ...
        ch, mA, numel(a), mB, numel(b));
end

%% ------------------------------------------------------------------------
%  5. Figure 1 - FFT amplitude per test
%  ------------------------------------------------------------------------
figure('Name', 'Fig 1 - FFT amplitude per test', 'NumberTitle', 'off');
for c = 1:numel(channels)
    ch = channels{c};
    subplot(2, 2, c);
    plotHist(testMean.(ch), nBins, ch, ...
        sprintf('Mean FFT amplitude at %g/rev [%s]', targetHarmonic, ampUnit), ...
        globalMean.(ch));
end
addFigTitle(sprintf('FFT amplitude per test - %s (red = fleet mean)', targetCondition));

%% ------------------------------------------------------------------------
%  6. Figure 2 - deviation from the fleet baseline
%  ------------------------------------------------------------------------
figure('Name', 'Fig 2 - deviation from fleet baseline', 'NumberTitle', 'off');
for c = 1:numel(channels)
    ch = channels{c};
    subplot(2, 2, c);
    plotHist(testPct.(ch), nBins, ch, ...
        'Deviation from fleet mean (%)', [-pctThreshold, pctThreshold]);
end
addFigTitle(sprintf('Test mean vs. fleet baseline - %s (red = +/-%g %% band)', ...
    targetCondition, pctThreshold));

%% ------------------------------------------------------------------------
%  7. Figure 3 - raw FFT amplitude per flight entry
%  ------------------------------------------------------------------------
figure('Name', 'Fig 3 - raw FFT amplitude (all flights)', 'NumberTitle', 'off');
for c = 1:numel(channels)
    ch = channels{c};
    subplot(2, 2, c);
    plotHist(globalVals.(ch), nBins, ch, ...
        sprintf('FFT amplitude at %g/rev [%s]', targetHarmonic, ampUnit), ...
        globalMean.(ch));
end
addFigTitle(sprintf('Raw FFT amplitude, every flight entry - %s (red = fleet mean)', targetCondition));

%% ------------------------------------------------------------------------
%  8. Figure 4 - compliance outcome of the tests
%  ------------------------------------------------------------------------
figure('Name', 'Fig 4 - compliance outcome', 'NumberTitle', 'off');

% (1) outcome counts
subplot(2, 3, 1);
counts = [nComp, nNon, nNo];
bar(1:3, counts);
set(gca, 'xtick', 1:3, 'xticklabel', {'Compliant', 'Non-comp.', 'No data'});
for k = 1:3
    text(k, counts(k), sprintf('%d', counts(k)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end
ylabel('Tests');
title('Outcome of the last flight');
grid on;

% (2) violated readings per non-compliant test
subplot(2, 3, 2);
v = testNumViol(testStatus == 0);
if isempty(v)
    plotHist([], 1, 'Violations per non-compliant test', '');
else
    plotHist(v, 1:max(v), 'Violations per non-compliant test', 'Violated readings on last flight');
end

% (3) flights per test, compliant vs non-compliant
subplot(2, 3, 3);
fl = testNumFlights(testStatus >= 0);
if isempty(fl)
    plotGroupedHist([], [], 1, 'Flights per test', '', 'Compliant', 'Non-compliant');
else
    plotGroupedHist(testNumFlights(testStatus == 1), testNumFlights(testStatus == 0), ...
        1:max(fl), 'Flights per test', 'Flights in test', 'Compliant', 'Non-compliant');
end

% (4) before / after the limit change
subplot(2, 3, 4);
isBefore = ~isnan(testEnd) & (testEnd <  axisLimitDate);
isAfter  = ~isnan(testEnd) & (testEnd >= axisLimitDate);
E = [sum(isBefore & testStatus == 1), sum(isBefore & testStatus == 0); ...
     sum(isAfter  & testStatus == 1), sum(isAfter  & testStatus == 0)];
bar(1:2, E, 'grouped');
set(gca, 'xtick', 1:2, 'xticklabel', {'Before 20.07.2023', 'From 20.07.2023'});
ylabel('Tests');
title('Test end date vs. Lateral limit change');
hl = legend('Compliant', 'Non-compliant', 'Location', 'northeast');
set(hl, 'fontsize', 8);
grid on;

% (5) per-aircraft share of non-compliant tests
subplot(2, 3, 5);
aircraftIds = unique(testAircraft);
rate = nan(1, numel(aircraftIds));
for a = 1:numel(aircraftIds)
    mask = (testAircraft == aircraftIds(a)) & (testStatus >= 0);
    if any(mask)
        rate(a) = 100 * sum(testStatus(mask) == 0) / sum(mask);
    end
end
plotHist(rate, 10, 'Aircraft', 'Non-compliant tests per aircraft (%)');

% (6) FFT entries behind each test
subplot(2, 3, 6);
totalN = zeros(size(testStatus));
for c = 1:numel(channels)
    totalN = totalN + testN.(channels{c});
end
plotHist(totalN(totalN > 0), nBins, 'Tests with FFT data', 'FFT entries per test (all channels)');

addFigTitle('Compliance outcome of the tests (last flight)');

%% ------------------------------------------------------------------------
%  9. Figure 5 - FFT amplitude: compliant vs non-compliant tests
%  ------------------------------------------------------------------------
figure('Name', 'Fig 5 - FFT amplitude vs compliance', 'NumberTitle', 'off');
for c = 1:numel(channels)
    ch = channels{c};
    subplot(2, 2, c);
    v = testMean.(ch);
    plotGroupedHist(v(testStatus == 1), v(testStatus == 0), nBins, ch, ...
        sprintf('Mean FFT amplitude at %g/rev [%s]', targetHarmonic, ampUnit), ...
        'Closed compliant', 'Closed non-compliant');
end
addFigTitle(sprintf('FFT amplitude of compliant vs. non-compliant tests - %s', targetCondition));

%% ------------------------------------------------------------------------
%  10. Figure 6 - FFT deviation category vs compliance outcome
%  ------------------------------------------------------------------------
figure('Name', 'Fig 6 - FFT deviation vs compliance', 'NumberTitle', 'off');
catLabels = {sprintf('LOWER <-%g%%', pctThreshold), 'close', sprintf('HIGHER >+%g%%', pctThreshold)};

fprintf('\nShare of NON-compliant tests per FFT deviation category:\n');
for c = 1:numel(channels)
    ch  = channels{c};
    pct = testPct.(ch);

    valid  = ~isnan(pct) & (testStatus >= 0);
    catIdx = 2 * ones(size(pct));
    catIdx(pct < -pctThreshold) = 1;
    catIdx(pct >  pctThreshold) = 3;

    M = zeros(3, 2);
    for k = 1:3
        M(k, 1) = sum(valid & catIdx == k & testStatus == 1);
        M(k, 2) = sum(valid & catIdx == k & testStatus == 0);
    end

    subplot(2, 2, c);
    bar(1:3, M, 'grouped');
    set(gca, 'xtick', 1:3, 'xticklabel', catLabels);
    ylabel('Tests');
    title(ch);
    hl = legend('Closed compliant', 'Closed non-compliant', 'Location', 'northeast');
    set(hl, 'fontsize', 8);
    grid on;

    fprintf('  %-9s', ch);
    for k = 1:3
        tot = M(k, 1) + M(k, 2);
        if tot > 0
            fprintf(' | %s: %.1f %% (n=%d)', catLabels{k}, 100 * M(k, 2) / tot, tot);
        else
            fprintf(' | %s: n/a', catLabels{k});
        end
    end
    fprintf('\n');
end
addFigTitle('FFT deviation from fleet mean vs. compliance outcome');
