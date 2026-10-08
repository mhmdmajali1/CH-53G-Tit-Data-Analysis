
fid = fopen('CH-53G Tit_data-1.0.0.47.json', 'r');
raw = fread(fid, inf, 'uint8=>char')';
fclose(fid);
data = jsondecode(raw);

fprintf('Loaded %d aircraft. \n', numel(data.Aircraft));

%% STEP 1: Remove flights with neither BalanceData nor TrackData
removedCount = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)
        flights = normalizeFlights(tests(j).Flights);
        if iscell (flights)
            flights = [flights{:}];
        end
        keepMask = true(numel(flights), 1);

        for k = 1:numel(flights)
            bd = normalizeBalanceData(getFieldOrEmpty(flights(k), 'BalanceData'));
            td = normalizeTrackData(getFieldOrEmpty(flights(k), 'TrackData'));
            if isempty(bd) && isempty(td)
            keepMask(k) = false;
            removedCount = removedCount + 1;
            end

        end
        flights = flights(keepMask);
        data.Aircraft(i).Tests(j).Flights = flights;

    end
end
fprintf('STEP 1: Removed %d flights with no BalanceData/TrackData.\n', removedCount);

%% STEP 2a: Aircraft 84+24
ai = findAircraftIdx(data, '84+24');
jMain  = findTestIdxByDate(data.Aircraft(ai).Tests, '2021-03-03', '2021-05-12');
jSmall = findTestIdxByDate(data.Aircraft(ai).Tests, '2021-04-20', '');

flightsMain  = normalizeFlights(data.Aircraft(ai).Tests(jMain).Flights);
if iscell(flightsMain), flightsMain = [flightsMain{:}]; end
flightsMain  = flightsMain(:);        % force column
flightsSmall = normalizeFlights(data.Aircraft(ai).Tests(jSmall).Flights);
if iscell(flightsSmall), flightsSmall = [flightsSmall{:}]; end
flightsSmall = flightsSmall(:);       % force column
[flightsMain, flightsSmall] = alignStructFields(flightsMain, flightsSmall);

newFlights = [flightsMain(1); flightsSmall; flightsMain(2:end)];
data.Aircraft(ai).Tests(jMain).Flights = newFlights;
data.Aircraft(ai).Tests(jSmall) = [];
fprintf('STEP 2a done for 84+24 (now %d flights in merged test).\n', numel(newFlights));



%% STEP 2b: Aircraft 84+34
ai = findAircraftIdx(data, '84+34');
jMain  = findTestIdxByDate(data.Aircraft(ai).Tests, '2020-08-31', '2020-09-03');
jSmall = findTestIdxByDate(data.Aircraft(ai).Tests, '2020-08-31', '2020-08-31');

flightsMain  = normalizeFlights(data.Aircraft(ai).Tests(jMain).Flights);
if iscell(flightsMain), flightsMain = [flightsMain{:}]; end
flightsMain  = flightsMain(:);
flightsSmall = normalizeFlights(data.Aircraft(ai).Tests(jSmall).Flights);
if iscell(flightsSmall), flightsSmall = [flightsSmall{:}]; end
flightsSmall = flightsSmall(:);
[flightsMain, flightsSmall] = alignStructFields(flightsMain, flightsSmall);

newFlights = [flightsMain(1:3); flightsSmall; flightsMain(4:end)];
data.Aircraft(ai).Tests(jMain).Flights = newFlights;
data.Aircraft(ai).Tests(jSmall) = [];
fprintf('STEP 2b done for 84+34 (now %d flights in merged test).\n', numel(newFlights));


%% STEP 2c: Aircraft 84+64 -- split last 2 REAL flights into a new test
ai = findAircraftIdx(data, '84+64');
jBig = findTestIdxByDate(data.Aircraft(ai).Tests, '2022-11-30', '2023-04-14');
jRef = findTestIdxByDate(data.Aircraft(ai).Tests, '2023-02-08', '2023-02-09');

flightsBig = normalizeFlights(data.Aircraft(ai).Tests(jBig).Flights);
if iscell(flightsBig), flightsBig = [flightsBig{:}]; end
flightsBig = flightsBig(:);           % force column

