function C = seq(n)

    arguments
        n (1,1) double {mustBePositive, mustBeInteger}
    end

    A = mpptlab.util.style().SeqAnchors;
    if n == 1
        C = A(end, :);
        return
    end
    x  = linspace(0, 1, size(A, 1));
    xq = linspace(0, 1, n);
    C  = [interp1(x, A(:,1), xq)', interp1(x, A(:,2), xq)', interp1(x, A(:,3), xq)'];
end
