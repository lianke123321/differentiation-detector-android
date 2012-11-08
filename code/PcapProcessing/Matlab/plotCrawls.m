clear;
tic;

lineType = {'b-', 'b--', 'b:' , 'b-.', 'r-', 'r--', 'r:' , 'r-.'};

%toplot
%1: plot number of new IP addresses (and CDF) discovered with time
%2: 
%*************************TO BE CONFIGURED (BEGIN)*************************
disp('******* BEGIN Initial Conf *******');
%       1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40%
toplot=[0 0 0 0 0 0 1 0 1 1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0]

%order scenarios by increasing duration
scenario=[8,7,9,4]
scenario=[9]

%isprint=1 print all the plots
isprint=1;
disp(sprintf('isprint=%i', isprint));

%isprintBW=1 print all the plots in BW for camera ready version. Better
%printing.
isprintBW=1;
disp(sprintf('isprintBW=%i', isprintBW));

%ispause=1 pause before each print
ispause=1;
disp(sprintf('ispause=%i', ispause));

%iscloseall=1 close a plot as soon as it is created.
iscloseall=0;
disp(sprintf('iscloseall=%i', iscloseall));


%Linux
if isunix
    rootDir='/home/alegout/Meddle/';
    resultsDir=[rootDir, 'Results/'];
    savepath=[resultsDir, 'Fig/'];         
%Windows
else
    rootDir='C:\Backup\INRIA\Research\Meddle\localSVN\';
    %fileToLoad=[rootDir, 'tmp.txt'];
    resultsDir=[rootDir, 'Results\'];
    savepath=[resultsDir, 'Fig\'];         
end
savepathbw=[savepath, 'bw_'];

userNames = {'amy-droid', 'arao-droid' , 'arao-ipod', 'arnaud-iphone', 'arvind-iphone', ...
    'dave-ipad', 'dave-iphone', 'dave-stdroid', 'strong-droid', ...
    'justine-droid', 'will-droid', 'wills-ipad'};

%userNames = userNames(4)
for u=userNames
    fileToLoad = [resultsDir, sprintf('%s_frequency.txt', char(u))];
    if ~exist(fileToLoad)
        continue
    end
    M = load(fileToLoad);
    disp('Matrix loaded');
    
    figure; 
    plot(M(:,1), M(:,2));
    globalplotdefs;
    grid on;
    xlabel('time');
    ylabel('number of packets')
    title(sprintf('Number of packets sent with time %s', char(u)))
    %set(gca,'YScale','log');
    printP2P(['frequency_packets', sprintf('_%s', char(u))], isprint, isprintBW, ...
             ispause, savepath, savepathbw, iscloseall);  
    
    figure; 
    plot(M(:,1), M(:,3));
    globalplotdefs;
    grid on;
    xlabel('time');
    ylabel('number of bytes')
    title(sprintf('Number of bytes sent with time %s', char(u)))
    %set(gca,'YScale','log');
    printP2P(['frequency_bytes', sprintf('_%s', char(u))], isprint, isprintBW, ...
             ispause, savepath, savepathbw, iscloseall);   
end



% for s=scenario
%     if toplot(1) || toplot(2) || toplot(3) || toplot(4) || toplot(5)
%         fileToLoad = [resultsDir, sprintf('ipStatsIPContentsMerged_S%d.txt', s)];       
%         M = load(fileToLoad);
%         disp('Matrix loaded');
%         toc;
%     end

%     %[IPaddress, sumPort, maxPort, firstAppear, nbAppear, sumContent,
%     %maxContent]
%     if toplot(1)
%         disp('toplot(1)');
%         figure;
%         snapshots = unique(M(:,4));
%         newIPs = zeros(1,size(snapshots,1));
%         for i=1:length(snapshots)
%             newIPs(i) = size(find(M(:,4)==snapshots(i)),1);
%         end
%         plot(snapshots, newIPs);        
%         globalplotdefs;
%         grid on;
%         xlabel('Snapshot number');
%         ylabel('Number of unique IP addresses');
%         title('New IP addresses Found With Time');   
%         axis([0 max(nbAppear) 0 1])
%         %set(gca,'XScale','log')
%         printP2P(['newIPsWithTime', sprintf('_%d', s)], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);        

        
%         a = cdfplot(ipPort_single);
%         hold on;
%         b = cdfplot(ip_single);
%         c = cdfplot(as_single);
%         set(a,'Color','r', 'LineStyle', '--'); 
%         set(b,'Color','b');
%         set(c,'Color','g', 'LineStyle', ':');
%         globalplotdefs;
%         legend([a, b, c], '(IP,Port)', 'IP', 'AS');
%         grid on;
%         xlabel('#(IP,port), #IP, or #AS');
%         ylabel('CDF of contents');
%         set(gca,'XScale','log');
%         toc;
%     end
% end

% cpt = 1;
% M_S=cell(1,length(scenario));
% for s=scenario
%     if toplot(6)
%         fileToLoad = [resultsDir, sprintf('ipStatsIPContentsMerged_S%d.txt', s)];
%         M_S{cpt} = load(fileToLoad);
%         %M = load([resultsDir,fileToLoad]);
%         disp('Matrix loaded');
%         cpt = cpt + 1;
%         toc;
%     end
% end





