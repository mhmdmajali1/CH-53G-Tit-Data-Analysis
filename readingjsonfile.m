%% ========================================================================
%  CH-53G Tit-Data Analysis
%  Reads the JSON dataset and computes summary statistics across all
%  aircraft, tests, and flights.
%  ========================================================================

%% 1. Load and parse the JSON file
fid = fopen('CH-53G Tit_data-CLEANED.json', 'r');
raw = fread(fid, inf, 'uint8=>char')';
fclose(fid);

data = jsondecode(raw);
pwd
%% 2. Explore top-level structure
disp(fieldnames(data))
data.AircraftType
data.AmplitudeUnits


%% 3. Total number of aircraft / tests / flights
numTests   = 0;
numFlights = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;
    numTests = numTests + numel(tests);

    for j = 1:numel(tests)
        numFlights = numFlights + numel(tests(j).Flights);
    end
end

fprintf('Total number of aircraft: %d\n', numel(data.Aircraft));
fprintf('Total number of tests:    %d\n', numTests);
fprintf('Total number of flights:  %d\n', numFlights);


%% 4. Tests with ONLY 'Bodenlauf' vs. tests with ALL 5 target conditions
targetConditions = {'Bodenlauf', 'Hovern OGE', '90 Knoten', '110 Knoten', '130 Knoten'};

numTestsOnlyBodenlauf = 0;
numTestsAllConditions = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end
        testConditions = {};

        for k = 1:numel(flights)
            bd = normalizeBalanceData(flights(k).BalanceData);
            if isempty(bd)
                continue
            end
            testConditions = [testConditions, {bd.TestCondition}];
        end

        uniqueConditions = unique(testConditions);

        % Test contains ONLY 'Bodenlauf' and nothing else
        if isequal(uniqueConditions, {'Bodenlauf'})
            numTestsOnlyBodenlauf = numTestsOnlyBodenlauf + 1;
        end

        % Test contains all 5 target conditions (extra ones allowed too)
        if all(ismember(targetConditions, uniqueConditions))
            numTestsAllConditions = numTestsAllConditions + 1;
        end
    end
end

fprintf('Tests with ONLY Bodenlauf:   %d\n', numTestsOnlyBodenlauf);
fprintf('Tests with ALL 5 conditions: %d\n', numTestsAllConditions);


%% 5. Flights / tests containing Haupt (main rotor) or Heck (tail rotor) data
numFlightsHaupt = 0;
numFlightsHeck  = 0;
numTestsHaupt   = 0;
numTestsHeck    = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
         end
        testHasHaupt = false;
        testHasHeck  = false;

        for k = 1:numel(flights)
            bd = normalizeBalanceData(flights(k).BalanceData);
            if isempty(bd)
                continue
            end

            parts = {bd.Part};
            flightHasHaupt = any(strcmp(parts, 'Haupt'));
            flightHasHeck  = any(strcmp(parts, 'Heck'));

            if flightHasHaupt
                numFlightsHaupt = numFlightsHaupt + 1;
                testHasHaupt = true;
            end
            if flightHasHeck
                numFlightsHeck = numFlightsHeck + 1;
                testHasHeck = true;
            end
        end

        if testHasHaupt
            numTestsHaupt = numTestsHaupt + 1;
        end
        if testHasHeck
            numTestsHeck = numTestsHeck + 1;
        end
    end
end

fprintf('Flights with Haupt data: %d\n', numFlightsHaupt);
fprintf('Tests with Haupt data:   %d\n', numTestsHaupt);
fprintf('Flights with Heck data:  %d\n', numFlightsHeck);
fprintf('Tests with Heck data:    %d\n', numTestsHeck);


%% 6. Inspect a single example (first aircraft, first test, first flight)
numel(data.Aircraft)
data.Aircraft(1).TailNumber
data.Aircraft(1).Tests(1)

flights1 = normalizeFlights(data.Aircraft(1).Tests(1).Flights);
bd = normalizeBalanceData(flights1(1).BalanceData);
disp(bd)             % struct array
{bd.TestCondition}   % cell array of condition names
[bd.Amplitude]        % vector of amplitudes
[bd.Phase]             % vector of phases

