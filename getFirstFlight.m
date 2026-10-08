function [idx, flight] = getFirstFlight(flightItems)
    startedTimes = Inf(numel(flightItems), 1);
    for k = 1:numel(flightItems)
        s = getFieldOrEmpty(flightItems{k}, 'Started');
        if ~isempty(s), startedTimes(k) = iso2serial(s); end
    end
    [~, idx] = min(startedTimes);
    flight = flightItems{idx};
end
