function s = iso2serial(isoStr)

    dotIdx = strfind(isoStr, '.');
    if ~isempty(dotIdx)
        mainPart = isoStr(1:dotIdx(1)-1);
        fracStr  = isoStr(dotIdx(1)+1:end);
        fracSec  = str2double(['0.' fracStr]);
    else
        mainPart = isoStr;
        fracSec  = 0;
    end

    s = datenum(mainPart, 'yyyy-mm-ddTHH:MM:SS') + fracSec / 86400;
end