nBig = numel(flightsBig);
lastTwo   = flightsBig(nBig-1:nBig);
remaining = flightsBig(1:nBig-2);

newTest = data.Aircraft(ai).Tests(jBig);
newTest.TestNumber = max([data.Aircraft(ai).Tests.TestNumber]) + 1;
newTest.Started = lastTwo(1).Started;
newTest.Ended   = lastTwo(2).Ended;
newTest.Flights = lastTwo;

data.Aircraft(ai).Tests(jBig).Flights = remaining;
data.Aircraft(ai).Tests(jBig).Started = remaining(1).Started;
data.Aircraft(ai).Tests(jBig).Ended   = remaining(end).Ended;

allTests = data.Aircraft(ai).Tests;
allTests = allTests(:);               % force column here too
[allTests, newTestArr] = alignStructFields(allTests, newTest);
newTest = newTestArr;
data.Aircraft(ai).Tests = [allTests(1:jRef); newTest; allTests(jRef+1:end)];
fprintf('STEP 2c done for 84+64.\n');


%% STEP 2d: Aircraft 85+07 -- delete 2nd flight, rename test
ai = findAircraftIdx(data, '85+07');
j = findTestIdxByDate(data.Aircraft(ai).Tests, '2022-07-23', '2022-10-18');

flights = normalizeFlights(data.Aircraft(ai).Tests(j).Flights);
if iscell(flights), flights = [flights{:}]; end
flights = flights(:);
flights(2) = [];
data.Aircraft(ai).Tests(j).Flights = flights;
data.Aircraft(ai).Tests(j).Ended = flights(end).Ended;
fprintf('STEP 2d done for 85+07.\n');

%% STEP 3a0: Resolve EXACT duplicate tailnumber '85+01' (two separate aircraft entries)
%% STEP 3a-pre: Resolve exact-duplicate TailNumber '85+01'
idxDup = findAircraftIdx(data, '85+01');

if numel(idxDup) > 1
    % Identify which of the two entries is the "donor" (exactly 1 test)
    testCounts = arrayfun(@(x) numel(data.Aircraft(x).Tests), idxDup);
    donorPos = find(testCounts == 1, 1);

    if isempty(donorPos)
        error('Could not identify which duplicate 85+01 has exactly 1 test -- check manually.');
    end

    iDonor     = idxDup(donorPos);
    iRecipient = idxDup(idxDup ~= iDonor);
    iRecipient = iRecipient(1);

    donorTest = data.Aircraft(iDonor).Tests;
    if iscell(donorTest), donorTest = [donorTest{:}]; end
    donorTest = donorTest(:);

    recipientTests = data.Aircraft(iRecipient).Tests;
    recipientTests = recipientTests(:);

    [recipientTests, donorTest] = alignStructFields(recipientTests, donorTest);

    nRec = numel(recipientTests);
    newTests = [recipientTests(1:nRec-1); donorTest; recipientTests(nRec)];
    data.Aircraft(iRecipient).Tests = newTests;

    % Delete the now-merged duplicate entry
    data.Aircraft(iDonor) = [];

    fprintf('STEP 3a-pre: Merged exact-duplicate 85+01 -- inserted its 1 test before the last test of the other entry, deleted the duplicate.\n');
else
    fprintf('STEP 3a-pre: No exact duplicate 85+01 found (already resolved or not present).\n');
end

%% STEP 3a-pre2: Resolve exact-duplicate TailNumber '84+97'
idxDup97 = findAircraftIdx(data, '84+97');

if numel(idxDup97) > 1
    % Identify which of the two entries is the "donor" (exactly 1 test)
    testCounts = arrayfun(@(x) numel(data.Aircraft(x).Tests), idxDup97);
    donorPos = find(testCounts == 1, 1);

    if isempty(donorPos)
        error('Could not identify which duplicate 84+97 has exactly 1 test -- check manually.');
    end

    iDonor     = idxDup97(donorPos);
    iRecipient = idxDup97(idxDup97 ~= iDonor);
    iRecipient = iRecipient(1);

    donorTest = data.Aircraft(iDonor).Tests;
    if iscell(donorTest), donorTest = [donorTest{:}]; end
    donorTest = donorTest(:);

    recipientTests = data.Aircraft(iRecipient).Tests;
    recipientTests = recipientTests(:);

    [recipientTests, donorTest] = alignStructFields(recipientTests, donorTest);

    % Insert AFTER the last test (append at the end), per confirmed instruction
    newTests = [recipientTests; donorTest];
    data.Aircraft(iRecipient).Tests = newTests;

    % Delete the now-merged duplicate entry
    data.Aircraft(iDonor) = [];

    fprintf('STEP 3a-pre2: Merged exact-duplicate 84+97 -- appended its 1 test after the last test of the other entry, deleted the duplicate.\n');