%% 7. Check chronological order of Test and Flight dates

orderIssues = {};  % collect a description of every problem found

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        testStart = iso2serial(tests(j).Started);
        testEnd   = iso2serial(tests(j).Ended);

        % 1) Test itself: Started must be <= Ended
        if testStart > testEnd
            orderIssues{end+1} = sprintf(...
                'Aircraft %s, Test %d: Test Started (%s) is AFTER Test Ended (%s)', ...
                data.Aircraft(i).TailNumber, j, tests(j).Started, tests(j).Ended);
        end

        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end
        prevFlightEnd = -Inf;

        for k = 1:numel(flights)
            flStart = iso2serial(flights(k).Started);
            flEnd   = iso2serial(flights(k).Ended);

            % 2) Flight itself: Started must be <= Ended
            if flStart > flEnd
                orderIssues{end+1} = sprintf(...
                    'Aircraft %s, Test %d, Flight %d: Flight Started (%s) is AFTER Flight Ended (%s)', ...
                    data.Aircraft(i).TailNumber, j, k, flights(k).Started, flights(k).Ended);
            end

            % 3) Flight must lie within the Test's time window
            if flStart < testStart || flEnd > testEnd
                orderIssues{end+1} = sprintf(...
                    'Aircraft %s, Test %d, Flight %d: Flight (%s - %s) is OUTSIDE Test window (%s - %s)', ...
                    data.Aircraft(i).TailNumber, j, k, flights(k).Started, flights(k).Ended, tests(j).Started, tests(j).Ended);
            end

            % 4) Flights must be in chronological order within the test
            if flStart < prevFlightEnd
                orderIssues{end+1} = sprintf(...
                    'Aircraft %s, Test %d, Flight %d: starts (%s) BEFORE the previous flight ended', ...
                    data.Aircraft(i).TailNumber, j, k, flights(k).Started);
            end

            prevFlightEnd = flEnd;
        end
    end
end

fprintf('\nTotal chronological order issues found: %d\n', numel(orderIssues));
for idx = 1:numel(orderIssues)
    fprintf('%s\n', orderIssues{idx});
end

%% 8. Flights/tests by condition type (Bodenlauf-only vs. other)

Fa = 0;  % flights with ONLY 'Bodenlauf' condition
Fb = 0;  % flights with any OTHER condition present
Ta = 0;  % tests with at least one flight that is Bodenlauf-only
Tb = 0;  % tests with at least one flight that has some other condition

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end

        testHasBodenlaufOnlyFlight = false;
        testHasOtherConditionFlight = false;

        for k = 1:numel(flights)
            bd = normalizeBalanceData(flights(k).BalanceData);
            if isempty(bd)
                continue
            end

            flightConditions = unique({bd.TestCondition});

            % Flight contains ONLY 'Bodenlauf' and nothing else
            if isequal(flightConditions, {'Bodenlauf'})
                Fa = Fa + 1;
                testHasBodenlaufOnlyFlight = true;
            else
                % Flight has at least one condition that is not Bodenlauf
                Fb = Fb + 1;
                testHasOtherConditionFlight = true;
            end
        end

        if testHasBodenlaufOnlyFlight
            Ta = Ta + 1;
        end
        if testHasOtherConditionFlight
            Tb = Tb + 1;
        end
    end
end

fprintf('Fa (flights with ONLY Bodenlauf):        %d\n', Fa);
fprintf('Fb (flights with any OTHER condition):   %d\n', Fb);
fprintf('Ta (tests with >=1 Bodenlauf-only flight): %d\n', Ta);
fprintf('Tb (tests with >=1 other-condition flight): %d\n', Tb);

%% 9. A1 / A2 / B1 / B2: Bodenlauf-only flights (Track + Balance), split by Haupt / Heck

