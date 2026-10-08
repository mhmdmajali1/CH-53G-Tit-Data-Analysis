function [confirmed, changedCount, matchDirCount, details] = checkSettingsChanged(lastFlight, firstFlight)
    % Compares actual physical settings between the two BOUNDARY flights directly,
    % rather than matching against a computed recommendation.
    actLast  = getCurrentSettingsMap(lastFlight);
    actFirst = getCurrentSettingsMap(firstFlight);
    recMap   = getRecommendedSettingsMap(lastFlight);

    confirmed = false;
    changedCount = 0;
    matchDirCount = 0;
    details = {};

    allKeys = unique([keys(actLast), keys(actFirst)]);
    if isempty(allKeys)
        details{end+1} = 'Signal 3 not computable (no CurrentSettings on either flight).';
        return
    end

    for k = 1:numel(allKeys)
        key = allKeys{k};
        vLast  = ternaryMap(actLast, key, NaN);
        vFirst = ternaryMap(actFirst, key, NaN);

        if isnan(vLast) || isnan(vFirst)
            continue
        end

        delta = vFirst - vLast;

        if abs(delta) > 1e-9
            changedCount = changedCount + 1;
            dirNote = '';

            if isKey(recMap, key)
                recVal = recMap(key);
                sameDirection = sign(delta) == sign(recVal) && recVal ~= 0;
                if sameDirection
                    matchDirCount = matchDirCount + 1;
                    dirNote = ' (direction MATCHES recommendation)';
                else
                    dirNote = ' (direction differs from recommendation)';
                end
            end

            details{end+1} = sprintf('CHANGED %s: %.3f -> %.3f (delta=%.3f)%s', ...
                key, vLast, vFirst, delta, dirNote);
        end
    end

    confirmed = changedCount > 0 && matchDirCount > 0;   % at minimum: something physically changed
end

function v = ternaryMap(m, key, defaultVal)
    if isKey(m, key)
        v = m(key);
    else
        v = defaultVal;
    end
end
