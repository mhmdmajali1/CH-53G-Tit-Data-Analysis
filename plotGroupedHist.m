function plotGroupedHist(xA, xB, bins, ttl, xl, labelA, labelB, asPercent)
    % Draws two groups as side-by-side bars on SHARED bins.
    %   xA, xB    - numeric data of group A / group B (NaNs are ignored)
    %   bins      - number of bins (scalar) OR vector of bin centres
    %   asPercent - true (default): each group is scaled to 100 %, so groups of
    %               very different size can be compared by shape.
    %               false: raw counts.

    if nargin < 8
        asPercent = true;
    end

    xA = xA(:);  xA = xA(~isnan(xA));
    xB = xB(:);  xB = xB(~isnan(xB));
    allx = [xA; xB];

    if isempty(allx)
        text(0.5, 0.5, 'no data', 'HorizontalAlignment', 'center');
        set(gca, 'xtick', [], 'ytick', []);
        title(ttl);
        return
    end

    if isscalar(bins)
        lo = min(allx);
        hi = max(allx);
        if lo == hi
            lo = lo - 0.5;
            hi = hi + 0.5;
        end
        edges   = linspace(lo, hi, max(bins, 2) + 1);
        centers = edges(1:end-1) + diff(edges) / 2;
    else
        centers = bins(:)';
    end

    if numel(centers) < 2          % hist() treats a scalar as "number of bins"
        centers = [centers, centers + 1];
    end

    nA = zeros(1, numel(centers));
    nB = zeros(1, numel(centers));
    if ~isempty(xA), nA = hist(xA, centers); end
    if ~isempty(xB), nB = hist(xB, centers); end

    if asPercent
        if ~isempty(xA), nA = 100 * nA / numel(xA); end
        if ~isempty(xB), nB = 100 * nB / numel(xB); end
        yLabelText = 'Share of group (%)';
    else
        yLabelText = 'Count';
    end

    bar(centers, [nA(:), nB(:)], 'grouped');
    xlabel(xl);
    ylabel(yLabelText);
    title(ttl);
    hl = legend(sprintf('%s (n=%d)', labelA, numel(xA)), ...
                sprintf('%s (n=%d)', labelB, numel(xB)), ...
                'Location', 'northeast');
    set(hl, 'fontsize', 8);
    grid on;
end