A1 = 0;
A2 = 0;
A3 = 0;
A4 = 0;
B1 = 0;
B2 = 0;
B3 = 0;
B4 = 0;
otherConditions = {'Hovern OGE', '90 Knoten', '110 Knoten', '130 Knoten'};

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end

        testHasA1 = false;
        testHasA2 = false;
        testHasA3 = false;
        testHasA4 = false;

        for k = 1:numel(flights)
            bd = normalizeBalanceData(getFieldOrEmpty(flights(k),'BalanceData'));
            td = normalizeTrackData(getFieldOrEmpty(flights(k), 'TrackData'));

            % Combine TestConditions from both Track and Balance data
            combinedConditions = {};
            if ~isempty(bd)
                combinedConditions = [combinedConditions, {bd.TestCondition}];
            end
            if ~isempty(td)
                combinedConditions = [combinedConditions, {td.TestCondition}];
            end

            if isempty(combinedConditions)
                continue  % no track/balance data at all -> skip this flight
            end

            uniqueConditions = unique(combinedConditions);
            isBodenlaufOnly = isequal(uniqueConditions, {'Bodenlauf'});
            hasOtherCondition = any(ismember(combinedConditions, otherConditions));


            % Haupt: check both TrackData and BalanceData
            hasHaupt = false;
            if ~isempty(bd) && any(strcmp({bd.Part}, 'Haupt'))
                hasHaupt = true;
            end
            if ~isempty(td) && any(strcmp({td.Part}, 'Haupt'))
                hasHaupt = true;
            end

            % Heck: BalanceData only (TrackData never has Heck)
            hasHeck = ~isempty(bd) && any(strcmp({bd.Part}, 'Heck'));

            if isBodenlaufOnly && hasHaupt
            A1 = A1 + 1;
            testHasA1 = true;
            end
            if isBodenlaufOnly && hasHeck
            A2 = A2 + 1;
            testHasA2 = true;
            end
            if hasOtherCondition && hasHaupt
            A3 = A3 + 1;
            testHasA3 = true;
            end
            if hasOtherCondition && hasHeck
            A4 = A4 + 1;
            testHasA4 = true;
            end
            end

            if testHasA1
                B1 = B1 + 1;
            end
            if testHasA2
                B2 = B2 + 1;
            end
            if testHasA3
                B3 = B3 + 1;
            end
            if testHasA4
                B4 = B4 + 1;
            end
    end
end

fprintf('\n');
fprintf('A1 (Bodenlauf-only flights with Haupt in Track/Balance): %d\n', A1);
fprintf('A2 (Bodenlauf-only flights with Heck in Balance):        %d\n', A2);
fprintf('B1 (tests with >=1 qualifying A1 flight):                %d\n', B1);
fprintf('B2 (tests with >=1 qualifying A2 flight):                %d\n', B2);
fprintf('A3 (Other-condition flights with Haupt in Track/Balance: %d\n', A3);
fprintf('A4 (Other-condition flights with Heck in Balance):       %d\n', A4);
fprintf('B3 (tests with >=1 qualifying A3 flight):                %d\n', B3);
fprintf('B4 (tests with >=1 qualifying A4 flight):                %d\n', B4);


%% 10. Check gap between last flight of a test and first flight of the next test

