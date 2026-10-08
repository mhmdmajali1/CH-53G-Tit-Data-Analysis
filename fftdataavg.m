%% Compute GLOBAL average (across every flight in the whole dataset)
fid = fopen('CH-53G Tit_data.json', 'r');
raw = fread(fid, inf, 'uint8=>char')';
fclose(fid);
data = jsondecode(raw);

targetCondition = '130 Knoten';
targetHarmonic  = 1;
channels = {'Lateral', 'Vertikal', 'Radial', 'Axial'};
axisLimitDate = iso2serial('2023-07-20T00:00:00');

allFlights = {};
for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;
    for j = 1:numel(tests)
        flightItems = toItems(normalizeFlights(tests(j).Flights));
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
    fprintf('%-10s: mean=%.4f (n=%d)\n', ch, globalMean.(ch), numel(globalVals.(ch)));
end

%% PASS 1: compute every test's summary (FFT + compliance), store for later filtering

testSummaries = {};   % each entry: struct with all info needed to print later

numTestsCompliantAtClose    = 0;
numTestsNonCompliantAtClose = 0;
numTestsNoData              = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;
    tests = tests(:);

    % Sort chronologically so "the test right after it" is well-defined
    starts = zeros(numel(tests), 1);
    for j = 1:numel(tests)
        starts(j) = iso2serial(tests(j).Started);
    end
    [~, sortIdx] = sort(starts);
    tests = tests(sortIdx);

    for j = 1:numel(tests)
        flightItems = toItems(normalizeFlights(tests(j).Flights));
        if isempty(flightItems)
            continue
        end

        % ---- FFT comparison for this test ----
        testVals = collectHarmonicAmplitudes(flightItems, targetCondition, targetHarmonic);
        hasAnyFftData = ~isempty(testVals.Lateral) || ~isempty(testVals.Vertikal) || ...
                        ~isempty(testVals.Radial)  || ~isempty(testVals.Axial);

        fftLines = {};
        if hasAnyFftData
            for c = 1:numel(channels)
                ch = channels{c};
                vals = testVals.(ch);
                if isempty(vals)
                    fftLines{end+1} = sprintf('  %-10s: no matching samples in this test', ch);
                    continue
                end
                testMean = mean(vals);
                gMean = globalMean.(ch);
                if isnan(gMean) || gMean == 0
                    fftLines{end+1} = sprintf('  %-10s: mean=%.4f (n=%d) -- no valid global baseline to compare against', ...
                        ch, testMean, numel(vals));
                    continue
                end
                pctDiff = 100 * (testMean - gMean) / gMean;
                if abs(pctDiff) <= 10
                    comment = 'close to fleet average';
                elseif pctDiff > 10
                    comment = 'HIGHER than fleet average -- worth reviewing';
                else
                    comment = 'LOWER than fleet average';
                end
                fftLines{end+1} = sprintf('  %-10s: mean=%.4f (n=%d) | global=%.4f | diff=%+.1f%% -- %s', ...
                    ch, testMean, numel(vals), gMean, pctDiff, comment);
            end
        else
            fftLines{end+1} = sprintf('  (no matching FFT harmonic data for condition "%s" in this test)', targetCondition);
        end

        % ---- Compliance check on the actual last flight ----
        endedTimes = -Inf(numel(flightItems), 1);
        for k = 1:numel(flightItems)
            eStr = getFieldOrEmpty(flightItems{k}, 'Ended');
            if ~isempty(eStr)
                endedTimes(k) = iso2serial(eStr);
            end
        end
        [~, lastIdx] = max(endedTimes);
        lastFlight = flightItems{lastIdx};
        [compliant, hasComplianceData, violations] = checkFlightCompliance(lastFlight, axisLimitDate);

        if ~hasAnyFftData && ~hasComplianceData
            continue   % nothing relevant at all -- skip entirely, don't even store
        end

        s = struct();
        s.aircraftIdx = i;
        s.tailNumber  = data.Aircraft(i).TailNumber;
        s.testNumber  = tests(j).TestNumber;
        s.started     = tests(j).Started;
        s.ended       = tests(j).Ended;
        s.fftLines    = fftLines;
        s.hasComplianceData = hasComplianceData;

        if hasComplianceData
            if compliant
                numTestsCompliantAtClose = numTestsCompliantAtClose + 1;
                s.status = 'compliant';
                s.complianceLine = sprintf('Aircraft %s, Test %d: last flight ended %s -- CLOSED COMPLIANT', ...
                    s.tailNumber, s.testNumber, lastFlight.Ended);
                s.violationLines = {};
            else
                numTestsNonCompliantAtClose = numTestsNonCompliantAtClose + 1;
                s.status = 'noncompliant';
                s.complianceLine = sprintf('Aircraft %s, Test %d: last flight ended %s -- CLOSED WHILE STILL NON-COMPLIANT', ...
                    s.tailNumber, s.testNumber, lastFlight.Ended);
                s.violationLines = violations;
            end
        else
            numTestsNoData = numTestsNoData + 1;
            s.status = 'nodata';
            s.complianceLine = '  (no relevant BalanceData to determine compliance for this test)';
            s.violationLines = {};
        end

        testSummaries{end+1} = s;
    end
end

%% PASS 2: decide which summaries to print, per your rule

n = numel(testSummaries);
printFlag = false(n, 1);
compliantShown = 0;

for idx = 1:n
    s = testSummaries{idx};

    if strcmp(s.status, 'compliant') && compliantShown < 2
        printFlag(idx) = true;
        compliantShown = compliantShown + 1;
    end

    if strcmp(s.status, 'noncompliant')
        printFlag(idx) = true;
        % also mark the NEXT test, only if it belongs to the SAME aircraft
        if idx < n && testSummaries{idx+1}.aircraftIdx == s.aircraftIdx
            printFlag(idx+1) = true;
        end
    end
end

%% PASS 3: print only the flagged summaries

fprintf('\n=== Per-test FFT comparison + compliance outcome (filtered view) ===\n');

for idx = 1:n
    if ~printFlag(idx)
        continue
    end
    s = testSummaries{idx};

    fprintf('\n--- Aircraft %s, Test %d (%s to %s) ---\n', s.tailNumber, s.testNumber, s.started, s.ended);
    for L = 1:numel(s.fftLines)
        fprintf('%s\n', s.fftLines{L});
    end

    fprintf('%s\n', s.complianceLine);
    for v = 1:numel(s.violationLines)
        fprintf('    - %s\n', s.violationLines{v});
    end
end

%% Overall summary -- based on ALL tests, not just the printed subset

totalChecked = numTestsCompliantAtClose + numTestsNonCompliantAtClose;

fprintf('\n=== Overall summary (full dataset) ===\n');
fprintf('Tests closed COMPLIANT:                %d (%.1f%%)\n', ...
    numTestsCompliantAtClose, 100*numTestsCompliantAtClose/totalChecked);
fprintf('Tests closed WHILE STILL NON-COMPLIANT: %d (%.1f%%)\n', ...
    numTestsNonCompliantAtClose, 100*numTestsNonCompliantAtClose/totalChecked);
fprintf('Tests skipped (no relevant BalanceData): %d\n', numTestsNoData);
