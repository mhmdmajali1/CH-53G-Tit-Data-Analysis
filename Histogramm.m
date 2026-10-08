clear;
clc;
close all;


%% ========================================================================
%  1. Load JSON data
%  ========================================================================

fid = fopen('CH-53G Tit_data.json', 'r');

if fid == -1
    error('Could not open CH-53G Tit_data.json');
end

raw = fread(fid, inf, 'uint8=>char')';

fclose(fid);

data = jsondecode(raw);


%% ========================================================================
%  2. Define conditions
%  ========================================================================

otherConditions = {
    'Hovern OGE'
    '90 Knoten'
    '110 Knoten'
    '130 Knoten'
};


%% ========================================================================
%  3. Preallocate arrays
%
%  Each element corresponds to ONE TEST.
%
%  Example:
%
%  allFlightsPerTest(10) = 7
%
%  means Aircraft/Test #10 contains 7 flights.
%  ========================================================================

numTests = 0;

allFlightsPerTest          = [];
hauptFlightsPerTest        = [];
heckFlightsPerTest         = [];

hauptBodenlaufPerTest      = [];
hauptOtherPerTest          = [];

heckBodenlaufPerTest       = [];
heckOtherPerTest           = [];


%% ========================================================================
%  4. Loop through aircraft and tests
%  ========================================================================

for i = 1:numel(data.Aircraft)

    tests = data.Aircraft(i).Tests;

    for j = 1:numel(tests)

        numTests = numTests + 1;

        % ---------------------------------------------------------------
        % Normalize flights
        % ---------------------------------------------------------------

        flights = normalizeFlights(tests(j).Flights);

        if iscell(flights)
            flights = [flights{:}];
        end


        % ---------------------------------------------------------------
        % Counters for THIS TEST
        % ---------------------------------------------------------------

        nAll        = 0;
        nHaupt      = 0;
        nHeck       = 0;

        nHauptBoden = 0;
        nHauptOther = 0;

        nHeckBoden  = 0;
        nHeckOther  = 0;


        % ===============================================================
        % Loop through flights in this test
        % ===============================================================

        for k = 1:numel(flights)

            % -----------------------------------------------------------
            % Get BalanceData safely
            % -----------------------------------------------------------

            bd = normalizeBalanceData( ...
                getFieldOrEmpty(flights(k), 'BalanceData'));


            % -----------------------------------------------------------
            % Get TrackData safely
            % -----------------------------------------------------------

            td = normalizeTrackData( ...
                getFieldOrEmpty(flights(k), 'TrackData'));


            % -----------------------------------------------------------
            % If flight has neither BalanceData nor TrackData,
            % skip it for the condition-based analysis.
            % -----------------------------------------------------------

            if isempty(bd) && isempty(td)

                % It is still a flight, so it belongs to the
                % total-flight count.
                nAll = nAll + 1;

                continue;

            end


            % -----------------------------------------------------------
            % Every entry in Flights counts as one flight
            % -----------------------------------------------------------

            nAll = nAll + 1;


            % ===========================================================
            % Determine conditions in this flight
            % ===========================================================

            combinedConditions = {};


            % Balance conditions
            if ~isempty(bd)

                if isfield(bd, 'TestCondition')

                    for b = 1:numel(bd)
                        combinedConditions{end+1} = bd(b).TestCondition;
                    end

                end

            end


            % Track conditions
            if ~isempty(td)

                if isfield(td, 'TestCondition')

                    for t = 1:numel(td)
                        combinedConditions{end+1} = td(t).TestCondition;
                    end

                end

            end


            % Remove duplicate conditions
            uniqueConditions = unique(combinedConditions);


            % ===========================================================
            % Determine whether flight contains Haupt
            % ===========================================================

            hasHaupt = false;

            % Haupt in BalanceData
            if ~isempty(bd)

                if isfield(bd, 'Part')

                    for b = 1:numel(bd)

                        if strcmp(bd(b).Part, 'Haupt')

                            hasHaupt = true;
                            break;

                        end

                    end

                end

            end


            % Haupt in TrackData
            if ~isempty(td) && ~hasHaupt

                if isfield(td, 'Part')

                    for t = 1:numel(td)

                        if strcmp(td(t).Part, 'Haupt')

                            hasHaupt = true;
                            break;

                        end

                    end

                end

            end


            % ===========================================================
            % Determine whether flight contains Heck
            %
            % Heck is checked ONLY in BalanceData
            % ===========================================================

            hasHeck = false;

            if ~isempty(bd)

                if isfield(bd, 'Part')

                    for b = 1:numel(bd)

                        if strcmp(bd(b).Part, 'Heck')

                            hasHeck = true;
                            break;

                        end

                    end

                end

            end


            % ===========================================================
            % Determine condition category
            % ===========================================================

            isBodenlaufOnly = false;
            hasOtherCondition = false;


            if ~isempty(uniqueConditions)

                % Only Bodenlauf
                if numel(uniqueConditions) == 1 && ...
                   strcmp(uniqueConditions{1}, 'Bodenlauf')

                    isBodenlaufOnly = true;

                end


                % Any of the four other conditions
                if any(ismember(uniqueConditions, otherConditions))

                    hasOtherCondition = true;

                end

            end


            % ===========================================================
            % Count Haupt
            % ===========================================================

            if hasHaupt

                nHaupt = nHaupt + 1;

            end


            % ===========================================================
            % Count Heck
            % ===========================================================

            if hasHeck

                nHeck = nHeck + 1;

            end


            % ===========================================================
            % Haupt + Bodenlauf only
            % ===========================================================

            if hasHaupt && isBodenlaufOnly

                nHauptBoden = nHauptBoden + 1;

            end


            % ===========================================================
            % Haupt + other condition
            % ===========================================================

            if hasHaupt && hasOtherCondition

                nHauptOther = nHauptOther + 1;

            end


            % ===========================================================
            % Heck + Bodenlauf only
            % ===========================================================

            if hasHeck && isBodenlaufOnly

                nHeckBoden = nHeckBoden + 1;

            end


            % ===========================================================
            % Heck + other condition
            % ===========================================================

            if hasHeck && hasOtherCondition

                nHeckOther = nHeckOther + 1;

            end

        end


        % ===============================================================
        % Store results for THIS TEST
        % ===============================================================

        allFlightsPerTest(end+1)     = nAll;

        hauptFlightsPerTest(end+1)   = nHaupt;

        heckFlightsPerTest(end+1)    = nHeck;

        hauptBodenlaufPerTest(end+1) = nHauptBoden;

        hauptOtherPerTest(end+1)     = nHauptOther;

        heckBodenlaufPerTest(end+1)  = nHeckBoden;

        heckOtherPerTest(end+1)      = nHeckOther;

    end

