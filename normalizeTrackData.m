function td = normalizeTrackData(td)
    if iscell(td)
        if isempty(td)
            td = struct('TestCondition', {}, 'Part', {}, 'TrackSplit', {}, 'BladeHeights', {});
        else
            td = [td{:}];
        end
    end
end