else
    fprintf('STEP 3a-pre2: No exact duplicate 84+97 found (already resolved or not present).\n');
end

%% STEP 3a: Merge pairs, keeping the '+'-formatted one, deleting the other
pairsToMerge = {
    '84+39', '8439';
    '84+43', '8443';
    '84+91', '8491';
    '84+97', '8497';
    '85+01', '8501';
    '85+03', '8503'
};

for p = 1:size(pairsToMerge, 1)
    keepTail   = pairsToMerge{p,1};
    removeTail = pairsToMerge{p,2};

    iKeep   = findAircraftIdx(data, keepTail);
    iRemove = findAircraftIdx(data, removeTail);

    if isempty(iRemove)
        fprintf('%s not found, skipping.\n', removeTail);
        continue
    end

    testsKeep   = data.Aircraft(iKeep).Tests;
    testsRemove = data.Aircraft(iRemove).Tests;

    testsKeep   = testsKeep(:);
    testsRemove = testsRemove(:);
    [testsKeep, testsRemove] = alignStructFields(testsKeep, testsRemove);

    allTests = [testsKeep; testsRemove];

    % Sort merged tests chronologically by Started date
    starts = zeros(numel(allTests), 1);
    for t = 1:numel(allTests)
        starts(t) = iso2serial(allTests(t).Started);
    end
    [~, order] = sort(starts);
    data.Aircraft(iKeep).Tests = allTests(order);

    fprintf('Merged %d tests from %s into %s.\n', numel(testsRemove), removeTail, keepTail);
end

% Delete the now-redundant aircraft entries (after merging, before renumbering indices)
removeTails = pairsToMerge(:,2);
removeIdx = [];
for r = 1:numel(removeTails)
    idx = findAircraftIdx(data, removeTails{r});
    removeIdx = [removeIdx, idx];
end
data.Aircraft(removeIdx) = [];
fprintf('STEP 3a: Deleted %d duplicate aircraft entries.\n', numel(removeIdx));


%% STEP 3b: Delete standalone junk entries
junkTails = {'J', 'V85+00'};
idxToDelete = [];
for j = 1:numel(junkTails)
    idx = findAircraftIdx(data, junkTails{j});
    idxToDelete = [idxToDelete, idx];
end
data.Aircraft(idxToDelete) = [];
fprintf('STEP 3b: Deleted aircraft entries: %s\n', strjoin(junkTails, ', '));


%% STEP 3c: 85+06 & 8506 special case — keep only the LAST test from 8506, merge into 85+06
iKeep   = findAircraftIdx(data, '85+06');
iRemove = findAircraftIdx(data, '8506');

testsRemove = data.Aircraft(iRemove).Tests;
starts = zeros(numel(testsRemove), 1);
for t = 1:numel(testsRemove)
    starts(t) = iso2serial(testsRemove(t).Started);
end
[~, order] = sort(starts);
testsRemoveSorted = testsRemove(order);

lastTest = testsRemoveSorted(end);   % only keep this one

allTests = [data.Aircraft(iKeep).Tests; lastTest];
starts2 = zeros(numel(allTests), 1);
for t = 1:numel(allTests)
    starts2(t) = iso2serial(allTests(t).Started);
end
[~, order2] = sort(starts2);
data.Aircraft(iKeep).Tests = allTests(order2);

data.Aircraft(iRemove) = [];
fprintf('STEP 3c: Merged last test of 8506 into 85+06, deleted 8506.\n');



deletions = {
    '84+24', '2018-12-14', '';
    '84+44', '2019-10-30', '';
    '84+48', '2021-01-21', '';
    '85+03', '2018-01-25', '2018-03-05'
};

