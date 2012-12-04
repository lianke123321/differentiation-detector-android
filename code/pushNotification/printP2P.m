function [] = printP2P(fileName, isprint, isprintBW, ispause, savepath, savepathbw, iscloseall)

if isprint==1
    if ispause==1
        pause
    end
    print('-depsc',[savepath, fileName])
end
if isprintBW==1
    if ispause==1
        pause
    end
    print('-deps',[savepathbw, fileName])
    close all;
end
if iscloseall==1
    close all;
end