gapIssues = {};      % descriptions of qualifying cases
maxGapDays = 30;      % threshold

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    % ---- Build a list of test start times so we can sort tests chronologically ----
    testStarts = zeros(numel(tests), 1);
    for j = 1:numel(tests)
        testStarts(j) = iso2serial(tests(j).Started);
    end

    [~, sortIdx] = sort(testStarts);   % chronological order of tests within this aircraft

    % ---- Walk through consecutive tests in chronological order ----
    for s = 1:numel(sortIdx)-1
        jCurrent = sortIdx(s);
        jNext    = sortIdx(s+1);

        flightsCurrent = normalizeFlights(tests(jCurrent).Flights);
        if iscell(flightsCurrent)
            flightsCurrent = [flightsCurrent{:}];
        end

        flightsNext = normalizeFlights(tests(jNext).Flights);
        if iscell(flightsNext)
            flightsNext = [flightsNext{:}];
        end

        if isempty(flightsCurrent) || isempty(flightsNext)
            continue   % nothing to compare
        end

        % ---- Find the LAST flight of the current test (latest Ended time) ----
        endedTimes = zeros(numel(flightsCurrent), 1);
        for k = 1:numel(flightsCurrent)
            endedTimes(k) = iso2serial(flightsCurrent(k).Ended);
        end
        [lastFlightEnd, lastIdx] = max(endedTimes);

        % ---- Find the FIRST flight of the next test (earliest Started time) ----
        startedTimes = zeros(numel(flightsNext), 1);
        for k = 1:numel(flightsNext)
            startedTimes(k) = iso2serial(flightsNext(k).Started);
        end
        [nextFlightStart, firstIdx] = min(startedTimes);

        % ---- Compute the gap in days ----
        gapDays = nextFlightStart - lastFlightEnd;

        if gapDays >= 0 && gapDays <= maxGapDays
            gapIssues{end+1} = sprintf(...
                'Aircraft %s: Test %d last flight ended %s -> Test %d first flight started %s (gap = %.2f days)', ...
                data.Aircraft(i).TailNumber, ...
                tests(jCurrent).TestNumber, flightsCurrent(lastIdx).Ended, ...
                tests(jNext).TestNumber, flightsNext(firstIdx).Started, ...
                gapDays);
        end
    end
end

fprintf('\nTotal test-pairs with a gap <= %d days: %d\n', maxGapDays, numel(gapIssues));
for idx = 1:numel(gapIssues)
    fprintf('%s\n', gapIssues{idx});
end

%% 11. Flights with NEITHER BalanceData NOR TrackData

emptyFlights = {};

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end

        for k = 1:numel(flights)
            bd = normalizeBalanceData(getFieldOrEmpty(flights(k), 'BalanceData'));
            td = normalizeTrackData(getFieldOrEmpty(flights(k), 'TrackData'));

            if isempty(bd) && isempty(td)
                emptyFlights{end+1} = sprintf(...
                    'Aircraft %s, Test %d, Flight %d: Started=%s, Ended=%s -> NO BalanceData and NO TrackData', ...
                    data.Aircraft(i).TailNumber, tests(j).TestNumber, k, ...
                    flights(k).Started, flights(k).Ended);
            end
        end
    end
end

fprintf('\nTotal flights with NO BalanceData and NO TrackData: %d\n', numel(emptyFlights));
for idx = 1:numel(emptyFlights)
    fprintf('%s\n', emptyFlights{idx});
end

%% 12. Duplicate detection: TailNumbers, Tests, Flights

% ---- 12a. Duplicate TailNumbers (raw, exact string match) ----
rawTails = {data.Aircraft.TailNumber};
[uniqueRaw, ~, ic] = unique(rawTails);
countsRaw = accumarray(ic, 1);
dupRawIdx = find(countsRaw > 1);

fprintf('\n=== 12a. Exact duplicate TailNumbers ===\n');
if isempty(dupRawIdx)
    fprintf('None found.\n');
else
    for d = 1:numel(dupRawIdx)
        fprintf('TailNumber "%s" appears %d times\n', ...
            uniqueRaw{dupRawIdx(d)}, countsRaw(dupRawIdx(d)));
    end
end

% ---- 12b. Duplicate TailNumbers after normalizing (digits only) ----
normalizedTails = cell(size(rawTails));
for t = 1:numel(rawTails)
    digitsOnly = regexprep(rawTails{t}, '\D', '');
    normalizedTails{t} = digitsOnly;
end

[uniqueNorm, ~, icNorm] = unique(normalizedTails);
countsNorm = accumarray(icNorm, 1);
dupNormIdx = find(countsNorm > 1);

fprintf('\n=== 12b. TailNumbers that MATCH after stripping non-digits ===\n');

if isempty(dupNormIdx)
    fprintf('None found.\n');
