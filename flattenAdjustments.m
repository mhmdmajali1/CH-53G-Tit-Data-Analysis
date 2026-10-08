function m = flattenAdjustments(parts)
    m = containers.Map('KeyType', 'char', 'ValueType', 'double');
    if isempty(parts)
        return
    end
    if iscell(parts), parts = [parts{:}]; end
    for p = 1:numel(parts)
        partName = getFieldOrEmpty(parts(p), 'Part');
        adjTypes = getFieldOrEmpty(parts(p), 'AdjustmentTypes');
        if iscell(adjTypes), adjTypes = [adjTypes{:}]; end
        for a = 1:numel(adjTypes)
            adjTypeName = getFieldOrEmpty(adjTypes(a), 'AdjustmentType');
            points = getFieldOrEmpty(adjTypes(a), 'AdjustmentPoints');
            if iscell(points), points = [points{:}]; end
            for pt = 1:numel(points)
                pointName = getFieldOrEmpty(points(pt), 'AdjustmentPoint');
                val = getFieldOrEmpty(points(pt), 'Value');
                if isempty(val), continue; end
                key = sprintf('%s|%s|%s', partName, adjTypeName, num2str(pointName));
                m(key) = val;
            end
        end
    end
end
