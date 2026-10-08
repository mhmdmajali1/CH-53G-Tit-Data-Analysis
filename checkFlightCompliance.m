function [compliant, hasRelevantData, violations] = checkFlightCompliance(flight, axisLimitDate)
    % Checks whether a single flight's BalanceData is within the Haupt/Heck
    % limits (Vertikal/Radial/Axial fixed at 0.2; Lateral 0.3 before
    % 20.07.2023, 0.25 after), across every TestCondition present.
    %
    % Returns:
    %   compliant       -- true if every relevant reading is within limit
    %   hasRelevantData -- true if the flight had at least one Haupt/Heck
    %                      Vertikal/Lateral/Radial/Axial reading to check
    %   violations      -- cell array describing any readings that failed

    limitFixed = struct('Vertikal', 0.2, 'Radial', 0.2, 'Axial', 0.2);
    lateralLimitBefore = 0.3;
    lateralLimitAfter  = 0.25;
    heckAxes = {'Radial', 'Axial'};

    compliant = true;
    hasRelevantData = false;
    violations = {};

    bd = normalizeBalanceData(getFieldOrEmpty(flight, 'BalanceData'));
    if isempty(bd)
        return
    end

    flightEndStr = getFieldOrEmpty(flight, 'Ended');
    if isempty(flightEndStr)
        return
    end
    flightEnd = iso2serial(flightEndStr);
    isAfterCutoff = flightEnd >= axisLimitDate;

    for b = 1:numel(bd)
        axisName = bd(b).Axis;
        partName = bd(b).Part;
        amp      = bd(b).Amplitude;
        cond     = bd(b).TestCondition;
        lim = [];

        if strcmp(partName, 'Haupt')
            if strcmp(axisName, 'Vertikal')
                lim = limitFixed.Vertikal;
            elseif strcmp(axisName, 'Lateral')
                lim = ternary(isAfterCutoff, lateralLimitAfter, lateralLimitBefore);
            end
        elseif strcmp(partName, 'Heck') && ismember(axisName, heckAxes)
            lim = limitFixed.(axisName);
        end

        if ~isempty(lim)
            hasRelevantData = true;
            if amp > lim
                compliant = false;
                violations{end+1} = sprintf('%s-%s (%s): %.4f > %.4f', partName, axisName, cond, amp, lim);
            end
        end
    end
end
