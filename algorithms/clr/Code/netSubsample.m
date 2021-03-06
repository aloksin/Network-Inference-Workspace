function [prec, sens, setSize] = netSubsample(data, REPEAT, netMethod, minChips, step, maxChips)
%[prec, sens, setSize] = netSubsample(data, REPEAT, netMethod, minChips,
%step, maxChips)
%
%Determine efficiency of network reconstruction on a subset of data
%
%Inputs:
%data: genes by experiments normalized data matrix
%REPEAT: number of times to subsample with a given number of chips to
%   estimate mean and stddev
%netMethod: clr mode ('rayleigh' (default), 'normal')
%minChips: the fewest chips to build a network with
%step: chip# increment
%maxChips: the largest set size to sample
%
%Outputs:
%Vectors of precision and sensitivity at every set size in the setSize
%   array
%
%Also outputs a plot of reconstruction performance
%

if 1 ~= exist('REPEAT')
	REPEAT = 3;
end

if 1 ~= exist('netMethod')
	netMethod = 'rayleigh';
end

if 1 ~= exist('minChips') || 1 ~= exist('step') || 1 ~= exist('maxChips')
	minChips = 10;
	step = 5;
	maxChips = 80;
end

%--------------------------------------
%find condition clusters
%--------------------------------------
load reg_b3

%find coefficient of variation and pick top 1000 genes
cv = std(data')./mean(data');
[cvsorted, cvidx] = sort(cv, 'descend');
Y = 1 - normcdf(double(clr(data(cvidx(1:1000), :)', netMethod)));

Y = Y - diag(diag(Y));
Y = squareform(Y, 'tovector');

%Y = pdist(r', 'mahal');
Z = linkage(Y, 'complete');
%[H, T, PERM] = dendrogram(Z, length(v3i.conditions), 'orientation', 'left', 'labels', v3i.conditions);
prec = [];
sens = [];
precRand = [];
sensRand = [];
precRandLim = [];
sensRandLim = [];
setSize = {};
for branches = minChips:step:maxChips
    branches
	[H, T, PERM] = dendrogram(Z, branches, 'orientation', 'left');
	for r = 1:REPEAT
		%pick a random set, one node from each cluster
		exptIdx = [];
		for i = 1:max(T)
			idx = find(T == i);
			exptIdx = [exptIdx; idx(floor(rand*length(idx) + 1))];
		end
		%and another, of the same dimensionality, but truly random
		exptIdxRand = [];
		for i = 1:length(exptIdx)			
			e = floor(rand*length(T) + 1);
			while ~isempty(find(exptIdxRand == e))
				e = floor(rand*length(T) + 1);
			end
			exptIdxRand = [exptIdxRand, e];
		end
		%and a third, of the same dimensionality, and random, but from
		%a limited set of clusters (as few as possible, chosen at random)
		exptIdxRandLim = [];
		branchOrder = randperm(branches);
		for i = 1:branches
			idx = find(T == branchOrder(i));
			exptIdxRandLim = [exptIdxRandLim; idx];
			if length(exptIdxRandLim) >= length(exptIdx)
				%keep random experiments to match length(exptIdx)
				idx = randperm(length(exptIdxRandLim));
				exptIdxRandLim = exptIdxRandLim(idx(1:length(exptIdx)));
				break
			end
		end			
		z = clr(data(:, exptIdx), netMethod);
		zRand = clr(data(:, exptIdxRand), netMethod);
		zRandLim = clr(data(:, exptIdxRandLim), netMethod);
		if length(z) == 4217
			z = z(reg_b3.cds_idx, reg_b3.cds_idx);
			zRand = zRand(reg_b3.cds_idx, reg_b3.cds_idx);
			zRandLim = zRandLim(reg_b3.cds_idx, reg_b3.cds_idx);
		end
		z(:, reg_b3.zidxTest) = 0;
		zRand(:, reg_b3.zidxTest) = 0;
		zRandLim(:, reg_b3.zidxTest) = 0;
		[p, s] = matrixPvalue(z, zRand, zRandLim, reg_b3.Atest, length(reg_b3.tfidxTest), 95, .01, 100, 5);
		prec = [prec; p(1, :)];
		sens = [sens; s(1, :)];
		precRand = [precRand; p(2, :)];
		sensRand = [sensRand; s(2, :)];
		precRandLim = [precRandLim; p(3, :)];
		sensRandLim = [sensRandLim; s(3, :)];
		setSize{length(setSize) + 1} = num2str(branches);
	end
end

%maybe try scaling to 10 to get 10% of the range?
prec = round(prec * 100);
precRand = round(precRand * 100);
precRandLim = round(precRandLim * 100);
sens = sens * 100;
sensRand = sensRand * 100;
sensRandLim = sensRandLim * 100;
[r, c] = size(prec);
all = [];
allRand = [];
allRandLim = [];
allStd = [];
allRandStd = [];
allRandLimStd = [];
allBranch = [];
for i = 1:r/REPEAT
	s = [];
	sRand = [];
	sRandLim = [];
	for j = 1:REPEAT
		idx = find(prec((i - 1)*REPEAT + j, :) == 30);
		idxRand = find(precRand((i - 1)*REPEAT + j, :) == 30);
		idxRandLim = find(precRandLim((i - 1)*REPEAT + j, :) == 30);
		
		if isempty(idx)
			s = 0;
		else
			idx = idx(end); %take the right-most point on prec-sens chart
			%mean of prec at this sens
			s = [s, mean(sens((i - 1)*REPEAT + j, idx))];
		end
		if isempty(idxRand)
			sRand = 0;
		else
			idxRand = idxRand(end); %take the right-most point on prec-sens chart
			%mean of prec at this sens
			sRand = [sRand, mean(sensRand((i - 1)*REPEAT + j, idxRand))];
		end
		if isempty(idxRandLim)
			sRandLim = 0;
		else
			idxRandLim = idxRandLim(end); %take the right-most point on prec-sens chart
			%mean of prec at this sens
			sRandLim = [sRandLim, mean(sensRandLim((i - 1)*REPEAT + j, idxRandLim))];
		end
	end
	all = [all, median(s)];
	allRand = [allRand, median(sRand)];
	allRandLim = [allRandLim, median(sRandLim)];
	allStd = [allStd, std(s)];
	allRandStd = [allRandStd, std(sRand)];
	allRandLimStd = [allRandLimStd, std(sRandLim)];
	allBranch = [allBranch, str2double(setSize{(i - 1)*REPEAT + 1})];
end
clf
errorbar(allBranch, all, allStd, 'r-o');
hold on;
errorbar(allBranch, allRand, allRandStd, 'b-o');
errorbar(allBranch, allRandLim, allRandLimStd, 'g-o');
hold off;
title('Number of distant chips vs sensitivity at 30% precision');
xlabel('Number of chips');
ylabel('Sensitivity at 30% precision');
legend({'Informationally most-distant chips', 'Random chips', 'Chips chosen from few random clusters'});