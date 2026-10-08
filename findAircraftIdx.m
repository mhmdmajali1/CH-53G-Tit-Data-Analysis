function idx = findAircraftIdx(data, tailStr)
    idx = find(strcmp({data.Aircraft.TailNumber}, tailStr));
end
