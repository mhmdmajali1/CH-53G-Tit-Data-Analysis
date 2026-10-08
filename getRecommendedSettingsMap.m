function m = getRecommendedSettingsMap(flight)
    sr = getFieldOrEmpty(flight, 'SolveResults');
    if iscell(sr), sr = [sr{:}]; end
    m = containers.Map('KeyType', 'char', 'ValueType', 'double');
    if isempty(sr)
        return
    end
    createdTimes = zeros(numel(sr), 1);
    for c = 1:numel(sr)
        try
            createdTimes(c) = iso2serial(sr(c).Created);
        catch
            createdTimes(c) = -Inf;
        end
    end
    [~, latestIdx] = max(createdTimes);

    adjustments = getFieldOrEmpty(sr(latestIdx), 'Adjustments');
    if iscell(adjustments), adjustments = [adjustments{:}]; end
    for a = 1:numel(adjustments)
        partsMap = flattenAdjustments(getFieldOrEmpty(adjustments(a), 'Parts'));
        ks = keys(partsMap);
        for k = 1:numel(ks)
            m(ks{k}) = partsMap(ks{k});
        end
    end
end
