function channelVals = collectHarmonicAmplitudes(flightItems, targetCondition, targetHarmonic)
    % Extracts the amplitude at targetHarmonic, for targetCondition, across
    % all four channels (Lateral, Vertikal, Radial, Axial), from a cell
    % array of flight structs. Returns a struct with one numeric vector
    % per channel (raw matched values, not yet averaged).

    channelVals = struct('Lateral', [], 'Vertikal', [], 'Radial', [], 'Axial', []);

    for k = 1:numel(flightItems)
        flight = flightItems{k};
        fftItems = toItems(getFieldOrEmpty(flight, 'FftData'));

        for f = 1:numel(fftItems)
            fftEntry = fftItems{f};
            cond = getFieldOrEmpty(fftEntry, 'TestCondition');
            if ~strcmp(cond, targetCondition)
                continue
            end

            fftRange = getFieldOrEmpty(fftEntry, 'FftRange');
            if isempty(fftRange) || isempty(strfind(fftRange, 'Harmonic'))
                continue
            end

            numMatch = regexp(fftRange, '0-(\d+)[TR]', 'tokens');
            if isempty(numMatch)
                continue
            end
            N = str2double(numMatch{1}{1});

            transducerItems = toItems(getFieldOrEmpty(fftEntry, 'Transducers'));

            for t = 1:numel(transducerItems)
                transducer = transducerItems{t};
                tname = lower(getFieldOrEmpty(transducer, 'Transducer'));
                if isempty(tname), continue; end

                channel = '';
                if ~isempty(strfind(tname, 'lat'))
                    channel = 'Lateral';
                elseif ~isempty(strfind(tname, 'vertikal'))
                    channel = 'Vertikal';
                elseif ~isempty(strfind(tname, 'radial'))
                    channel = 'Radial';
                elseif ~isempty(strfind(tname, 'axial'))
                    channel = 'Axial';
                else
                    continue
                end

                sampleItems = toItems(getFieldOrEmpty(transducer, 'Samples'));
                if isempty(sampleItems), continue; end

                freqs = zeros(numel(sampleItems), 1);
                amps  = zeros(numel(sampleItems), 1);
                for sIdx = 1:numel(sampleItems)
                    freqs(sIdx) = getFieldOrEmpty(sampleItems{sIdx}, 'Frequency');
                    a = getFieldOrEmpty(sampleItems{sIdx}, 'Amplitude');
                    if isempty(a), a = NaN; end
                    amps(sIdx) = a;
                end

                maxFreq = max(freqs);
                if maxFreq <= 0 || N <= 0
                    continue
                end
                fundamental = maxFreq / N;
                targetFreq = fundamental * targetHarmonic;

                [minDiff, bestIdx] = min(abs(freqs - targetFreq));
                stepSize = freqs(2) - freqs(1);
                if minDiff <= stepSize/2 + eps
                    amp = amps(bestIdx);
                    if ~isnan(amp)
                        channelVals.(channel)(end+1) = amp;
                    end
                end
            end
        end
    end
end