for d = 1:size(deletions, 1)
    tail = deletions{d,1};
    sDate = deletions{d,2};
    eDate = deletions{d,3};

    ai = findAircraftIdx(data, tail);
    tests = data.Aircraft(ai).Tests;
    idx = findTestIdxByDate(tests, sDate, eDate);

    tests(idx) = [];
    data.Aircraft(ai).Tests = tests;
    fprintf('Deleted %d test(s) from %s matching %s.\n', numel(idx), tail, sDate);
end

ai = findAircraftIdx(data, '84+51');
tests = data.Aircraft(ai).Tests;
idx1 = findTestIdxByDate(tests, '2017-07-24', '2017-09-21');
idx2 = findTestIdxByDate(tests, '2017-09-21', '');
idxAll = unique([idx1, idx2]);
tests(idxAll) = [];
data.Aircraft(ai).Tests = tests;
fprintf('Deleted %d test(s) from 84+51.\n', numel(idxAll));


ai = findAircraftIdx(data, '85+01');
tests = data.Aircraft(ai).Tests;
idx = findTestIdxByDate(tests, '2023-09-07', '');

andreasTests = tests(idx);
tests(idx) = [];
data.Aircraft(ai).Tests = tests;

data.AndreasSeparatedTests = struct('TailNumber', '85+01', 'Tests', {andreasTests});
fprintf('Separated %d test(s) from 85+01 into data.AndreasSeparatedTests.\n', numel(idx));



%% STEP 6: Merge non-compliant test chains (replaces Step 5 entirely)
%
%  Case 1: test is compliant -> leave it alone, move to the next test.
%  Case 2: test is non-compliant, next test also ends up non-compliant
%          after merging -> keep extending the chain forward.
%  Case 3: test is non-compliant, but after merging the next test the
%          chain becomes compliant -> merge, then STOP (resolved).
%  A chain only extends when ALL THREE signals hold together:
%    sameConfig && settingsChanged && gapOK

axisLimitDate  = iso2serial('2023-07-20T00:00:00');
maxGapDaysChain = 45;

resolvedChains   = {};
unresolvedTests  = {};
compliantLeftAlone = 0;

