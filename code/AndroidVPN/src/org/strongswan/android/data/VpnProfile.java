/*
 * Copyright (C) 2012 Tobias Brunner
 * Copyright (C) 2012 Giuliano Grassi
 * Copyright (C) 2012 Ralf Sager
 * Hochschule fuer Technik Rapperswil
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 */

package org.strongswan.android.data;

public class VpnProfile implements Cloneable {
	/** google url is for US locale */
	private static final String GOOGLE = "www.google.com";
	/** baidu url is for China locale */
	private static final String BAIDU = "www.baidu.com";
	
	private String mName, mGateway, mUsername, mPassword, mCertificate,
			mUserCertificate, mAutoReconnect, mURLAddress;
	
	
	private VpnType mVpnType;
	private long mId = -1;

	public long getId() {
		return mId;
	}

	public void setId(long id) {
		this.mId = id;
	}

	public String getName() {
		return mName;
	}

	public void setName(String name) {
		this.mName = name;
	}

	public String getGateway() {
		return mGateway;
	}

	public void setGateway(String gateway) {
		this.mGateway = gateway;
	}

	public VpnType getVpnType() {
		return mVpnType;
	}

	public void setVpnType(VpnType type) {
		this.mVpnType = type;
	}

	public String getUsername() {
		return mUsername;
	}

	public void setUsername(String username) {
		this.mUsername = username;
	}

	public String getPassword() {
		return mPassword;
	}

	public void setPassword(String password) {
		this.mPassword = password;
	}

	public String getCertificateAlias() {
		return mCertificate;
	}

	public void setCertificateAlias(String alias) {
		this.mCertificate = alias;
	}

	public String getUserCertificateAlias() {
		return mUserCertificate;
	}

	public void setUserCertificateAlias(String alias) {
		this.mUserCertificate = alias;
	}

	@Override
	public String toString() {
		return mName;
	}

	@Override
	public boolean equals(Object o) {
		if (o != null && o instanceof VpnProfile) {
			return this.mId == ((VpnProfile) o).getId();
		}
		return false;
	}

	@Override
	public VpnProfile clone() {
		try {
			return (VpnProfile) super.clone();
		} catch (CloneNotSupportedException e) {
			throw new AssertionError();
		}
	}


	public String getAutoReconnect() {
		return mAutoReconnect;
	}

	/**
	 * set the auto reconnect check box.
	 * @param mAutoReconnect
	 */
	public void setAutoReconnect(Boolean mAutoReconnect) {
		// mAutoReconnect should only be string "true" or "false"
		this.mAutoReconnect = mAutoReconnect.toString();
	}
	
	/**
	 * set the url address depends on the locale.
	 * @param url
	 */
	public void setURLAddress(String url){
		this.mURLAddress = url;
	}
	
	/**
	 * The position of the spinner corresponding to the url address.<br>
	 * 0 = Google<br>
	 * 1 = baidu<br>
	 * 
	 * @param position
	 */
	public void setURLAddressPosition(int position){
		// default is google.
		String urlAddress = GOOGLE;
		if (position == 1){
			urlAddress = BAIDU;
		}
		this.mURLAddress = urlAddress;
	}
	
	/**
	 * get the position for the spinner.
	 * @return 0 = google, 1 = baidu
	 */
	public int getURLAddressPosition(){
		if (mURLAddress.equals(GOOGLE)){
			return 0;
		} else if (mURLAddress.equals(BAIDU)){
			return 1;
		}
		// default is google
		return 0;
	}
	
	/**
	 * @return the current url address. Should be www.google.com or
	 *         www.baidu.com
	 */
	public String getURLAddress(){
		return mURLAddress;
	}

	/**
	 * 
	 * mAutoReconnect needed to be access by CharonVpnService in order to enable
	 * or disable auto reconnection timer
	 * 
	 * @return true if auto reconnect button is clicked
	 */
	public boolean isAutoReconnectClicked() {
		// defensive programming, make sure mAutoReconnect != null
		return mAutoReconnect != null && mAutoReconnect.equals("true");
	}
}
