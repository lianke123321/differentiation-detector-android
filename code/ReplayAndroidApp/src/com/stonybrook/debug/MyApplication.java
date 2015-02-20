package com.stonybrook.debug;

import org.acra.ACRA;
import org.acra.ReportField;
import org.acra.ReportingInteractionMode;
import org.acra.annotation.ReportsCrashes;
import org.acra.sender.HttpSender;

import android.app.Application;

import com.stonybrook.replay.R;

@ReportsCrashes(
	    formUri = "https://ankeli.cloudant.com/acra-diffdetector/_design/acra-storage/_update/report",
	    reportType = HttpSender.Type.JSON,
	    httpMethod = HttpSender.Method.POST,
	    formUriBasicAuthLogin = "hentedereartakedstomenti",
	    formUriBasicAuthPassword = "3VpKoQvvkV74GBDGD6uyuy34",
	    formKey = "", // This is required for backward compatibility but not used
	    customReportContent = {
	            ReportField.APP_VERSION_CODE,
	            ReportField.APP_VERSION_NAME,
	            ReportField.ANDROID_VERSION,
	            ReportField.PACKAGE_NAME,
	            ReportField.REPORT_ID,
	            ReportField.BUILD,
	            ReportField.STACK_TRACE
	    },
	    mode = ReportingInteractionMode.TOAST,
	    resToastText = R.string.crash_toast_text
	)

/*@ReportsCrashes(formKey = "", // will not be used
				mailTo = "diffdetector.report@ankeli.me",
				mode = ReportingInteractionMode.TOAST,
				resToastText = R.string.crash_toast_text)*/

public class MyApplication extends Application {
	@Override
	public void onCreate() {
		super.onCreate();

		// The following line triggers the initialization of ACRA
		ACRA.init(this);
	}
}