end


%% ========================================================================
%  5. Display basic information
%  ========================================================================

fprintf('\n============================================================\n');
fprintf('Histogram data generated\n');
fprintf('============================================================\n');

fprintf('Number of tests: %d\n', numTests);

fprintf('\nMaximum number of flights in one test:\n');
fprintf('All flights:       %d\n', max(allFlightsPerTest));
fprintf('Haupt flights:     %d\n', max(hauptFlightsPerTest));
fprintf('Heck flights:      %d\n', max(heckFlightsPerTest));
fprintf('Haupt Bodenlauf:   %d\n', max(hauptBodenlaufPerTest));
fprintf('Haupt other:       %d\n', max(hauptOtherPerTest));
fprintf('Heck Bodenlauf:    %d\n', max(heckBodenlaufPerTest));
fprintf('Heck other:        %d\n', max(heckOtherPerTest));


%% ========================================================================
%  6. Create seven histogram charts
%  ========================================================================

figure('Name', 'CH-53G Tit - Flight Distribution', ...
       'NumberTitle', 'off');


% ========================================================================
% Histogram 1
% ========================================================================

subplot(4,2,1);

hist(allFlightsPerTest, 0:max(allFlightsPerTest));
xlim([0, max(allFlightsPerTest)+1]);
xlabel('Number of flights per test');
ylabel('Count');
title('All flights per test');

grid on;


% ========================================================================
% Histogram 2
% ========================================================================

subplot(4,2,2);

hist(hauptFlightsPerTest, 0:max(hauptFlightsPerTest));
xlim([0, max(hauptFlightsPerTest)+1]);
xlabel('Number of Haupt flights per test');
ylabel('Count');
title('Haupt flights per test');

grid on;

% ========================================================================
% Histogram 3
% ========================================================================

subplot(4,2,3);

hist(heckFlightsPerTest, 0:max(heckFlightsPerTest));
xlim([0, max(heckFlightsPerTest)+1]);
xlabel('Number of Heck flights per test');
ylabel('Count');
title('Heck flights per test');

grid on;

% ========================================================================
% Histogram 4
% ========================================================================

subplot(4,2,4);

hist(hauptBodenlaufPerTest, 0:max(hauptBodenlaufPerTest));
xlim([0, max(hauptBodenlaufPerTest)+1]);
xlabel('Number of Haupt Bodenlauf-only flights per test');
ylabel('Count');
title('Haupt - Bodenlauf only');

grid on;

% ========================================================================
% Histogram 5
% ========================================================================

subplot(4,2,5);

hist(hauptOtherPerTest, 0:max(hauptOtherPerTest));
xlim([0, max(hauptOtherPerTest)+1]);
xlabel('Number of Haupt other-condition flights per test');
ylabel('Count');
title('Haupt - Other conditions');

grid on;

% ========================================================================
% Histogram 6
% ========================================================================

subplot(4,2,6);

hist(heckBodenlaufPerTest, 0:max(heckBodenlaufPerTest));
xlim([0, max(heckBodenlaufPerTest)+1]);
xlabel('Number of Heck Bodenlauf-only flights per test');
ylabel('Count');
title('Heck - Bodenlauf only');

grid on;


% ========================================================================
% Histogram 7
% ========================================================================

subplot(4,2,7);

hist(heckOtherPerTest, 0:max(heckOtherPerTest));
xlim([0, max(heckOtherPerTest)+1]);
xlabel('Number of Heck other-condition flights per test');
ylabel('Count');
title('Heck - Other conditions');

grid on;


%% ========================================================================
%  7. Overall title
% ========================================================================

annotation('textbox', [0 0.96 1 0.04], ...
           'String', 'CH-53G Tit - Distribution of Flights per Test', ...
           'EdgeColor', 'none', ...
           'HorizontalAlignment', 'center', ...
           'FontSize', 14, ...
           'FontWeight', 'bold');