else
    for d = 1:numel(dupNormIdx)
        normVal = uniqueNorm{dupNormIdx(d)};
        aircraftIdx = find(strcmp(normalizedTails, normVal));  % indices into data.Aircraft

        fprintf('\n---------------------------------------------------------\n');
        fprintf('Normalized tail "%s" matches %d aircraft entries:\n', normVal, numel(aircraftIdx));
        for a = 1:numel(aircraftIdx)
            fprintf('  [%d] Raw TailNumber = "%s" (Aircraft index %d, %d tests)\n', ...
                a, data.Aircraft(aircraftIdx(a)).TailNumber, aircraftIdx(a), ...
                numel(data.Aircraft(aircraftIdx(a)).Tests));
        end

        % ---- Build a summary of each matched aircraft's tests: Started/Ended/TestNumber ----
        aircraftTestSummaries = cell(numel(aircraftIdx), 1);
        for a = 1:numel(aircraftIdx)
            tests = data.Aircraft(aircraftIdx(a)).Tests;
            summary = repmat(struct('TestNumber', [], 'Started', '', 'Ended', ''), numel(tests), 1);
            for j = 1:numel(tests)
                summary(j).TestNumber = tests(j).TestNumber;
                summary(j).Started    = tests(j).Started;
                summary(j).Ended      = tests(j).Ended;
            end
            aircraftTestSummaries{a} = summary;
        end

        % ---- Compare every pair of matched aircraft entries against each other ----
        for a1 = 1:numel(aircraftIdx)-1
            for a2 = a1+1:numel(aircraftIdx)
                tests1 = aircraftTestSummaries{a1};
                tests2 = aircraftTestSummaries{a2};

                fprintf('\n  Comparing "%s" (idx %d) vs "%s" (idx %d):\n', ...
                    data.Aircraft(aircraftIdx(a1)).TailNumber, aircraftIdx(a1), ...
                    data.Aircraft(aircraftIdx(a2)).TailNumber, aircraftIdx(a2));

                % Exact match: same Started+Ended appearing in both test lists
                keys1 = arrayfun(@(s) sprintf('%s|%s', s.Started, s.Ended), tests1, 'UniformOutput', false);
                keys2 = arrayfun(@(s) sprintf('%s|%s', s.Started, s.Ended), tests2, 'UniformOutput', false);

                exactMatches = intersect(keys1, keys2);

                if ~isempty(exactMatches)
                    fprintf('    EXACT test matches (same Started & Ended) found: %d\n', numel(exactMatches));
                    for m = 1:numel(exactMatches)
                        fprintf('      %s\n', exactMatches{m});
                    end
                else
                    fprintf('    No exact Started/Ended test matches.\n');
                end

                % Time-range overlap check: does ANY test from aircraft1 overlap
                % in time with ANY test from aircraft2, even if not identical?
                overlapFound = false;
                for j1 = 1:numel(tests1)
                    s1 = iso2serial(tests1(j1).Started);
                    e1 = iso2serial(tests1(j1).Ended);
                    for j2 = 1:numel(tests2)
                        s2 = iso2serial(tests2(j2).Started);
                        e2 = iso2serial(tests2(j2).Ended);

                        % Standard interval overlap condition
                        if s1 <= e2 && s2 <= e1
                            overlapFound = true;
                            fprintf('    OVERLAP: Test %d (%s to %s) overlaps Test %d (%s to %s)\n', ...
                                tests1(j1).TestNumber, tests1(j1).Started, tests1(j1).Ended, ...
                                tests2(j2).TestNumber, tests2(j2).Started, tests2(j2).Ended);
                        end
                    end
                end

                if ~overlapFound && isempty(exactMatches)
                    fprintf('    No overlapping test date ranges either -> likely genuinely DIFFERENT aircraft testing histories.\n');
                end
            end
        end
    end
end

% ---- 12c. Duplicate Tests (same aircraft, same Started+Ended) ----
fprintf('\n=== 12c. Duplicate Tests (same aircraft, same Started & Ended) ===\n');
dupTestCount = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;
    testKeys = cell(numel(tests), 1);
    for j = 1:numel(tests)
        testKeys{j} = sprintf('%s|%s', tests(j).Started, tests(j).Ended);
    end

    [uniqueKeys, ~, icTest] = unique(testKeys);
    countsTest = accumarray(icTest, 1);
    dupIdx = find(countsTest > 1);

    for d = 1:numel(dupIdx)
        matchingJ = find(strcmp(testKeys, uniqueKeys{dupIdx(d)}));
        testNums = arrayfun(@(x) tests(x).TestNumber, matchingJ);
        fprintf('Aircraft %s: Tests %s share Started/Ended = %s\n', ...
            data.Aircraft(i).TailNumber, mat2str(testNums), uniqueKeys{dupIdx(d)});
        dupTestCount = dupTestCount + 1;
    end