for i = 1:numel(data.Aircraft)
    tests = data.Aircraft(i).Tests;
    tests = tests(:);

    starts = zeros(numel(tests), 1);
    for j = 1:numel(tests)
        starts(j) = iso2serial(tests(j).Started);
    end
    [~, sortIdx] = sort(starts);
    tests = tests(sortIdx);

    newTests = {};
    t = 1;

    while t <= numel(tests)
        flightItems = toItems(normalizeFlights(tests(t).Flights));
        if isempty(flightItems)
            newTests{end+1} = tests(t);
            t = t + 1;
            continue
        end

        [~, lastFlight] = getLastFlight(flightItems);
        [compliant, hasData, ~] = checkFlightCompliance(lastFlight, axisLimitDate);

        % ---- CASE 1: compliant -- leave alone entirely ----
        if ~hasData || compliant
            if hasData, compliantLeftAlone = compliantLeftAlone + 1; end
            newTests{end+1} = tests(t);
            t = t + 1;
            continue
        end

        % ---- Non-compliant: attempt to build a chain forward ----
        chainTests = tests(t);
        chainFlights = flightItems;
        currentLastFlight = lastFlight;
        n = t;
        chainOutcome = '';   % 'resolved' or 'unresolved'

        while n < numel(tests)
            nextTest = tests(n+1);
            nextFlightItems = toItems(normalizeFlights(nextTest.Flights));
            if isempty(nextFlightItems)
                chainOutcome = 'unresolved';
                break
            end
            [~, nextFirstFlight] = getFirstFlight(nextFlightItems);

            % ---- ALL THREE signals required together ----
            lastConfig  = getFieldOrEmpty(currentLastFlight, 'ConfigurationUsed');
            firstConfig = getFieldOrEmpty(nextFirstFlight, 'ConfigurationUsed');
            sameConfig = ~isempty(lastConfig) && ~isempty(firstConfig) && strcmp(lastConfig, firstConfig);

            [settingsChanged, ~, ~, ~] = checkSettingsChanged(currentLastFlight, nextFirstFlight);

            gapDaysChain = iso2serial(nextFirstFlight.Started) - iso2serial(currentLastFlight.Ended);
            gapOK = gapDaysChain >= 0 && gapDaysChain <= maxGapDaysChain;

            continuityOK = sameConfig && settingsChanged && gapOK;

            if ~continuityOK
                chainOutcome = 'unresolved';
                break
            end

            % ---- Evidence holds: merge this next test's flights in ----
            chainTests = [chainTests; nextTest];
            chainFlights = [chainFlights(:); nextFlightItems(:)];
            n = n + 1;

            [~, newLastFlight] = getLastFlight(nextFlightItems);
            currentLastFlight = newLastFlight;

            [compliantNow, hasDataNow, ~] = checkFlightCompliance(newLastFlight, axisLimitDate);

            if hasDataNow && compliantNow
                % ---- CASE 3: resolved -- stop here ----
                chainOutcome = 'resolved';
                break
            end
            % ---- CASE 2: still non-compliant -- loop continues, try next test ----
        end

        if isempty(chainOutcome)
            chainOutcome = 'unresolved';   % ran out of tests entirely
        end

        chainLength = numel(chainTests);

        if chainLength > 1 && strcmp(chainOutcome, 'resolved')
            % ---- Build the merged test: real flight boundaries, first TestNumber kept ----
            mergedFlights = chainFlights{1};
            for c = 2:numel(chainFlights)
                [mergedFlights, nextArr] = alignStructFields(mergedFlights, chainFlights{c});
                mergedFlights = [mergedFlights; nextArr];
            end

            startedTimes = arrayfun(@(f) iso2serial(f.Started), mergedFlights);
            endedTimes   = arrayfun(@(f) iso2serial(f.Ended), mergedFlights);
            [~, firstIdxAll] = min(startedTimes);
            [~, lastIdxAll]  = max(endedTimes);

            mergedTest = chainTests(1);   % keeps chainTests(1)'s TestNumber as the surviving identity
            mergedTest.Flights = mergedFlights;
            mergedTest.Started = mergedFlights(firstIdxAll).Started;
            mergedTest.Ended   = mergedFlights(lastIdxAll).Ended;

            newTests{end+1} = mergedTest;

            resolvedChains{end+1} = sprintf(...
                'Aircraft %s: merged Tests %s -> Test %d (%s to %s), now COMPLIANT', ...
                data.Aircraft(i).TailNumber, ...
                strjoin(arrayfun(@(x) num2str(x.TestNumber), chainTests, 'UniformOutput', false), ' + '), ...
                mergedTest.TestNumber, mergedTest.Started, mergedTest.Ended);
        else
            % ---- Unresolved: leave every test in the (failed) chain untouched ----
            for c = 1:chainLength
                newTests{end+1} = chainTests(c);
            end
            unresolvedTests{end+1} = sprintf(...
                'Aircraft %s: Test %d -- STILL NON-COMPLIANT, no evidence-backed chain found', ...
                data.Aircraft(i).TailNumber, tests(t).TestNumber);
        end

        t = n + 1;
    end

    rebuilt = newTests{1};
    for c = 2:numel(newTests)
        [a, b] = alignStructFields(rebuilt, newTests{c});
        rebuilt = [a; b];
    end
    data.Aircraft(i).Tests = rebuilt;
end

fprintf('\n=== STEP 6: Resolved merge chains (%d) ===\n', numel(resolvedChains));
for r = 1:numel(resolvedChains)
    fprintf('%s\n', resolvedChains{r});
end

fprintf('\n=== STEP 6: Unresolved non-compliant tests (%d) ===\n', numel(unresolvedTests));
for r = 1:numel(unresolvedTests)
    fprintf('%s\n', unresolvedTests{r});
end

fprintf('\nTests left alone (already compliant): %d\n', compliantLeftAlone);

%% Export the fully cleaned dataset to a new JSON file, same structure as the original

outStr = jsonencode(data, 'PrettyPrint', true);

fidOut = fopen('CH-53G_Tit-data_CLEANED.json', 'w');
if fidOut == -1
    error('Could not open output file for writing.');
end

fwrite(fidOut, outStr, 'char');
fclose(fidOut);

fprintf('\nCleaned file written to CH-53G Tit_data-CLEANEDD.json\n');
