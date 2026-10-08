function [idx, flight] = getLastFlight(flightItems)
    endedTimes = -Inf(numel(flightItems), 1);
    for k = 1:numel(flightItems)
        e = getFieldOrEmpty(flightItems{k}, 'Ended');
        if ~isempty(e), endedTimes(k) = iso2serial(e); end
    end
    [~, idx] = max(endedTimes);
    flight = flightItems{idx};
end
