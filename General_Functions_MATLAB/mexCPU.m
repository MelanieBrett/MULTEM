function [] = mexCPU(opt, mfile, path, varargin)
nVarargs = length(varargin);
for k = 1:nVarargs
  varargin{k} = strcat(path, '/', char(varargin{k}));
end;

if (opt==1)
    textcomands = strjoin({'mex -g -largeArrayDims', strcat('-I', path), mfile, strjoin(varargin)});      
else
    textcomands = strjoin({'mex -largeArrayDims', strcat('-I', path), mfile, strjoin(varargin)});    
end;

eval(textcomands);