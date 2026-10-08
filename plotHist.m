function plotHist(x, bins, ttl, xl, vlines)
    % Draws one histogram on the current axes.
    %   x      - numeric data (NaNs are ignored)
    %   bins   - number of bins (scalar) OR vector of bin centres
    %   ttl    - plot title (the sample size n is appended automatically)
    %   xl     - x-axis label
    %   vlines - optional vector of x positions for red dashed reference lines

    if nargin < 5
        vlines = [];
    end

    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        text(0.5, 0.5, 'no data', 'HorizontalAlignment', 'center');
        set(gca, 'xtick', [], 'ytick', []);
        title(ttl);
        return
    end

    hist(x, bins);
    hold on;
    yl = ylim;
    for v = 1:numel(vlines)
        if ~isnan(vlines(v))
            plot([vlines(v) vlines(v)], yl, 'r--', 'LineWidth', 1.5);
        end
    end
    ylim(yl);
    hold off;

    xlabel(xl);
    ylabel('Count');
    title(sprintf('%s (n=%d)', ttl, numel(x)));
    grid on;
end