end

if dupTestCount == 0
    fprintf('None found.\n');
end

% ---- 12d. Duplicate Flights (same aircraft+test, same Started+Ended) ----
fprintf('\n=== 12d. Duplicate Flights (same test, same Started & Ended) ===\n');
dupFlightCount = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end

        if numel(flights) < 2
            continue
        end

        flightKeys = cell(numel(flights), 1);
        for k = 1:numel(flights)
            flightKeys{k} = sprintf('%s|%s', flights(k).Started, flights(k).Ended);
        end

        [uniqueFKeys, ~, icFlight] = unique(flightKeys);
        countsFlight = accumarray(icFlight, 1);
        dupIdx = find(countsFlight > 1);

        for d = 1:numel(dupIdx)
            matchingK = find(strcmp(flightKeys, uniqueFKeys{dupIdx(d)}));
            fprintf('Aircraft %s, Test %d: Flights %s share Started/Ended = %s\n', ...
                data.Aircraft(i).TailNumber, tests(j).TestNumber, ...
                mat2str(matchingK), uniqueFKeys{dupIdx(d)});
            dupFlightCount = dupFlightCount + 1;
        end
    end
end

if dupFlightCount == 0
    fprintf('None found.\n');
end

% ---- 12e. Duplicate Flights ACROSS ALL TESTS within the same aircraft ----
fprintf('\n=== 12e. Duplicate Flights across ALL tests (same aircraft, same Started & Ended) ===\n');
dupFlightAcrossTestsCount = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    % ---- Collect every flight from every test in this aircraft ----
    allFlightKeys  = {};   % Started|Ended string
    allFlightTestJ = [];   % which test index (j) this flight belongs to
    allFlightK     = [];   % which flight index (k) within that test

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end

        for k = 1:numel(flights)
            key = sprintf('%s|%s', flights(k).Started, flights(k).Ended);
            allFlightKeys{end+1}  = key;
            allFlightTestJ(end+1) = j;
            allFlightK(end+1)     = k;
        end
    end

    if numel(allFlightKeys) < 2
        continue   % fewer than 2 flights total for this aircraft, nothing to compare
    end

    % ---- Find any Started+Ended combo that appears more than once ----
    [uniqueKeys, ~, ic] = unique(allFlightKeys);
    counts = accumarray(ic, 1);
    dupIdx = find(counts > 1);

    for d = 1:numel(dupIdx)
        matchingIdx = find(strcmp(allFlightKeys, uniqueKeys{dupIdx(d)}));

        fprintf('Aircraft %s: %d flights share Started/Ended = %s\n', ...
            data.Aircraft(i).TailNumber, numel(matchingIdx), uniqueKeys{dupIdx(d)});

        for m = 1:numel(matchingIdx)
            jj = allFlightTestJ(matchingIdx(m));
            kk = allFlightK(matchingIdx(m));
            fprintf('    -> Test %d (TestNumber %d), Flight index %d\n', ...
                jj, tests(jj).TestNumber, kk);
        end

        dupFlightAcrossTestsCount = dupFlightAcrossTestsCount + 1;
    end
end

if dupFlightAcrossTestsCount == 0
    fprintf('None found.\n');
end

