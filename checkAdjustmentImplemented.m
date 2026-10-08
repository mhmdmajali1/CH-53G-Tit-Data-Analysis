function [confirmed, matchRatio, details] = checkAdjustmentImplemented(lastFlight, firstFlight)
    recMap = getRecommendedSettingsMap(lastFlight);
    actMap = getCurrentSettingsMap(firstFlight);

    confirmed = false;
    matchRatio = NaN;
    details = {};

    recKeys = keys(recMap);
    if isempty(recKeys) || isempty(actMap)
        details{end+1} = 'Signal 3 not computable (missing SolveResults or CurrentSettings).';
        return
    end

    matched = 0;
    tolerance = 0.05;   % adjust if your Value units need a different tolerance
    
    for k = 1:numel(recKeys)
        key = recKeys{k};
        recVal = recMap(key);
        if isKey(actMap, key)
            actVal = actMap(key);
            if abs(actVal - recVal) <= max(tolerance, 0.02*abs(recVal))
                matched = matched + 1;
                details{end+1} = sprintf('MATCH  %s: recommended=%.3f, actual=%.3f', key, recVal, actVal);
            else
                details{end+1} = sprintf('DIFFER %s: recommended=%.3f, actual=%.3f', key, recVal, actVal);
            end
        else
            details{end+1} = sprintf('MISSING %s: recommended=%.3f, not found in next flight''s settings', key, recVal);
        end
    end

    matchRatio = matched / numel(recKeys);
    confirmed = matchRatio >= 0.8;   % 80%+ of recommended points implemented
end


