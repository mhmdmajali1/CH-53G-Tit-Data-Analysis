function m = getCurrentSettingsMap(flight)
    cs = getFieldOrEmpty(flight, 'CurrentSettings');
    if iscell(cs), cs = [cs{:}]; end
    m = containers.Map('KeyType', 'char', 'ValueType', 'double');
    if isempty(cs)
        return
    end

    % Sort all CurrentSettings entries oldest -> newest, then merge key-by-key
    % so a later entry only OVERWRITES keys it actually mentions, rather than
    % replacing the whole map and losing untouched points.
    createdTimes = zeros(numel(cs), 1);
    for c = 1:numel(cs)
        try
            createdTimes(c) = iso2serial(cs(c).Created);
        catch
            createdTimes(c) = -Inf;
        end
    end
    [~, order] = sort(createdTimes);   % oldest first

    for idx = 1:numel(order)
        entryMap = flattenAdjustments(getFieldOrEmpty(cs(order(idx)), 'Parts'));
        ks = keys(entryMap);
        for k = 1:numel(ks)
            m(ks{k}) = entryMap(ks{k});   % later entries overwrite, but only their own keys
        end
    end
end
