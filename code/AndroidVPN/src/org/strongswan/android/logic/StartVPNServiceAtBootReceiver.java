/**
 * 
 */
package org.strongswan.android.logic;

import org.strongswan.android.data.VpnProfileDataSource;
import org.strongswan.android.ui.MainActivity;

import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;


/**
 * @author choffnes
 *
 */
public class StartVPNServiceAtBootReceiver extends BroadcastReceiver {

	/* (non-Javadoc)
	 * @see android.content.BroadcastReceiver#onReceive(android.content.Context, android.content.Intent)
	 */
	@Override
	public void onReceive(Context context, Intent intent) {
		Intent intent2 = VpnService.prepare(context);
		if (intent2 != null)
		{
			try
			{
				Intent newIntent = new Intent(context, MainActivity.class);
				newIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				context.startActivity(newIntent);
			}
			catch (ActivityNotFoundException ex)
			{
				/* it seems some devices, even though they come with Android 4,
				 * don't have the VPN components built into the system image.
				 * com.android.vpndialogs/com.android.vpndialogs.ConfirmDialog
				 * will not be found then */
//				showVpnNotSupportedError();
			}
		}
		
//		if ("android.intent.action.BOOT_COMPLETED".equals(intent.getAction())) {
			Intent serviceIntent = new Intent(context, CharonVpnService.class);
			serviceIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
//            Intent serviceIntent = new Intent("org.strongswan.android.logic.CharonVpnService");
            context.startService(serviceIntent);
//        }

	}

}