% ---- 12f. Flights sharing EITHER Started OR Ended (not necessarily both) ----
fprintf('\n=== 12f. Flights sharing Started OR Ended (partial match) across ALL tests, same aircraft ===\n');
partialMatchCount = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    % ---- Collect every flight from every test in this aircraft ----
    allStarted = {};
    allEnded   = {};
    allTestJ   = [];
    allK       = [];

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell(flights)
            flights = [flights{:}];
        end

        for k = 1:numel(flights)
            allStarted{end+1} = flights(k).Started;
            allEnded{end+1}   = flights(k).Ended;
            allTestJ(end+1)   = j;
            allK(end+1)       = k;
        end
    end

    n = numel(allStarted);
    if n < 2
        continue
    end

    % ---- Compare every pair of flights within this aircraft ----
    for p = 1:n-1
        for q = p+1:n
            sameStart = strcmp(allStarted{p}, allStarted{q});
            sameEnd   = strcmp(allEnded{p},   allEnded{q});

            if sameStart || sameEnd
                jp = allTestJ(p); kp = allK(p);
                jq = allTestJ(q); kq = allK(q);

                matchType = '';
                if sameStart && sameEnd
                    matchType = 'BOTH Started and Ended match';
                elseif sameStart
                    matchType = 'ONLY Started matches';
                else
                    matchType = 'ONLY Ended matches';
                end

                fprintf('Aircraft %s: %s\n', data.Aircraft(i).TailNumber, matchType);
                fprintf('    Flight A -> Test %d (TestNumber %d), Flight index %d: Started=%s, Ended=%s\n', ...
                    jp, tests(jp).TestNumber, kp, allStarted{p}, allEnded{p});
                fprintf('    Flight B -> Test %d (TestNumber %d), Flight index %d: Started=%s, Ended=%s\n', ...
                    jq, tests(jq).TestNumber, kq, allStarted{q}, allEnded{q});

                partialMatchCount = partialMatchCount + 1;
            end
        end
    end
end

fprintf('\nTotal partial-match flight pairs found: %d\n', partialMatchCount);

%% 13. Check for overlapping Tests within the same aircraft
%     (next test's Started date is BEFORE the previous test's Ended date)

testOverlapIssues = {};

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    % ---- Sort tests chronologically by Started date ----
    testStarts = zeros(numel(tests), 1);
    for j = 1:numel(tests)
        testStarts(j) = iso2serial(tests(j).Started);
    end
    [~, sortIdx] = sort(testStarts);

    % ---- Walk through consecutive tests in chronological order ----
    for s = 1:numel(sortIdx)-1
        jCurrent = sortIdx(s);
        jNext    = sortIdx(s+1);

        currentEnd  = iso2serial(tests(jCurrent).Ended);
        nextStart   = iso2serial(tests(jNext).Started);

        if nextStart < currentEnd
            testOverlapIssues{end+1} = sprintf(...
                'Aircraft %s: Test %d (%s to %s) OVERLAPS with Test %d (%s to %s) -> next test starts %.2f days BEFORE previous test ended', ...
                data.Aircraft(i).TailNumber, ...
                tests(jCurrent).TestNumber, tests(jCurrent).Started, tests(jCurrent).Ended, ...
                tests(jNext).TestNumber, tests(jNext).Started, tests(jNext).Ended, ...
                currentEnd - nextStart);
        end
    end
end

fprintf('\nTotal overlapping test pairs found: %d\n', numel(testOverlapIssues));
for idx = 1:numel(testOverlapIssues)
    fprintf('%s\n', testOverlapIssues{idx});
end

%% 14. List start and end dates of all tests for TailNumber 84+97

targetTail = '8497';

fprintf('\n=== Tests for TailNumber 84+97 ===\n');

for i = 1:numel(data.Aircraft)

    % Normalize TailNumber by removing non-digits
    normalizedTail = regexprep(data.Aircraft(i).TailNumber, '\D', '');

    if strcmp(normalizedTail, targetTail)

        tests = data.Aircraft(i).Tests;

        fprintf('TailNumber: %s\n', data.Aircraft(i).TailNumber);
        fprintf('Number of tests: %d\n\n', numel(tests));

        for j = 1:numel(tests)
            fprintf('Test %d (TestNumber %d):\n', j, tests(j).TestNumber);
            fprintf('    Started: %s\n', tests(j).Started);
            fprintf('    Ended:   %s\n', tests(j).Ended);
        end
    end
end
