function [] = printP2P(fileName, isprint, isprintBW, ispause, savepath, savepathbw, iscloseall)

if isprint==1
    if ispause==1
        pause
    end
    set(gcf,'Renderer', 'painters')
    print('-depsc',[savepath, fileName, '.eps'])
    %print('-djpeg','-r150',[savepath, fileName, '.jpg'])
    print('-dpng',[savepath, fileName, '.png'])
end
if isprintBW==1
    if ispause==1
        pause
    end
    set(gcf,'Renderer', 'painters')
    print('-deps',[savepathbw, fileName, '.eps'])
    %print('-djpeg','-r150',[savepath, fileName, '.jpg'])
    %print('-dpng',[savepath, fileName, '.png'])
    close all;
end
if iscloseall==1
    close all;
end