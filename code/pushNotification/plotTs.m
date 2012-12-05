%isprint=1 print all the plots
isprint=1
%isprintBW=1 print all the plots in BW for camera ready version. Better
%printing.
isprintBW=1
%ispause=1 pause before each print
ispause=0
%iscloseall=1 close a plot as soon as it is created.
iscloseall=0



%IUN: Iphone Unplugged NoVPN
rootDir = 'C:\Backup\INRIA\Research\Meddle\code\pushNotification\';
savepath=[rootDir, 'Fig\'];
savepathbw=[rootDir, 'Fig\bw_'];


expeName = 'iphone_wifi_3g_unplug_novpn';
%expeName = 'iphone_wifi_3g_unplug_vpn';
M_IUN_interTs = load([rootDir, 'Traces\', expeName, '_interTs.txt']);
M_IUN_Ts = load([rootDir, 'Traces\', expeName, '_ts.txt']);


figure;
hist(M_IUN_interTs,600);
globalplotdefs;
xlabel('Inter-arrival time (s)');
ylabel('Number');
title('Iphone, Wifi, 3G, unplugged, no VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName,'_interTs'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

figure;
cdfplot(M_IUN_Ts);
globalplotdefs;
xlabel('Packet arrival time (s)');
ylabel('CDF');
title('Iphone, Wifi, 3G, unplugged, no VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName, '_ts'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

expeName = 'iphone_wifi_3g_unplug_novpn_run2';
%expeName = 'iphone_wifi_3g_unplug_vpn';
M_IUN_interTs = load([rootDir, 'Traces\', expeName, '_interTs.txt']);
M_IUN_Ts = load([rootDir, 'Traces\', expeName, '_ts.txt']);


figure;
hist(M_IUN_interTs,600);
globalplotdefs;
xlabel('Inter-arrival time (s)');
ylabel('Number');
title('Iphone, Wifi, 3G, unplugged, no VPN (run2)');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName,'_interTs'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

figure;
cdfplot(M_IUN_Ts);
globalplotdefs;
xlabel('Packet arrival time (s)');
ylabel('CDF');
title('Iphone, Wifi, 3G, unplugged, no VPN (run2)');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName, '_ts'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);


expeName = 'iphone_wifi_3g_unplug_vpn';
%expeName = 'iphone_wifi_3g_unplug_vpn';
M_IUN_interTs = load([rootDir, 'Traces\', expeName, '_interTs.txt']);
M_IUN_Ts = load([rootDir, 'Traces\', expeName, '_ts.txt']);


figure;
hist(M_IUN_interTs,600);
globalplotdefs;
xlabel('Inter-arrival time (s)');
ylabel('Number');
title('Iphone, Wifi, 3G, unplugged, VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName,'_interTs'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

figure;
cdfplot(M_IUN_Ts);
globalplotdefs;
xlabel('Packet arrival time (s)');
ylabel('CDF');
title('Iphone, Wifi, 3G, unplugged, VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName, '_ts'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);


expeName = 'iphone_wifi_3g_unplug_vpn_run2';
%expeName = 'iphone_wifi_3g_unplug_vpn';
M_IUN_interTs = load([rootDir, 'Traces\', expeName, '_interTs.txt']);
M_IUN_Ts = load([rootDir, 'Traces\', expeName, '_ts.txt']);


figure;
hist(M_IUN_interTs,600);
globalplotdefs;
xlabel('Inter-arrival time (s)');
ylabel('Number');
title('Iphone, Wifi, 3G, unplugged, VPN (run2)');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName,'_interTs'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

figure;
cdfplot(M_IUN_Ts);
globalplotdefs;
xlabel('Packet arrival time (s)');
ylabel('CDF');
title('Iphone, Wifi, 3G, unplugged, VPN (run2)');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName, '_ts'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);


expeName = 'iphone_wifi_unplug_vpn';
%expeName = 'iphone_wifi_3g_unplug_vpn';
M_IUN_interTs = load([rootDir, 'Traces\', expeName, '_interTs.txt']);
M_IUN_Ts = load([rootDir, 'Traces\', expeName, '_ts.txt']);


figure;
hist(M_IUN_interTs,600);
globalplotdefs;
xlabel('Inter-arrival time (s)');
ylabel('Number');
title('Iphone, Wifi, unplugged, VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName,'_interTs'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

figure;
cdfplot(M_IUN_Ts);
globalplotdefs;
xlabel('Packet arrival time (s)');
ylabel('CDF');
title('Iphone, Wifi, unplugged, VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName, '_ts'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

expeName = 'iphone_wifi_unplug_novpn';
%expeName = 'iphone_wifi_3g_unplug_vpn';
M_IUN_interTs = load([rootDir, 'Traces\', expeName, '_interTs.txt']);
M_IUN_Ts = load([rootDir, 'Traces\', expeName, '_ts.txt']);


figure;
hist(M_IUN_interTs,600);
globalplotdefs;
xlabel('Inter-arrival time (s)');
ylabel('Number');
title('Iphone, Wifi, unplugged, no VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName,'_interTs'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

figure;
cdfplot(M_IUN_Ts);
globalplotdefs;
xlabel('Packet arrival time (s)');
ylabel('CDF');
title('Iphone, Wifi, unplugged, no VPN');
%set(gca,'YScale','log')
%set(gca,'XLim',[0 Msm]);
printP2P([expeName, '_ts'], isprint, isprintBW, ispause, savepath, savepathbw, iscloseall);

