function idx = findTestIdxByDate(tests, startDateStr, endDateStr)
    % startDateStr / endDateStr format: 'yyyy-mm-dd'. Pass '' for endDateStr to ignore it.
    idx = [];
    for j = 1:numel(tests)
        sMatch = strncmp(tests(j).Started, startDateStr, 10);
        if isempty(endDateStr)
            eMatch = true;
        else
            eMatch = strncmp(tests(j).Ended, endDateStr, 10);
        end
        if sMatch && eMatch
            idx(end+1) = j;
        end
    end
end
